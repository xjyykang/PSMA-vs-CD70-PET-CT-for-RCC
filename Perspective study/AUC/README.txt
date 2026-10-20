README: AUC analysis for CCR-26-2321

Manuscript: Comparison of PSMA- and CD70-targeted PET/CT in Diagnosing
Renal Cell Carcinoma: A Retrospective Cohort and Prospective Head-to-head Study
Manuscript ID: CCR-26-2321

====================================================================
1. Contents
====================================================================

- AUC.xlsx
- AUC.R
- sessionInfo.txt
- README.txt

====================================================================
2. Data dictionary
====================================================================

File: AUC.xlsx
Sheet: Sheet1

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
- TBR: Lesion-to-background ratio.
- GoldStandard: Reference standard result, 1 = positive, 0 = negative.
- TracerResult: PET/CT result for the given tracer, 1 = positive,
  0 = negative.

Notes:
- The data are fully de-identified.
- The analysis uses SUVmax and TBR as predictors, and GoldStandard
  as the binary outcome.
- TracerResult is included in the data file but is not used in this
  script.

====================================================================
3. Script and output
====================================================================

Script: AUC.R

Input file: AUC.xlsx (Sheet1)

Output file: AUC_Supplementary Table S18,S19,S20.xlsx

The output Excel file contains three worksheets:

(1) "Sheet1"
    - Original and bootstrap-corrected diagnostic performance for
      each tracer (CD70, PSMA) and each predictor (SUVmax, TBR).
    - Includes AUC, cutoff, sensitivity, specificity, and their
      95% bootstrap confidence intervals.
    - Also includes calibration slope and intercept, both original
      and optimism-corrected.
    - Corresponds to: Supplementary Table S18

(2) "Sheet2"
    - Lesion-type-specific cutoff values back-calculated from the
      GLMM for each tracer and predictor.
    - Corresponds to: Supplementary Table S19

(3) "Sheet3"
    - Paired AUC comparison between CD70 and PSMA for each predictor
      (SUVmax, TBR), using patient-level cluster bootstrap.
    - Reports AUC for each tracer, difference in AUC, 95% CI, and
      p-value.
    - Corresponds to: Supplementary Table S20

Please verify the exact mapping of worksheets to supplementary table
numbers against your manuscript and adjust if needed.

The script also generates ROC curves for each predictor in the
"Figures" directory (PDF files, 15 x 14 cm). No calibration curves
are generated.

====================================================================
4. How to run the script
====================================================================

Step 1. Set the working directory to the folder that contains
        "AUC.xlsx" and "AUC.R".

Step 2. Install the required packages if not already installed:

    install.packages(c(
      "readxl", "lme4", "pROC", "dplyr", "openxlsx"
    ))

Step 3. Run the script:

    source("AUC.R")

Important:
- The Excel file must be in the same directory as the R script, or
  the data_path object at the top of the script must be adjusted
  accordingly.
- The script writes the output Excel file to the current working
  directory and creates a "Figures" folder for ROC PDFs.
- The script sets a random seed (123) before bootstrap, so the
  bootstrap results are fully reproducible.

====================================================================
5. Statistical methods
====================================================================

- Generalized linear mixed models (GLMM) were fitted using lme4,
  with the following specification:

    GoldStandard ~ predictor_scaled + LesionType + (1 | patient_ID)

  where predictor_scaled is the standardized SUVmax or TBR.
- Predicted probabilities from the GLMM were used to construct ROC
  curves and calculate AUC, cutoff, sensitivity, and specificity
  using pROC.
- The cutoff was determined by the Youden index.
- Bootstrap resampling was performed at the patient level
  (cluster bootstrap) with 1000 resamples to account for
  within-patient clustering of lesions.
- Bootstrap 95% confidence intervals were obtained using the
  percentile method (2.5th and 97.5th percentiles).
- Optimism-corrected calibration slope and intercept were computed
  using the bootstrap samples.
- Paired AUC comparison between CD70 and PSMA was also performed
  using patient-level cluster bootstrap with 1000 resamples.
- No random seed is required for deterministic parts; a fixed seed
  (123) is used for all bootstrap procedures.

====================================================================
6. Software environment
====================================================================

- R version: 4.6.1 (2026-06-24 ucrt)
- Platform: x86_64-w64-mingw32/x64
- Operating system: Windows 11 x64 (build 26200)
- Packages used: readxl, lme4, pROC, dplyr, openxlsx
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