# ============================================================
# 完整修正版：CD70 vs PSMA 各组SUVmax比较分析（仅ccRCC亚型）
# ============================================================
library(readxl)
library(dplyr)
library(tidyr)
library(lme4)
library(lmerTest)
library(emmeans)
library(openxlsx)

# -------------------- 1. 读取数据 --------------------
file_path <- "Retrospective study_SUVmax.xlsx"
df <- read_excel(file_path, sheet = "Sheet1")

df <- df %>%
  mutate(
    Group = factor(Group, levels = c("CD70", "PSMA")),
    LesionType = factor(LesionType, 
                        levels = c("Primary tumor", "Lymph node metastasis", 
                                   "Bone metastasis", "Pulmonary metastasis", 
                                   "Liver metastasis", "Other metastasis")),
    PatientID = factor(PatientID),
    type = factor(type)  # 保留type列用于筛选
  ) %>%
  # 关键筛选：仅保留ccRCC亚型
  filter(type == "ccRCC")

# -------------------- 2. 描述统计与独立检验 --------------------
lesion_levels <- c(levels(df$LesionType), "All lesions")
desc_stats <- list()
indep_test <- list()

for (les in lesion_levels) {
  sub_df <- if (les == "All lesions") df else filter(df, LesionType == les)
  
  stats <- sub_df %>%
    group_by(Group) %>%
    summarise(n = n(), mean = mean(SUVmax, na.rm = TRUE), sd = sd(SUVmax, na.rm = TRUE)) %>%
    mutate(Label = paste0(round(mean, 2), "±", round(sd, 2)))
  
  stats_wide <- stats %>%
    select(Group, n, Label) %>%
    pivot_wider(names_from = Group, values_from = c(n, Label), names_sep = "_") %>%
    mutate(LesionType = les)
  desc_stats[[les]] <- stats_wide
  
  cd70_vals <- filter(sub_df, Group == "CD70") %>% pull(SUVmax)
  psma_vals <- filter(sub_df, Group == "PSMA") %>% pull(SUVmax)
  shapiro_cd70 <- if (length(cd70_vals) >= 3) shapiro.test(cd70_vals)$p.value else NA
  shapiro_psma <- if (length(psma_vals) >= 3) shapiro.test(psma_vals)$p.value else NA
  
  if (!is.na(shapiro_cd70) && !is.na(shapiro_psma) && shapiro_cd70 > 0.05 && shapiro_psma > 0.05) {
    test_res <- t.test(SUVmax ~ Group, data = sub_df, var.equal = FALSE)
    method <- "Welch t-test"
  } else {
    test_res <- wilcox.test(SUVmax ~ Group, data = sub_df)
    method <- "Mann-Whitney U test"
  }
  indep_test[[les]] <- data.frame(LesionType = les, Method = method, 
                                  Statistic = test_res$statistic, P_value = test_res$p.value)
}

desc_table <- bind_rows(desc_stats) %>%
  select(LesionType, n_CD70, Label_CD70, n_PSMA, Label_PSMA)
indep_table <- bind_rows(indep_test)

# -------------------- 3. 混合效应模型（稳健修正） --------------------
model <- lmer(log(SUVmax) ~ Group * LesionType + (1 | PatientID), 
              data = df, 
              control = lmerControl(optimizer = "bobyqa"))

var_comp <- as.data.frame(VarCorr(model))
icc <- var_comp[1, "vcov"] / (var_comp[1, "vcov"] + var_comp[2, "vcov"])

# 亚组
emm_sub <- emmeans(model, ~ Group | LesionType)
contr_sub <- contrast(emm_sub, method = "pairwise")
sub_summary <- summary(contr_sub, infer = c(TRUE, TRUE), level = 0.95)
sub_results <- data.frame(
  LesionType = sub_summary$LesionType,
  Ratio = exp(sub_summary$estimate),
  Ratio_CI_lower = exp(sub_summary$lower.CL),
  Ratio_CI_upper = exp(sub_summary$upper.CL),
  P_value_adj = sub_summary$p.value
)

# 整体
emm_overall <- emmeans(model, ~ Group)
contr_overall <- contrast(emm_overall, method = "pairwise")
overall_summary <- summary(contr_overall, infer = c(TRUE, TRUE), level = 0.95)
overall_results <- data.frame(
  LesionType = "All lesions",
  Ratio = exp(overall_summary$estimate),
  Ratio_CI_lower = exp(overall_summary$lower.CL),
  Ratio_CI_upper = exp(overall_summary$upper.CL),
  P_value_adj = overall_summary$p.value
)

mixed_result <- bind_rows(sub_results, overall_results)

# 交互项F检验
anova_res <- anova(model)
interaction_row <- anova_res[rownames(anova_res) == "Group:LesionType", ]
interaction_df <- data.frame(
  NumDF = interaction_row$NumDF,
  DenDF = interaction_row$DenDF,
  F_value = interaction_row$`F value`,
  P_value = interaction_row$`Pr(>F)`
)

# -------------------- 4. 输出Excel --------------------
wb <- createWorkbook()
addWorksheet(wb, "Sheet1")
writeData(wb, "Sheet1", desc_table)

sheet2 <- indep_table %>%
  left_join(mixed_result, by = "LesionType") %>%
  mutate(ICC = icc) %>%
  mutate(Ratio_CI = paste0("(", round(Ratio_CI_lower, 3), ", ", round(Ratio_CI_upper, 3), ")")) %>%
  select(LesionType, Method, Statistic, P_value, Ratio, Ratio_CI, P_value_adj, ICC)
addWorksheet(wb, "Sheet2")
writeData(wb, "Sheet2", sheet2)

addWorksheet(wb, "Sheet3")
writeData(wb, "Sheet3", interaction_df)

saveWorkbook(wb, "SUVmax_ccRCC subtype analysis_results.xlsx", overwrite = TRUE)