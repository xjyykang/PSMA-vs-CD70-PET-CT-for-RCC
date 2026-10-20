# ================================================================
# 完整分析脚本：CD70 vs PSMA 诊断效能（GLMM + 聚类 Bootstrap 配对比较）
# 包含乐观校正的校准斜率和截距
# ROC曲线无截断值标注，图片尺寸 15×14 cm（双栏）
# 修正：Bootstrap 按患者 ID 整群抽样，保留病灶聚类效应
# 输出有效 Bootstrap 次数
# ================================================================

# 1. 加载所需包
library(readxl)
library(lme4)
library(pROC)
library(dplyr)
library(openxlsx)

# 2. 设置文件路径（请修改为您的实际路径）
data_path <- "AUC.xlsx"        # 输入数据文件
output_excel <- "AUC_Supplementary Table S18,S19,S20.xlsx"      # 输出 Excel 文件
fig_dir <- "Figures"                     # 图片输出文件夹（自动创建）

# 3. 读取数据
data <- read_excel(data_path)
data$LesionType <- as.factor(data$LesionType)
data$patient_ID <- as.factor(data$patient_ID)
data$Pairing_ID <- as.factor(data$Pairing_ID)
data <- data[complete.cases(data[, c("SUVmax", "TBR", "GoldStandard", "LesionType", "patient_ID")]), ]

# ================================================================
# 4. 核心 GLMM 分析函数（含乐观校正校准）
#    修正：Bootstrap 按患者 ID 整群抽样，保留病灶聚类效应
#    返回有效 Bootstrap 次数
# ================================================================
analyze_glmm <- function(df, predictor_col, gold_col = "GoldStandard",
                         n_boot = 1000, seed = 123) {
  df <- df[, c(gold_col, predictor_col, "LesionType", "patient_ID", "Pairing_ID")]
  colnames(df)[2] <- "predictor"
  df <- df[complete.cases(df), ]
  df$predictor_scaled <- scale(df$predictor)
  
  control <- glmerControl(optimizer = "bobyqa", optCtrl = list(maxfun = 2e5))
  model <- try(glmer(GoldStandard ~ predictor_scaled + LesionType + (1 | patient_ID),
                     data = df, family = binomial, control = control, nAGQ = 0),
               silent = TRUE)
  if (inherits(model, "try-error")) {
    control2 <- glmerControl(optimizer = "Nelder_Mead", optCtrl = list(maxfun = 2e5))
    model <- try(glmer(GoldStandard ~ predictor_scaled + LesionType + (1 | patient_ID),
                       data = df, family = binomial, control = control2, nAGQ = 0),
                 silent = TRUE)
  }
  if (inherits(model, "try-error")) return(NULL)
  
  pred_prob <- predict(model, type = "response", re.form = NA)
  
  # ---- 原始校准（Logit-Logit） ----
  cal_model_orig <- glm(df$GoldStandard ~ qlogis(pred_prob), family = binomial)
  cal_slope_orig <- coef(cal_model_orig)[2]
  cal_intercept_orig <- coef(cal_model_orig)[1]
  
  # ---- 原始 ROC ----
  roc_obj <- roc(df$GoldStandard, pred_prob, quiet = TRUE)
  auc_orig <- as.numeric(auc(roc_obj))
  coords_orig <- coords(roc_obj, "best", ret = c("threshold", "sensitivity", "specificity", "youden"),
                        best.method = "youden")
  cutoff_orig <- as.numeric(coords_orig[["threshold"]])
  sens_orig   <- as.numeric(coords_orig[["sensitivity"]])
  spec_orig   <- as.numeric(coords_orig[["specificity"]])
  
  # ============================================================
  # ---- 修改：按患者 ID 整群 Bootstrap ----
  # ============================================================
  set.seed(seed)
  patient_ids <- unique(df$patient_ID)   # 聚类单元
  n_patients <- length(patient_ids)
  
  boot_mat <- matrix(NA, nrow = n_boot, ncol = 4)
  colnames(boot_mat) <- c("AUC", "cutoff", "sens", "spec")
  
  # 用于累积乐观估计
  optimism_slope <- numeric(n_boot)
  optimism_intercept <- numeric(n_boot)
  valid_boot_count <- 0  # 用于校准的有效次数
  
  for (i in 1:n_boot) {
    # 对患者 ID 进行有放回重抽样
    boot_pids <- sample(patient_ids, size = n_patients, replace = TRUE)
    # 拉取这些患者的全部病灶数据
    d <- do.call(rbind, lapply(boot_pids, function(id) {
      df[df$patient_ID == id, ]
    }))
    rownames(d) <- NULL
    
    # 检查数据是否满足建模条件
    if (length(unique(d$GoldStandard)) < 2 || 
        length(unique(d$patient_ID)) < 2 ||
        length(unique(d$predictor)) < 2) {
      boot_mat[i, ] <- c(NA_real_, NA_real_, NA_real_, NA_real_)
      next
    }
    
    d$predictor_scaled <- scale(d$predictor)
    if (anyNA(d$predictor_scaled)) {
      boot_mat[i, ] <- c(NA_real_, NA_real_, NA_real_, NA_real_)
      next
    }
    
    # 拟合 GLMM
    fit <- try(glmer(GoldStandard ~ predictor_scaled + LesionType + (1 | patient_ID),
                     data = d, family = binomial, control = control, nAGQ = 0),
               silent = TRUE)
    if (inherits(fit, "try-error")) {
      fit <- try(glmer(GoldStandard ~ predictor_scaled + LesionType + (1 | patient_ID),
                       data = d, family = binomial, control = control2, nAGQ = 0),
                 silent = TRUE)
    }
    
    res <- c(AUC = NA_real_, cutoff = NA_real_, sens = NA_real_, spec = NA_real_)
    if (!inherits(fit, "try-error")) {
      # 预测 Bootstrap 样本自身
      pred_self <- predict(fit, type = "response", re.form = NA)
      # 预测原始数据（用于乐观校正）
      pred_orig <- predict(fit, newdata = df, type = "response", re.form = NA)
      
      # 校准参数（Bootstrap 样本）
      if (length(unique(pred_self)) > 1) {
        cal_self <- try(glm(d$GoldStandard ~ qlogis(pred_self), family = binomial), silent = TRUE)
        if (!inherits(cal_self, "try-error")) {
          slope_self <- coef(cal_self)[2]
          intercept_self <- coef(cal_self)[1]
        } else {
          slope_self <- NA; intercept_self <- NA
        }
      } else {
        slope_self <- NA; intercept_self <- NA
      }
      
      # 校准参数（原始数据上应用 Bootstrap 模型）
      if (length(unique(pred_orig)) > 1) {
        cal_orig <- try(glm(df$GoldStandard ~ qlogis(pred_orig), family = binomial), silent = TRUE)
        if (!inherits(cal_orig, "try-error")) {
          slope_orig_boot <- coef(cal_orig)[2]
          intercept_orig_boot <- coef(cal_orig)[1]
        } else {
          slope_orig_boot <- NA; intercept_orig_boot <- NA
        }
      } else {
        slope_orig_boot <- NA; intercept_orig_boot <- NA
      }
      
      # 计算乐观值（仅当两者都有效）
      if (!is.na(slope_self) && !is.na(slope_orig_boot)) {
        optimism_slope[valid_boot_count + 1] <- slope_self - slope_orig_boot
        optimism_intercept[valid_boot_count + 1] <- intercept_self - intercept_orig_boot
        valid_boot_count <- valid_boot_count + 1
      }
      
      # ROC 性能（Bootstrap 样本自身）
      pred <- pred_self
      if (length(unique(pred)) > 1) {
        roc_tmp <- try(roc(d$GoldStandard, pred, quiet = TRUE), silent = TRUE)
        if (!inherits(roc_tmp, "try-error")) {
          auc_tmp <- as.numeric(auc(roc_tmp))
          coords_tmp <- try(coords(roc_tmp, "best", ret = c("threshold", "sensitivity", "specificity"),
                                   best.method = "youden"), silent = TRUE)
          if (!inherits(coords_tmp, "try-error")) {
            cutoff_val <- if (length(coords_tmp[["threshold"]]) > 0) as.numeric(coords_tmp[["threshold"]][1]) else NA_real_
            sens_val   <- if (length(coords_tmp[["sensitivity"]]) > 0) as.numeric(coords_tmp[["sensitivity"]][1]) else NA_real_
            spec_val   <- if (length(coords_tmp[["specificity"]]) > 0) as.numeric(coords_tmp[["specificity"]][1]) else NA_real_
            res <- c(AUC = auc_tmp, cutoff = cutoff_val, sens = sens_val, spec = spec_val)
          }
        }
      }
    }
    if (length(res) != 4) res <- c(NA_real_, NA_real_, NA_real_, NA_real_)
    boot_mat[i, ] <- res
  }
  # ============================================================
  # ---- 修改结束 ----
  # ============================================================
  
  # 平均乐观值
  if (valid_boot_count > 0) {
    avg_optimism_slope <- mean(optimism_slope[1:valid_boot_count], na.rm = TRUE)
    avg_optimism_intercept <- mean(optimism_intercept[1:valid_boot_count], na.rm = TRUE)
  } else {
    avg_optimism_slope <- 0
    avg_optimism_intercept <- 0
  }
  
  # 乐观校正后的校准参数
  cal_slope_corrected <- cal_slope_orig - avg_optimism_slope
  cal_intercept_corrected <- cal_intercept_orig - avg_optimism_intercept
  
  # ---- 处理 Bootstrap 性能 ----
  valid <- complete.cases(boot_mat)
  boot_valid <- boot_mat[valid, , drop = FALSE]
  if (nrow(boot_valid) == 0) {
    boot_median <- c(AUC = NA, cutoff = NA, sens = NA, spec = NA)
    boot_ci <- matrix(NA, nrow = 4, ncol = 2)
  } else {
    boot_median <- apply(boot_valid, 2, median, na.rm = TRUE)
    boot_ci <- apply(boot_valid, 2, quantile, probs = c(0.025, 0.975), na.rm = TRUE)
  }
  
  list(
    model = model,
    pred_prob = pred_prob,
    df = df,
    original = list(AUC = auc_orig, cutoff = cutoff_orig, sens = sens_orig, spec = spec_orig),
    bootstrap = list(
      median = boot_median, 
      ci = boot_ci,
      n_valid_perf = nrow(boot_valid),   # 用于性能指标的有效 Bootstrap 次数
      n_valid_cal = valid_boot_count     # 用于校准乐观估计的有效 Bootstrap 次数
    ),
    calibration = list(
      slope_orig = cal_slope_orig,
      intercept_orig = cal_intercept_orig,
      slope_corrected = cal_slope_corrected,
      intercept_corrected = cal_intercept_corrected,
      avg_optimism_slope = avg_optimism_slope,
      avg_optimism_intercept = avg_optimism_intercept
    ),
    roc_obj = roc_obj
  )
}

# ================================================================
# 5. 运行所有组合
# ================================================================
tracers <- c("CD70", "PSMA")
predictors <- c("SUVmax", "TBR")
results <- list()

for (tr in tracers) {
  sub_data <- data[data$Tracer == tr, ]
  for (pred in predictors) {
    cat("拟合", tr, "-", pred, "...\n")
    res <- analyze_glmm(sub_data, pred, n_boot = 1000)
    if (!is.null(res)) {
      key <- paste(tr, pred, sep = "_")
      results[[key]] <- res
    } else {
      cat("  失败\n")
    }
  }
}

# ================================================================
# 6. Sheet1：原始及 Bootstrap 校正结果（含乐观校正后的校准）
# ================================================================
sheet1 <- data.frame(
  Tracer = character(),
  Predictor = character(),
  AUC_orig = numeric(),
  Cutoff_orig = numeric(),
  Sens_orig = numeric(),
  Spec_orig = numeric(),
  AUC_boot = numeric(),
  AUC_CI_lower = numeric(),
  AUC_CI_upper = numeric(),
  Cutoff_boot = numeric(),
  Cutoff_CI_lower = numeric(),
  Cutoff_CI_upper = numeric(),
  Sens_boot = numeric(),
  Sens_CI_lower = numeric(),
  Sens_CI_upper = numeric(),
  Spec_boot = numeric(),
  Spec_CI_lower = numeric(),
  Spec_CI_upper = numeric(),
  Calib_slope_orig = numeric(),
  Calib_intercept_orig = numeric(),
  Calib_slope_corrected = numeric(),
  Calib_intercept_corrected = numeric(),
  stringsAsFactors = FALSE
)

for (key in names(results)) {
  parts <- strsplit(key, "_")[[1]]
  tr <- parts[1]; pred <- parts[2]
  res <- results[[key]]
  orig <- res$original
  boot <- res$bootstrap
  cal <- res$calibration
  sheet1 <- rbind(sheet1, data.frame(
    Tracer = tr,
    Predictor = pred,
    AUC_orig = round(orig$AUC, 3),
    Cutoff_orig = round(orig$cutoff, 3),
    Sens_orig = round(orig$sens, 3),
    Spec_orig = round(orig$spec, 3),
    AUC_boot = round(boot$median["AUC"], 3),
    AUC_CI_lower = round(boot$ci[1, "AUC"], 3),
    AUC_CI_upper = round(boot$ci[2, "AUC"], 3),
    Cutoff_boot = round(boot$median["cutoff"], 3),
    Cutoff_CI_lower = round(boot$ci[1, "cutoff"], 3),
    Cutoff_CI_upper = round(boot$ci[2, "cutoff"], 3),
    Sens_boot = round(boot$median["sens"], 3),
    Sens_CI_lower = round(boot$ci[1, "sens"], 3),
    Sens_CI_upper = round(boot$ci[2, "sens"], 3),
    Spec_boot = round(boot$median["spec"], 3),
    Spec_CI_lower = round(boot$ci[1, "spec"], 3),
    Spec_CI_upper = round(boot$ci[2, "spec"], 3),
    Calib_slope_orig = round(cal$slope_orig, 3),
    Calib_intercept_orig = round(cal$intercept_orig, 3),
    Calib_slope_corrected = round(cal$slope_corrected, 3),
    Calib_intercept_corrected = round(cal$intercept_corrected, 3)
  ))
}

# ================================================================
# 7. Sheet2：各病灶类型反推截断值（不变）
# ================================================================
get_cutoffs_by_lesion <- function(res_obj) {
  model <- res_obj$model
  df <- res_obj$df
  P_cutoff <- res_obj$original$cutoff
  if (is.na(P_cutoff)) return(NULL)
  
  fixef_vals <- fixef(model)
  beta0 <- fixef_vals["(Intercept)"]
  beta1 <- fixef_vals["predictor_scaled"]
  lesion_coefs <- fixef_vals[grepl("LesionType", names(fixef_vals))]
  
  pred_orig <- df$predictor
  mean_pred <- mean(pred_orig, na.rm = TRUE)
  sd_pred <- sd(pred_orig, na.rm = TRUE)
  if (sd_pred == 0) return(NULL)
  
  logit_cut <- log(P_cutoff / (1 - P_cutoff))
  
  levs <- levels(df$LesionType)
  ref_level <- levs[1]
  res <- data.frame(LesionType = levs, Cutoff_raw = NA_real_, stringsAsFactors = FALSE)
  
  cut_ref <- as.numeric(mean_pred + sd_pred * (logit_cut - beta0) / beta1)
  res$Cutoff_raw[res$LesionType == ref_level] <- cut_ref
  for (nm in names(lesion_coefs)) {
    lesion_name <- gsub("LesionType", "", nm)
    coef_val <- lesion_coefs[nm]
    cut_val <- as.numeric(mean_pred + sd_pred * (logit_cut - beta0 - coef_val) / beta1)
    res$Cutoff_raw[res$LesionType == lesion_name] <- cut_val
  }
  res$Cutoff_raw <- round(as.numeric(res$Cutoff_raw), 2)
  res$Interpretation <- ifelse(is.na(res$Cutoff_raw) | is.infinite(res$Cutoff_raw) | 
                                 res$Cutoff_raw < 0 | res$Cutoff_raw > 100,
                               "无临床阈值（几乎全阳/全阴）",
                               paste(">", res$Cutoff_raw))
  return(res)
}

sheet2 <- data.frame()
for (key in names(results)) {
  parts <- strsplit(key, "_")[[1]]
  tr <- parts[1]; pred <- parts[2]
  sub_table <- get_cutoffs_by_lesion(results[[key]])
  if (!is.null(sub_table)) {
    sub_table$Tracer <- tr
    sub_table$Predictor <- pred
    sheet2 <- rbind(sheet2, sub_table[, c("Tracer", "Predictor", "LesionType", "Cutoff_raw", "Interpretation")])
  }
}

# ================================================================
# 8. Sheet3：配对 AUC 比较（不变，已基于患者聚类）
# ================================================================
compare_auc_paired_cluster <- function(pred1, gold1, pred2, gold2, patient_id, B = 1000, seed = 123) {
  auc1 <- as.numeric(auc(roc(gold1, pred1, quiet = TRUE)))
  auc2 <- as.numeric(auc(roc(gold2, pred2, quiet = TRUE)))
  diff_orig <- auc1 - auc2
  
  df <- data.frame(pid = patient_id, gold1 = gold1, pred1 = pred1, gold2 = gold2, pred2 = pred2)
  pids <- unique(df$pid)
  set.seed(seed)
  diff_boot <- numeric(B)
  for (i in 1:B) {
    boot_pids <- sample(pids, size = length(pids), replace = TRUE)
    boot_df <- do.call(rbind, lapply(boot_pids, function(id) df[df$pid == id, ]))
    a1 <- tryCatch(as.numeric(auc(roc(boot_df$gold1, boot_df$pred1, quiet = TRUE))), error = function(e) NA)
    a2 <- tryCatch(as.numeric(auc(roc(boot_df$gold2, boot_df$pred2, quiet = TRUE))), error = function(e) NA)
    if (!is.na(a1) && !is.na(a2)) diff_boot[i] <- a1 - a2
  }
  diff_boot <- diff_boot[!is.na(diff_boot)]
  ci <- quantile(diff_boot, probs = c(0.025, 0.975), na.rm = TRUE)
  
  p_less   <- mean(diff_boot < 0, na.rm = TRUE)
  p_greater <- mean(diff_boot > 0, na.rm = TRUE)
  p_value <- 2 * min(p_less, p_greater)
  
  return(list(diff = diff_orig, ci = ci, p.value = p_value))
}

sheet3 <- data.frame()
for (pred in predictors) {
  cd70_key <- paste("CD70", pred, sep = "_")
  psma_key <- paste("PSMA", pred, sep = "_")
  if (!(cd70_key %in% names(results)) || !(psma_key %in% names(results))) next
  
  cd70_res <- results[[cd70_key]]
  psma_res <- results[[psma_key]]
  
  cd70_auc <- cd70_res$bootstrap$median["AUC"]
  cd70_ci  <- cd70_res$bootstrap$ci[, "AUC"]
  cd70_lower <- cd70_ci[1]
  cd70_upper <- cd70_ci[2]
  
  psma_auc <- psma_res$bootstrap$median["AUC"]
  psma_ci  <- psma_res$bootstrap$ci[, "AUC"]
  psma_lower <- psma_ci[1]
  psma_upper <- psma_ci[2]
  
  cd70_pred <- cd70_res$pred_prob
  cd70_gold <- cd70_res$df$GoldStandard
  cd70_pid  <- cd70_res$df$patient_ID
  cd70_pair <- cd70_res$df$Pairing_ID
  
  psma_pred <- psma_res$pred_prob
  psma_gold <- psma_res$df$GoldStandard
  psma_pid  <- psma_res$df$patient_ID
  psma_pair <- psma_res$df$Pairing_ID
  
  cd70_df <- data.frame(Pairing_ID = cd70_pair, gold = cd70_gold, pred = cd70_pred, patient_ID = cd70_pid)
  psma_df <- data.frame(Pairing_ID = psma_pair, gold = psma_gold, pred = psma_pred, patient_ID = psma_pid)
  merged <- merge(cd70_df, psma_df, by = "Pairing_ID", suffixes = c("_CD70", "_PSMA"))
  
  comp <- compare_auc_paired_cluster(merged$pred_CD70, merged$gold_CD70,
                                     merged$pred_PSMA, merged$gold_PSMA,
                                     patient_id = merged$patient_ID_CD70,
                                     B = 1000)
  
  sheet3 <- rbind(sheet3, data.frame(
    Predictor = pred,
    AUC_CD70 = round(cd70_auc, 3),
    CI_CD70_lower = round(cd70_lower, 3),
    CI_CD70_upper = round(cd70_upper, 3),
    AUC_PSMA = round(psma_auc, 3),
    CI_PSMA_lower = round(psma_lower, 3),
    CI_PSMA_upper = round(psma_upper, 3),
    AUC_Diff = round(comp$diff, 3),
    CI_diff_lower = round(comp$ci[1], 3),
    CI_diff_upper = round(comp$ci[2], 3),
    P_value = round(comp$p.value, 4)
  ))
}

# ================================================================
# 9. 写入 Excel
# ================================================================
wb <- createWorkbook()
addWorksheet(wb, "Sheet1")
writeData(wb, "Sheet1", sheet1)
addWorksheet(wb, "Sheet2")
writeData(wb, "Sheet2", sheet2)
addWorksheet(wb, "Sheet3")
writeData(wb, "Sheet3", sheet3)
saveWorkbook(wb, output_excel, overwrite = TRUE)
cat("Excel 结果已保存至:", output_excel, "\n")

# ================================================================
# 10. 可视化（仅保留 ROC 图）
# ================================================================
if (!dir.exists(fig_dir)) dir.create(fig_dir)

width_cm <- 15
height_cm <- 14

for (pred in predictors) {
  cd70_key <- paste("CD70", pred, sep = "_")
  psma_key <- paste("PSMA", pred, sep = "_")
  if (!(cd70_key %in% names(results)) || !(psma_key %in% names(results))) next
  
  pdf(file = file.path(fig_dir, paste0("ROC_", pred, ".pdf")), 
      width = width_cm / 2.54, 
      height = height_cm / 2.54)
  
  roc1 <- results[[cd70_key]]$roc_obj
  roc2 <- results[[psma_key]]$roc_obj
  
  plot(roc1, col = "#7CA0D4", lwd = 2, 
       main = paste(pred, "- ROC"),
       xlab = "1 - Specificity", ylab = "Sensitivity",
       xaxs = "i", yaxs = "i")
  lines(roc2, col = "#A48AD3", lwd = 2)
  legend("bottomright", legend = c("CD70", "PSMA"), 
         col = c("#7CA0D4", "#A48AD3"), lwd = 2, bty = "n")
  
  grid(nx = 10, ny = 10, col = "gray", lty = 2)
  box()
  dev.off()
  cat("保存 ROC 图:", file.path(fig_dir, paste0("ROC_", pred, ".pdf")), "\n")
}

cat("\nROC 图已保存至目录:", fig_dir, "\n")
cat("图片尺寸：宽", width_cm, "cm，高", height_cm, "cm（双栏）\n")

# ================================================================
# 11. 控制台打印（包含乐观校正结果及有效 Bootstrap 次数）
# ================================================================
n_boot <- 1000  # 用于显示总次数
cat("\n========== 最终结果摘要 ==========\n")
for (key in names(results)) {
  parts <- strsplit(key, "_")[[1]]
  tr <- parts[1]; pred <- parts[2]
  res <- results[[key]]
  orig <- res$original
  boot <- res$bootstrap
  cal <- res$calibration
  cat("\nPredictor:", pred, "   Tracer:", tr, "\n")
  cat("---------- Original ----------\n")
  cat("AUC:", round(orig$AUC, 3), "  Cutoff:", round(orig$cutoff, 3),
      "  Sens:", round(orig$sens, 3), "  Spec:", round(orig$spec, 3), "\n")
  cat("---------- Bootstrap Corrected (median, n=1000) ----------\n")
  cat("AUC:", round(boot$median["AUC"], 3), "  95% CI:", 
      round(boot$ci[1, "AUC"], 3), "-", round(boot$ci[2, "AUC"], 3), "\n")
  cat("Cutoff:", round(boot$median["cutoff"], 3), "  95% CI:", 
      round(boot$ci[1, "cutoff"], 3), "-", round(boot$ci[2, "cutoff"], 3), "\n")
  cat("Sens:", round(boot$median["sens"], 3), "  95% CI:", 
      round(boot$ci[1, "sens"], 3), "-", round(boot$ci[2, "sens"], 3), "\n")
  cat("Spec:", round(boot$median["spec"], 3), "  95% CI:", 
      round(boot$ci[1, "spec"], 3), "-", round(boot$ci[2, "spec"], 3), "\n")
  cat("---------- Bootstrap Details ----------\n")
  cat("有效次数 (AUC/性能):", boot$n_valid_perf, "/", n_boot, "\n")
  cat("有效次数 (校准乐观度):", boot$n_valid_cal, "/", n_boot, "\n")
  cat("---------- Calibration (Original) ----------\n")
  cat("Slope:", round(cal$slope_orig, 3), "  Intercept:", round(cal$intercept_orig, 3), "\n")
  cat("---------- Calibration (Optimism-corrected) ----------\n")
  cat("Slope:", round(cal$slope_corrected, 3), "  Intercept:", round(cal$intercept_corrected, 3), "\n")
}

cat("\n========== 配对比较结果 (Sheet3) ==========\n")
print(sheet3, row.names = FALSE)

cat("\n全部分析完成！\n")