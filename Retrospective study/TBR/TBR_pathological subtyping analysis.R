# ============================================================================
# R脚本：CD70 vs PSMA PET/CT TBR按病理分型比较分析（无可视化）
# 数据文件：回顾性TBR_with_pathological_type.xlsx
# 输出文件：TBR_analysis_results.xlsx（包含3个sheet）
# ============================================================================

# 加载所需包（若未安装，请先运行 install.packages()）
library(readxl)      # 读取Excel
library(dplyr)       # 数据处理
library(tidyr)       # 数据整形
library(lme4)        # 线性混合模型
library(lmerTest)    # 提供p值和分母自由度
library(emmeans)     # 边际均值和对比
library(openxlsx)    # 输出Excel

# ------------------------------ 1. 读取数据 ---------------------------------
data <- read_excel("Retrospective study_TBR.xlsx", 
                   sheet = "Sheet1")  # 根据实际sheet名调整

# 查看数据结构，确认列名
str(data)
# 预期列名：Group, LesionType, TBR, PatientID, type

# 将分类变量转为因子
data$Group <- factor(data$Group, levels = c("PSMA", "CD70"))
data$type  <- factor(data$type, levels = c("ccRCC", "nccRCC"))
data$LesionType <- factor(data$LesionType)
data$PatientID  <- factor(data$PatientID)

# 检查有无缺失
if (any(is.na(data$TBR))) warning("存在缺失值，请检查数据")

# ------------------------------ 2. 描述性统计 ---------------------------------
# 按 Group 和 type 计算病灶数、均值、标准差（针对TBR）
desc <- data %>%
  group_by(Group, type) %>%
  summarise(
    N = n(),
    Mean = mean(TBR),
    SD   = sd(TBR),
    .groups = "drop"
  ) %>%
  mutate(Mean_SD = paste0(round(Mean, 2), " ± ", round(SD, 2)))

# 打印到控制台（可选）
print(desc)

# 转换用于输出Sheet1的宽格式
sheet1_data <- desc %>%
  select(Group, type, N, Mean_SD) %>%
  pivot_wider(names_from = Group, values_from = c(N, Mean_SD), names_sep = "_") %>%
  select(type, starts_with("N_"), starts_with("Mean_SD_"))

# ------------------------------ 3. 传统假设检验（t-test或Mann-Whitney）--------
# 定义函数：对两组TBR进行正态性检验，并根据结果选择检验方法
compare_two_groups <- function(data_sub, group_col, value_col) {
  groups <- unique(data_sub[[group_col]])
  if (length(groups) != 2) stop("必须恰好两组")
  
  g1 <- data_sub[[value_col]][data_sub[[group_col]] == groups[1]]
  g2 <- data_sub[[value_col]][data_sub[[group_col]] == groups[2]]
  
  # Shapiro-Wilk正态性检验（每组样本量需在3~5000之间）
  shapiro_p1 <- if (length(g1) >= 3 && length(g1) <= 5000) shapiro.test(g1)$p.value else NA
  shapiro_p2 <- if (length(g2) >= 3 && length(g2) <= 5000) shapiro.test(g2)$p.value else NA
  
  # 若两组均符合正态（p>0.05）则用t检验，否则用Wilcoxon
  if (!is.na(shapiro_p1) && !is.na(shapiro_p2) && shapiro_p1 > 0.05 && shapiro_p2 > 0.05) {
    test_result <- t.test(g1, g2, var.equal = FALSE)  # Welch's t-test
    method <- "t-test (Welch)"
    p_value <- test_result$p.value
  } else {
    test_result <- wilcox.test(g1, g2)
    method <- "Mann-Whitney U"
    p_value <- test_result$p.value
  }
  
  return(list(method = method, p_value = p_value))
}

# 四个比较：
# 1) ccRCC中 CD70 vs PSMA
ccRCC_data <- filter(data, type == "ccRCC")
comp1 <- compare_two_groups(ccRCC_data, "Group", "TBR")

# 2) nccRCC中 CD70 vs PSMA
nccRCC_data <- filter(data, type == "nccRCC")
comp2 <- compare_two_groups(nccRCC_data, "Group", "TBR")

# 3) CD70组中 ccRCC vs nccRCC
CD70_data <- filter(data, Group == "CD70")
comp3 <- compare_two_groups(CD70_data, "type", "TBR")

# 4) PSMA组中 ccRCC vs nccRCC
PSMA_data <- filter(data, Group == "PSMA")
comp4 <- compare_two_groups(PSMA_data, "type", "TBR")

# 整理传统检验结果
traditional_results <- data.frame(
  Comparison = c("CD70 vs PSMA in ccRCC",
                 "CD70 vs PSMA in nccRCC",
                 "ccRCC vs nccRCC in CD70",
                 "ccRCC vs nccRCC in PSMA"),
  Method = c(comp1$method, comp2$method, comp3$method, comp4$method),
  P_value = c(comp1$p_value, comp2$p_value, comp3$p_value, comp4$p_value)
)

# ------------------------------ 4. 线性混合模型（LMM）校正 ---------------------
# 对TBR取自然对数（确保无零或负值；若有需处理，此处假设均为正数）
data$logTBR <- log(data$TBR)

# 拟合混合模型：固定效应 Group * type + LesionType，随机截距 PatientID
lmm <- lmer(logTBR ~ Group * type + LesionType + (1 | PatientID), data = data)

# 计算ICC（组内相关系数）
var_random <- as.data.frame(VarCorr(lmm))$vcov[1]  # 患者随机效应方差
var_resid <- as.data.frame(VarCorr(lmm))$vcov[2]   # 残差方差
ICC <- var_random / (var_random + var_resid)

# 交互项检验（用于sheet3）
anova_lmm <- anova(lmm)
interaction_row <- which(rownames(anova_lmm) == "Group:type")
if (length(interaction_row) > 0) {
  inter_F <- anova_lmm[interaction_row, "F value"]
  inter_NumDF <- anova_lmm[interaction_row, "NumDF"]
  inter_DenDF <- anova_lmm[interaction_row, "DenDF"]
  inter_P <- anova_lmm[interaction_row, "Pr(>F)"]
} else {
  inter_F <- inter_NumDF <- inter_DenDF <- inter_P <- NA
}

# 使用emmeans计算边际均值对比（简单效应）
# 在每个type内比较Group
emm_group <- emmeans(lmm, ~ Group | type)
ccRCC_contrast <- contrast(emm_group, "pairwise", by = "type")
ccRCC_res <- as.data.frame(ccRCC_contrast)

# 提取ccRCC和nccRCC中 CD70 vs PSMA
ccRCC_cd70_vs_psma <- ccRCC_res[ccRCC_res$type == "ccRCC", ]
nccRCC_cd70_vs_psma <- ccRCC_res[ccRCC_res$type == "nccRCC", ]

# 计算几何均值比及95%CI（TBR的几何均值比）
calc_ratio_ci <- function(row) {
  est <- row$estimate
  se <- row$SE
  df <- row$df
  ratio <- exp(est)
  ci_low <- exp(est - qt(0.975, df) * se)
  ci_high <- exp(est + qt(0.975, df) * se)
  return(data.frame(ratio = ratio, ci_low = ci_low, ci_high = ci_high, p = row$p.value))
}

res_ccRCC <- calc_ratio_ci(ccRCC_cd70_vs_psma)
res_nccRCC <- calc_ratio_ci(nccRCC_cd70_vs_psma)

# 在每个Group内比较type
emm_type <- emmeans(lmm, ~ type | Group)
type_contrast <- contrast(emm_type, "pairwise", by = "Group")
type_res <- as.data.frame(type_contrast)

CD70_ccRCC_vs_nccRCC <- type_res[type_res$Group == "CD70", ]
PSMA_ccRCC_vs_nccRCC <- type_res[type_res$Group == "PSMA", ]

res_CD70 <- calc_ratio_ci(CD70_ccRCC_vs_nccRCC)
res_PSMA <- calc_ratio_ci(PSMA_ccRCC_vs_nccRCC)

# 汇总校正结果
lmm_results <- data.frame(
  Comparison = c("CD70 vs PSMA in ccRCC",
                 "CD70 vs PSMA in nccRCC",
                 "ccRCC vs nccRCC in CD70",
                 "ccRCC vs nccRCC in PSMA"),
  Geom_mean_ratio = c(res_ccRCC$ratio, res_nccRCC$ratio, res_CD70$ratio, res_PSMA$ratio),
  CI_low = c(res_ccRCC$ci_low, res_nccRCC$ci_low, res_CD70$ci_low, res_PSMA$ci_low),
  CI_high = c(res_ccRCC$ci_high, res_nccRCC$ci_high, res_CD70$ci_high, res_PSMA$ci_high),
  P_value_corrected = c(res_ccRCC$p, res_nccRCC$p, res_CD70$p, res_PSMA$p)
)
lmm_results$ICC <- ICC  # 每行都填相同ICC

# ------------------------------ 5. 组合结果输出到Excel -------------------------
wb <- createWorkbook()

# ---- Sheet1: 描述性统计 ----
addWorksheet(wb, "Sheet1")
writeData(wb, "Sheet1", sheet1_data)

# ---- Sheet2: 传统检验和校正后结果 ----
sheet2_data <- traditional_results %>%
  left_join(lmm_results, by = "Comparison") %>%
  select(Comparison, Method, P_value, P_value_corrected, 
         Geom_mean_ratio, CI_low, CI_high, ICC)

# 格式化：保留三位小数，生成CI字符串
sheet2_data <- sheet2_data %>%
  mutate(
    P_value = round(P_value, 3),
    P_value_corrected = round(P_value_corrected, 3),
    Geom_mean_ratio = round(Geom_mean_ratio, 3),
    CI_low = round(CI_low, 3),
    CI_high = round(CI_high, 3),
    ICC = round(ICC, 3),
    CI_95 = paste0("(", CI_low, ", ", CI_high, ")")
  ) %>%
  select(Comparison, Method, P_value, P_value_corrected, 
         Geom_mean_ratio, CI_95, ICC)

addWorksheet(wb, "Sheet2")
writeData(wb, "Sheet2", sheet2_data)

# ---- Sheet3: 交互项F检验 ----
sheet3_data <- data.frame(
  Effect = "Group:type",
  NumDF = inter_NumDF,
  DenDF = inter_DenDF,
  F_value = round(inter_F, 3),
  P_value = round(inter_P, 3)
)
addWorksheet(wb, "Sheet3")
writeData(wb, "Sheet3", sheet3_data)

# 保存Excel文件
saveWorkbook(wb, "TBR_pathological subtyping analysis_Supplementary Table S6.xlsx", overwrite = TRUE)