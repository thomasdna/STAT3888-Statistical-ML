# Build a clean person-level analysis dataset from the NNPAS Basic CURF.
#
# The person file (AHSnpa11bp) already carries day-1/day-2 nutrient totals and
# ADG food-group serves, so the 226 MB food file is only needed for
# food-occasion level questions. This script therefore joins the person file to
# the biomedical file, converts ABS sentinel codes to NA, labels the
# categorical variables from the parsed codebook, and derives the quantities we
# actually want to model.
#
# Output: data/derived/npa_person.rds  (+ .csv) and a codebook of the derived
#         variables.

source("00_setup.R", chdir = TRUE)

CODEBOOK_LEVELS <- read_csv(file.path(DERIVED, "codebook_levels.csv"),
                            show_col_types = FALSE) |>
  filter(survey == "npa")

#' Convert an ABS coded integer to a labelled factor using the parsed codebook.
label_var <- function(x, var, drop_codes = integer()) {
  map <- CODEBOOK_LEVELS |>
    filter(variable == var, !code_num %in% drop_codes) |>
    # ABS labels carry footnote markers such as "Highest 20%*".
    mutate(label = str_squish(str_remove(label, "\\*+$"))) |>
    arrange(code_num)
  factor(unname(setNames(map$label, map$code_num)[as.character(x)]),
         levels = map$label)
}

# ---- Read ------------------------------------------------------------------

person <- fread(file.path(CSV_DIR, "AHSnpa11bp.csv"), showProgress = FALSE)
biomed <- fread(file.path(CSV_DIR, "AHSnpa11bb.csv"), showProgress = FALSE) |>
  select(-any_of(c("ABSHID", "ABSLFID", "ABSBID", "ABSFID", "ABSSID", "LEVEL10")),
         -starts_with("RPWGT"))

raw <- person |>
  as_tibble() |>
  inner_join(as_tibble(biomed), by = "ABSPID")

stopifnot(nrow(raw) == nrow(person))

# ---- Biomarker band midpoints ----------------------------------------------
# Bands are ordered intervals; midpoints let us plot a rough continuous scale.
# Open-ended top categories get a conventional value slightly above the cut.

MIDPOINTS <- list(
  CHOLRESB = c(`1` = 3.75, `2` = 4.25, `3` = 4.75, `4` = 5.25, `5` = 5.75,
               `6` = 6.25, `7` = 6.75, `8` = 7.5),
  LDLRESB  = c(`1` = 1.25, `2` = 1.75, `3` = 2.25, `4` = 2.75, `5` = 3.25,
               `6` = 3.75, `7` = 4.25, `8` = 4.9),
  TRIGRESB = c(`1` = 0.35, `2` = 0.75, `3` = 1.25, `4` = 1.75, `5` = 2.25,
               `6` = 2.75, `7` = 3.5),
  GLUCFREB = c(`1` = 4.2,  `2` = 4.75, `3` = 5.25, `4` = 5.8,  `5` = 6.5,
               `6` = 7.25, `7` = 8.0),
  HDLCHREB = c(`1` = 0.85, `2` = 1.15, `3` = 1.40, `4` = 1.75, `5` = 2.25,
               `6` = 2.8),
  HBA1PREB = c(`1` = 4.7,  `2` = 5.25, `3` = 5.75, `4` = 6.25, `5` = 6.75,
               `6` = 7.5)
)

BAND_MISSING <- list(
  CHOLRESB = c(97, 98), LDLRESB = c(97, 98), TRIGRESB = c(97, 98),
  GLUCFREB = c(97, 98), HDLCHREB = c(7, 8),  HBA1PREB = c(7, 8)
)

# ---- Derive ----------------------------------------------------------------

dat <- raw |>
  transmute(
    # -- identifiers and survey weights
    household_id = ABSHID,
    person_id    = ABSPID,
    weight_person = NPAFINWT,
    weight_day2   = ahs_na(NPAD2WGT, 0),
    weight_biomed = ahs_na(NHMSPERW, 0),

    # -- demographics
    age  = AGEC,                                   # 85 = "85 and over"
    age_topcoded = AGEC == 85,
    sex  = factor(SEX, levels = c(1, 2), labels = c("Male", "Female")),
    age_group = cut(AGEC,
                    breaks = c(-Inf, 8, 17, 30, 45, 60, 75, Inf),
                    labels = c("2-8", "9-17", "18-30", "31-45",
                               "46-60", "61-75", "76+")),
    is_adult  = AGEC >= 18,
    seifa_quintile = label_var(SF2SA1QN, "SF2SA1QN", drop_codes = 0),
    remoteness     = label_var(ARIABC,   "ARIABC",   drop_codes = c(0, 8)),
    household_size = ahs_na(HHSIZECB, 0),
    income_decile  = ahs_na(INCDEC, c(0, 98, 99)),

    # -- anthropometry
    bmi    = ahs_na(BMISC,    c(0, 98, 99)),
    weight_kg = ahs_na(PHDKGWBC, c(0, 998, 999)),
    height_cm = ahs_na(PHDCMHBC, c(0, 998, 999)),
    waist_cm  = ahs_na(PHDCMWBC, c(0, 998, 999)),
    bmi_category = label_var(BMICATHY, "BMICATHY", drop_codes = c(0, 98, 99)),

    # -- lifestyle
    smoker_status  = label_var(SMKSTAT,  "SMKSTAT",  drop_codes = 0),
    activity_level = label_var(EXLEVELN, "EXLEVELN", drop_codes = c(0, 8)),
    sitting_mins_week = ahs_na(ADTOTSE, c(9996, 9999)),
    sleep_mins        = ahs_na(SLPTIME, c(9998, 9999)),
    salt_cooking   = label_var(DIETQ12, "DIETQ12", drop_codes = 6),
    salt_at_table  = label_var(DIETQ14, "DIETQ14", drop_codes = 6),
    ran_out_of_food = label_var(FDSECQ1, "FDSECQ1", drop_codes = 8),

    # -- self-reported long-term conditions (current = codes 1 or 2)
    has_diabetes     = DIABBC  %in% 1:2,
    has_high_chol    = HCHOLBC %in% 1:2,
    has_hypertension = HYPBC   %in% 1:2,
    has_heart_disease = ISCHBC %in% 1:2,

    # -- day-1 intake: absolute
    energy_kj_d1  = ENERGYT1,
    protein_g_d1  = PROTT1,
    fat_g_d1      = FATT1,
    satfat_g_d1   = SATFATT1,
    carb_g_d1     = CHOWSAT1,
    sugars_g_d1   = SUGART1,
    fibre_g_d1    = FIBRET1,
    sodium_mg_d1  = SODIUMT1,
    potassium_mg_d1 = POTAST1,
    calcium_mg_d1 = CALCT1,
    iron_mg_d1    = IRONT1,
    alcohol_g_d1  = ALCT1,
    free_sugars_g_d1 = FRESUG1N,

    # -- day-1 intake: percentage of energy
    pct_energy_protein_d1 = PROPER1,
    pct_energy_fat_d1     = FATPER1,
    pct_energy_satfat_d1  = SATPER1,
    pct_energy_carb_d1    = CHOPER1,
    pct_energy_sugars_d1  = SUGPER1,
    pct_energy_alcohol_d1 = ALCPER1,
    pct_energy_freesug_d1 = PEFRESD1,

    # -- plausibility of the recall (Goldberg-style ratio).
    # 997 = not applicable, 998 = not available (needs measured weight).
    ei_bmr_d1 = ahs_na(EIBMR1, c(997, 998)),
    ei_bmr_d2 = ahs_na(EIBMR2, c(0, 997, 998)),
    bmr_kj    = ahs_na(BMR, 99998),

    # -- day-1 ADG food-group serves
    serves_grains_d1 = GRAINS1N,
    serves_wholegrain_d1 = WHOLGR1N,
    serves_veg_d1    = VEGLEG1N,
    serves_fruit_d1  = FRUIT1N,
    serves_juice_d1  = FRJUIC1N,
    serves_dairy_d1  = DAIRY1N,
    serves_meat_d1   = MEAT1N,
    serves_fish_d1   = FISH1N,
    serves_nuts_d1   = NUTS1N,
    serves_water_d1  = WATER1N,

    # -- day 2 (subsample). Day-2 participation is defined by having a
    # non-zero day-2 weight, not by non-zero energy: 8 respondents genuinely
    # reported no intake on day 2.
    has_day2     = NPAD2WGT > 0,
    energy_kj_d2 = if_else(NPAD2WGT > 0, ENERGYT2, NA_real_),
    fibre_g_d2   = if_else(NPAD2WGT > 0, FIBRET2,  NA_real_),
    sodium_mg_d2 = if_else(NPAD2WGT > 0, SODIUMT2, NA_real_),
    serves_veg_d2   = if_else(NPAD2WGT > 0, VEGLEG2N, NA_real_),
    serves_fruit_d2 = if_else(NPAD2WGT > 0, FRUIT2N,  NA_real_),

    # -- biomedical: participation, then bands and their midpoints
    biomed_participant = BIORESPC == 2,
    fasting_status = label_var(FASTSTAD, "FASTSTAD", drop_codes = 0),

    chol_band = label_var(CHOLRESB, "CHOLRESB", drop_codes = c(97, 98)),
    hdl_band  = label_var(HDLCHREB, "HDLCHREB", drop_codes = c(7, 8)),
    ldl_band  = label_var(LDLRESB,  "LDLRESB",  drop_codes = c(97, 98)),
    trig_band = label_var(TRIGRESB, "TRIGRESB", drop_codes = c(97, 98)),
    gluc_band = label_var(GLUCFREB, "GLUCFREB", drop_codes = c(97, 98)),
    hba1c_band = label_var(HBA1PREB, "HBA1PREB", drop_codes = c(7, 8)),

    chol_mmol  = band_midpoint(CHOLRESB, MIDPOINTS$CHOLRESB, BAND_MISSING$CHOLRESB),
    hdl_mmol   = band_midpoint(HDLCHREB, MIDPOINTS$HDLCHREB, BAND_MISSING$HDLCHREB),
    ldl_mmol   = band_midpoint(LDLRESB,  MIDPOINTS$LDLRESB,  BAND_MISSING$LDLRESB),
    trig_mmol  = band_midpoint(TRIGRESB, MIDPOINTS$TRIGRESB, BAND_MISSING$TRIGRESB),
    gluc_mmol  = band_midpoint(GLUCFREB, MIDPOINTS$GLUCFREB, BAND_MISSING$GLUCFREB),
    hba1c_pct  = band_midpoint(HBA1PREB, MIDPOINTS$HBA1PREB, BAND_MISSING$HBA1PREB),

    # -- biomedical: binary abnormality flags supplied by the ABS
    chol_abnormal = case_when(CHOLNTR == 1 ~ FALSE, CHOLNTR == 2 ~ TRUE),
    hdl_abnormal  = case_when(HDLCHSEX == 1 ~ FALSE, HDLCHSEX == 2 ~ TRUE),
    ldl_abnormal  = case_when(LDLNTR == 1 ~ FALSE, LDLNTR == 2 ~ TRUE),
    trig_abnormal = case_when(TRIGNTR == 1 ~ FALSE, TRIGNTR == 2 ~ TRUE)
  ) |>
  mutate(
    # BMICATHY splits normal/obese by adult vs child cut-offs; collapse to the
    # four classes people actually report on.
    bmi_class = fct_collapse(bmi_category,
      Underweight = c("Underweight Class 3", "Underweight Class 2", "Underweight Class 1"),
      Normal      = c("Normal range", "Normal range (Adult only)"),
      Overweight  = "Overweight",
      Obese       = c("Obese Class 1", "Obese Class 2 (Adult only)",
                      "Obese Class 3 (Adult only)")
    ) |> fct_relevel("Underweight", "Normal", "Overweight", "Obese"),

    # Derived indices
    sodium_potassium_ratio = sodium_mg_d1 / potassium_mg_d1,
    energy_density_kj_per_g = NA_real_,  # filled below from the food file if wanted
    waist_height_ratio = waist_cm / height_cm,
    sitting_hours_day  = sitting_mins_week / 7 / 60,
    sleep_hours        = sleep_mins / 60,
    meets_veg_target   = serves_veg_d1 >= 5,
    meets_fruit_target = serves_fruit_d1 >= 2,
    # A recall is implausible if reported energy is far from basal needs.
    implausible_recall = ei_bmr_d1 < 0.9 | ei_bmr_d1 > 2.5
  ) |>
  select(-energy_density_kj_per_g)

# ---- Sanity checks ---------------------------------------------------------

stopifnot(
  nrow(dat) == 12153,
  n_distinct(dat$person_id) == 12153,
  all(dat$energy_kj_d1 >= 0),
  !anyNA(dat$sex)
)

message("analysis dataset: ", nrow(dat), " persons x ", ncol(dat), " variables")
message("adults (18+): ", sum(dat$is_adult))
message("biomedical participants: ", sum(dat$biomed_participant))
message("with a usable cholesterol band: ", sum(!is.na(dat$chol_mmol)))
message("with day-2 recall: ", sum(dat$has_day2))
message("flagged implausible day-1 recall: ", sum(dat$implausible_recall, na.rm = TRUE))

saveRDS(dat, file.path(DERIVED, "npa_person.rds"))
write_csv(dat, file.path(DERIVED, "npa_person.csv"))

# Record what each derived variable means and how complete it is.
derived_codebook <- tibble(
  variable = names(dat),
  type     = map_chr(dat, \(x) class(x)[1]),
  n_missing = map_int(dat, \(x) sum(is.na(x))),
  pct_missing = round(100 * map_dbl(dat, \(x) mean(is.na(x))), 1),
  example  = map_chr(dat, \(x) paste(head(na.omit(as.character(x)), 3), collapse = "; "))
)
write_csv(derived_codebook, file.path(DERIVED, "npa_person_codebook.csv"))
message("\nwrote data/derived/npa_person.rds, .csv and npa_person_codebook.csv")
