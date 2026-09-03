# RQ2: which dietary, physical-activity, demographic and socioeconomic
# characteristics distinguish adults with elevated cardiometabolic risk, and do
# those characteristics act differently at normal BMI?
#
# Design: the full biomedical sample (n = 3,525) is used rather than only the
# normal-BMI stratum, and BMI class x predictor interactions test whether each
# association differs by adiposity. This is more efficient than a normal-BMI-only
# model (1,523 events rather than 276) and it answers the "beyond BMI" question
# directly: an interaction means the predictor carries information about risk
# that BMI does not already encode.
#
# Two things are reported for every predictor:
#   1. the adjusted association with elevated risk, controlling for BMI class;
#   2. the BMI-class-specific association, from the interaction model.
# The normal-BMI-only stratified model is also fitted, because that is what RQ2
# literally asks, and it should agree with the interaction model's normal stratum.
#
# All models are survey-weighted using the 60 NHMS jackknife replicate weights.
#
# Output: outputs/tables/rq2_*.csv, outputs/figures/rq2_*.png

source("00_setup.R", chdir = TRUE)
suppressPackageStartupMessages(library(survey))
options(survey.lonely.psu = "adjust")

rule <- function(t) cat("\n", strrep("=", 74), "\n", t, "\n", strrep("=", 74), "\n", sep = "")

cmr <- readRDS(file.path(DERIVED, "cmr_analysis.rds"))
eng <- readRDS(file.path(DERIVED, "engelen_adults.rds"))
npa <- readRDS(file.path(DERIVED, "npa_person.rds"))

rep_cols <- grep("^RPWGT", names(cmr), value = TRUE)

# ============================================================================
# 1. Assemble predictors
# ============================================================================
# Dietary variables are energy-adjusted. Absolute intakes are strongly collinear
# with total energy (see 04_eda.R: energy-fat rho = 0.83), so nutrients enter as
# densities per 1000 kJ or as percentage of energy, with total energy kept as a
# separate term. The energy-intake-to-BMR ratio is included to adjust for
# differential under-reporting, which 04_eda.R showed varies systematically with
# adiposity and would otherwise bias every diet association.

dat <- cmr |>
  select(person_id, weight_biomed, all_of(rep_cols),
         age, sex, bmi, bmi_class, cmr_elevated, cmr_score) |>
  left_join(
    eng |> select(person_id, total_pa_min, sitting_min, seifa, education,
                  occupation, smoking, self_rated_health),
    by = "person_id") |>
  left_join(
    npa |> select(person_id, energy_kj_d1, fibre_g_d1, sodium_mg_d1,
                  potassium_mg_d1, pct_energy_satfat_d1, pct_energy_freesug_d1,
                  serves_veg_d1, serves_fruit_d1, ei_bmr_d1, sleep_hours,
                  sodium_potassium_ratio),
    by = "person_id") |>
  filter(
    bmi_class != "Underweight",                  # n = 37, too few to model
    energy_kj_d1 > 0                             # 4 recalls report no intake at all
  ) |>
  mutate(
    bmi_class = fct_drop(bmi_class),
    energy_mj = energy_kj_d1 / 1000,
    fibre_per_mj  = fibre_g_d1   / energy_mj,
    sodium_per_mj = sodium_mg_d1 / energy_mj,
    pa_hours_week = total_pa_min / 60,
    sitting_hours_day = sitting_min / 60 / 7,

    # Occupation collapsed from 10 categories to 5; the full set leaves cells
    # too small once crossed with BMI class.
    occupation5 = fct_collapse(occupation,
      "Managers/professionals" = c("Managers", "Professionals"),
      "Technicians/trades"     = "Technicians-trade",
      "Service/clerical/sales" = c("Community-person service",
                                   "Clerical-administrative", "Sales"),
      "Machinery/labourers"    = c("Machinery operators-drivers", "Labourers"),
      "Not employed"           = c("Unemployed", "Not in Labour Force")),
    smoking = fct_relevel(smoking, "Never smoked"),
    seifa = fct_relevel(seifa, "Lowest 20%")
  )

# Total energy is deliberately excluded: it correlates 0.89 with the
# energy-intake-to-BMR ratio (VIF 6.0 and 5.6 with both in the model), and the
# ratio is the more interpretable term because it expresses intake relative to
# metabolic requirement and therefore doubles as the under-reporting adjustment.
# All nutrients enter as densities, so the absolute-amount dimension is already
# accounted for.
CONTINUOUS <- c("age", "bmi", "pa_hours_week", "sitting_hours_day", "sleep_hours",
                "fibre_per_mj", "sodium_per_mj",
                "pct_energy_satfat_d1", "pct_energy_freesug_d1",
                "serves_veg_d1", "serves_fruit_d1", "ei_bmr_d1")

# Standardise so every odds ratio is per one standard deviation and therefore
# comparable across predictors on very different scales.
sds <- dat |> summarise(across(all_of(CONTINUOUS), \(x) sd(x, na.rm = TRUE)))
dat <- dat |> mutate(across(all_of(CONTINUOUS), \(x) as.numeric(scale(x))))

PREDICTORS <- c(CONTINUOUS[CONTINUOUS != "bmi"],
                "sex", "seifa", "education", "occupation5", "smoking",
                "self_rated_health")

model_dat <- dat |> filter(if_all(all_of(c(PREDICTORS, "bmi", "cmr_elevated")), \(x) !is.na(x)))
message("analysis n: ", nrow(model_dat),
        " | elevated: ", sum(model_dat$cmr_elevated),
        " | normal-BMI elevated: ",
        sum(model_dat$cmr_elevated & model_dat$bmi_class == "Normal"))

des <- svrepdesign(
  data = model_dat, weights = ~weight_biomed,
  repweights = model_dat[, rep_cols], type = "JK1",
  scale = 59 / 60, combined.weights = TRUE
)

LABELS <- c(
  age = "Age (per SD, 16.6 y)", sex = "Sex", bmi = "BMI (per SD)",
  bmi_class = "BMI category",
  pa_hours_week = "Physical activity (per SD, h/wk)",
  sitting_hours_day = "Sitting time (per SD, h/day)",
  sleep_hours = "Sleep duration (per SD, h)",
  fibre_per_mj = "Fibre density (per SD, g/MJ)",
  sodium_per_mj = "Sodium density (per SD, mg/MJ)",
  pct_energy_satfat_d1 = "% energy from saturated fat (per SD)",
  pct_energy_freesug_d1 = "% energy from free sugars (per SD)",
  serves_veg_d1 = "Vegetable serves (per SD)",
  serves_fruit_d1 = "Fruit serves (per SD)",
  ei_bmr_d1 = "Energy intake : BMR (per SD)",
  seifa = "SEIFA quintile", education = "Education",
  occupation5 = "Occupation", smoking = "Smoking status",
  self_rated_health = "Self-rated health"
)

# ============================================================================
# 2. Main-effects model: adjusted associations controlling for BMI class
# ============================================================================

rule("RQ2a: ADJUSTED ASSOCIATIONS WITH ELEVATED RISK (main effects)")

f_main <- reformulate(c("bmi_class", PREDICTORS), response = "I(cmr_elevated)")
m_main <- svyglm(f_main, design = des, family = quasibinomial())

tidy_svyglm <- function(model, keep = NULL) {
  s <- summary(model)$coefficients
  ci <- suppressMessages(confint(model))
  out <- tibble(term = rownames(s), or = exp(s[, 1]),
                lcl = exp(ci[, 1]), ucl = exp(ci[, 2]), p = s[, 4]) |>
    filter(term != "(Intercept)")
  if (!is.null(keep)) out <- out |> filter(str_detect(term, keep))
  out
}

main_tbl <- tidy_svyglm(m_main) |>
  mutate(
    variable = map_chr(term, \(t) {
      hit <- names(LABELS)[map_lgl(names(LABELS), \(v) startsWith(t, v))]
      if (length(hit)) hit[which.max(nchar(hit))] else t
    }),
    level = if_else(term == variable, "", str_remove(term, fixed(variable))),
    label = LABELS[variable] |> coalesce(variable),
    across(c(or, lcl, ucl), \(v) round(v, 3)), p = signif(p, 3)
  ) |>
  select(label, level, or, lcl, ucl, p) |>
  arrange(p)

print(as.data.frame(main_tbl), max = 300)
save_tab(main_tbl, "rq2_01_main_effects")

# Design-based joint test for each variable (handles multi-level factors).
joint <- tibble(
  variable = c("bmi_class", PREDICTORS),
  p_joint = map_dbl(c("bmi_class", PREDICTORS),
                    \(v) tryCatch(regTermTest(m_main, v)$p[1], error = \(e) NA_real_))
) |>
  mutate(label = coalesce(LABELS[variable], variable),
         p_holm = p.adjust(p_joint, "holm")) |>
  arrange(p_joint) |>
  select(label, p_joint, p_holm) |>
  mutate(across(c(p_joint, p_holm), \(v) signif(v, 3)))

rule("RQ2a: JOINT WALD TESTS, HOLM-ADJUSTED")
print(as.data.frame(joint))
save_tab(joint, "rq2_02_joint_tests")

# ============================================================================
# 3. Interaction models: does each predictor act differently by BMI class?
# ============================================================================
# One interaction is tested at a time, keeping all other predictors as main
# effects. Fitting every interaction simultaneously would be unstable with 5
# multi-level factors; testing them one at a time with Holm adjustment across
# the family of tests is the standard compromise.

rule("RQ2b: BMI CLASS x PREDICTOR INTERACTIONS")

test_interaction <- function(v) {
  f <- reformulate(c("bmi_class", PREDICTORS, paste0("bmi_class:", v)),
                   response = "I(cmr_elevated)")
  m <- svyglm(f, design = des, family = quasibinomial())
  p <- tryCatch(regTermTest(m, paste0("bmi_class:", v))$p[1], error = \(e) NA_real_)
  list(model = m, p = p)
}

inter <- map(set_names(PREDICTORS), test_interaction)

inter_tbl <- tibble(
  variable = names(inter),
  p_interaction = map_dbl(inter, "p")
) |>
  mutate(label = coalesce(LABELS[variable], variable),
         p_holm = p.adjust(p_interaction, "holm")) |>
  arrange(p_interaction) |>
  select(label, p_interaction, p_holm) |>
  mutate(across(c(p_interaction, p_holm), \(v) signif(v, 3)))

print(as.data.frame(inter_tbl))
save_tab(inter_tbl, "rq2_03_interaction_tests")

# ============================================================================
# 4. BMI-class-specific odds ratios for the continuous predictors
# ============================================================================
# Fitted from the interaction model as the simple slope within each BMI class,
# so the normal-BMI column is the direct answer to RQ2 as worded.

rule("RQ2c: PREDICTOR ODDS RATIOS WITHIN EACH BMI CLASS")

CONT_PRED <- setdiff(CONTINUOUS, "bmi")

stratum_or <- function(v) {
  m <- inter[[v]]$model
  b <- coef(m); V <- vcov(m)
  levs <- levels(model_dat$bmi_class)
  map_dfr(levs, \(lv) {
    terms <- if (lv == levs[1]) v else c(v, paste0("bmi_class", lv, ":", v))
    terms <- intersect(terms, names(b))
    L <- rep(0, length(b)); names(L) <- names(b); L[terms] <- 1
    est <- sum(L * b); se <- sqrt(drop(t(L) %*% V %*% L))
    tibble(variable = v, bmi_class = lv, or = exp(est),
           lcl = exp(est - 1.96 * se), ucl = exp(est + 1.96 * se),
           p = 2 * pnorm(-abs(est / se)))
  })
}

strat <- map_dfr(CONT_PRED, stratum_or) |>
  mutate(label = LABELS[variable],
         bmi_class = factor(bmi_class, levels = levels(model_dat$bmi_class)))

strat_print <- strat |>
  select(label, bmi_class, or, lcl, ucl, p) |>
  mutate(across(c(or, lcl, ucl), \(v) round(v, 3)), p = signif(p, 3))
print(as.data.frame(strat_print), max = 300)
save_tab(strat_print, "rq2_04_stratum_specific_or")

# ---- Cross-check against a genuinely normal-BMI-only model ------------------
rule("RQ2 CROSS-CHECK: normal-BMI-only stratified model")

nw <- model_dat |> filter(bmi_class == "Normal")
des_nw <- svrepdesign(
  data = nw, weights = ~weight_biomed, repweights = nw[, rep_cols],
  type = "JK1", scale = 59 / 60, combined.weights = TRUE
)
m_nw <- svyglm(reformulate(PREDICTORS, response = "I(cmr_elevated)"),
               design = des_nw, family = quasibinomial())

nw_tbl <- tidy_svyglm(m_nw) |>
  filter(term %in% CONT_PRED) |>
  transmute(label = LABELS[term], or_normal_only = round(or, 3),
            lcl = round(lcl, 3), ucl = round(ucl, 3), p = signif(p, 3))

compare_nw <- strat |>
  filter(bmi_class == "Normal") |>
  transmute(label, or_from_interaction = round(or, 3)) |>
  left_join(nw_tbl, by = "label") |>
  mutate(ratio = round(or_from_interaction / or_normal_only, 3))
print(as.data.frame(compare_nw))
save_tab(compare_nw, "rq2_05_normal_only_crosscheck")
message("n normal-BMI: ", nrow(nw), " | elevated: ", sum(nw$cmr_elevated))

# ============================================================================
# 5. Figures
# ============================================================================

sig_main <- main_tbl |> filter(p < 0.05) |> pull(label) |> unique()

p_main <- tidy_svyglm(m_main) |>
  mutate(
    variable = map_chr(term, \(t) {
      hit <- names(LABELS)[map_lgl(names(LABELS), \(v) startsWith(t, v))]
      if (length(hit)) hit[which.max(nchar(hit))] else t
    }),
    level = if_else(term == variable, "", str_remove(term, fixed(variable))),
    display = if_else(level == "", coalesce(LABELS[variable], variable),
                      paste0(coalesce(LABELS[variable], variable), ": ", level)),
    block = case_when(
      variable %in% c("age", "sex", "bmi_class") ~ "Demographic\n& BMI",
      variable %in% c("pa_hours_week", "sitting_hours_day", "sleep_hours",
                      "smoking") ~ "Activity,\nsleep,\nsmoking",
      variable %in% c("seifa", "education", "occupation5",
                      "self_rated_health") ~ "Socioeconomic\n& health",
      TRUE ~ "Diet"),
    signif = p < 0.05
  ) |>
  ggplot(aes(x = or, y = fct_reorder(display, or), colour = signif)) +
  geom_vline(xintercept = 1, linetype = "dashed", colour = "grey40") +
  geom_pointrange(aes(xmin = lcl, xmax = ucl), size = 0.32) +
  facet_grid(block ~ ., scales = "free_y", space = "free_y", switch = "y") +
  scale_x_log10() +
  scale_colour_manual(values = c(`TRUE` = "#C0392B", `FALSE` = "grey55"),
                      labels = c(`TRUE` = "p < 0.05", `FALSE` = "n.s."), name = NULL) +
  labs(title = "RQ2: adjusted associations with elevated cardiometabolic risk",
       subtitle = sprintf("Survey-weighted logistic regression, mutually adjusted, n = %s adults in the biomedical subsample",
                          format(nrow(model_dat), big.mark = ",")),
       x = "Odds ratio (log scale)", y = NULL,
       caption = "Continuous predictors are per standard deviation. Diet variables are energy-adjusted and the energy-intake-to-BMR ratio adjusts for differential under-reporting.") +
  theme(strip.placement = "outside",
        strip.text.y.left = element_text(angle = 0, size = 8, face = "bold"))

save_fig(p_main, "rq2_01_main_effects", width = 11, height = 10)

top_inter <- inter_tbl |> slice_head(n = 6) |> pull(label)

p_strat <- strat |>
  filter(label %in% top_inter) |>
  ggplot(aes(x = or, y = fct_rev(bmi_class), colour = bmi_class)) +
  geom_vline(xintercept = 1, linetype = "dashed", colour = "grey40") +
  geom_pointrange(aes(xmin = lcl, xmax = ucl), size = 0.42, show.legend = FALSE) +
  facet_wrap(~str_wrap(label, 30), scales = "free_x") +
  scale_x_log10() +
  scale_colour_brewer(palette = "RdYlBu", direction = -1) +
  labs(title = "RQ2: do predictors act differently at normal BMI?",
       subtitle = "Simple slopes within each BMI class, from the BMI-class x predictor interaction models",
       x = "Odds ratio per SD (log scale)", y = NULL,
       caption = "The six predictors with the smallest interaction p-values are shown. Survey-weighted with 60 jackknife replicate weights.")

save_fig(p_strat, "rq2_02_stratum_specific", width = 11, height = 6.5)

# Descriptive comparison of the two normal-BMI phenotypes, which is the
# contrast RQ2 is framed around.
pheno <- model_dat |>
  filter(bmi_class == "Normal") |>
  mutate(group = if_else(cmr_elevated, "Normal weight,\nelevated risk",
                         "Normal weight,\nfavourable")) |>
  select(group, all_of(CONT_PRED)) |>
  pivot_longer(-group, names_to = "variable", values_to = "z") |>
  group_by(variable, group) |>
  summarise(mean_z = mean(z), se = sd(z) / sqrt(n()), .groups = "drop") |>
  mutate(label = LABELS[variable] |> str_remove(" \\(per SD.*\\)"))

p_pheno <- ggplot(pheno, aes(x = mean_z, y = fct_reorder(label, mean_z),
                             colour = group)) +
  geom_vline(xintercept = 0, linetype = "dashed", colour = "grey40") +
  geom_pointrange(aes(xmin = mean_z - 1.96 * se, xmax = mean_z + 1.96 * se),
                  position = position_dodge(width = 0.5), size = 0.35) +
  scale_colour_manual(values = c("Normal weight,\nfavourable" = "#3B7EA1",
                                 "Normal weight,\nelevated risk" = "#C0392B"),
                      name = NULL) +
  labs(title = "The two normal-BMI phenotypes, side by side",
       subtitle = "Standardised means with 95% CI; zero is the overall sample mean",
       x = "Standardised mean (SD units)", y = NULL, caption = CAPTION)

save_fig(p_pheno, "rq2_03_normal_bmi_phenotypes", width = 9, height = 6)

saveRDS(model_dat, file.path(DERIVED, "rq2_model_data.rds"))
write_csv(sds |> pivot_longer(everything(), names_to = "variable",
                              values_to = "sd_original_units"),
          file.path(TAB_DIR, "rq2_00_predictor_sds.csv"))
message("\nRQ2 complete.")
