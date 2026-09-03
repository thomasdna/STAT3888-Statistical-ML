# Run the whole pipeline from the project root or from R/.
# Rscript R/run_all.R

setwd(dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE)[1]))))

scripts <- c(# shared: codebook and integrity checks
             "01_build_codebook.R", "02_verify_data.R",
             # nutrition survey (NNPAS): cardiometabolic risk beyond BMI
             "03_prepare_data.R", "04_eda.R", "05_repro_engelen.R",
             "06_cmr_outcome.R", "07_rq2_interaction.R", "08_rq3_prediction.R",
             "09_diet_exposure_test.R",
             # health survey (NHS): the team's cholesterol screening candidate
             "10_nhs_chol_build.R", "11_chol_bmi_waist.R",
             "12_chol_screening_eval.R")

for (s in scripts) {
  message("\n", strrep("=", 72), "\n", s, "\n", strrep("=", 72))
  source(s, echo = FALSE)
}

message("\nPipeline complete.")
