# ================================================================
# 完整分析脚本（含总体及亚组率差，Bootstrap患者层面聚类）
# 1. 亚组和总体检出率（Clopper-Pearson 95% CI）
# 2. 患者层面聚类Bootstrap（1000次）率差及置信区间、P值
# 3. 结果输出到 Excel
# ================================================================

# ----- 1. 安装和加载包 -----
required_packages <- c("dplyr", "readxl", "openxlsx")

install_if_missing <- function(pkg) {
  if (!require(pkg, character.only = TRUE)) {
    install.packages(pkg)
    library(pkg, character.only = TRUE)
  }
}
invisible(lapply(required_packages, install_if_missing))

# ----- 2. Clopper-Pearson 函数 -----
clopper_pearson <- function(x, n, conf.level = 0.95) {
  if (n == 0) return(c(est = NA, lcl = NA, ucl = NA))
  alpha <- 1 - conf.level
  if (x == 0) {
    lcl <- 0
    ucl <- 1 - (alpha/2)^(1/n)
  } else if (x == n) {
    lcl <- (alpha/2)^(1/n)
    ucl <- 1
  } else {
    lcl <- qbeta(alpha/2, x, n - x + 1)
    ucl <- qbeta(1 - alpha/2, x + 1, n - x)
  }
  return(c(est = x/n, lcl = lcl, ucl = ucl))
}

# ----- 3. 读取数据 -----
df <- read_excel("Detection rates.xlsx", sheet = "Sheet1")
names(df) <- c("Group", "LesionType", "SUVmax", "PatientID", "type", "Detection")
df$Detection <- as.numeric(df$Detection == "Yes")
df$Group     <- as.factor(df$Group)
df$type      <- as.factor(df$type)
df$PatientID <- as.factor(df$PatientID)
if (any(is.na(df$Detection))) stop("检测到缺失值")

# ----- 4. 亚组及总体检出率 (Clopper-Pearson) -----
groups <- list(
  ccRCC_CD70  = df$Group == "CD70" & df$type == "ccRCC",
  ccRCC_PSMA  = df$Group == "PSMA" & df$type == "ccRCC",
  nccRCC_CD70 = df$Group == "CD70" & df$type == "nccRCC",
  nccRCC_PSMA = df$Group == "PSMA" & df$type == "nccRCC"
)

rate_list <- lapply(names(groups), function(name) {
  idx <- groups[[name]]
  x <- sum(df$Detection[idx])
  n <- sum(idx)
  ci <- clopper_pearson(x, n)
  data.frame(Subgroup = name, x = x, n = n,
             rate_percent     = ci["est"] * 100,
             CI_lower_percent = ci["lcl"] * 100,
             CI_upper_percent = ci["ucl"] * 100,
             stringsAsFactors = FALSE)
})
rate_table <- do.call(rbind, rate_list)
rownames(rate_table) <- NULL

overall_groups <- list(
  CD70_overall = df$Group == "CD70",
  PSMA_overall = df$Group == "PSMA"
)
overall_list <- lapply(names(overall_groups), function(name) {
  idx <- overall_groups[[name]]
  x <- sum(df$Detection[idx])
  n <- sum(idx)
  ci <- clopper_pearson(x, n)
  data.frame(Subgroup = name, x = x, n = n,
             rate_percent     = ci["est"] * 100,
             CI_lower_percent = ci["lcl"] * 100,
             CI_upper_percent = ci["ucl"] * 100,
             stringsAsFactors = FALSE)
})
overall_table <- do.call(rbind, overall_list)
rownames(overall_table) <- NULL

cat("\n========== 检出率 (Clopper-Pearson 95% CI) ==========\n")
cat("\n--- 亚组 ---\n"); print(rate_table)
cat("\n--- 总体 ---\n"); print(overall_table)

# ----- 5. 患者层面聚类 Bootstrap（1000 次）-----
safe_mean <- function(x) if (length(x) == 0) NA_real_ else mean(x, na.rm = TRUE)

# 计算一组率差的辅助函数
calc_diffs <- function(d) {
  p_cc_cd70  <- safe_mean(d$Detection[d$Group == "CD70" & d$type == "ccRCC"])
  p_cc_psma  <- safe_mean(d$Detection[d$Group == "PSMA" & d$type == "ccRCC"])
  p_ncc_cd70 <- safe_mean(d$Detection[d$Group == "CD70" & d$type == "nccRCC"])
  p_ncc_psma <- safe_mean(d$Detection[d$Group == "PSMA" & d$type == "nccRCC"])
  p_cd70_all <- safe_mean(d$Detection[d$Group == "CD70"])
  p_psma_all <- safe_mean(d$Detection[d$Group == "PSMA"])
  
  c(diff_cc_CD70vsPSMA      = p_cc_cd70  - p_cc_psma,
    diff_ncc_CD70vsPSMA     = p_ncc_cd70 - p_ncc_psma,
    diff_CD70_ccvsncc       = p_cc_cd70  - p_ncc_cd70,
    diff_PSMA_ccvsncc       = p_cc_psma  - p_ncc_psma,
    diff_overall_CD70vsPSMA = p_cd70_all - p_psma_all)
}

# 预先按患者拆分，避免循环内反复过滤
df_by_patient <- split(df, df$PatientID)
patient_ids   <- names(df_by_patient)
n_patients    <- length(patient_ids)

set.seed(20260827)
B <- 1000
boot_mat <- matrix(NA_real_, nrow = B, ncol = 5)
colnames(boot_mat) <- names(calc_diffs(df))

for (b in seq_len(B)) {
  sampled_ids <- sample(patient_ids, size = n_patients, replace = TRUE)
  boot_df     <- do.call(rbind, df_by_patient[sampled_ids])
  boot_mat[b, ] <- calc_diffs(boot_df)
}

boot_est <- calc_diffs(df)
boot_lcl <- apply(boot_mat, 2, quantile, probs = 0.025, na.rm = TRUE)
boot_ucl <- apply(boot_mat, 2, quantile, probs = 0.975, na.rm = TRUE)
boot_p   <- apply(boot_mat, 2, function(x) {
  x <- x[!is.na(x)]
  if (length(x) == 0) return(NA_real_)
  min(2 * min(mean(x <= 0), mean(x >= 0)), 1)
})

comparisons <- c("ccRCC: CD70 vs PSMA",
                 "nccRCC: CD70 vs PSMA",
                 "CD70: ccRCC vs nccRCC",
                 "PSMA: ccRCC vs nccRCC",
                 "Overall: CD70 vs PSMA")

boot_results <- data.frame(
  Comparison    = comparisons,
  estimate      = as.numeric(boot_est),
  lcl           = as.numeric(boot_lcl),
  ucl           = as.numeric(boot_ucl),
  p             = as.numeric(boot_p),
  estimate_perc = as.numeric(boot_est) * 100,
  lcl_perc      = as.numeric(boot_lcl) * 100,
  ucl_perc      = as.numeric(boot_ucl) * 100,
  row.names = NULL, stringsAsFactors = FALSE
)

cat("\n\n========== 患者层面聚类Bootstrap率差 (1000次, 百分位数CI) ==========\n")
print(boot_results[, c("Comparison", "estimate_perc", "lcl_perc", "ucl_perc", "p")])

# ----- 6. 输出到 Excel -----
wb <- createWorkbook()
addWorksheet(wb, "亚组检出率")
writeData(wb, "亚组检出率", rate_table)

addWorksheet(wb, "总体检出率")
writeData(wb, "总体检出率", overall_table)

addWorksheet(wb, "Bootstrap率差比较")
writeData(wb, "Bootstrap率差比较",
          boot_results[, c("Comparison", "estimate_perc", "lcl_perc", "ucl_perc", "p")])

saveWorkbook(wb, "Detection rates_Supplementary Table S9,S10.xlsx", overwrite = TRUE)