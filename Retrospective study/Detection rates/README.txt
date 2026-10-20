README: Detection rate analysis for CCR-26-2321

Manuscript: Comparison of PSMA- and CD70-targeted PET/CT in Diagnosing
Renal Cell Carcinoma: A Retrospective Cohort and Prospective Head-to-head Study
Manuscript ID: CCR-26-2321

====================================================================
1. Contents
====================================================================

- Detection rates.xlsx
- Detection rates.R
- sessionInfo.txt
- README.txt

====================================================================
2. Data dictionary
====================================================================

File: Detection rates.xlsx
Sheet: Sheet1

Columns:
- Group: Tracer group, either PSMA or CD70.
- LesionType: Lesion category, one of the following:
  Primary tumor, Lymph node metastasis, Bone metastasis,
  Pulmonary metastasis, Liver metastasis, Other metastasis.
- SUVmax: Lesion SUVmax measured on PET/CT.
- PatientID: De-identified patient identifier. Multiple lesions can
  belong to the same patient.
- type: Pathological subtype, either ccRCC or nccRCC.
- Detection: Lesion detection status, either Yes or No.
  Yes = detected, No = not detected.

Notes:
- Detection is converted to a numeric variable (Yes = 1, No = 0) in
  the R script.
- No missing values are present in the Detection column.
- The data are fully de-identified.
- Because multiple lesions can belong to the same patient, bootstrap
  resampling is performed at the patient level.

====================================================================
3. Script and output
====================================================================

Script: Detection rates.R

Input file: Detection rates.xlsx (Sheet1)

Output file: Detection rates_Supplementary Table S9,S10.xlsx

The output Excel file contains three worksheets:

(1) "亚组检出率" (Subgroup detection rates)
    - Detection rates and Clopper-Pearson 95% CIs for the following
      subgroups:
      ccRCC_CD70, ccRCC_PSMA, nccRCC_CD70, nccRCC_PSMA.
    - Corresponds to: Supplementary Table S9 (subgroup results)

(2) "总体检出率" (Overall detection rates)
    - Detection rates and Clopper-Pearson 95% CIs for the overall
      CD70 and PSMA groups.
    - Corresponds to: Supplementary Table S9 (overall results)

(3) "Bootstrap率差比较" (Bootstrap rate difference comparisons)
    - Patient-level cluster bootstrap (1000 replicates) for the
      following rate differences:
      - ccRCC: CD70 vs PSMA
      - nccRCC: CD70 vs PSMA
      - CD70: ccRCC vs nccRCC
      - PSMA: ccRCC vs nccRCC
      - Overall: CD70 vs PSMA
    - Reports the estimated rate difference (%), 95% percentile CI,
      and two-sided p-value.
    - Corresponds to: Supplementary Table S10

Please verify the exact mapping of worksheets to supplementary table
numbers against your manuscript and adjust if needed.

====================================================================
4. How to run the script
====================================================================

Step 1. Set the working directory to the folder that contains
        "Detection rates.xlsx" and "Detection rates.R".

Step 2. Install the required packages if not already installed:

    install.packages(c("dplyr", "readxl", "openxlsx"))

Step 3. Run the script:

    source("Detection rates.R")

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

- Detection rates were calculated as the proportion of detected
  lesions among all lesions in each subgroup or overall group.
- Exact 95% confidence intervals were computed using the
  Clopper-Pearson method.
- Rate differences were estimated using a patient-level cluster
  bootstrap with 1000 resamples to account for within-patient
  clustering of lesions.
- Bootstrap 95% confidence intervals were obtained using the
  percentile method (2.5th and 97.5th percentiles).
- Two-sided bootstrap p-values were calculated as
  min(2 * min(P(boot <= 0), P(boot >= 0)), 1).
- A fixed random seed (20260827) was used to ensure reproducibility.

====================================================================
6. Software environment
====================================================================

- R version: 4.6.1 (2026-06-24 ucrt)
- Platform: x86_64-w64-mingw32/x64
- Operating system: Windows 11 x64 (build 26200)
- Packages used: dplyr, readxl, openxlsx
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