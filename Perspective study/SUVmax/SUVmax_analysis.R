# ==================== 0. 自动安装并加载所需包 ====================
packages <- c("readxl", "dplyr", "tidyr", "purrr", "lme4", "lmerTest", "writexl")

for (pkg in packages) {
  if (!require(pkg, character.only = TRUE)) {
    install.packages(pkg, dependencies = TRUE)
    library(pkg, character.only = TRUE)
  }
}

# 设置 lmer 控制参数：使用 bobyqa 优化器，增加迭代，忽略奇异拟合警告
lmer_control <- lmerControl(
  optimizer = "bobyqa",
  optCtrl = list(maxfun = 100000),
  check.conv.singular = .makeCC(action = "ignore", tol = 1e-4)
)

# ==================== 1. 读取数据 ====================
file_path <- "Retrospective study_SUVmax.xlsx"
df <- read_excel(file_path, sheet = "Sheet1")

cat("数据前几行：\n")
print(head(df))
cat(sprintf("\n总记录数：%d\n", nrow(df)))
cat(sprintf("唯一 Pairing_ID 数：%d\n", length(unique(df$Pairing_ID))))
cat(sprintf("唯一患者数：%d\n", length(unique(df$patient_ID))))

# 检查配对完整性
pair_counts <- df %>% group_by(Pairing_ID) %>% summarise(n = n(), .groups = "drop")
if (any(pair_counts$n != 2)) {
  warning("存在 Pairing_ID 记录数不为2，请检查数据！")
} else {
  cat("每个 Pairing_ID 均有两条记录，配对数据完整。\n")
}

# ==================== 2. 定义变量 ====================
lesion_types <- c("Primary tumor", "Lymph node metastasis", "Bone metastasis",
                  "Pulmonary metastasis", "Liver metastasis", "Other metastasis")
df$LesionType <- factor(df$LesionType, levels = lesion_types, ordered = FALSE)
df$Group <- factor(df$Group, levels = c("CD70", "PSMA"))  
df$logSUVmax <- log(df$SUVmax)

# ==================== 3. 定义辅助函数 ====================
mean_sd_str <- function(x) {
  sprintf("%.2f ± %.2f", mean(x, na.rm = TRUE), sd(x, na.rm = TRUE))
}

# ==================== 4. 各亚组及总病灶的描述统计与配对检验 ====================
all_groups <- c(lesion_types, "All lesions")
results <- list()

for (group in all_groups) {
  if (group == "All lesions") {
    sub_df <- df
  } else {
    sub_df <- df %>% filter(LesionType == group)
  }
  
  if (nrow(sub_df) == 0) {
    cat(sprintf("%s: 无数据，跳过\n", group))
    next
  }
  
  cd70 <- sub_df %>% filter(Group == "CD70") %>% arrange(Pairing_ID) %>% pull(SUVmax)
  psma <- sub_df %>% filter(Group == "PSMA") %>% arrange(Pairing_ID) %>% pull(SUVmax)
  n_pairs <- length(cd70)
  
  if (n_pairs == 0) {
    cat(sprintf("%s: 配对数据为空，跳过\n", group))
    next
  }
  
  cd70_mean_sd <- mean_sd_str(cd70)
  psma_mean_sd <- mean_sd_str(psma)
  diff_vals <- cd70 - psma
  
  if (n_pairs >= 3) {
    shapiro_p <- shapiro.test(diff_vals)$p.value
  } else {
    shapiro_p <- NA
  }
  
  if (n_pairs >= 2) {
    if (!is.na(shapiro_p) && shapiro_p > 0.05) {
      test_method <- "Paired t-test"
      test_res <- t.test(cd70, psma, paired = TRUE)
      p_value <- test_res$p.value
    } else {
      test_method <- "Wilcoxon signed-rank"
      test_res <- wilcox.test(cd70, psma, paired = TRUE, exact = FALSE)
      p_value <- test_res$p.value
    }
  } else {
    test_method <- "N/A"
    p_value <- NA
  }
  
  p_value <- round(p_value, 3)
  
  results[[group]] <- data.frame(
    Group = group,
    N_pairs = n_pairs,
    CD70_mean_std = cd70_mean_sd,
    PSMA_mean_std = psma_mean_sd,
    Test = test_method,
    P_value = p_value,
    stringsAsFactors = FALSE
  )
}

summary_df <- bind_rows(results)
cat("\n==================== 描述统计与配对检验结果 ====================\n")
print(summary_df)

# ==================== 5. 混合效应模型（亚组特定，直接输出 CD70/PSMA 几何均值比） ====================
fit_mixed_model <- function(data, group_name) {
  if (nrow(data) == 0 || length(unique(data$Group)) < 2) {
    return(data.frame(
      Group = group_name,
      Ratio_PSMA_CD70 = NA,
      CI_low = NA,
      CI_high = NA,
      P_val_mixed = NA,
      Model_Status = "No data or single group",
      stringsAsFactors = FALSE
    ))
  }
  
  data$Group <- factor(data$Group, levels = c("CD70", "PSMA"))
  data$Pairing_ID <- factor(data$Pairing_ID)
  data$patient_ID <- factor(data$patient_ID)
  
  tryCatch({
    model <- lmer(logSUVmax ~ Group + (1 | patient_ID) + (1 | Pairing_ID), 
                  data = data, control = lmer_control)
    
    coef_log_PSMA_vs_CD70 <- fixef(model)[2]   # 第2个系数
    se <- sqrt(vcov(model)[2,2])
    p_val <- summary(model)$coefficients[2, "Pr(>|t|)"]
    
    # CD70/PSMA 的几何均值比
    ratio <- round(exp(coef_log_PSMA_vs_CD70), 2)
    
    # 95% Wald CI（对数尺度），并转换到原始尺度
    ci_low_log <- coef_log_PSMA_vs_CD70 - 1.96 * se
    ci_high_log <- coef_log_PSMA_vs_CD70 + 1.96 * se
    ci_low <- round(exp(ci_low_log), 2)
    ci_high <- round(exp(ci_high_log), 2)
    
    p_val <- round(p_val, 3)
    
    return(data.frame(
      Group = group_name,
      Ratio_PSMA_CD70 = ratio,
      CI_low = ci_low,
      CI_high = ci_high,
      P_val_mixed = p_val,
      Model_Status = "Success",
      stringsAsFactors = FALSE
    ))
  }, error = function(e) {
    cat(sprintf("混合模型拟合失败 (%s): %s\n", group_name, e$message))
    return(data.frame(
      Group = group_name,
      Ratio_PSMA_CD70 = NA,
      CI_low = NA,
      CI_high = NA,
      P_val_mixed = NA,
      Model_Status = paste0("Error: ", substr(e$message, 1, 50)),
      stringsAsFactors = FALSE
    ))
  })
}

mixed_results <- list()
for (group in all_groups) {
  if (group == "All lesions") {
    sub_df <- df
  } else {
    sub_df <- df %>% filter(LesionType == group)
  }
  if (nrow(sub_df) == 0) next
  res <- fit_mixed_model(sub_df, group)
  mixed_results[[group]] <- res
}

mixed_df <- bind_rows(mixed_results)
cat("\n==================== 混合效应模型校正结果（CD70/PSMA 几何均值比） ====================\n")
print(mixed_df[, c("Group", "Ratio_PSMA_CD70", "CI_low", "CI_high", "P_val_mixed")])

# ==================== 6. 整体交互效应检验（Group * LesionType） ====================
cat("\n==================== 交互效应检验（Group × LesionType） ====================\n")
model_interaction <- lmer(logSUVmax ~ Group * LesionType + (1 | patient_ID) + (1 | Pairing_ID), 
                          data = df, control = lmer_control)
anova_inter <- anova(model_interaction)
interaction_row <- anova_inter[grepl("Group.*LesionType", rownames(anova_inter)), ]
if (nrow(interaction_row) == 0) {
  interaction_row <- anova_inter[grepl("LesionType.*Group", rownames(anova_inter)), ]
}
print(interaction_row)

interaction_df <- data.frame(
  Effect = "Group:LesionType",
  NumDF = interaction_row$NumDF,
  DenDF = interaction_row$DenDF,
  F_value = round(interaction_row$`F value`, 3),
  P_value = round(interaction_row$`Pr(>F)`, 3),
  stringsAsFactors = FALSE
)
print(interaction_df)

# ==================== 7. 合并最终结果 ====================
final_df <- summary_df %>%
  left_join(mixed_df, by = "Group") %>%
  mutate(`95% CI` = ifelse(!is.na(CI_low), sprintf("[%.2f, %.2f]", CI_low, CI_high), "NA")) %>%
  select(Group, N_pairs, CD70_mean_std, PSMA_mean_std, Test, P_value,
         `Geometric Mean Ratio (PSMA/CD70)` = Ratio_PSMA_CD70,
         `95% CI`,
         P_val_mixed)

cat("\n==================== 最终汇总表（CD70/PSMA 几何均值比及 95% CI） ====================\n")
print(final_df)

# ==================== 8. 保存结果到 Excel ====================
write_xlsx(list(Summary = final_df, 
                MixedModel = mixed_df,
                Interaction = interaction_df), 
           "SUVmax_analysis_Supplementary Table S15.xlsx")