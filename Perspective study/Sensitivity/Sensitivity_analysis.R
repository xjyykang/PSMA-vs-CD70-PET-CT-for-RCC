# =============================================================================
# R Script: Sensitivity Comparison (CD70 vs PSMA) 
# Method: Patient-level cluster bootstrap (1000 resamples)
# Output: LesionType, Sens_CD70, Sens_CD70_CI, Sens_PSMA, Sens_PSMA_CI,
#         Diff_Sensitivity, Diff_CI, P_raw (Bootstrap)
# No automatic FDR correction
# =============================================================================

library(readxl)
library(dplyr)
library(tidyr)
library(openxlsx)

# ----------------------------- 1. Read data -----------------------------
data <- read_excel("Sensitivity.xlsx", sheet = 1)
data$Tracer <- factor(data$Tracer, levels = c("CD70", "PSMA"))
data$GoldStandard <- as.integer(data$GoldStandard)
data$TracerResult <- as.integer(data$TracerResult)
data$patient_ID <- as.factor(data$patient_ID)

# ----------------------------- 2. Define groups -----------------------------
groups <- c("Primary tumor", "Lymph node metastasis", "Bone metastasis", 
            "Pulmonary metastasis", "Liver metastasis", "Other metastasis",
            "All metastasis", "All lesions")

# ----------------------------- 3. Helper functions -----------------------------

# Clopper-Pearson CI for a single sensitivity
calc_sensitivity <- function(df, tracer) {
  sub <- df %>% filter(Tracer == tracer)
  TP <- sum(sub$GoldStandard == 1 & sub$TracerResult == 1)
  FN <- sum(sub$GoldStandard == 1 & sub$TracerResult == 0)
  N_pos <- TP + FN
  sens <- if (N_pos > 0) TP/N_pos else NA
  sens_ci <- if (!is.na(sens) && N_pos > 0) {
    ci <- binom.test(TP, N_pos, conf.level = 0.95)$conf.int
    paste0("(", sprintf("%.3f", ci[1]), ",", sprintf("%.3f", ci[2]), ")")
  } else { NA_character_ }
  return(list(estimate = sens, ci_str = sens_ci))
}

# ---------- Patient-level cluster bootstrap for sensitivity difference ----------
boot_sens_diff <- function(df, R = 1000) {
  sub <- df %>% filter(GoldStandard == 1)
  if (nrow(sub) == 0 || n_distinct(sub$patient_ID) < 2) {
    return(list(diff = NA, lci = NA, uci = NA, p = NA))
  }
  
  patients <- unique(sub$patient_ID)
  n_patients <- length(patients)
  boot_diffs <- numeric(R)
  
  set.seed(20260827)
  for (r in 1:R) {
    sampled_patients <- sample(patients, size = n_patients, replace = TRUE)
    boot_df <- do.call(rbind, lapply(sampled_patients, function(pid) {
      sub[sub$patient_ID == pid, ]
    }))
    sens_cd70 <- mean(boot_df$TracerResult[boot_df$Tracer == "CD70"], na.rm = TRUE)
    sens_psma <- mean(boot_df$TracerResult[boot_df$Tracer == "PSMA"], na.rm = TRUE)
    boot_diffs[r] <- sens_cd70 - sens_psma
  }
  
  diff_est <- mean(sub$TracerResult[sub$Tracer == "CD70"], na.rm = TRUE) - 
    mean(sub$TracerResult[sub$Tracer == "PSMA"], na.rm = TRUE)
  
  lci <- quantile(boot_diffs, probs = 0.025, na.rm = TRUE)
  uci <- quantile(boot_diffs, probs = 0.975, na.rm = TRUE)
  
  p_val <- 2 * min(mean(boot_diffs <= 0, na.rm = TRUE), 
                   mean(boot_diffs >= 0, na.rm = TRUE))
  p_val <- min(p_val, 1)
  
  return(list(diff = diff_est, lci = lci, uci = uci, p = p_val))
}

# ----------------------------- 4. Main analysis loop -----------------------------
table_data <- list()

for (grp in groups) {
  cat("Processing subgroup:", grp, "\n")
  
  # Build df_grp based on group type — each lesion appears in only one subgroup
  if (grp == "All lesions") {
    df_grp <- data
  } else if (grp == "All metastasis") {
    df_grp <- data %>% filter(grepl("metastasis", LesionType, ignore.case = TRUE))
  } else {
    # Specific lesion type
    df_grp <- data %>% filter(LesionType == grp)
  }
  
  if (nrow(df_grp) == 0) next
  
  sens_cd70 <- calc_sensitivity(df_grp, "CD70")
  sens_psma <- calc_sensitivity(df_grp, "PSMA")
  boot_out <- boot_sens_diff(df_grp, R = 1000)
  
  row <- data.frame(
    LesionType = grp,
    Sens_CD70 = sprintf("%.3f", sens_cd70$estimate),
    Sens_CD70_CI = sens_cd70$ci_str,
    Sens_PSMA = sprintf("%.3f", sens_psma$estimate),
    Sens_PSMA_CI = sens_psma$ci_str,
    Diff_Sensitivity = sprintf("%.3f", boot_out$diff),
    Diff_CI = paste0("(", sprintf("%.3f", boot_out$lci), ",", sprintf("%.3f", boot_out$uci), ")"),
    P_raw = ifelse(is.na(boot_out$p), NA, sprintf("%.3f", boot_out$p)),
    stringsAsFactors = FALSE
  )
  table_data[[grp]] <- row
}

results <- bind_rows(table_data)

# ----------------------------- 5. Write to Excel (no Q_FDR) -----------------------------
wb <- createWorkbook()
addWorksheet(wb, "Sensitivity_analysis_TABLE 2")
writeData(wb, "Sensitivity_analysis_TABLE 2", results)
saveWorkbook(wb, "Sensitivity_analysis_TABLE 2.xlsx", overwrite = TRUE)