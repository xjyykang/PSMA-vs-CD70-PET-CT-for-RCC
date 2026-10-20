README: Biodistribution analysis for CCR-26-2321

Manuscript: Comparison of PSMA- and CD70-targeted PET/CT in Diagnosing
Renal Cell Carcinoma: A Retrospective Cohort and Prospective Head-to-head Study
Manuscript ID: CCR-26-2321

====================================================================
1. Contents
====================================================================

- Background_SUVmax.xlsx
- Biodistribution.R
- README.txt
- sessionInfo.txt

====================================================================
2. Data dictionary
====================================================================

File: Background_SUVmax.xlsx
Sheet: Sheet1

Columns:
- Number: Pairing number. Each number should have exactly two records
  (one CD70 and one PSMA).
- Tracer: Tracer group, either CD70 or PSMA.
- Kidney: Background SUVmax in kidney.
- Liver: Background SUVmax in liver.
- Blood Pool: Background SUVmax in blood pool.
- Lung: Background SUVmax in lung.
- Bone: Background SUVmax in bone.
- Muscle: Background SUVmax in muscle.
- Cervical Lymph Node: Background SUVmax in cervical lymph node.
- Parotid Gland: Background SUVmax in parotid gland.
- Brain: Background SUVmax in brain.

Notes:
- The data are fully de-identified.
- Each Number is expected to have exactly two records, one for CD70
  and one for PSMA.
- The analysis compares organ-level background SUVmax between CD70
  and PSMA using paired tests.

====================================================================
3. Script and output
====================================================================

Script: Biodistribution.R

Input file: Background_SUVmax.xlsx (Sheet1)

Output file: Biodistribution_Supplementary Table S14.xlsx

The output Excel file contains one worksheet with the following
columns for each organ:
- 部位 (Organ)
- CD70 SUVmax(均值±SD) (mean ± SD for CD70)
- PSMA SUVmax(均值±SD) (mean ± SD for PSMA)
- 差值Shapiro_P (Shapiro-Wilk P value for paired differences)
- 检验方法 (Statistical test used)
- P值 (P value for the paired comparison)

Organs included:
Kidney, Liver, Blood Pool, Lung, Bone, Muscle, Cervical Lymph Node,
Parotid Gland, Brain.

Please verify the exact mapping of this output to the supplementary
table numbers in your manuscript and adjust if needed.

====================================================================
4. How to run the script
====================================================================

Step 1. Set the working directory to the folder that contains
        "Background_SUVmax.xlsx" and "Biodistribution.R".

Step 2. Install the required packages if not already installed:

    install.packages(c("readxl", "dplyr", "writexl"))

Step 3. Run the script:

    source("Biodistribution.R")

Important:
- The Excel file must be in the same directory as the R script, or
  the file_path object at the top of the script must be adjusted
  accordingly.
- The script writes the output Excel file to the current working
  directory.
- The script checks that the Number column is identical between the
  CD70 and PSMA subsets before performing paired tests.

====================================================================
5. Statistical methods
====================================================================

- For each organ, paired differences were calculated as
  PSMA - CD70.
- Normality of the paired differences was assessed using the
  Shapiro-Wilk test.
- If the differences were normally distributed (P >= 0.05), a paired
  t-test was used; otherwise, a Wilcoxon signed-rank test was used.
- Results are reported as mean ± SD for each tracer, along with the
  Shapiro-Wilk P value for the differences, the test method, and the
  P value for the paired comparison.
- No random seed is required because the analyses are deterministic.

====================================================================
6. Software environment
====================================================================

- R version: 4.6.1 (2026-06-24 ucrt)
- Platform: x86_64-w64-mingw32/x64
- Operating system: Windows 11 x64 (build 26200)
- Packages used: readxl, dplyr, writexl
- Full package versions are recorded in sessionInfo.txt (if provided).

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