# Reproduction of Engelen et al. (2017), Aust NZ J Public Health 41(2):178-183,
# "Who is at risk of chronic disease? Associations between risk profiles of
#  physical activity, sitting and cardio-metabolic disease in Australian adults".
#
# Design: cross-sectional, NNPAS 2011-12 adults 18+ (n = 9,435). Adults are
# cross-classified into four physical-activity x sitting-time groups at the
# weighted medians, then logistic regression relates group membership to
# cardiovascular disease, diabetes and metabolic syndrome.
#
# Output: outputs/tables/engelen_*.csv and outputs/figures/repro_engelen_*.png

source("00_setup.R", chdir = TRUE)
suppressPackageStartupMessages(library(survey))
options(survey.lonely.psu = "adjust")

rule <- function(t) cat("\n", strrep("=", 74), "\n", t, "\n", strrep("=", 74), "\n", sep = "")

# ============================================================================
# 1. Build the Engelen analysis dataset
# ============================================================================

person <- fread(file.path(CSV_DIR, "AHSnpa11bp.csv"))
biomed <- fread(file.path(CSV_DIR, "AHSnpa11bb.csv"))

lv <- read_csv(file.path(DERIVED, "codebook_levels.csv"), show_col_types = FALSE) |>
  filter(survey == "npa")
lab <- function(x, var, drop = integer()) {
  m <- lv |> filter(variable == var, !code_num %in% drop) |>
    mutate(label = str_squish(str_remove(label, "\\*+$"))) |> arrange(code_num)
  factor(unname(setNames(m$label, m$code_num)[as.character(x)]), levels = m$label)
}

adults <- person[AGEC >= 18]
stopifnot(nrow(adults) == 9435)

# The NNPAS person file does carry 60 delete-a-group jackknife replicate
# weights (WPM0101-WPM0160), so the full-sample models can use the same
# variance estimator Engelen used rather than falling back on simple weighting.
person_rep_cols <- sprintf("WPM01%02d", 1:60)
stopifnot(all(person_rep_cols %in% names(adults)))

eng <- adults |>
  as_tibble() |>
  transmute(
    person_id = ABSPID,
    wt = NPAFINWT,
    across(all_of(person_rep_cols)),

    # ---- exposure: Active Australia total PA and total sitting time
    # EXLWTBC is the ABS total of walking + moderate + vigorous minutes, so
    # the Active Australia score (walk + moderate + 2*vigorous) is obtained by
    # adding vigorous minutes once more. Engelen's analytical n of 9,403 equals
    # 9,435 less exactly the 32 missing sitting records, so missing PA minutes
    # were treated as zero rather than dropped.
    pa_missing = EXLWTBC >= 9996 | EXLWVBC >= 9996,
    total_pa_min = if_else(pa_missing, 0, EXLWTBC + EXLWVBC),
    sitting_min  = if_else(ADTOTSE %in% c(9996, 9999), NA_real_, as.numeric(ADTOTSE)),

    # ---- covariates
    sex = factor(SEX, levels = c(2, 1), labels = c("Women", "Men")),
    age_group = cut(AGEC, c(17, 24, 34, 44, 54, 64, 74, Inf),
                    labels = c("18-24", "25-34", "35-44", "45-54",
                               "55-64", "65-74", "75+")),
    education = factor(
      case_when(LVHNSQBC %in% 1:2 ~ "University/degree",
                LVHNSQBC %in% 3:7 ~ "Year12/certificate/diploma"),
      levels = c("University/degree", "Year12/certificate/diploma")),
    self_rated_health = lab(SF12Q2, "SF12Q2", drop = 0),
    seifa = lab(SF2SA1QN, "SF2SA1QN", drop = 0),
    residence = lab(ARIABC, "ARIABC", drop = c(0, 8)),
    smoking = factor(
      case_when(SMKSTAT == 5 ~ "Never smoked",
                SMKSTAT %in% 1:3 ~ "Current",
                SMKSTAT == 4 ~ "Ex-smoker"),
      levels = c("Never smoked", "Current", "Ex-smoker")),

    # Engelen's 10 occupation categories: the eight ANZSCO major groups, plus
    # unemployed and not-in-labour-force split out using labour force status.
    occupation = factor(
      case_when(
        LFSBC == 2 ~ "Unemployed",
        LFSBC == 3 ~ "Not in Labour Force",
        ANZSCOBC == 1 ~ "Managers",
        ANZSCOBC == 2 ~ "Professionals",
        ANZSCOBC == 3 ~ "Technicians-trade",
        ANZSCOBC == 4 ~ "Community-person service",
        ANZSCOBC == 5 ~ "Clerical-administrative",
        ANZSCOBC == 6 ~ "Sales",
        ANZSCOBC == 7 ~ "Machinery operators-drivers",
        ANZSCOBC == 8 ~ "Labourers"),
      levels = c("Managers", "Professionals", "Technicians-trade",
                 "Community-person service", "Clerical-administrative", "Sales",
                 "Machinery operators-drivers", "Labourers", "Unemployed",
                 "Not in Labour Force")),

    waist_cm = if_else(PHDCMWBC %in% c(0, 998, 999), NA_real_, as.numeric(PHDCMWBC)),
    systolic  = if_else(SYSTOL %in% c(998, 999), NA_real_, as.numeric(SYSTOL)),
    diastolic = if_else(DIASTOL %in% c(998, 999), NA_real_, as.numeric(DIASTOL)),

    # ---- outcomes: self-reported circulatory conditions and diabetes.
    # "Ever told by a health professional" = codes 1-3.
    cvd = (HYPBC %in% 1:3) | (ISCHBC %in% 1:3) | (HFOBC %in% 1:3) |
          (CEREVBC %in% 1:3) | (OEDBC %in% 1:3) | (ANGBC %in% 1:3),
    diabetes = DIABBC %in% 1:3,
    hypertension_reported = HYPBC %in% 1:2
  ) |>
  mutate(
    waist_category = factor(
      case_when(
        is.na(waist_cm) ~ NA_character_,
        sex == "Men"   & waist_cm <  94 ~ "Not at risk",
        sex == "Men"   & waist_cm < 102 ~ "Increased risk",
        sex == "Men"                    ~ "Substantially increased risk",
        sex == "Women" & waist_cm <  80 ~ "Not at risk",
        sex == "Women" & waist_cm <  88 ~ "Increased risk",
        TRUE                            ~ "Substantially increased risk"),
      levels = c("Not at risk", "Increased risk", "Substantially increased risk"))
  )

# ---- Metabolic syndrome from the biomedical subsample -----------------------
# NCEP/AHA criteria, 3 or more of: central obesity; fasting triglycerides
# >= 1.7; low HDL; blood pressure >= 130/85 or treated; fasting glucose >= 6.1.
#
# The Basic CURF releases triglycerides only in bands (1.5-2.0, 2.0-2.5, ...),
# so the 1.7 cut-point cannot be applied exactly. We bracket it: band 05+
# (>= 2.0) is too strict, band 04+ (>= 1.5) too lenient. The primary analysis
# uses the strict version and the lenient one is reported as a sensitivity.

bio <- biomed |>
  as_tibble() |>
  select(person_id = ABSPID, BIORESPC, TRIGRESB, HDLCHSEX, GLUCFPD, NHMSPERW,
         starts_with("RPWGT")) |>
  filter(BIORESPC == 2)

mets_dat <- eng |>
  inner_join(bio, by = "person_id") |>
  mutate(
    trig_band = if_else(TRIGRESB %in% c(97, 98), NA_integer_, as.integer(TRIGRESB)),
    c_waist = if_else(sex == "Women", waist_cm > 88, waist_cm > 102),
    c_hdl   = case_when(HDLCHSEX == 1 ~ FALSE, HDLCHSEX == 2 ~ TRUE),
    c_bp    = (systolic >= 130 | diastolic >= 85) | hypertension_reported,
    c_gluc  = case_when(GLUCFPD %in% 1L ~ FALSE, GLUCFPD %in% 2:3 ~ TRUE),
    c_trig_strict  = trig_band >= 5,
    c_trig_lenient = trig_band >= 4
  ) |>
  mutate(
    n_avail = rowSums(!is.na(cbind(c_waist, c_trig_strict, c_hdl, c_bp, c_gluc))),
    mets = if_else(n_avail == 5,
                   rowSums(cbind(c_waist, c_trig_strict, c_hdl, c_bp, c_gluc)) >= 3,
                   NA),
    mets_lenient = if_else(n_avail == 5,
                   rowSums(cbind(c_waist, c_trig_lenient, c_hdl, c_bp, c_gluc)) >= 3,
                   NA)
  )

message("adults: ", nrow(eng), "  (published 9,435)")
message("biomedical adults: ", nrow(mets_dat), "  (published 3,803)")

# ============================================================================
# 2. PA-Sit groups at the weighted medians
# ============================================================================

wquant <- function(x, w, probs) {
  ok <- !is.na(x) & !is.na(w); x <- x[ok]; w <- w[ok]
  o <- order(x); x <- x[o]; w <- w[o]; cw <- cumsum(w) / sum(w)
  vapply(probs, \(q) x[which(cw >= q)[1]], numeric(1))
}

cut_pa  <- wquant(eng$total_pa_min, eng$wt, 0.5)
cut_sit <- wquant(eng$sitting_min,  eng$wt, 0.5)

eng <- eng |>
  mutate(
    pa_sit = factor(
      case_when(
        total_pa_min <  cut_pa & sitting_min >  cut_sit ~ "Low PA-High Sit",
        total_pa_min <  cut_pa & sitting_min <= cut_sit ~ "Low PA-Low Sit",
        total_pa_min >= cut_pa & sitting_min >  cut_sit ~ "High PA-High Sit",
        total_pa_min >= cut_pa & sitting_min <= cut_sit ~ "High PA-Low Sit"),
      levels = c("High PA-Low Sit", "Low PA-Low Sit",
                 "High PA-High Sit", "Low PA-High Sit")),
    high_risk = pa_sit == "Low PA-High Sit",
    low_risk  = pa_sit == "High PA-Low Sit"
  )

mets_dat <- mets_dat |>
  left_join(eng |> select(person_id, pa_sit), by = "person_id")

rule("EXPOSURE DISTRIBUTION: OURS vs PUBLISHED")

exposure_check <- tibble(
  quantity = c("Adults 18+ (n)", "Analytical n (non-missing sitting)",
               "Biomedical adults (n)",
               "Total PA, weighted mean (min/wk)", "Total PA, weighted median",
               "Total PA, weighted p25", "Total PA, weighted p75",
               "Sitting, weighted mean (h/wk)", "Sitting, weighted median (h/wk)",
               "Sitting, weighted p25 (h/wk)", "Sitting, weighted p75 (h/wk)"),
  published = c(9435, 9403, 3803, 284, 160, 30, 390, 38.8, 36.0, 23.0, 52.5),
  ours = c(
    nrow(eng), sum(!is.na(eng$sitting_min)), nrow(mets_dat),
    round(weighted.mean(eng$total_pa_min, eng$wt), 0),
    wquant(eng$total_pa_min, eng$wt, 0.50),
    wquant(eng$total_pa_min, eng$wt, 0.25),
    wquant(eng$total_pa_min, eng$wt, 0.75),
    round(weighted.mean(eng$sitting_min, eng$wt, na.rm = TRUE) / 60, 1),
    wquant(eng$sitting_min, eng$wt, 0.50) / 60,
    wquant(eng$sitting_min, eng$wt, 0.25) / 60,
    wquant(eng$sitting_min, eng$wt, 0.75) / 60
  )
) |>
  mutate(difference = ours - published)

print(as.data.frame(exposure_check))
save_tab(exposure_check, "engelen_01_exposure_check")

group_check <- tibble(
  group = c("Low PA-High Sit", "Low PA-Low Sit", "High PA-High Sit", "High PA-Low Sit"),
  published_n = c(2323, 2497, 2339, 2244)
) |>
  left_join(eng |> filter(!is.na(pa_sit)) |> count(pa_sit, name = "our_n") |>
              rename(group = pa_sit) |> mutate(group = as.character(group)),
            by = "group") |>
  mutate(difference = our_n - published_n,
         pct_difference = round(100 * difference / published_n, 1))

rule("PA-SIT GROUP SIZES: OURS vs PUBLISHED")
print(as.data.frame(group_check))
save_tab(group_check, "engelen_02_group_sizes")

# ============================================================================
# 3. Outcome prevalence
# ============================================================================

rule("OUTCOME PREVALENCE: OURS vs PUBLISHED")

des_full <- svrepdesign(
  data = eng, weights = ~wt, repweights = eng[, person_rep_cols],
  type = "JK1", scale = 59 / 60, combined.weights = TRUE
)

rep_cols <- grep("^RPWGT", names(mets_dat), value = TRUE)
des_bio <- svrepdesign(
  data = mets_dat, weights = ~NHMSPERW,
  repweights = mets_dat[, rep_cols], type = "JK1",
  scale = 59 / 60, combined.weights = TRUE
)

prev <- function(design, formula) {
  e <- svymean(formula, design, na.rm = TRUE)
  c(est = 100 * as.numeric(e)[2], se = 100 * as.numeric(SE(e))[2])
}

outcome_check <- tibble(
  outcome = c("Cardiovascular disease", "Diabetes",
              "Metabolic syndrome (trig >= 2.0, strict)",
              "Metabolic syndrome (trig >= 1.5, lenient)"),
  published_pct = c(24.1, 5.1, 16.1, 16.1),
  published_se  = c(0.48, 0.24, 0.84, 0.84),
  ours_pct = c(prev(des_full, ~I(cvd))[1], prev(des_full, ~I(diabetes))[1],
               prev(des_bio, ~I(mets))[1], prev(des_bio, ~I(mets_lenient))[1]),
  ours_se  = c(prev(des_full, ~I(cvd))[2], prev(des_full, ~I(diabetes))[2],
               prev(des_bio, ~I(mets))[2], prev(des_bio, ~I(mets_lenient))[2])
) |>
  mutate(across(where(is.numeric), \(v) round(v, 2)))

print(as.data.frame(outcome_check))
save_tab(outcome_check, "engelen_03_outcome_prevalence")

# ============================================================================
# 4. Table 2: joint associations of PA-Sit group with each outcome
# ============================================================================
# Model 1: unadjusted
# Model 2: + sex, age group
# Model 3: + waist category, education, self-rated health, SEIFA, residence,
#          smoking, occupation
# Model 4: backward elimination from Model 3, dropping terms with p > 0.1.
# Waist circumference is excluded from the MetS models because it is one of the
# diagnostic criteria.

COVARS3 <- c("waist_category", "education", "self_rated_health", "seifa",
             "residence", "smoking", "occupation")

fit_model <- function(design, outcome, covars) {
  f <- reformulate(c("pa_sit", covars), response = paste0("I(", outcome, ")"))
  svyglm(f, design = design, family = quasibinomial())
}

backward <- function(design, outcome, covars) {
  keep <- covars
  repeat {
    m <- fit_model(design, outcome, keep)
    if (!length(keep)) return(m)
    pv <- vapply(keep, \(v) tryCatch(regTermTest(m, v)$p, error = \(e) NA_real_), numeric(1))
    worst <- names(which.max(pv))
    if (is.na(pv[worst]) || pv[worst] <= 0.1) return(m)
    keep <- setdiff(keep, worst)
  }
}

tidy_pa_sit <- function(model, label) {
  s <- summary(model)$coefficients
  rows <- grep("^pa_sit", rownames(s))
  ci <- suppressMessages(confint(model))
  tibble(
    model = label,
    group = str_remove(rownames(s)[rows], "^pa_sit"),
    or = exp(s[rows, 1]),
    lcl = exp(ci[rows, 1]),
    ucl = exp(ci[rows, 2]),
    p = s[rows, 4]
  )
}

run_outcome <- function(design, outcome, covars, drop_waist = FALSE) {
  cv <- if (drop_waist) setdiff(covars, "waist_category") else covars
  bind_rows(
    tidy_pa_sit(fit_model(design, outcome, character()), "Model 1"),
    tidy_pa_sit(fit_model(design, outcome, c("sex", "age_group")), "Model 2"),
    tidy_pa_sit(fit_model(design, outcome, c("sex", "age_group", cv)), "Model 3"),
    tidy_pa_sit(backward(design, outcome, c("sex", "age_group", cv)), "Model 4")
  ) |>
    mutate(outcome = outcome, .before = 1)
}

rule("TABLE 2 REPRODUCTION: joint associations with PA-Sit group")

table2 <- bind_rows(
  run_outcome(des_full, "cvd", COVARS3),
  run_outcome(des_full, "diabetes", COVARS3),
  run_outcome(des_bio, "mets", COVARS3, drop_waist = TRUE)
)

# Published odds ratios from Engelen Table 2, for comparison.
published <- tribble(
  ~outcome,   ~model,    ~group,             ~pub_or, ~pub_lcl, ~pub_ucl,
  "cvd",      "Model 1", "Low PA-Low Sit",     1.73, 1.42, 2.10,
  "cvd",      "Model 1", "High PA-High Sit",   0.92, 0.75, 1.14,
  "cvd",      "Model 1", "Low PA-High Sit",    1.65, 1.37, 1.98,
  "cvd",      "Model 2", "Low PA-Low Sit",     1.42, 1.18, 1.62,
  "cvd",      "Model 2", "High PA-High Sit",   1.27, 1.03, 1.57,
  "cvd",      "Model 2", "Low PA-High Sit",    1.74, 1.45, 2.09,
  "cvd",      "Model 3", "Low PA-Low Sit",     1.26, 1.01, 1.57,
  "cvd",      "Model 3", "High PA-High Sit",   1.28, 1.02, 1.60,
  "cvd",      "Model 3", "Low PA-High Sit",    1.40, 1.12, 1.74,
  "cvd",      "Model 4", "Low PA-Low Sit",     1.27, 1.03, 1.58,
  "cvd",      "Model 4", "High PA-High Sit",   1.28, 1.02, 1.60,
  "cvd",      "Model 4", "Low PA-High Sit",    1.41, 1.13, 1.75,
  "diabetes", "Model 1", "Low PA-Low Sit",     1.32, 0.90, 1.95,
  "diabetes", "Model 1", "High PA-High Sit",   0.63, 0.40, 1.00,
  "diabetes", "Model 1", "Low PA-High Sit",    1.38, 0.94, 2.03,
  "diabetes", "Model 2", "Low PA-Low Sit",     1.06, 0.70, 1.60,
  "diabetes", "Model 2", "High PA-High Sit",   0.76, 0.47, 1.22,
  "diabetes", "Model 2", "Low PA-High Sit",    1.28, 0.86, 1.90,
  "diabetes", "Model 3", "Low PA-Low Sit",     0.79, 0.50, 1.24,
  "diabetes", "Model 3", "High PA-High Sit",   0.93, 0.58, 1.49,
  "diabetes", "Model 3", "Low PA-High Sit",    0.94, 0.63, 1.41,
  "diabetes", "Model 4", "Low PA-Low Sit",     0.81, 0.51, 1.26,
  "diabetes", "Model 4", "High PA-High Sit",   0.84, 0.53, 1.35,
  "diabetes", "Model 4", "Low PA-High Sit",    0.90, 0.60, 1.36,
  "mets",     "Model 1", "Low PA-Low Sit",     1.85, 1.27, 2.70,
  "mets",     "Model 1", "High PA-High Sit",   1.13, 0.72, 1.78,
  "mets",     "Model 1", "Low PA-High Sit",    2.77, 1.99, 3.86,
  "mets",     "Model 2", "Low PA-Low Sit",     1.87, 1.26, 2.77,
  "mets",     "Model 2", "High PA-High Sit",   1.27, 0.81, 1.99,
  "mets",     "Model 2", "Low PA-High Sit",    2.71, 1.88, 3.90,
  "mets",     "Model 3", "Low PA-Low Sit",     1.41, 0.99, 2.23,
  "mets",     "Model 3", "High PA-High Sit",   1.39, 0.85, 2.28,
  "mets",     "Model 3", "Low PA-High Sit",    2.29, 1.56, 3.36,
  "mets",     "Model 4", "Low PA-Low Sit",     1.47, 0.99, 2.16,
  "mets",     "Model 4", "High PA-High Sit",   1.51, 0.95, 2.39,
  "mets",     "Model 4", "Low PA-High Sit",    2.37, 1.63, 3.45
)

comparison <- table2 |>
  left_join(published, by = c("outcome", "model", "group")) |>
  mutate(
    or_ratio = or / pub_or,
    covers_published = pub_or >= lcl & pub_or <= ucl,
    across(c(or, lcl, ucl, pub_or, pub_lcl, pub_ucl, or_ratio), \(v) round(v, 3)),
    p = signif(p, 3)
  ) |>
  select(outcome, model, group, or, lcl, ucl, p,
         pub_or, pub_lcl, pub_ucl, or_ratio, covers_published)

print(as.data.frame(comparison), max = 400)
save_tab(comparison, "engelen_04_table2_comparison")

agree <- comparison |> filter(!is.na(pub_or))
message("\nour CI covers the published OR in ",
        sum(agree$covers_published), " of ", nrow(agree), " comparisons")
message("median |log OR ratio|: ",
        round(median(abs(log(agree$or_ratio))), 3))

# ============================================================================
# 5. Figures
# ============================================================================

lab_out <- c(cvd = "Cardiovascular disease", diabetes = "Diabetes",
             mets = "Metabolic syndrome")

plot_dat <- comparison |>
  filter(!is.na(pub_or)) |>
  mutate(outcome = factor(lab_out[outcome], levels = lab_out),
         group = factor(group, levels = c("Low PA-Low Sit", "High PA-High Sit",
                                          "Low PA-High Sit")))

p_forest <- plot_dat |>
  pivot_longer(c(or, pub_or), names_to = "source", values_to = "estimate") |>
  mutate(
    lo = if_else(source == "or", lcl, pub_lcl),
    hi = if_else(source == "or", ucl, pub_ucl),
    source = factor(if_else(source == "or", "Our reproduction", "Engelen et al. (2017)"),
                    levels = c("Engelen et al. (2017)", "Our reproduction"))
  ) |>
  ggplot(aes(x = estimate, y = fct_rev(group), colour = source)) +
  geom_vline(xintercept = 1, linetype = "dashed", colour = "grey40") +
  geom_pointrange(aes(xmin = lo, xmax = hi),
                  position = position_dodge(width = 0.6), size = 0.35) +
  facet_grid(outcome ~ model) +
  scale_x_log10(breaks = c(0.5, 1, 2, 4)) +
  scale_colour_manual(values = c("Engelen et al. (2017)" = "grey35",
                                 "Our reproduction" = "#C0392B"), name = NULL) +
  labs(
    title = "Reproduction of Engelen et al. (2017), Table 2",
    subtitle = "Odds of each condition by physical-activity/sitting group, reference = High PA-Low Sit",
    x = "Odds ratio (log scale)", y = NULL,
    caption = paste("Source: ABS NNPAS 2011-12 Basic CURF, adults 18+.",
                    "Metabolic syndrome uses the biomedical subsample with 60 jackknife replicate weights.")
  )

save_fig(p_forest, "repro_engelen_01_forest", width = 12, height = 7)

p_scatter <- plot_dat |>
  ggplot(aes(x = pub_or, y = or, colour = outcome, shape = model)) +
  geom_abline(slope = 1, intercept = 0, linetype = "dashed", colour = "grey40") +
  geom_point(size = 2.6) +
  scale_x_log10() + scale_y_log10() +
  scale_colour_brewer(palette = "Dark2", name = NULL) +
  labs(title = "Our odds ratios against the published values",
       subtitle = "Points on the dashed line are exact reproductions",
       x = "Published odds ratio (log scale)",
       y = "Our odds ratio (log scale)", shape = NULL)

save_fig(p_scatter, "repro_engelen_02_agreement", width = 8, height = 6.5)

p_gradient <- eng |>
  filter(!is.na(pa_sit)) |>
  group_by(pa_sit) |>
  summarise(cvd = weighted.mean(cvd, wt), diabetes = weighted.mean(diabetes, wt),
            n = n(), .groups = "drop") |>
  pivot_longer(c(cvd, diabetes), names_to = "outcome", values_to = "prev") |>
  mutate(outcome = lab_out[outcome]) |>
  ggplot(aes(x = pa_sit, y = prev, fill = pa_sit)) +
  geom_col(width = 0.72, show.legend = FALSE) +
  geom_text(aes(label = percent(prev, accuracy = 0.1)), vjust = -0.5, size = 3.2) +
  facet_wrap(~outcome, scales = "free_y") +
  scale_y_continuous(labels = percent, expand = expansion(mult = c(0, 0.15))) +
  scale_fill_brewer(palette = "RdYlBu", direction = -1) +
  labs(title = "Weighted prevalence of self-reported disease by activity-sitting group",
       x = NULL, y = "Weighted prevalence", caption = CAPTION) +
  theme(axis.text.x = element_text(angle = 20, hjust = 1))

save_fig(p_gradient, "repro_engelen_03_prevalence_gradient", width = 10, height = 5)

saveRDS(eng, file.path(DERIVED, "engelen_adults.rds"))
saveRDS(mets_dat, file.path(DERIVED, "engelen_mets.rds"))

message("\nReproduction complete.")
