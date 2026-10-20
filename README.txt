# Code and Data for: Comparison of PSMA- and CD70-targeted PET/CT in RCC
 
**Title:** Comparison of PSMA- and CD70-targeted PET/CT in Diagnosing Renal Cell Carcinoma: A Retrospective Cohort and Prospective Head-to-head Study

This repository contains the de-identified data and custom R scripts used for the statistical analyses in the above manuscript. The repository is organized into two main modules corresponding to the study design: the **Retrospective Cohort** and the **Prospective Head-to-head Study**.

---

## Directory Structure

### 1. `01_Retrospective_Cohort/`
This module contains the analyses based on the retrospective cohort of 128 patients with pathologically confirmed RCC.
*   **`01_Detection_Rates/`**: Subgroup and overall detection rates, and patient-level cluster bootstrap for rate differences. (Supplementary Tables S9, S10)
*   **`02_Biodistribution/`**: Paired comparison of normal-organ background SUVmax between tracers. (Supplementary Table S14)
*   **`03_SUVmax_Paired/`**: Lesion SUVmax comparisons (overall, ccRCC-specific, and by pathological subtype). (Supplementary Tables S3, S4, S5)
*   **`04_TBR_Paired/`**: Lesion TBR comparisons (overall, ccRCC-specific, and by pathological subtype). (Supplementary Tables S6, S7, S8)
    *   *Note: Please refer to the `README.txt` inside each subfolder for exact table mappings and execution instructions.*

### 2. `02_Prospective_Cohort/`
This module contains the analyses based on the independent prospective head-to-head study of 30 patients.
*   **`01_AUC_Analysis/`**: GLMM-based diagnostic performance, calibration, and paired AUC comparisons with patient-level cluster bootstrap. ROC curves are generated in the `Figures/` folder. (Supplementary Tables S18, S19, S20)
*   **`02_Sensitivity/`**: Lesion-level sensitivity comparison with patient-level cluster bootstrap. (Table 2)
*   **`03_Specificity/`**: Specificity calculation, best/worst-case sensitivity analyses, and Bayesian equivalence testing. (Supplementary Table S17)

---

## Software Environment

All analyses were conducted using **R version 4.6.1 (2026-06-24 ucrt)** on Windows 11 x64. The specific R packages and their versions are recorded in the `sessionInfo.txt` file inside each subdirectory. Key packages include:
*   Data manipulation: `readxl`, `dplyr`, `tidyr`, `purrr`
*   Mixed models & contrasts: `lme4`, `lmerTest`, `emmeans`
*   ROC & Bootstrap: `pROC`, `boot`
*   Export: `openxlsx`, `writexl`

---

## How to Run

1. Navigate to the specific analysis subdirectory (e.g., `02_Prospective_Cohort/01_AUC_Analysis/`).
2. Ensure all required packages are installed (refer to the `README.txt` in that folder).
3. Set the working directory to that folder.
4. Run the script (e.g., `source("AUC.R")`).
5. The script will generate the output Excel files and figures in the same directory.

**Reproducibility Note:** Random seeds for all bootstrap procedures are hard-coded in the respective scripts (e.g., `set.seed(123)`) to ensure full reproducibility.

---

## Data Availability

The de-identified data underlying the results are fully available in this repository. The original clinical data can be shared with investigators whose proposed use has been approved by the IRB of Xijing Hospital; requests should be directed to the corresponding author with a signed data access agreement.

## Contact

**Corresponding Author:**  
Fei Kang, MD, PhD  
Department of Nuclear Medicine, Xijing Hospital, Fourth Military Medical University  
E-mail: fmmukangf@fmmu.edu.cn