# Install packages required to reproduce the Team 15 analysis.
# Run once from R/:  Rscript install_packages.R

pkgs <- c(
  "data.table",
  "dplyr",
  "tidyr",
  "readr",
  "readxl",
  "stringr",
  "purrr",
  "forcats",
  "tibble",
  "ggplot2",
  "scales",
  "patchwork",
  "survey",
  "glmnet",
  "Matrix",
  "broom"
)

need <- pkgs[!vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)]
if (length(need)) {
  message("Installing: ", paste(need, collapse = ", "))
  install.packages(need, repos = "https://cloud.r-project.org")
} else {
  message("All required packages are already installed.")
}

ok <- vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)
if (!all(ok)) {
  stop("Still missing: ", paste(pkgs[!ok], collapse = ", "))
}
message("Ready. R ", getRversion())
