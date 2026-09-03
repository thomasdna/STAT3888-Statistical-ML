# Theme: cardiometabolic health beyond BMI.
#
# Builds a biomarker-based cardiometabolic risk (CMR) outcome that is
# deliberately INDEPENDENT of adiposity (no waist, no BMI), then answers RQ1:
# how well does BMI category agree with biomarker-defined risk?
#
# Design choices, and why:
#
# 1. Which markers. The ABS supplies binary "*NTR" status flags that already sit
#    on clinical cut-points (e.g. CHOLNTR splits at 5.5 mmol/L). Using these
#    sidesteps the band-interpolation problem that limits the metabolic-syndrome
#    reproduction in 05_repro_engelen.R, where the 1.7 mmol/L triglyceride cut
#    falls inside a band.
#
# 2. Fasting. LDL, triglycerides and fasting glucose exist only for the ~3,180
#    respondents who fasted 8+ hours. Restricting to them would cost ~500
#    people. The core score therefore uses five markers that do not require
#    fasting, and the fasting markers are kept for a sensitivity analysis.
#
# 3. Adiposity is excluded from the outcome by construction. If waist were a
#    component, RQ1 would be partly tautological.
#
# Output: data/derived/cmr_adults.rds, outputs/tables/cmr_*, outputs/figures/rq1_*

source("00_setup.R", chdir = TRUE)
suppressPackageStartupMessages(library(survey))

CMR_THRESHOLD <- 2  # "elevated" = this many or more of the five core factors

rule <- function(t) cat("\n", strrep("=", 74), "\n", t, "\n", strrep("=", 74), "\n", sep = "")

# ============================================================================
# 1. Assemble the analysis dataset
# ============================================================================

person <- fread(file.path(CSV_DIR, "AHSnpa11bp.csv"))
biomed <- fread(file.path(CSV_DIR, "AHSnpa11bb.csv"))

rep_cols <- grep("^RPWGT", names(biomed), value = TRUE)

raw <- merge(
  person[AGEC >= 18],
  biomed[, c("ABSPID", "BIORESPC", "FASTSTAD", "NHMSPERW", "CHOLNTR", "HDLCHSEX",
             "LDLNTR", "TRIGNTR", "GLUCFPD", "DIAHBRSK", "ALTNTR", "GGTNTR",
             "APOBNTR", "EGFRIMP", rep_cols), with = FALSE],
  by = "ABSPID"
) |>
  as_tibble() |>
  filter(BIORESPC == 2)

cmr <- raw |>
  transmute(
    person_id = ABSPID,
    weight_biomed = NHMSPERW,
    across(all_of(rep_cols)),

    age = AGEC,
    sex = factor(SEX, 1:2, c("Male", "Female")),
    fasted = FASTSTAD == 1,

    bmi   = if_else(BMISC %in% c(0, 98, 99), NA_real_, BMISC),
    waist = if_else(PHDCMWBC %in% c(0, 998, 999), NA_real_, as.numeric(PHDCMWBC)),
    sys   = if_else(SYSTOL %in% c(998, 999), NA_real_, as.numeric(SYSTOL)),
    dia   = if_else(DIASTOL %in% c(998, 999), NA_real_, as.numeric(DIASTOL)),

    hypertension_reported = HYPBC %in% 1:2,
    diabetes_reported     = DIABBC %in% 1:2,

    # ---- five core risk factors, none requiring a fasting sample
    rf_bp = case_when(
      (!is.na(sys) & (sys >= 130 | dia >= 85)) | hypertension_reported ~ TRUE,
      !is.na(sys) ~ FALSE),
    rf_dysglycaemia = case_when(
      GLUCFPD %in% 2:3 | DIAHBRSK %in% 2:3 | diabetes_reported ~ TRUE,
      GLUCFPD == 1 | DIAHBRSK == 1 ~ FALSE),
    rf_low_hdl = case_when(HDLCHSEX == 1 ~ FALSE, HDLCHSEX == 2 ~ TRUE),
    rf_high_chol = case_when(CHOLNTR == 1 ~ FALSE, CHOLNTR == 2 ~ TRUE),
    rf_liver = case_when(
      ALTNTR == 2 | GGTNTR == 2 ~ TRUE,
      ALTNTR == 1 | GGTNTR == 1 ~ FALSE),

    # ---- fasting-dependent markers, for the sensitivity analysis
    rf_high_ldl = case_when(LDLNTR == 1 ~ FALSE, LDLNTR == 2 ~ TRUE),
    rf_high_trig = case_when(TRIGNTR == 1 ~ FALSE, TRIGNTR == 2 ~ TRUE),

    # ---- other markers available for extension
    rf_high_apob = case_when(APOBNTR == 1 ~ FALSE, APOBNTR == 2 ~ TRUE),
    rf_low_egfr  = case_when(EGFRIMP == 1 ~ FALSE, EGFRIMP == 2 ~ TRUE)
  )

CORE <- c("rf_bp", "rf_dysglycaemia", "rf_low_hdl", "rf_high_chol", "rf_liver")

cmr <- cmr |>
  mutate(
    n_core_available = rowSums(!is.na(across(all_of(CORE)))),
    cmr_score = rowSums(across(all_of(CORE)), na.rm = TRUE),
    core_complete = n_core_available == length(CORE),
    cmr_score = if_else(core_complete, cmr_score, NA_integer_),
    cmr_elevated = cmr_score >= CMR_THRESHOLD,

    bmi_class = cut(bmi, c(0, 18.5, 25, 30, Inf), right = FALSE,
                    labels = c("Underweight", "Normal", "Overweight", "Obese")),
    bmi_high = bmi_class %in% c("Overweight", "Obese"),

    # The four phenotypes this project is about.
    phenotype = case_when(
      is.na(cmr_elevated) | is.na(bmi_class) ~ NA_character_,
      bmi_class == "Normal"  & !cmr_elevated ~ "Normal weight, favourable",
      bmi_class == "Normal"  &  cmr_elevated ~ "Normal weight, elevated risk",
      bmi_class == "Obese"   & !cmr_elevated ~ "Obese, favourable",
      bmi_class == "Obese"   &  cmr_elevated ~ "Obese, elevated risk",
      bmi_class == "Overweight" & !cmr_elevated ~ "Overweight, favourable",
      bmi_class == "Overweight" &  cmr_elevated ~ "Overweight, elevated risk",
      TRUE ~ "Underweight"
    )
  )

analysis <- cmr |> filter(core_complete, !is.na(bmi_class))

message("biomedical adults: ", nrow(cmr))
message("with all 5 core markers: ", sum(cmr$core_complete))
message("and a measured BMI: ", nrow(analysis))

des <- svrepdesign(
  data = analysis, weights = ~weight_biomed,
  repweights = analysis[, rep_cols], type = "JK1",
  scale = 59 / 60, combined.weights = TRUE
)

# ============================================================================
# 2. Risk factor prevalence
# ============================================================================

rule("RISK FACTOR PREVALENCE (weighted, jackknife SE)")

rf_labels <- c(
  rf_bp = "Raised blood pressure (>=130/85 or treated)",
  rf_dysglycaemia = "Dysglycaemia (glucose >6.0, HbA1c >=6.0% or reported diabetes)",
  rf_low_hdl = "Low HDL (<1.0 M / <1.3 F mmol/L)",
  rf_high_chol = "High total cholesterol (>=5.5 mmol/L)",
  rf_liver = "Elevated liver enzymes (ALT or GGT)"
)

rf_prev <- imap_dfr(rf_labels, \(lab, v) {
  e <- svymean(reformulate(paste0("I(", v, ")")), des, na.rm = TRUE)
  tibble(risk_factor = lab,
         weighted_pct = 100 * as.numeric(e)[2],
         se = 100 * as.numeric(SE(e))[2],
         n_present = sum(analysis[[v]], na.rm = TRUE))
}) |>
  mutate(across(where(is.numeric), \(v) round(v, 2)))

print(as.data.frame(rf_prev))
save_tab(rf_prev, "cmr_01_risk_factor_prevalence")

# ============================================================================
# 3. RQ1: agreement between BMI category and biomarker-defined risk
# ============================================================================

rule("RQ1: CROSS-CLASSIFICATION OF BMI AND CARDIOMETABOLIC RISK")

xtab <- analysis |>
  count(bmi_class, cmr_elevated) |>
  pivot_wider(names_from = cmr_elevated, values_from = n, values_fill = 0,
              names_prefix = "risk_") |>
  mutate(n = risk_FALSE + risk_TRUE,
         pct_elevated = round(100 * risk_TRUE / n, 1))
print(as.data.frame(xtab))
save_tab(xtab, "cmr_02_bmi_by_risk")

# Weighted prevalence of elevated risk within each BMI class.
prev_by_bmi <- svyby(~I(cmr_elevated), ~bmi_class, des, svymean, na.rm = TRUE) |>
  as_tibble() |>
  select(bmi_class, pct = 3, se = 5) |>
  mutate(pct = 100 * pct, se = 100 * se,
         across(where(is.numeric), \(v) round(v, 2)))
print(as.data.frame(prev_by_bmi))
save_tab(prev_by_bmi, "cmr_03_weighted_prevalence_by_bmi")

rule("RQ1: HOW GOOD A CLASSIFIER IS BMI >= 25?")

cm <- table(bmi_high = analysis$bmi_high, cmr_elevated = analysis$cmr_elevated)
print(cm)

agreement <- local({
  tp <- cm["TRUE", "TRUE"];  fp <- cm["TRUE", "FALSE"]
  fn <- cm["FALSE", "TRUE"]; tn <- cm["FALSE", "FALSE"]
  n <- sum(cm)
  po <- (tp + tn) / n
  pe <- sum(rowSums(cm) * colSums(cm)) / n^2
  tibble(
    metric = c("Sensitivity", "Specificity", "Positive predictive value",
               "Negative predictive value", "Observed agreement",
               "Cohen's kappa", "Youden's J", "Balanced accuracy"),
    value = c(tp / (tp + fn), tn / (tn + fp), tp / (tp + fp), tn / (tn + fn),
              po, (po - pe) / (1 - pe),
              tp / (tp + fn) + tn / (tn + fp) - 1,
              (tp / (tp + fn) + tn / (tn + fp)) / 2)
  ) |> mutate(value = round(value, 3))
})
print(as.data.frame(agreement))
save_tab(agreement, "cmr_04_bmi_agreement")

# How much does BMI as a continuous marker discriminate? Compare with waist.
auc <- function(score, label) {
  ok <- !is.na(score) & !is.na(label)
  s <- score[ok]; y <- label[ok]
  r <- rank(s)
  (sum(r[y]) - sum(y) * (sum(y) + 1) / 2) / (sum(y) * sum(!y))
}
discrim <- tibble(
  marker = c("BMI (continuous)", "Waist circumference (continuous)",
             "Age (continuous)", "BMI >= 25 (binary)"),
  auc = c(auc(analysis$bmi, analysis$cmr_elevated),
          auc(analysis$waist, analysis$cmr_elevated),
          auc(analysis$age, analysis$cmr_elevated),
          auc(as.numeric(analysis$bmi_high), analysis$cmr_elevated))
) |> mutate(auc = round(auc, 3))

rule("RQ1: DISCRIMINATION (AUC) OF ANTHROPOMETRY FOR ELEVATED RISK")
print(as.data.frame(discrim))
save_tab(discrim, "cmr_05_discrimination")

# Sensitivity: does adding the fasting markers change the picture?
rule("SENSITIVITY: 7-marker score on the fasting subsample")
fast <- cmr |>
  filter(fasted, !is.na(bmi_class)) |>
  mutate(
    n7 = rowSums(!is.na(across(all_of(c(CORE, "rf_high_ldl", "rf_high_trig"))))),
    score7 = rowSums(across(all_of(c(CORE, "rf_high_ldl", "rf_high_trig"))), na.rm = TRUE),
    elevated7 = if_else(n7 == 7, score7 >= 3, NA)
  ) |>
  filter(!is.na(elevated7))
cm7 <- table(bmi_high = fast$bmi_high, elevated = fast$elevated7)
po7 <- sum(diag(cm7)) / sum(cm7)
pe7 <- sum(rowSums(cm7) * colSums(cm7)) / sum(cm7)^2
message("fasting subsample n: ", nrow(fast))
message("elevated (>=3 of 7): ", round(100 * mean(fast$elevated7), 1), "%")
message("kappa with BMI >= 25: ", round((po7 - pe7) / (1 - pe7), 3),
        "   (core 5-marker score: ", agreement$value[agreement$metric == "Cohen's kappa"], ")")

# ============================================================================
# 4. Figures
# ============================================================================

p_mosaic <- analysis |>
  count(bmi_class, cmr_elevated) |>
  group_by(bmi_class) |>
  mutate(prop = n / sum(n), total = sum(n)) |>
  ungroup() |>
  mutate(risk = factor(if_else(cmr_elevated, "Elevated risk (2+ factors)",
                               "Favourable (0-1 factors)"),
                       levels = c("Favourable (0-1 factors)", "Elevated risk (2+ factors)"))) |>
  ggplot(aes(x = bmi_class, y = prop, fill = risk)) +
  geom_col(width = 0.78) +
  geom_text(aes(label = n), position = position_stack(vjust = 0.5), size = 3.3,
            colour = "white", fontface = "bold") +
  geom_text(aes(x = bmi_class, y = 1.04, label = paste0("n=", total)),
            inherit.aes = FALSE, size = 3, colour = "grey35",
            data = \(d) distinct(d, bmi_class, total)) +
  scale_y_continuous(labels = percent, expand = expansion(mult = c(0, 0.09))) +
  scale_fill_manual(values = c("Favourable (0-1 factors)" = "#3B7EA1",
                               "Elevated risk (2+ factors)" = "#C0392B"), name = NULL) +
  labs(
    title = "BMI category agrees only weakly with biomarker-defined cardiometabolic risk",
    subtitle = sprintf("Cohen's kappa = %.2f. A quarter of normal-weight adults carry two or more risk factors, and %.0f%% of adults with obesity carry fewer than two.",
                       agreement$value[agreement$metric == "Cohen's kappa"],
                       100 * xtab$risk_FALSE[xtab$bmi_class == "Obese"] / xtab$n[xtab$bmi_class == "Obese"]),
    x = "BMI category (measured)", y = "Share of adults",
    caption = "Source: ABS NNPAS 2011-12 Basic CURF, adults 18+ in the biomedical subsample (n=3,525). Risk score excludes waist and BMI by construction. Counts unweighted."
  )

save_fig(p_mosaic, "rq1_01_bmi_vs_risk", width = 9.5, height = 6)

p_score <- analysis |>
  count(bmi_class, cmr_score) |>
  group_by(bmi_class) |>
  mutate(prop = n / sum(n)) |>
  ungroup() |>
  ggplot(aes(x = factor(cmr_score), y = prop, fill = bmi_class)) +
  geom_col(position = "dodge", width = 0.8) +
  scale_y_continuous(labels = percent) +
  scale_fill_brewer(palette = "RdYlBu", direction = -1, name = NULL) +
  labs(title = "Number of cardiometabolic risk factors by BMI category",
       subtitle = "The distributions overlap heavily: BMI shifts the mean but does not separate the groups",
       x = "Number of risk factors present (of 5)", y = "Share within BMI category",
       caption = CAPTION)

save_fig(p_score, "rq1_02_score_distribution", width = 9.5, height = 5.5)

p_rf <- analysis |>
  select(bmi_class, all_of(CORE)) |>
  pivot_longer(-bmi_class, names_to = "rf", values_to = "present") |>
  filter(!is.na(present)) |>
  group_by(bmi_class, rf) |>
  summarise(prev = mean(present), n = n(), .groups = "drop") |>
  mutate(rf = str_wrap(rf_labels[rf], 26),
         se = sqrt(prev * (1 - prev) / n)) |>
  ggplot(aes(x = bmi_class, y = prev, fill = bmi_class)) +
  geom_col(width = 0.75, show.legend = FALSE) +
  geom_errorbar(aes(ymin = prev - 1.96 * se, ymax = prev + 1.96 * se),
                width = 0.16, colour = "grey25") +
  facet_wrap(~rf, nrow = 1) +
  scale_y_continuous(labels = percent) +
  scale_fill_brewer(palette = "RdYlBu", direction = -1) +
  labs(title = "Which risk factors drive the BMI gradient?",
       subtitle = "Blood pressure, dysglycaemia and low HDL track BMI; total cholesterol barely does",
       x = NULL, y = "Prevalence", caption = CAPTION) +
  theme(axis.text.x = element_text(angle = 35, hjust = 1, size = 7.5),
        strip.text = element_text(size = 7.5))

save_fig(p_rf, "rq1_03_risk_factors_by_bmi", width = 13, height = 5)

saveRDS(cmr, file.path(DERIVED, "cmr_adults.rds"))
saveRDS(analysis, file.path(DERIVED, "cmr_analysis.rds"))
message("\nwrote data/derived/cmr_adults.rds and cmr_analysis.rds")
