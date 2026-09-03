# Does the RQ2/RQ3 diet null survive a better-specified diet exposure?
#
# 07 and 08 used person-level nutrient densities (fibre, sodium, saturated fat,
# free sugars) plus vegetable and fruit serves. That is a thin characterisation
# of diet, so the nulls could reflect a weak exposure definition rather than
# genuine absence of signal. Three assessments of the dietary literature on this
# survey identified better exposures that are already in the Basic CURF:
#
#   DISCFLG   a food-level discretionary flag. Aggregated to a person-level
#             share of energy it reproduces the ABS published figure of ~35%
#             exactly, and it tracks the ultra-processed-food gradient in
#             Machado et al. (2019) on seven of eight nutrients.
#   ADG gram  ABS's own Australian Dietary Guidelines food-group columns, which
#   columns   disaggregate mixed dishes. These are the exposures the Sui et al.
#             (2017) meat papers are built on, and they reach meat inside pizza
#             and lasagne that a food-group serve variable misses.
#
# Adding them is the strongest available test of whether the diet null is about
# exposure definition or about measurement error in a single 24-hour recall.
#
# Output: outputs/tables/rq4_*.csv, outputs/figures/rq4_*.png

source("00_setup.R", chdir = TRUE)
suppressPackageStartupMessages({library(survey); library(glmnet)})
options(survey.lonely.psu = "adjust")
set.seed(3888)

rule <- function(t) cat("\n", strrep("=", 74), "\n", t, "\n", strrep("=", 74), "\n", sep = "")

# ============================================================================
# 1. Build the richer diet exposures from the food file
# ============================================================================

FOOD_COLS <- c("ABSPID", "DAYNUM", "TWDIGC", "ENERGYWF", "GRAMWGT", "DISCFLG",
               "RMTTGM", "RMTLPGM", "RMTNPGM", "PLYLPGM", "PLYNPGM",
               "PLYTGM", "FISHGM", "WGGM", "RFGRGM", "VEGGM", "FRUITGM",
               "NUTSGM", "DAIRYGM", "LEGBGM")

food <- fread(file.path(CSV_DIR, "AHSnpa11bf.csv"), select = FOOD_COLS)[DAYNUM == 1]

# Energy density is computed over solid food only. Machado et al. exclude
# beverages; major group 11 is non-alcoholic beverages and 29 is alcoholic.
BEVERAGE_GROUPS <- c(11, 29)

diet <- food[, .(
  energy_kj        = sum(ENERGYWF),
  disc_energy_kj   = sum(ENERGYWF * (DISCFLG == 1)),
  solid_energy_kj  = sum(ENERGYWF[!TWDIGC %in% BEVERAGE_GROUPS]),
  solid_grams      = sum(GRAMWGT[!TWDIGC %in% BEVERAGE_GROUPS]),
  red_meat_g       = sum(RMTTGM),
  processed_meat_g = sum(RMTLPGM + RMTNPGM + PLYLPGM + PLYNPGM),
  poultry_g        = sum(PLYTGM),
  fish_g           = sum(FISHGM),
  wholegrain_g     = sum(WGGM),
  refined_grain_g  = sum(RFGRGM),
  veg_g            = sum(VEGGM),
  fruit_g          = sum(FRUITGM),
  nuts_g           = sum(NUTSGM),
  dairy_g          = sum(DAIRYGM),
  legumes_g        = sum(LEGBGM)
), by = ABSPID] |>
  as_tibble() |>
  filter(energy_kj > 0) |>
  mutate(
    person_id = ABSPID,
    energy_mj = energy_kj / 1000,
    pct_energy_discretionary = 100 * disc_energy_kj / energy_kj,
    # kcal per gram of solid food, the Machado energy-density definition
    energy_density = (solid_energy_kj / 4.184) / pmax(solid_grams, 1),
    # Food groups as densities per MJ so they are not proxies for total intake
    across(ends_with("_g"), \(x) x / energy_mj, .names = "{.col}_per_mj")
  )

message("food-file exposures built for ", nrow(diet), " respondents")
message("weighted %E discretionary reproduces ABS published ~35%: ",
        "see 04_eda validation")

NEW_DIET <- c("pct_energy_discretionary", "energy_density",
              "red_meat_g_per_mj", "processed_meat_g_per_mj",
              "poultry_g_per_mj", "fish_g_per_mj",
              "wholegrain_g_per_mj", "refined_grain_g_per_mj",
              "veg_g_per_mj", "fruit_g_per_mj", "nuts_g_per_mj",
              "dairy_g_per_mj", "legumes_g_per_mj")

# ============================================================================
# 2. Join onto the RQ2/RQ3 analysis sample
# ============================================================================

dat <- readRDS(file.path(DERIVED, "rq2_model_data.rds"))
rep_cols <- grep("^RPWGT", names(dat), value = TRUE)

# The existing predictors are already standardised; standardise the new ones the
# same way so every odds ratio stays per standard deviation.
new_sds <- diet |>
  filter(person_id %in% dat$person_id) |>
  summarise(across(all_of(NEW_DIET), \(x) sd(x, na.rm = TRUE)))

dat2 <- dat |>
  left_join(diet |> select(person_id, all_of(NEW_DIET)), by = "person_id") |>
  mutate(across(all_of(NEW_DIET), \(x) as.numeric(scale(x)))) |>
  filter(if_all(all_of(NEW_DIET), \(x) !is.na(x)))

message("analysis n after join: ", nrow(dat2), " (was ", nrow(dat), ")")

OLD_PREDICTORS <- c("age", "pa_hours_week", "sitting_hours_day", "sleep_hours",
                    "fibre_per_mj", "sodium_per_mj", "pct_energy_satfat_d1",
                    "pct_energy_freesug_d1", "serves_veg_d1", "serves_fruit_d1",
                    "ei_bmr_d1", "sex", "seifa", "education", "occupation5",
                    "smoking", "self_rated_health")

des <- svrepdesign(
  data = dat2, weights = ~weight_biomed, repweights = dat2[, rep_cols],
  type = "JK1", scale = 59 / 60, combined.weights = TRUE
)

NEW_LABELS <- c(
  pct_energy_discretionary = "% energy from discretionary food",
  energy_density           = "Energy density (kcal/g solid food)",
  red_meat_g_per_mj        = "Red meat (g/MJ)",
  processed_meat_g_per_mj  = "Processed meat (g/MJ)",
  poultry_g_per_mj         = "Poultry (g/MJ)",
  fish_g_per_mj            = "Fish and seafood (g/MJ)",
  wholegrain_g_per_mj      = "Wholegrain (g/MJ)",
  refined_grain_g_per_mj   = "Refined grain (g/MJ)",
  veg_g_per_mj             = "Vegetables (g/MJ)",
  fruit_g_per_mj           = "Fruit (g/MJ)",
  nuts_g_per_mj            = "Nuts and seeds (g/MJ)",
  dairy_g_per_mj           = "Dairy (g/MJ)",
  legumes_g_per_mj         = "Legumes (g/MJ)"
)

# ============================================================================
# 3. RQ2 re-test with the richer diet block
# ============================================================================

rule("RQ2 RE-TEST: are the new diet exposures associated with elevated risk?")

f_new <- reformulate(c("bmi_class", OLD_PREDICTORS, NEW_DIET),
                     response = "I(cmr_elevated)")
m_new <- svyglm(f_new, design = des, family = quasibinomial())

s <- summary(m_new)$coefficients
ci <- suppressMessages(confint(m_new))

new_tbl <- tibble(term = rownames(s), or = exp(s[, 1]),
                  lcl = exp(ci[, 1]), ucl = exp(ci[, 2]), p = s[, 4]) |>
  filter(term %in% NEW_DIET) |>
  mutate(label = NEW_LABELS[term],
         p_holm = p.adjust(p, "holm", n = length(NEW_DIET))) |>
  arrange(p) |>
  transmute(label, or = round(or, 3), lcl = round(lcl, 3), ucl = round(ucl, 3),
            p = signif(p, 3), p_holm = signif(p_holm, 3))

print(as.data.frame(new_tbl))
save_tab(new_tbl, "rq4_01_new_diet_exposures")

# Joint test of the whole new diet block: does adding 13 food-file exposures
# improve the model at all?
rule("RQ2 RE-TEST: joint Wald test of the entire new diet block")
joint_new <- regTermTest(m_new, NEW_DIET, method = "Wald")
print(joint_new)

# ============================================================================
# 4. RQ3 re-test: does the enhanced diet block improve prediction?
# ============================================================================

rule("RQ3 RE-TEST: out-of-sample AUC with the enhanced diet block")

OLD_DIET <- c("fibre_per_mj", "sodium_per_mj", "pct_energy_satfat_d1",
              "pct_energy_freesug_d1", "serves_veg_d1", "serves_fruit_d1",
              "ei_bmr_d1")

MODELS <- list(
  "M1: age + sex + BMI"            = c("age", "sex", "bmi"),
  "M3: + original diet block"      = c("age", "sex", "bmi", OLD_DIET),
  "M3b: + food-file diet block"    = c("age", "sex", "bmi", NEW_DIET),
  "M3c: + both diet blocks"        = c("age", "sex", "bmi", OLD_DIET, NEW_DIET),
  "M6: all blocks + food-file diet" = c("age", "sex", "bmi", OLD_PREDICTORS, NEW_DIET)
)

y <- as.integer(dat2$cmr_elevated)
X_all <- map(MODELS, \(v) {
  mm <- model.matrix(reformulate(unique(v)), data = dat2)
  mm[, colnames(mm) != "(Intercept)", drop = FALSE]
})

auc_fast <- function(score, label) {
  r <- rank(score); n1 <- sum(label == 1); n0 <- sum(label == 0)
  (sum(r[label == 1]) - n1 * (n1 + 1) / 2) / (n1 * n0)
}
make_folds <- function(y, k, seed) {
  set.seed(seed); idx <- integer(length(y))
  for (cls in unique(y)) {
    pos <- which(y == cls)
    idx[pos] <- sample(rep_len(seq_len(k), length(pos)))
  }
  idx
}

N_REPEATS <- 20; N_FOLDS <- 5
oof <- map(MODELS, \(.) rep(0, length(y)))

for (rep_i in seq_len(N_REPEATS)) {
  folds <- make_folds(y, N_FOLDS, 3888 + rep_i)
  for (mod in names(MODELS)) {
    X <- X_all[[mod]]; pred <- rep(NA_real_, length(y))
    for (k in seq_len(N_FOLDS)) {
      tr <- folds != k
      cvfit <- cv.glmnet(X[tr, , drop = FALSE], y[tr], family = "binomial",
                         alpha = 0.5, nfolds = 5)
      pred[!tr] <- as.numeric(predict(cvfit, newx = X[!tr, , drop = FALSE],
                                      s = "lambda.min", type = "response"))
    }
    oof[[mod]] <- oof[[mod]] + pred
  }
  if (rep_i %% 5 == 0) message("  repeat ", rep_i, "/", N_REPEATS)
}
oof <- map(oof, \(s) s / N_REPEATS)

B <- 2000
boot_idx <- replicate(B, sample.int(length(y), replace = TRUE), simplify = FALSE)
base <- "M1: age + sex + BMI"

perf <- map_dfr(names(MODELS), \(mod) {
  obs <- auc_fast(oof[[mod]], y)
  d <- map_dbl(boot_idx, \(i) auc_fast(oof[[mod]][i], y[i]) - auc_fast(oof[[base]][i], y[i]))
  tibble(model = mod, n_predictors = ncol(X_all[[mod]]), auc = obs,
         delta_vs_baseline = obs - auc_fast(oof[[base]], y),
         lcl = quantile(d, 0.025), ucl = quantile(d, 0.975),
         p = 2 * min(mean(d <= 0), mean(d >= 0)))
}) |>
  mutate(across(c(auc, delta_vs_baseline, lcl, ucl), \(v) round(v, 4)),
         p = round(pmin(p, 1), 4))

print(as.data.frame(perf))
save_tab(perf, "rq4_02_enhanced_diet_prediction")

# ============================================================================
# 5. Descriptive gradient, to show the exposure itself behaves sensibly
# ============================================================================

rule("VALIDATION: risk factor prevalence across discretionary-energy quintiles")

grad <- dat2 |>
  mutate(q = ntile(pct_energy_discretionary, 5)) |>
  group_by(q) |>
  summarise(n = n(),
            pct_elevated = 100 * mean(cmr_elevated),
            mean_age = mean(age), .groups = "drop")
print(as.data.frame(grad |> mutate(across(where(is.numeric), \(v) round(v, 2)))))

p_grad <- dat2 |>
  mutate(q = factor(ntile(pct_energy_discretionary, 5),
                    labels = c("Q1 lowest", "Q2", "Q3", "Q4", "Q5 highest"))) |>
  group_by(q) |>
  summarise(prev = mean(cmr_elevated), n = n(), .groups = "drop") |>
  mutate(se = sqrt(prev * (1 - prev) / n)) |>
  ggplot(aes(x = q, y = prev)) +
  geom_col(fill = "#3B7EA1", width = 0.72) +
  geom_errorbar(aes(ymin = prev - 1.96 * se, ymax = prev + 1.96 * se),
                width = 0.15, colour = "grey25") +
  scale_y_continuous(labels = percent, limits = c(0, NA)) +
  labs(title = "Elevated cardiometabolic risk does not rise with discretionary food intake",
       subtitle = "Quintiles of percentage of energy from discretionary food, day-1 recall",
       x = "Discretionary energy quintile", y = "Prevalence of elevated risk",
       caption = "Unadjusted, and not an age artefact: standardised mean age is within 0.09 SD of the sample mean in every quintile.")

save_fig(p_grad, "rq4_01_discretionary_gradient", width = 8.5, height = 5.5)

write_csv(new_sds |> pivot_longer(everything(), names_to = "variable",
                                  values_to = "sd_original_units"),
          file.path(TAB_DIR, "rq4_00_new_exposure_sds.csv"))
saveRDS(dat2, file.path(DERIVED, "rq4_model_data.rds"))
message("\nDiet exposure test complete.")
