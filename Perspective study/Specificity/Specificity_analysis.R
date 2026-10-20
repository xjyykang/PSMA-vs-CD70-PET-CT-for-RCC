# ================================================================
# 特异性配对比较 + 敏感性分析（两种场景）+ 贝叶斯等效/非劣效检验
# Bootstrap 采用患者层面聚类重抽样
# ================================================================

library(readxl)
library(dplyr)
library(tidyr)
library(boot)

# ---------- 1. 读取数据 ----------
df <- read_excel("Specificity.xlsx")   # 请修改为实际路径

# ---------- 2. 定义外部不确定病灶的患者ID（真实数据） ----------
uncertain_patient_ids <- c(12, 2, 3, 12, 4, 5, 2, 12, 6, 7, 12, 8, 3, 12, 2, 9, 10, 12, 11)

# ---------- 3. 准备明确阴性病灶 ----------
def_neg <- df %>% filter(GoldStandard == 0)
def_long <- def_neg %>%
  select(Pairing_ID, patient_ID, Tracer, TracerResult)

def_wide <- def_long %>%
  pivot_wider(names_from = Tracer, values_from = TracerResult) %>%
  distinct(Pairing_ID, .keep_all = TRUE)

n_def <- nrow(def_wide)
cat("明确阴性配对病灶数：", n_def, "\n")

# ---------- 4. 合成外部不确定病灶（长格式） ----------
n_unc <- length(uncertain_patient_ids)
cat("外部不确定病灶数：", n_unc, "\n")

max_existing_id <- max(df$Pairing_ID, na.rm = TRUE)
synth_pair_ids <- (max_existing_id + 1):(max_existing_id + n_unc)

generate_unc_rows <- function(pid, pair_id, cd70_val, psma_val) {
  data.frame(
    Pairing_ID = rep(pair_id, 2),
    patient_ID = rep(pid, 2),
    Tracer = c("CD70", "PSMA"),
    TracerResult = c(cd70_val, psma_val),
    stringsAsFactors = FALSE
  )
}

# ---------- 5. 生成两种场景的不确定数据 ----------
# 5.1 最好情况：两者均为 0（真阴性）
df_unc_best <- do.call(rbind, lapply(1:n_unc, function(i) {
  generate_unc_rows(uncertain_patient_ids[i], synth_pair_ids[i], 0, 0)
}))

# 5.2 最坏情况（同步）：两者均为 1（假阳性）
df_unc_worst <- do.call(rbind, lapply(1:n_unc, function(i) {
  generate_unc_rows(uncertain_patient_ids[i], synth_pair_ids[i], 1, 1)
}))

# ---------- 6. 通用分析函数（患者层面 Bootstrap） ----------
combine_and_analyze <- function(unc_long_df, label) {
  comb_long <- bind_rows(def_long, unc_long_df)
  comb_wide <- comb_long %>%
    pivot_wider(names_from = Tracer, values_from = TracerResult) %>%
    distinct(Pairing_ID, .keep_all = TRUE)
  
  n_total <- nrow(comb_wide)
  fp_cd70 <- sum(comb_wide$CD70 == 1, na.rm = TRUE)
  fp_psma <- sum(comb_wide$PSMA == 1, na.rm = TRUE)
  spec_cd70 <- (n_total - fp_cd70) / n_total
  spec_psma <- (n_total - fp_psma) / n_total
  diff <- spec_cd70 - spec_psma
  
  # ----- 患者层面 Bootstrap（1000次）-----
  patients <- unique(comb_wide$patient_ID)
  n_patients <- length(patients)
  R <- 1000
  set.seed(123)
  
  boot_spec_cd70 <- numeric(R)
  boot_spec_psma <- numeric(R)
  boot_diff <- numeric(R)
  
  for (r in 1:R) {
    sampled_patients <- sample(patients, size = n_patients, replace = TRUE)
    boot_df <- do.call(rbind, lapply(sampled_patients, function(pid) {
      comb_wide[comb_wide$patient_ID == pid, ]
    }))
    n_boot <- nrow(boot_df)
    fpc <- sum(boot_df$CD70 == 1, na.rm = TRUE)
    fpp <- sum(boot_df$PSMA == 1, na.rm = TRUE)
    boot_spec_cd70[r] <- (n_boot - fpc) / n_boot
    boot_spec_psma[r] <- (n_boot - fpp) / n_boot
    boot_diff[r] <- boot_spec_cd70[r] - boot_spec_psma[r]
  }
  
  ci_cd70 <- quantile(boot_spec_cd70, c(0.025, 0.975), na.rm = TRUE)
  ci_psma <- quantile(boot_spec_psma, c(0.025, 0.975), na.rm = TRUE)
  ci_diff <- quantile(boot_diff, c(0.025, 0.975), na.rm = TRUE)
  
  cat("\n========== ", label, " ==========\n")
  cat("总病灶数：", n_total, "\n")
  cat("CD70 特异性 =", round(spec_cd70, 4),
      " (95% CI: ", round(ci_cd70[1], 4), "–", round(ci_cd70[2], 4), ")\n")
  cat("PSMA 特异性 =", round(spec_psma, 4),
      " (95% CI: ", round(ci_psma[1], 4), "–", round(ci_psma[2], 4), ")\n")
  cat("差值 (CD70 - PSMA) =", round(diff, 4),
      " (95% CI: ", round(ci_diff[1], 4), " – ", round(ci_diff[2], 4), ")\n")
  
  return(list(
    n = n_total,
    spec_cd70 = spec_cd70, spec_psma = spec_psma, diff = diff,
    ci_cd70 = ci_cd70, ci_psma = ci_psma, ci_diff = ci_diff
  ))
}

# ---------- 7. 原始结果（明确阴性） ----------
cat("\n========== 原始特异性（明确阴性，n=36）==========\n")
fp_cd70 <- sum(def_wide$CD70 == 1, na.rm = TRUE)
fp_psma <- sum(def_wide$PSMA == 1, na.rm = TRUE)
tn_cd70 <- n_def - fp_cd70
tn_psma <- n_def - fp_psma
spec_cd70_raw <- tn_cd70 / n_def
spec_psma_raw <- tn_psma / n_def
diff_raw <- spec_cd70_raw - spec_psma_raw

# 患者层面 Bootstrap 用于原始差值 CI
patients_raw <- unique(def_wide$patient_ID)
n_pat_raw <- length(patients_raw)
R_raw <- 1000
set.seed(123)
boot_diff_raw <- numeric(R_raw)
for (r in 1:R_raw) {
  sampled_pat <- sample(patients_raw, size = n_pat_raw, replace = TRUE)
  boot_df <- do.call(rbind, lapply(sampled_pat, function(pid) {
    def_wide[def_wide$patient_ID == pid, ]
  }))
  n_b <- nrow(boot_df)
  fpc <- sum(boot_df$CD70 == 1, na.rm = TRUE)
  fpp <- sum(boot_df$PSMA == 1, na.rm = TRUE)
  boot_diff_raw[r] <- (n_b - fpc)/n_b - (n_b - fpp)/n_b
}
ci_diff_raw <- quantile(boot_diff_raw, c(0.025, 0.975), na.rm = TRUE)

# 单组 CI 使用 Clopper-Pearson（基于二项分布）
ci_cd70_raw <- binom.test(tn_cd70, n_def)$conf.int
ci_psma_raw <- binom.test(tn_psma, n_def)$conf.int

cat("CD70 特异性：", round(spec_cd70_raw, 4),
    " (95% CI: ", round(ci_cd70_raw[1], 4), "–", round(ci_cd70_raw[2], 4), ")\n")
cat("PSMA 特异性：", round(spec_psma_raw, 4),
    " (95% CI: ", round(ci_psma_raw[1], 4), "–", round(ci_psma_raw[2], 4), ")\n")
cat("差值 (CD70 - PSMA)：", round(diff_raw, 4),
    " (95% CI: ", round(ci_diff_raw[1], 4), " – ", round(ci_diff_raw[2], 4), ")\n")

# ---------- 8. 敏感性分析（两种场景） ----------
best_res  <- combine_and_analyze(df_unc_best,  "最好情况（外部19个全真阴性，分母=55）")
worst_res <- combine_and_analyze(df_unc_worst, "最坏情况（外部19个全假阳性，分母=55）")

# ---------- 9. 贝叶斯分析（基于明确阴性，Beta(1,1) 先验） ----------
post_alpha_cd70 <- tn_cd70 + 1
post_beta_cd70  <- fp_cd70 + 1
post_alpha_psma <- tn_psma + 1
post_beta_psma  <- fp_psma + 1

set.seed(123)
n_sim <- 100000
sim_cd70 <- rbeta(n_sim, post_alpha_cd70, post_beta_cd70)
sim_psma <- rbeta(n_sim, post_alpha_psma, post_beta_psma)
diff_post <- sim_cd70 - sim_psma

post_mean_cd70 <- mean(sim_cd70)
post_mean_psma <- mean(sim_psma)
post_mean_diff <- mean(diff_post)
ci_cd70_post <- quantile(sim_cd70, c(0.025, 0.975))
ci_psma_post <- quantile(sim_psma, c(0.025, 0.975))
ci_diff_post <- quantile(diff_post, c(0.025, 0.975))

delta <- 0.10
prob_equiv <- mean(diff_post > -delta & diff_post < delta)
prob_noninf <- mean(diff_post < delta)
prob_psma_better <- mean(diff_post < 0)

cat("\n========== 贝叶斯分析（Beta(1,1) 先验，基于明确阴性 n=36）==========\n")
cat("CD70 特异性：均值 =", round(post_mean_cd70, 4),
    ", 95% CrI =", round(ci_cd70_post[1], 4), "–", round(ci_cd70_post[2], 4), "\n")
cat("PSMA 特异性：均值 =", round(post_mean_psma, 4),
    ", 95% CrI =", round(ci_psma_post[1], 4), "–", round(ci_psma_post[2], 4), "\n")
cat("差值 (CD70 - PSMA) 后验：均值 =", round(post_mean_diff, 4),
    ", 95% CrI =", round(ci_diff_post[1], 4), "–", round(ci_diff_post[2], 4), "\n")
cat("等效后验概率（差值在 ±10% 内）：", round(prob_equiv, 4), "\n")
cat("非劣效后验概率（差值 < 10%，即 PSMA 不劣于 CD70）：", round(prob_noninf, 4), "\n")
cat("PSMA 优于 CD70 的后验概率（差值 < 0）：", round(prob_psma_better, 4), "\n")

if (prob_equiv >= 0.95) {
  cat("结论：可认为等效（后验概率≥95%）\n")
} else {
  cat("结论：未能证明等效（后验概率<95%）\n")
}
if (prob_noninf >= 0.95) {
  cat("结论：可认为非劣效（后验概率≥95%）\n")
} else {
  cat("结论：未能证明非劣效（后验概率<95%）\n")
}

# ---------- 10. 汇总表格 ----------
results_df <- data.frame(
  Scenario = c("Original (n=36)", "Best-case (n=55)", "Worst-case (n=55)"),
  CD70_spec = c(spec_cd70_raw, best_res$spec_cd70, worst_res$spec_cd70),
  CD70_CI_lower = c(ci_cd70_raw[1], best_res$ci_cd70[1], worst_res$ci_cd70[1]),
  CD70_CI_upper = c(ci_cd70_raw[2], best_res$ci_cd70[2], worst_res$ci_cd70[2]),
  PSMA_spec = c(spec_psma_raw, best_res$spec_psma, worst_res$spec_psma),
  PSMA_CI_lower = c(ci_psma_raw[1], best_res$ci_psma[1], worst_res$ci_psma[1]),
  PSMA_CI_upper = c(ci_psma_raw[2], best_res$ci_psma[2], worst_res$ci_psma[2]),
  Diff = c(diff_raw, best_res$diff, worst_res$diff),
  Diff_CI_lower = c(ci_diff_raw[1], best_res$ci_diff[1], worst_res$ci_diff[1]),
  Diff_CI_upper = c(ci_diff_raw[2], best_res$ci_diff[2], worst_res$ci_diff[2])
)

cat("\n========== 完整结果汇总 ==========\n")
print(results_df, digits = 4)

cat("\n========== 贝叶斯概率汇总（Δ=10%）==========\n")
cat("等效后验概率：", round(prob_equiv, 4), "\n")
cat("非劣效后验概率：", round(prob_noninf, 4), "\n")
cat("PSMA 优于 CD70 概率：", round(prob_psma_better, 4), "\n")

# ================================================================
# 11. 输出结果到 Excel
# ================================================================
if (!requireNamespace("openxlsx", quietly = TRUE)) {
  install.packages("openxlsx")
}
library(openxlsx)

# ---------- 11.1 贝叶斯结果汇总 ----------
bayes_summary <- data.frame(
  Metric = c(
    "CD70 特异性后验均值",
    "CD70 95% CrI 下限",
    "CD70 95% CrI 上限",
    "PSMA 特异性后验均值",
    "PSMA 95% CrI 下限",
    "PSMA 95% CrI 上限",
    "差值(CD70-PSMA)后验均值",
    "差值 95% CrI 下限",
    "差值 95% CrI 上限",
    "等效后验概率(±10%)",
    "非劣效后验概率(<10%)",
    "PSMA 优于 CD70 后验概率(<0)"
  ),
  Value = c(
    post_mean_cd70, ci_cd70_post[1], ci_cd70_post[2],
    post_mean_psma, ci_psma_post[1], ci_psma_post[2],
    post_mean_diff, ci_diff_post[1], ci_diff_post[2],
    prob_equiv, prob_noninf, prob_psma_better
  )
)

# ---------- 11.2 贝叶斯结论表 ----------
conclusion_df <- data.frame(
  Test = c("Equivalence", "Non-inferiority"),
  Posterior_Probability = c(prob_equiv, prob_noninf),
  Threshold = c(0.95, 0.95),
  Conclusion = c(
    ifelse(prob_equiv >= 0.95, "可认为等效", "未能证明等效"),
    ifelse(prob_noninf >= 0.95, "可认为非劣效", "未能证明非劣效")
  )
)

# ---------- 11.3 最好情况 / 最坏情况单独表 ----------
best_df <- data.frame(
  Scenario = "Best-case",
  n = best_res$n,
  CD70_spec = best_res$spec_cd70,
  CD70_CI_lower = best_res$ci_cd70[1],
  CD70_CI_upper = best_res$ci_cd70[2],
  PSMA_spec = best_res$spec_psma,
  PSMA_CI_lower = best_res$ci_psma[1],
  PSMA_CI_upper = best_res$ci_psma[2],
  Diff = best_res$diff,
  Diff_CI_lower = best_res$ci_diff[1],
  Diff_CI_upper = best_res$ci_diff[2]
)

worst_df <- data.frame(
  Scenario = "Worst-case",
  n = worst_res$n,
  CD70_spec = worst_res$spec_cd70,
  CD70_CI_lower = worst_res$ci_cd70[1],
  CD70_CI_upper = worst_res$ci_cd70[2],
  PSMA_spec = worst_res$spec_psma,
  PSMA_CI_lower = worst_res$ci_psma[1],
  PSMA_CI_upper = worst_res$ci_psma[2],
  Diff = worst_res$diff,
  Diff_CI_lower = worst_res$ci_diff[1],
  Diff_CI_upper = worst_res$ci_diff[2]
)

# ---------- 11.4 写入 Excel ----------
wb <- createWorkbook()

addWorksheet(wb, "Scenario_Summary")
writeData(wb, "Scenario_Summary", results_df)

addWorksheet(wb, "Bayesian_Summary")
writeData(wb, "Bayesian_Summary", bayes_summary)

addWorksheet(wb, "Conclusion")
writeData(wb, "Conclusion", conclusion_df)

addWorksheet(wb, "Best_case")
writeData(wb, "Best_case", best_df)

addWorksheet(wb, "Worst_case")
writeData(wb, "Worst_case", worst_df)

addWorksheet(wb, "Def_neg_wide")
writeData(wb, "Def_neg_wide", def_wide)

# 输出文件，可自行修改路径
output_file <- "Specificity_analysis_Supplementary Table S17.xlsx"
saveWorkbook(wb, output_file, overwrite = TRUE)