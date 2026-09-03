# Shared paths, packages and helpers for the STAT3888 AHS project.
# Source this at the top of every other script.

suppressPackageStartupMessages({
  library(data.table)
  library(dplyr)
  library(tidyr)
  library(readr)
  library(readxl)
  library(stringr)
  library(purrr)
  library(forcats)
  library(ggplot2)
  library(scales)
  library(patchwork)
})

# ---- Paths -------------------------------------------------------------------
# Works from the project root or from R/.
# CURF CSVs are NOT in this git folder (ABS licence + GitHub 100 MB limit).
# Locate them in this order:
#   1. TEAM15_AHS_DATA  (env var pointing at original_data/)
#   2. ./data/original_data  if all_files/ already contains CSVs
#   3. ../data/original_data  (this folder sitting inside STAT3888/)

PROJ <- local({
  cand <- c(".", "..")
  hit <- cand[file.exists(file.path(cand, "data", "original_data"))]
  if (!length(hit)) {
    stop("Run from the Team15_Git_upload root or R/: data/original_data not found.")
  }
  normalizePath(hit[1])
})

RAW_DIR <- local({
  env <- Sys.getenv("TEAM15_AHS_DATA", unset = "")
  cands <- c(
    if (nzchar(env)) env else NULL,
    file.path(PROJ, "data", "original_data"),
    file.path(PROJ, "..", "data", "original_data")
  )
  has_csv <- function(p) {
    dir.exists(file.path(p, "all_files")) &&
      length(list.files(file.path(p, "all_files"), pattern = "\\.csv$")) >= 5
  }
  hit <- cands[file.exists(cands) & vapply(cands, has_csv, logical(1))]
  if (length(hit)) return(normalizePath(hit[1]))
  # Item lists live in this repo even when CSVs do not; keep that path.
  local_raw <- file.path(PROJ, "data", "original_data")
  if (file.exists(local_raw)) return(normalizePath(local_raw))
  stop(
    "Cannot find the AHS CURF CSVs.\n",
    "  Copy or symlink them into data/original_data/all_files/, or\n",
    "  keep this folder inside STAT3888/ next to the original data/, or\n",
    "  set TEAM15_AHS_DATA to the original_data directory.\n",
    "  See README.md and data/original_data/all_files/README.md."
  )
})

CSV_DIR  <- file.path(RAW_DIR, "all_files")
DERIVED  <- file.path(PROJ, "data", "derived")
FIG_DIR  <- file.path(PROJ, "outputs", "figures")
TAB_DIR  <- file.path(PROJ, "outputs", "tables")

for (d in c(DERIVED, FIG_DIR, TAB_DIR)) dir.create(d, showWarnings = FALSE, recursive = TRUE)

# ---- ABS missing-value conventions ------------------------------------------
# The Basic CURFs use trailing 7/8/9 patterns for "not applicable", "not
# stated" and "not known" rather than blanks. The correct sentinel depends on
# the field width, so it has to be supplied per variable.

#' Replace ABS sentinel codes with NA.
#' @param x numeric vector
#' @param codes integer codes to treat as missing
ahs_na <- function(x, codes) {
  x[x %in% codes] <- NA
  x
}

#' Midpoint of an ABS "ranged" biomarker category.
#' Ranged variables (e.g. CHOLRESB) are ordered bands; treating them as
#' numeric midpoints is only ever an approximation, so keep the factor too.
band_midpoint <- function(x, midpoints, missing_codes = c(97, 98, 99)) {
  x <- ahs_na(as.integer(x), missing_codes)
  unname(midpoints[as.character(x)])
}

# ---- Plot theme --------------------------------------------------------------

theme_ahs <- function(base_size = 11) {
  theme_minimal(base_size = base_size) +
    theme(
      plot.title      = element_text(face = "bold", size = rel(1.05)),
      plot.subtitle   = element_text(colour = "grey35", size = rel(0.9)),
      plot.caption    = element_text(colour = "grey45", size = rel(0.75), hjust = 0),
      panel.grid.minor = element_blank(),
      strip.text      = element_text(face = "bold", size = rel(0.85)),
      legend.position = "bottom"
    )
}

theme_set(theme_ahs())

CAPTION <- "Source: ABS Australian Health Survey 2011-13, National Nutrition and Physical Activity Survey Basic CURF. Unweighted."

save_fig <- function(plot, name, width = 9, height = 6, dpi = 200) {
  path <- file.path(FIG_DIR, paste0(name, ".png"))
  ggsave(path, plot, width = width, height = height, dpi = dpi, bg = "white")
  message("  figure: ", basename(path))
  invisible(path)
}

save_tab <- function(x, name) {
  path <- file.path(TAB_DIR, paste0(name, ".csv"))
  write_csv(x, path)
  message("  table:  ", basename(path))
  invisible(path)
}
