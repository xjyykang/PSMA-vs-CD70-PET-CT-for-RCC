README: Specificity analysis for CCR-26-2321

Manuscript: Comparison of PSMA- and CD70-targeted PET/CT in Diagnosing
Renal Cell Carcinoma: A Retrospective Cohort and Prospective Head-to-head Study
Manuscript ID: CCR-26-2321

====================================================================
1. Contents
====================================================================

- Specificity.xlsx
- Specificity_analysis.R
- sessionInfo.txt
- README.txt

====================================================================
2. Data dictionary
====================================================================

File: Specificity.xlsx
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
- Specificity is calculated only among lesions with GoldStandard = 0
  (i.e., true negative lesions).
- The script also uses a pre-specified list of patient IDs for
  "uncertain" lesions from an external dataset. These are encoded
  directly in the script as `uncertain_patient_ids` and are used only
  for sensitivity analyses (best-case and worst-case scenarios).

====================================================================
3. Script and output
====================================================================

Script: Specificity_analysis.R

Input file: Specificity.xlsx (first sheet)

Output file: Specificity_analysis_Supplementary Table S17.xlsx

The output Excel file contains the following worksheets:

(1) "Scenario_Summary"
    - Specificity for CD70 and PSMA under three scenarios:
      Original (definite negatives only, n = 36),
      Best-case (definite negatives + 19 uncertain lesions assumed
      true negative, n = 55),
      Worst-case (definite negatives + 19 uncertain lesions assumed
      false positive, n = 55).
    - Reports specificity, 95% CI, and difference (CD70 - PSMA) with
      95% CI.
    - Corresponds to: Supplementary Table S17 (scenario summary)

(2) "Bayesian_Summary"
    - Posterior mean, 95% credible interval for CD70 specificity,
      PSMA specificity, and the difference (CD70 - PSMA).
    - Posterior probabilities for equivalence (±10%), non-inferiority
      (<10%), and PSMA being better than CD70 (<0).
    - Corresponds to: Supplementary Table S17 (Bayesian summary)

(3) "Conclusion"
    - Equivalence and non-inferiority conclusions based on posterior
      probabilities and a 0.95 threshold.
    - Corresponds to: Supplementary Table S17 (conclusion)

(4) "Best_case"
    - Detailed specificity results for the best-case scenario.
    - Corresponds to: Supplementary Table S17 (best-case results)

(5) "Worst_case"
    - Detailed specificity results for the worst-case scenario.
    - Corresponds to: Supplementary Table S17 (worst-case results)

(6) "Def_neg_wide"
    - Wide-format data for the definite negative lesions used in the
      primary analysis.
    - Provided for transparency.

Please verify the exact mapping of worksheets to supplementary table
numbers against your manuscript and adjust if needed.

====================================================================
4. How to run the script
====================================================================

Step 1. Set the working directory to the folder that contains
        "Specificity.xlsx" and "Specificity_analysis.R".

Step 2. Install the required packages if not already installed:

    install.packages(c(
      "readxl", "dplyr", "tidyr", "boot", "openxlsx"
    ))

Step 3. Run the script:

    source("Specificity_analysis.R")

Important:
- The Excel file must be in the same directory as the R script, or
  the file path in the script must be adjusted accordingly.
- The script writes the output Excel file to the current working
  directory.
- The script sets a random seed (123) before bootstrap and Bayesian
  simulation, so the results are fully reproducible.
- The list of uncertain patient IDs is hard-coded in the script.
  If the external data change, this list must be updated accordingly.

====================================================================
5. Statistical methods
====================================================================

- Specificity was calculated as TN / (TN + FP) among lesions with
  GoldStandard = 0.
- Exact 95% confidence intervals for a single specificity were
  computed using the Clopper-Pearson method (binom.test).
- Differences in specificity (CD70 - PSMA) were estimated using a
  patient-level cluster bootstrap with 1000 resamples to account for
  within-patient clustering of lesions.
- Bootstrap 95% confidence intervals were obtained using the
  percentile method (2.5th and 97.5th percentiles).
- Sensitivity analyses were performed under two extreme scenarios
  for the 19 uncertain lesions: best-case (all true negative) and
  worst-case (all false positive).
- Bayesian analysis was performed using a Beta(1,1) prior for each
  tracer. Posterior distributions were simulated with 100,000 draws.
- Posterior probabilities were computed for:
  - Equivalence: difference within ±10%.
  - Non-inferiority: difference < 10% (PSMA not inferior to CD70).
  - PSMA superiority: difference < 0.
- Equivalence or non-inferiority was concluded if the corresponding
  posterior probability was at least 0.95.

====================================================================
6. Software environment
====================================================================

- R version: 4.6.1 (2026-06-24 ucrt)
- Platform: x86_64-w64-mingw32/x64
- Operating system: Windows 11 x64 (build 26200)
- Packages used: readxl, dplyr, tidyr, boot, openxlsx
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