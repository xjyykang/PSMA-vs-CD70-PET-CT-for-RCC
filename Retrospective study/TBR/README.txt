README: TBR analysis of retrospective study for CCR-26-2321

Manuscript: Comparison of PSMA- and CD70-targeted PET/CT in Diagnosing
Renal Cell Carcinoma: A Retrospective Cohort and Prospective Head-to-head Study
Manuscript ID: CCR-26-2321

====================================================================
1. Contents
====================================================================

- Retrospective study_TBR.xlsx
- TBR_analysis.R
- TBR_ccRCC subtype analysis.R
- TBR_pathological subtyping analysis.R
- sessionInfo.txt
- README.txt

Note:  package versions are recorded in sessionInfo.txt.

====================================================================
2. Data dictionary
====================================================================

File: Retrospective study_TBR.xlsx
Sheet: Sheet1

Columns:
- Group: Tracer group, either PSMA or CD70.
- LesionType: Lesion category, one of the following:
  Primary tumor, Lymph node metastasis, Bone metastasis,
  Pulmonary metastasis, Liver metastasis, Other metastasis.
- TBR: Lesion-to-background ratio measured on PET/CT.
- PatientID: De-identified patient identifier. Multiple lesions can
  belong to the same patient.
- type: Pathological subtype, either ccRCC or nccRCC.

Notes:
- TBR contains no missing values.
- The data are fully de-identified.
- Because multiple lesions can belong to the same patient, all mixed
  models include a random intercept for PatientID.

====================================================================
3. Scripts and outputs
====================================================================

All three scripts read the same input file:
"Retrospective study_TBR.xlsx" (Sheet1).

(1) TBR_analysis.R
    - Analysis population: all lesions.
    - Model: log(TBR) ~ Group * LesionType + (1 | PatientID)
    - Output: TBR_analysis_Supplementary Table S4.xlsx
    - Corresponds to: Supplementary Table S4

(2) TBR_ccRCC subtype analysis.R
    - Analysis population: ccRCC lesions only.
    - Model: log(TBR) ~ Group * LesionType + (1 | PatientID)
    - Output: TBR_ccRCC subtype analysis_Supplementary Table S8.xlsx
    - Corresponds to: Supplementary Table S8

(3) TBR_pathological subtyping analysis.R
    - Analysis population: all lesions, compared by pathological subtype.
    - Model: log(TBR) ~ Group * type + LesionType + (1 | PatientID)
    - Output: TBR_pathological subtyping analysis_Supplementary Table S6.xlsx
    - Corresponds to: Supplementary Table S6

Note on ratio direction:
- In scripts (1) and (2), Group is factored with levels c("CD70", "PSMA").
  The reported ratio is therefore CD70 / PSMA.
- In script (3), Group is factored with levels c("PSMA", "CD70").
  The reported ratio is therefore PSMA / CD70.
  Please interpret the ratios accordingly.

====================================================================
4. How to run the scripts
====================================================================

Step 1. Set the working directory to the folder that contains the
        Excel file and the R scripts.

Step 2. Restore the R package environment using renv:

    renv::restore()

Step 3. Run the scripts in any order (they are independent):

    source("TBR_analysis.R")
    source("TBR_ccRCC subtype analysis.R")
    source("TBR_pathological subtyping analysis.R")

Important:
- The Excel file must be in the same directory as the R scripts, or
  the file_path object at the top of each script must be adjusted
  accordingly.
- Each script writes its output Excel file to the current working
  directory.

====================================================================
5. Statistical methods
====================================================================

- Normality was assessed using the Shapiro-Wilk test. If both groups
  passed normality (P > 0.05), a Welch t-test was used; otherwise, a
  Mann-Whitney U test was used.
- Linear mixed-effects models were fitted using lme4, with patient as
  a random intercept to account for within-patient clustering of
  lesions.
- TBR was log-transformed for the mixed models.
- P values for fixed effects were obtained using lmerTest.
- Estimated marginal means and pairwise comparisons were computed
  using emmeans, with Tukey adjustment for multiple comparisons.
- ICC was calculated as patient variance divided by
  (patient variance + residual variance).
- No random seed was required because the analyses are deterministic.

====================================================================
6. Software environment
====================================================================

- R version: 4.6.1 (2026-06-24 ucrt)
- Platform: x86_64-w64-mingw32/x64
- Operating system: Windows 11 x64 (build 26200)
- Full package versions are recorded in sessionInfo.txt
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