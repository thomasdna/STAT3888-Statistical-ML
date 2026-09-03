# ---------------------------------------------------------------------------
# 11_chol_bmi_waist.R
#
# Delivers the task assigned to Minh in STAT3888_Candidate_Q1.pdf:
#   "Task 3: BMI and obesity as screening indicators"
#   - measured high cholesterol across healthy-weight / overweight / obese
#   - BMI vs waist circumference: which shows a clearer relationship
#   - whether the relationship differs across age or sex
#   - conclusion on whether BMI or waist is useful
#
# It then extends the brief in the direction the previous NNPAS analysis
# (scripts 06-08) says matters: the same adiposity measures are tested against
# four different lipid outcomes, because the answer depends entirely on which
# lipid you pick. That also settles the HDL-vs-LDL point raised in the team
# chat.
#
# Everything is survey-weighted using the biomedical weight (NHMSPERW) with
# 60 replicate weights, so prevalences and standard errors are population
# estimates rather than sample descriptions.
# ---------------------------------------------------------------------------

source("00_setup.R")
suppressPackageStartupMessages(library(survey))
options(survey.lonely.psu = "adjust")

message("== 11_chol_bmi_waist ==")

d <- fread(file.path(DERIVED, "nhs_chol.csv"))
rep_cols <- sprintf("RPWGT%02d", 1:60)

# Restore factor ordering lost in the CSV round-trip.
d$bmi_class   <- factor(d$bmi_class, c("Underweight", "Normal", "Overweight",
                                       "Obese I", "Obese II-III"))
d$waist_class <- factor(d$waist_class, c("Not at risk", "Increased risk",
                                         "Substantially increased"))
d$age_grp     <- factor(d$age_grp, c("18-34", "35-44", "45-54", "55-64", "65+"))
d$sex         <- factor(d$sex, c("Male", "Female"))
d$smoking     <- factor(d$smoking, c("Never", "Ex-smoker", "Current"))
d$seifa_q     <- factor(d$seifa_q, c("Q1 (most disadv.)", "Q2", "Q3", "Q4",
                                     "Q5 (least disadv.)"))

# svymean treats a logical as a two-level factor and returns one column per
# level, so binary outcomes are carried as 0/1 integers instead.
log_cols <- names(d)[vapply(d, is.logical, logical(1))]
d[, (log_cols) := lapply(.SD, as.integer), .SDcols = log_cols]

CAP_NHS <- paste0(
  "Source: ABS Australian Health Survey 2011-13, National Health Survey Basic CURF.\n",
  "Weighted to the Australian population using the biomedical weight (NHMSPERW); ",
  "95% CIs from 60 jackknife replicate weights."
)

des <- svrepdesign(
  data = d, weights = ~weight_biomed, repweights = d[, ..rep_cols],
  type = "JK1", scale = 59 / 60, combined.weights = TRUE
)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

#' Weighted prevalence of a 0/1 outcome within groups, with replicate-weight CI.
wprev <- function(design, outcome, group) {
  f_out <- as.formula(paste0("~", outcome))
  f_grp <- as.formula(paste0("~", group))
  sub <- subset(design, !is.na(design$variables[[outcome]]) &
                        !is.na(design$variables[[group]]))
  est <- svyby(f_out, f_grp, sub, svymean, na.rm = TRUE, vartype = c("se", "ci"))
  n <- sub$variables |>
    filter(!is.na(.data[[outcome]]), !is.na(.data[[group]])) |>
    count(.data[[group]], name = "n")
  out <- tibble::tibble(
    group = as.character(est[[group]]),
    prev  = est[[outcome]],
    se    = est$se,
    lcl   = pmax(0, est$ci_l),
    ucl   = pmin(1, est$ci_u)
  )
  left_join(out, n |> rename(group = 1) |> mutate(group = as.character(group)),
            by = "group")
}

#' Weighted AUC (Mann-Whitney form with survey weights, ties counted at 0.5).
wauc <- function(score, label, w) {
  ok <- !is.na(score) & !is.na(label) & !is.na(w)
  score <- score[ok]; label <- as.integer(label[ok]); w <- w[ok]
  if (length(unique(label)) < 2) return(NA_real_)
  o <- order(score); score <- score[o]; label <- label[o]; w <- w[o]
  g <- match(score, unique(score))
  posw <- as.numeric(tapply(w * (label == 1), g, sum)); posw[is.na(posw)] <- 0
  negw <- as.numeric(tapply(w * (label == 0), g, sum)); negw[is.na(negw)] <- 0
  Wp <- sum(posw); Wn <- sum(negw)
  if (Wp == 0 || Wn == 0) return(NA_real_)
  below <- cumsum(c(0, head(negw, -1)))
  sum(posw * (below + 0.5 * negw)) / (Wp * Wn)
}

#' Replicate-weight CI for the weighted AUC.
wauc_ci <- function(data, score, label, w_col = "weight_biomed") {
  point <- wauc(data[[score]], data[[label]], data[[w_col]])
  reps <- vapply(rep_cols, \(rc) wauc(data[[score]], data[[label]], data[[rc]]),
                 numeric(1))
  se <- sqrt(59 / 60 * sum((reps - point)^2))
  c(auc = point, lcl = point - 1.96 * se, ucl = point + 1.96 * se, se = se)
}

OUTCOMES <- c(
  chol_high        = "High total cholesterol (>=5.5 mmol/L)",
  hdl_low          = "Low HDL cholesterol (sex-specific)",
  ldl_high         = "High LDL cholesterol (>=3.5, fasting)",
  dyslip_untreated = "Untreated dyslipidaemia (CVDMEDST=3)"
)

# ===========================================================================
# 1. DELIVERABLE: measured high cholesterol by BMI category
# ===========================================================================

message("\n-- 1. high cholesterol by BMI category (weighted) --")

bmi_prev <- bind_rows(
  wprev(des, "chol_high", "bmi_class") |> mutate(outcome = "Measured high total cholesterol"),
  wprev(des, "unrecognised_strict", "bmi_class") |>
    mutate(outcome = "High + no current self-report")
) |>
  mutate(group = factor(group, levels(d$bmi_class)))
print(as.data.frame(bmi_prev))
save_tab(bmi_prev, "11_prev_by_bmi_class")

p1 <- bmi_prev |>
  filter(!is.na(group)) |>
  ggplot(aes(x = group, y = prev, fill = outcome)) +
  geom_col(position = position_dodge(0.8), width = 0.72) +
  geom_errorbar(aes(ymin = lcl, ymax = ucl), position = position_dodge(0.8),
                width = 0.14, colour = "grey25") +
  geom_text(aes(label = percent(prev, accuracy = 0.1), y = ucl),
            position = position_dodge(0.8), vjust = -0.6, size = 3) +
  scale_y_continuous(labels = percent, limits = c(0, 0.62),
                     expand = expansion(mult = c(0, 0.02))) +
  scale_fill_manual(values = c("Measured high total cholesterol" = "#3B7EA1",
                               "High + no current self-report" = "#8FBFD8"),
                    name = NULL) +
  labs(
    title = "High total cholesterol rises only modestly with BMI, and is already common at normal weight",
    subtitle = paste0("Australian adults 18+ in the NHS biomedical sample. ",
                      "28% of normal-weight adults already have total cholesterol at or above 5.5 mmol/L,\n",
                      "against 38-39% of obese adults - a gap far too small to triage testing on."),
    x = "BMI category (BMICATHY)", y = "Weighted prevalence",
    caption = CAP_NHS
  )
save_fig(p1, "chol_01_bmi_category", width = 10, height = 6)

# ===========================================================================
# 2. DELIVERABLE: measured high cholesterol by waist category
# ===========================================================================

message("\n-- 2. high cholesterol by waist category (weighted) --")

waist_prev <- bind_rows(
  wprev(des, "chol_high", "waist_class") |> mutate(outcome = "Measured high total cholesterol"),
  wprev(des, "unrecognised_strict", "waist_class") |>
    mutate(outcome = "High + no current self-report")
) |>
  mutate(group = factor(group, levels(d$waist_class)))
print(as.data.frame(waist_prev))
save_tab(waist_prev, "11_prev_by_waist_class")

p2 <- waist_prev |>
  filter(!is.na(group)) |>
  ggplot(aes(x = group, y = prev, fill = outcome)) +
  geom_col(position = position_dodge(0.8), width = 0.72) +
  geom_errorbar(aes(ymin = lcl, ymax = ucl), position = position_dodge(0.8),
                width = 0.14, colour = "grey25") +
  geom_text(aes(label = percent(prev, accuracy = 0.1), y = ucl),
            position = position_dodge(0.8), vjust = -0.6, size = 3) +
  scale_y_continuous(labels = percent, limits = c(0, 0.62),
                     expand = expansion(mult = c(0, 0.02))) +
  scale_fill_manual(values = c("Measured high total cholesterol" = "#5B8C5A",
                               "High + no current self-report" = "#A9C9A8"),
                    name = NULL) +
  labs(
    title = "Waist-based risk categories show the same shallow gradient as BMI",
    subtitle = "Sex-specific waist thresholds (PHDWCATM/PHDWCATF): men 94/102 cm, women 80/88 cm",
    x = "Waist risk category", y = "Weighted prevalence", caption = CAP_NHS
  )
save_fig(p2, "chol_02_waist_category", width = 10, height = 6)

# ===========================================================================
# 3. DELIVERABLE: does the relationship differ by age or sex?
# ===========================================================================

message("\n-- 3. age and sex --")

age_sex <- svyby(~chol_high, ~age_grp + sex,
                 subset(des, !is.na(chol_high) & !is.na(age_grp)),
                 svymean, na.rm = TRUE, vartype = c("se", "ci"))
age_sex_tab <- tibble::tibble(
  age_grp = age_sex$age_grp, sex = age_sex$sex, prev = age_sex$chol_high,
  lcl = pmax(0, age_sex$ci_l), ucl = pmin(1, age_sex$ci_u)
)
print(as.data.frame(age_sex_tab))
save_tab(age_sex_tab, "11_prev_by_age_sex")

p3 <- age_sex_tab |>
  ggplot(aes(x = age_grp, y = prev, colour = sex, group = sex)) +
  geom_ribbon(aes(ymin = lcl, ymax = ucl, fill = sex), alpha = 0.15,
              colour = NA) +
  geom_line(linewidth = 1) +
  geom_point(size = 2.4) +
  scale_y_continuous(labels = percent) +
  scale_colour_manual(values = c(Male = "#2C6E8F", Female = "#B5541F"), name = NULL) +
  scale_fill_manual(values = c(Male = "#2C6E8F", Female = "#B5541F"), guide = "none") +
  labs(
    title = "Age moves cholesterol far more than BMI does - but the curve turns down after 65",
    subtitle = paste("Women overtake men after ~55 (post-menopausal lipid shift). The fall in the oldest",
                     "group is\ntreatment, not biology: lipid-lowering medication is concentrated there,",
                     "so measured\ncholesterol looks normal. Any outcome based on measured levels alone",
                     "inherits this bias."),
    x = "Age group", y = "Weighted prevalence of high total cholesterol",
    caption = CAP_NHS
  )
save_fig(p3, "chol_03_age_sex", width = 9.5, height = 5.5)

# Does the BMI-cholesterol association differ by age or sex? Test interactions
# on the full biomedical sample.
message("\n-- interaction tests (survey-weighted logistic regression) --")
m_main <- svyglm(chol_high ~ bmi + age + sex, design = des,
                 family = quasibinomial())
m_bmi_sex <- svyglm(chol_high ~ bmi * sex + age, design = des,
                    family = quasibinomial())
m_bmi_age <- svyglm(chol_high ~ bmi * age + sex, design = des,
                    family = quasibinomial())
# Each interaction contributes a single coefficient (sex is binary, age is
# continuous), so the Wald test on that coefficient is the whole test.
wald_p <- function(fit, pattern) {
  cf <- summary(fit)$coefficients
  cf[grep(pattern, rownames(cf), fixed = TRUE)[1], 4]
}
int_tab <- tibble::tibble(
  interaction = c("BMI x sex", "BMI x age"),
  p_value = c(wald_p(m_bmi_sex, "bmi:sex"), wald_p(m_bmi_age, "bmi:age"))
)
print(as.data.frame(int_tab))
save_tab(int_tab, "11_interaction_tests")

# Stratified BMI slopes, for the "short comparison across age or sex groups".
strat <- purrr::map_dfr(levels(d$age_grp), function(ag) {
  purrr::map_dfr(c("Male", "Female"), function(sx) {
    sub <- subset(des, age_grp == ag & sex == sx & !is.na(chol_high) & !is.na(bmi))
    n <- nrow(sub$variables)
    if (n < 80 || length(unique(na.omit(sub$variables$chol_high))) < 2)
      return(tibble::tibble(age_grp = ag, sex = sx, n = n, or = NA, lcl = NA, ucl = NA))
    fit <- svyglm(chol_high ~ bmi, design = sub, family = quasibinomial())
    ci <- suppressMessages(confint(fit))
    tibble::tibble(age_grp = ag, sex = sx, n = n,
                   or = exp(coef(fit)[["bmi"]] * 5),
                   lcl = exp(ci["bmi", 1] * 5), ucl = exp(ci["bmi", 2] * 5))
  })
})
message("odds ratio for high cholesterol per 5 kg/m2 of BMI, by age and sex:")
print(as.data.frame(strat))
save_tab(strat, "11_bmi_or_by_age_sex")

p4 <- strat |>
  filter(!is.na(or)) |>
  ggplot(aes(x = age_grp, y = or, colour = sex)) +
  geom_hline(yintercept = 1, linetype = "dashed", colour = "grey45") +
  geom_pointrange(aes(ymin = lcl, ymax = ucl),
                  position = position_dodge(0.4), size = 0.45) +
  scale_y_log10() +
  scale_colour_manual(values = c(Male = "#2C6E8F", Female = "#B5541F"), name = NULL) +
  labs(
    title = "The BMI-cholesterol association is weak in every age-sex stratum",
    subtitle = "Odds ratio per 5 kg/m\u00b2 of BMI; almost every confidence interval includes 1",
    x = "Age group", y = "Odds ratio (log scale)", caption = CAP_NHS
  )
save_fig(p4, "chol_04_bmi_or_by_age_sex", width = 9, height = 5.5)

# ===========================================================================
# 4. BMI vs WAIST vs AGE: which discriminates, and for which lipid?
#    This is the extension beyond the assigned brief.
# ===========================================================================

message("\n-- 4. discrimination of single markers across four lipid outcomes --")

SCORES <- c(bmi = "BMI", waist = "Waist circumference", age = "Age",
            sbp = "Systolic BP")

disc <- purrr::map_dfr(names(OUTCOMES), function(oc) {
  purrr::map_dfr(names(SCORES), function(sc) {
    sub <- d[!is.na(get(oc)) & !is.na(get(sc))]
    r <- wauc_ci(sub, sc, oc)
    tibble::tibble(outcome = OUTCOMES[[oc]], outcome_var = oc,
                   marker = SCORES[[sc]], marker_var = sc, n = nrow(sub),
                   auc = r[["auc"]], lcl = r[["lcl"]], ucl = r[["ucl"]])
  })
})
print(as.data.frame(disc |> mutate(across(auc:ucl, \(x) round(x, 3)))))
save_tab(disc, "11_auc_marker_by_outcome")

p5 <- disc |>
  mutate(outcome = factor(outcome, OUTCOMES),
         marker = factor(marker, SCORES)) |>
  ggplot(aes(x = auc, y = fct_rev(marker), colour = marker)) +
  geom_vline(xintercept = 0.5, linetype = "dashed", colour = "grey40") +
  geom_pointrange(aes(xmin = lcl, xmax = ucl), size = 0.45) +
  geom_text(aes(label = sprintf("%.3f", auc)), vjust = -0.9, size = 2.9,
            show.legend = FALSE) +
  facet_wrap(~outcome, nrow = 2) +
  scale_x_continuous(limits = c(0.45, 0.80)) +
  scale_colour_brewer(palette = "Dark2", guide = "none") +
  labs(
    title = "Which lipid you choose decides whether BMI and waist are useful at all",
    subtitle = paste("BMI and waist discriminate low HDL reasonably well, but are almost useless",
                     "for total\nand LDL cholesterol, where age is the stronger single marker."),
    x = "Weighted AUC (0.5 = no discrimination)", y = NULL, caption = CAP_NHS
  )
save_fig(p5, "chol_05_auc_by_outcome", width = 10.5, height = 7)

# Prevalence gradient across BMI categories, for all four outcomes.
grad <- purrr::map_dfr(names(OUTCOMES), function(oc) {
  wprev(des, oc, "bmi_class") |> mutate(outcome = OUTCOMES[[oc]])
}) |>
  filter(!is.na(group)) |>
  mutate(group = factor(group, levels(d$bmi_class)),
         outcome = factor(outcome, OUTCOMES))
save_tab(grad, "11_bmi_gradient_all_outcomes")

p6 <- grad |>
  ggplot(aes(x = group, y = prev, group = outcome, colour = outcome)) +
  geom_line(linewidth = 0.9) +
  geom_pointrange(aes(ymin = lcl, ymax = ucl), size = 0.35) +
  scale_y_continuous(labels = percent, limits = c(0, NA)) +
  scale_colour_brewer(palette = "Set1", name = NULL) +
  guides(colour = guide_legend(nrow = 2)) +
  labs(
    title = "Low HDL tracks BMI steeply; total and LDL cholesterol barely respond",
    subtitle = "Weighted prevalence by BMI category for four lipid outcomes",
    x = "BMI category", y = "Weighted prevalence", caption = CAP_NHS
  )
save_fig(p6, "chol_06_bmi_gradient_all_outcomes", width = 10, height = 6)

# ===========================================================================
# 5. Adjusted associations: BMI and waist per unit, for each outcome
# ===========================================================================

message("\n-- 5. adjusted odds ratios (age- and sex-adjusted) --")

adj <- purrr::map_dfr(names(OUTCOMES), function(oc) {
  purrr::map_dfr(c("bmi", "waist"), function(sc) {
    step <- if (sc == "bmi") 5 else 10   # per 5 kg/m2, per 10 cm
    f <- as.formula(paste0(oc, " ~ ", sc, " + age + sex"))
    fit <- svyglm(f, design = des, family = quasibinomial())
    ci <- suppressMessages(confint(fit))
    tibble::tibble(
      outcome = OUTCOMES[[oc]],
      marker = if (sc == "bmi") "BMI (per 5 kg/m2)" else "Waist (per 10 cm)",
      or = exp(coef(fit)[[sc]] * step),
      lcl = exp(ci[sc, 1] * step), ucl = exp(ci[sc, 2] * step),
      p = summary(fit)$coefficients[sc, 4]
    )
  })
})
print(as.data.frame(adj |> mutate(across(or:ucl, \(x) round(x, 3)),
                                  p = signif(p, 3))))
save_tab(adj, "11_adjusted_or")

p7 <- adj |>
  mutate(outcome = factor(outcome, OUTCOMES)) |>
  ggplot(aes(x = or, y = fct_rev(outcome), colour = marker)) +
  geom_vline(xintercept = 1, linetype = "dashed", colour = "grey40") +
  geom_pointrange(aes(xmin = lcl, xmax = ucl), size = 0.45,
                  position = position_dodge(0.5)) +
  scale_x_log10() +
  scale_colour_manual(values = c("BMI (per 5 kg/m2)" = "#3B7EA1",
                                 "Waist (per 10 cm)" = "#5B8C5A"), name = NULL) +
  labs(
    title = "Adiposity is strongly associated with low HDL, weakly with the other lipids",
    subtitle = "Age- and sex-adjusted odds ratios, survey-weighted",
    x = "Odds ratio (log scale)", y = NULL, caption = CAP_NHS
  )
save_fig(p7, "chol_07_adjusted_or", width = 10, height = 5.5)

message("\ndone.")
