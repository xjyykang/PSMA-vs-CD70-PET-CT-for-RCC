README: Paired SUVmax analysis of prospective study for CCR-26-2321

Manuscript: Comparison of PSMA- and CD70-targeted PET/CT in Diagnosing
Renal Cell Carcinoma: A Retrospective Cohort and Prospective Head-to-head Study
Manuscript ID: CCR-26-2321

====================================================================
1. Contents
====================================================================

- Retrospective study_SUVmax.xlsx
- SUVmax_analysis.R
- sessionInfo.txt
- README.txt

====================================================================
2. Data dictionary
====================================================================

File: Retrospective study_SUVmax.xlsx
Sheet: Sheet1

Columns:
- Pairing_ID: Identifier linking paired lesions imaged with both CD70
  and PSMA. Each Pairing_ID should have exactly two records.
- Group: Tracer group, either CD70 or PSMA.
- LesionType: Lesion category, one of the following:
  Primary tumor, Lymph node metastasis, Bone metastasis,
  Pulmonary metastasis, Liver metastasis, Other metastasis.
- SUVmax: Lesion SUVmax measured on PET/CT.
- TBR: Lesion-to-background ratio (also included in the data file).
- patient_ID: De-identified patient identifier. Multiple paired
  lesions can belong to the same patient.

Notes:
- The data are fully de-identified.
- Each Pairing_ID is expected to have two records (one CD70 and one
  PSMA).
- The analysis in SUVmax_analysis.R focuses on SUVmax.

====================================================================
3. Script and output
====================================================================

Script: SUVmax_analysis.R

Input file: Retrospective study_SUVmax.xlsx (Sheet1)

Output file: SUVmax_analysis_Supplementary Table S15.xlsx

The output Excel file contains three worksheets:

(1) "Summary"
    - Descriptive statistics (mean ± SD) for CD70 and PSMA in each
      lesion type and for all lesions combined.
    - Number of pairs, paired test method, and paired p-value.
    - Geometric mean ratio (PSMA/CD70) and 95% CI from the mixed
      model.
    - Mixed-model p-value.
    - Corresponds to: Supplementary Table S15 (summary section)

(2) "MixedModel"
    - Mixed-effects model results for each lesion type and for all
      lesions combined.
    - Reports the ratio (PSMA/CD70), 95% CI, p-value, and model
      status.
    - Corresponds to: Supplementary Table S15 (mixed-model section)

(3) "Interaction"
    - Overall interaction test for Group × LesionType.
    - Reports NumDF, DenDF, F value, and p-value.
    - Corresponds to: Supplementary Table S15 (interaction section)

Please verify the exact mapping of worksheets to supplementary table
numbers against your manuscript and adjust if needed.

====================================================================
4. How to run the script
====================================================================

Step 1. Set the working directory to the folder that contains
        "Retrospective study_SUVmax.xlsx" and "SUVmax_analysis.R".

Step 2. Install the required packages if not already installed:

    install.packages(c(
      "readxl", "dplyr", "tidyr", "purrr",
      "lme4", "lmerTest", "writexl"
    ))

Step 3. Run the script:

    source("SUVmax_analysis.R")

Important:
- The Excel file must be in the same directory as the R script, or
  the file_path object at the top of the script must be adjusted
  accordingly.
- The script writes the output Excel file to the current working
  directory.
- The script automatically installs missing packages if they are not
  already available.

====================================================================
5. Statistical methods
====================================================================

- For each lesion type and for all lesions combined, paired
  comparisons were performed between CD70 and PSMA.
- Normality of the paired differences was assessed using the
  Shapiro-Wilk test. If the differences were normally distributed
  (P > 0.05), a paired t-test was used; otherwise, a Wilcoxon
  signed-rank test was used.
- Linear mixed-effects models were fitted using lme4, with the
  following specification:

    log(SUVmax) ~ Group + (1 | patient_ID) + (1 | Pairing_ID)

  Group was coded with CD70 as the reference level, so the model
  coefficient represents the PSMA vs CD70 effect on the log scale.
- The geometric mean ratio was obtained by exponentiating the model
  coefficient (PSMA/CD70). The 95% CI was computed on the log scale
  using a Wald approximation and then exponentiated.
- P-values for fixed effects were obtained using lmerTest.
- An overall interaction test (Group × LesionType) was performed
  using a mixed model with the same random-effects structure.
- The optimizer was set to "bobyqa" with increased iterations to
  improve convergence.

====================================================================
6. Software environment
====================================================================

- R version: 4.6.1 (2026-06-24 ucrt)
- Platform: x86_64-w64-mingw32/x64
- Operating system: Windows 11 x64 (build 26200)
- Packages used: readxl, dplyr, tidyr, purrr, lme4, lmerTest, writexl
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