README: Sensitivity analysis for CCR-26-2321

Manuscript: Comparison of PSMA- and CD70-targeted PET/CT in Diagnosing
Renal Cell Carcinoma: A Retrospective Cohort and Prospective Head-to-head Study
Manuscript ID: CCR-26-2321

====================================================================
1. Contents
====================================================================

- Sensitivity.xlsx
- Sensitivity_analysis.R
- sessionInfo.txt
- README.txt

====================================================================
2. Data dictionary
====================================================================

File: Sensitivity.xlsx
Sheet: GLMM_data (first sheet)

Columns:
- Pairing_ID: Identifier linking paired lesions imaged with both CD70
  and PSMA. Each Pairing_ID should have exactly two records.
- patient_ID: De-identified patient identifier. Multiple lesions can
  belong to the same patient.
- LesionType: Lesion category, one of the following:
  Primary tumor, Lymph node metastasis, Bone metastasis,
  Pulmonary metastasis, Liver metastasis, Other metastasis.
- Tracer: Tracer group, either CD70 or PSMA.
- SUVmax: Lesion SUVmax measured on PET/CT.
- GoldStandard: Reference standard result, 1 = positive, 0 = negative.
- TracerResult: PET/CT result for the given tracer, 1 = positive,
  0 = negative.

Notes:
- The data are fully de-identified.
- Sensitivity is calculated only among lesions with GoldStandard = 1
  (i.e., true positive lesions).
- The analysis uses patient-level cluster bootstrap to account for
  within-patient clustering of lesions.

====================================================================
3. Script and output
====================================================================

Script: Sensitivity_analysis.R

Input file: Sensitivity.xlsx (first sheet)

Output file: Sensitivity_analysis_TABLE 2.xlsx

The output Excel file contains one worksheet:

"Sensitivity_analysis_TABLE 2"

Columns:
- LesionType: Subgroup or overall group.
- Sens_CD70: Sensitivity for CD70.
- Sens_CD70_CI: Clopper-Pearson 95% CI for CD70 sensitivity.
- Sens_PSMA: Sensitivity for PSMA.
- Sens_PSMA_CI: Clopper-Pearson 95% CI for PSMA sensitivity.
- Diff_Sensitivity: Difference in sensitivity (CD70 - PSMA).
- Diff_CI: 95% percentile bootstrap CI for the difference.
- P_raw: Two-sided bootstrap p-value for the difference.

Please verify the exact mapping of this output to the supplementary
table numbers in your manuscript and adjust if needed.

====================================================================
4. How to run the script
====================================================================

Step 1. Set the working directory to the folder that contains
        "Sensitivity.xlsx" and "Sensitivity_analysis.R".

Step 2. Install the required packages if not already installed:

    install.packages(c("readxl", "dplyr", "tidyr", "openxlsx"))

Step 3. Run the script:

    source("Sensitivity_analysis.R")

Important:
- The Excel file must be in the same directory as the R script, or
  the file path in the script must be adjusted accordingly.
- The script writes the output Excel file to the current working
  directory.
- The script sets a random seed (20260827) before bootstrap, so the
  bootstrap results are fully reproducible.

====================================================================
5. Statistical methods
====================================================================

- Sensitivity was calculated as TP / (TP + FN) among lesions with
  GoldStandard = 1.
- Exact 95% confidence intervals for a single sensitivity were
  computed using the Clopper-Pearson method (binom.test).
- Differences in sensitivity (CD70 - PSMA) were estimated using a
  patient-level cluster bootstrap with 1000 resamples to account for
  within-patient clustering of lesions.
- Bootstrap 95% confidence intervals were obtained using the
  percentile method (2.5th and 97.5th percentiles).
- Two-sided bootstrap p-values were calculated as
  min(2 * min(P(boot <= 0), P(boot >= 0)), 1).
- A fixed random seed (20260827) was used to ensure reproducibility.
- No FDR or multiple-comparison correction was applied in this
  script; p-values are reported as raw bootstrap p-values.

====================================================================
6. Software environment
====================================================================

- R version: 4.6.1 (2026-06-24 ucrt)
- Platform: x86_64-w64-mingw32/x64
- Operating system: Windows 11 x64 (build 26200)
- Packages used: readxl, dplyr, tidyr, openxlsx
- Full package versions are recorded in sessionInfo.txt.

====================================================================
7. Code Ocean
====================================================================

A Code Ocean compute capsule is being prepared and will be linked to
the manuscript once access is available. In the meantime, the data
and R code are provided as Supplementary Data for the reviewers.

====================================================================
8. Contact
====================================================================

Corresponding author:
Fei Kang, MD, PhD
Department of Nuclear Medicine
Xijing Hospital, Fourth Military Medical University
E-mail: fmmukangf@fmmu.edu.cn