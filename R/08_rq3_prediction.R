# RQ3: do dietary, physical-activity and socioeconomic variables improve
# out-of-sample prediction of elevated cardiometabolic risk beyond age, sex and
# BMI alone?
#
# Design. Six nested predictor blocks are compared, each fitted by penalised
# logistic regression (elastic net via glmnet). Performance is estimated by
# repeated stratified cross-validation with the penalty tuned INSIDE each
# training fold, so no test observation influences either the coefficients or
# the penalty. Comparisons are paired within replicate-fold, which is what makes
# the differences testable: the same test observations are scored by every model.
#
# Metrics:
#   AUC   - rank discrimination, the quantity RQ3 is naturally phrased around
#   Brier - overall accuracy of the predicted probabilities
#   Log loss - proper scoring rule, sensitive to calibration
#
# Note on weights. Prediction is assessed unweighted, because the question is
# how well an individual's risk can be predicted, not what the population mean
# is. Survey weights matter for the descriptive and inferential parts of this
# project (RQ1, RQ2) and are used there.
#
# Output: outputs/tables/rq3_*.csv, outputs/figures/rq3_*.png

source("00_setup.R", chdir = TRUE)
suppressPackageStartupMessages({library(glmnet); library(Matrix)})

set.seed(3888)

N_REPEATS <- 20
N_FOLDS   <- 5

rule <- function(t) cat("\n", strrep("=", 74), "\n", t, "\n", strrep("=", 74), "\n", sep = "")

dat <- readRDS(file.path(DERIVED, "rq2_model_data.rds"))

# ============================================================================
# 1. Predictor blocks
# ============================================================================

BLOCKS <- list(
  demographic   = c("age", "sex"),
  bmi           = "bmi",
  activity      = c("pa_hours_week", "sitting_hours_day", "sleep_hours"),
  diet          = c("fibre_per_mj", "sodium_per_mj", "pct_energy_satfat_d1",
                    "pct_energy_freesug_d1", "serves_veg_d1", "serves_fruit_d1",
                    "ei_bmr_d1"),
  socioeconomic = c("seifa", "education", "occupation5"),
  smoking       = "smoking"
)

MODELS <- list(
  "M0: age + sex"                    = c("demographic"),
  "M1: + BMI (baseline)"             = c("demographic", "bmi"),
  "M2: + activity & sleep"           = c("demographic", "bmi", "activity"),
  "M3: + diet"                       = c("demographic", "bmi", "diet"),
  "M4: + socioeconomic"              = c("demographic", "bmi", "socioeconomic"),
  "M5: + smoking"                    = c("demographic", "bmi", "smoking"),
  "M6: all blocks"                   = names(BLOCKS),
  "M7: all except BMI"               = setdiff(names(BLOCKS), "bmi")
)

y <- as.integer(dat$cmr_elevated)
message("n = ", length(y), " | events = ", sum(y),
        " (", round(100 * mean(y), 1), "%)")

design_matrix <- function(vars) {
  f <- reformulate(vars)
  mm <- model.matrix(f, data = dat)
  mm[, colnames(mm) != "(Intercept)", drop = FALSE]
}

X_all <- map(MODELS, \(blocks) design_matrix(unlist(BLOCKS[blocks], use.names = FALSE)))
message("predictor counts: ",
        paste(names(X_all), map_int(X_all, ncol), sep = "=", collapse = ", "))

# ============================================================================
# 2. Repeated stratified cross-validation
# ============================================================================

make_folds <- function(y, k, seed) {
  set.seed(seed)
  idx <- integer(length(y))
  for (cls in unique(y)) {
    pos <- which(y == cls)
    idx[pos] <- sample(rep_len(seq_len(k), length(pos)))
  }
  idx
}

auc_fast <- function(score, label) {
  r <- rank(score)
  n1 <- sum(label == 1); n0 <- sum(label == 0)
  if (n1 == 0 || n0 == 0) return(NA_real_)
  (sum(r[label == 1]) - n1 * (n1 + 1) / 2) / (n1 * n0)
}
brier <- function(p, y) mean((p - y)^2)
logloss <- function(p, y) {
  p <- pmin(pmax(p, 1e-12), 1 - 1e-12)
  -mean(y * log(p) + (1 - y) * log(1 - p))
}

message("\nrunning ", N_REPEATS, " x ", N_FOLDS, "-fold CV for ",
        length(MODELS), " models...")

results <- list()
oof_store <- list()

for (rep_i in seq_len(N_REPEATS)) {
  folds <- make_folds(y, N_FOLDS, seed = 3888 + rep_i)

  for (mod in names(MODELS)) {
    X <- X_all[[mod]]
    oof <- rep(NA_real_, length(y))

    for (k in seq_len(N_FOLDS)) {
      tr <- folds != k; te <- !tr

      # Penalty chosen by an inner CV on the training rows only.
      cvfit <- cv.glmnet(X[tr, , drop = FALSE], y[tr], family = "binomial",
                         alpha = 0.5, nfolds = 5, type.measure = "deviance")
      oof[te] <- as.numeric(predict(cvfit, newx = X[te, , drop = FALSE],
                                    s = "lambda.min", type = "response"))
    }

    results[[length(results) + 1]] <- tibble(
      repeat_id = rep_i, model = mod,
      auc = auc_fast(oof, y), brier = brier(oof, y), logloss = logloss(oof, y)
    )
    oof_store[[mod]] <- if (rep_i == 1) oof else oof_store[[mod]] + oof
  }
  if (rep_i %% 5 == 0) message("  completed repeat ", rep_i, "/", N_REPEATS)
}

# Averaging each observation's out-of-fold prediction over the replicates removes
# fold-assignment noise, leaving one stable held-out risk estimate per person.
oof_store <- map(oof_store, \(s) s / N_REPEATS)

cv <- bind_rows(results) |>
  mutate(model = factor(model, levels = names(MODELS)))

# ============================================================================
# 3. Performance summary
# ============================================================================

rule("RQ3: OUT-OF-SAMPLE PERFORMANCE")

perf <- cv |>
  group_by(model) |>
  summarise(
    n_predictors = ncol(X_all[[as.character(first(model))]]),
    auc_mean = mean(auc), auc_cv_sd = sd(auc),
    brier_mean = mean(brier), brier_cv_sd = sd(brier),
    logloss_mean = mean(logloss),
    .groups = "drop"
  ) |>
  mutate(across(where(is.numeric), \(v) round(v, 4)))

print(as.data.frame(perf))
save_tab(perf, "rq3_01_performance")
message("\nauc_cv_sd is the spread across CV replicates, i.e. fold-assignment")
message("noise only. Sampling uncertainty is quantified by the bootstrap below.")

# ---- Paired comparisons against the RQ3 baseline (M1: age + sex + BMI) -----
# Uncertainty here must come from resampling INDIVIDUALS, not folds. Comparing
# AUCs across CV replicates would only measure how much the fold split matters,
# which shrinks towards zero as replicates are added and would manufacture
# arbitrarily small p-values for a difference of any size.

rule("RQ3: PAIRED DIFFERENCES vs THE age + sex + BMI BASELINE (bootstrap)")

baseline <- "M1: + BMI (baseline)"
B <- 2000

set.seed(3888)
boot_idx <- replicate(B, sample.int(length(y), replace = TRUE), simplify = FALSE)

boot_stat <- function(mod, metric_fun) {
  p_mod <- oof_store[[mod]]; p_base <- oof_store[[baseline]]
  map_dbl(boot_idx, \(i) metric_fun(p_mod[i], y[i]) - metric_fun(p_base[i], y[i]))
}

paired <- map_dfr(setdiff(names(MODELS), baseline), \(mod) {
  d_auc <- boot_stat(mod, auc_fast)
  d_bri <- boot_stat(mod, brier)
  obs_auc <- auc_fast(oof_store[[mod]], y) - auc_fast(oof_store[[baseline]], y)
  obs_bri <- brier(oof_store[[mod]], y) - brier(oof_store[[baseline]], y)
  tibble(
    model = mod,
    metric = c("auc", "brier"),
    observed_diff = c(obs_auc, obs_bri),
    lcl = c(quantile(d_auc, 0.025), quantile(d_bri, 0.025)),
    ucl = c(quantile(d_auc, 0.975), quantile(d_bri, 0.975)),
    # Two-sided bootstrap p-value: how often the resampled difference crosses zero.
    p = c(2 * min(mean(d_auc <= 0), mean(d_auc >= 0)),
          2 * min(mean(d_bri <= 0), mean(d_bri >= 0)))
  )
}) |>
  mutate(model = factor(model, levels = names(MODELS)),
         across(c(observed_diff, lcl, ucl), \(v) round(v, 4)),
         p = round(pmin(p, 1), 4)) |>
  arrange(metric, model)

print(as.data.frame(paired))
save_tab(paired, "rq3_02_paired_differences")

# ---- How large is the gain relative to what BMI itself buys? ---------------
rule("RQ3: CONTEXT - what does each block buy?")

ref <- perf |> filter(model == "M0: age + sex") |> pull(auc_mean)
base_auc <- perf |> filter(model == baseline) |> pull(auc_mean)

context <- perf |>
  select(model, n_predictors, auc = auc_mean) |>
  mutate(
    gain_over_age_sex = round(auc - ref, 4),
    gain_over_baseline = round(auc - base_auc, 4),
    pct_of_bmi_gain = round(100 * (auc - base_auc) / (base_auc - ref), 1)
  )
print(as.data.frame(context))
save_tab(context, "rq3_03_block_contributions")

# ============================================================================
# 4. Which predictors does the full model actually keep?
# ============================================================================

rule("RQ3: COEFFICIENTS OF THE FULL MODEL (fitted on all data)")

X_full <- X_all[["M6: all blocks"]]
cv_full <- cv.glmnet(X_full, y, family = "binomial", alpha = 0.5, nfolds = 10)
co <- coef(cv_full, s = "lambda.min")

coefs <- tibble(term = rownames(co), coefficient = as.numeric(co)) |>
  filter(term != "(Intercept)") |>
  mutate(odds_ratio = exp(coefficient), retained = coefficient != 0) |>
  arrange(desc(abs(coefficient))) |>
  mutate(across(c(coefficient, odds_ratio), \(v) round(v, 4)))

print(as.data.frame(coefs), max = 200)
save_tab(coefs, "rq3_04_full_model_coefficients")
message("\npredictors retained at lambda.min: ", sum(coefs$retained),
        " of ", nrow(coefs))

# ============================================================================
# 5. Figures
# ============================================================================

p_auc <- cv |>
  ggplot(aes(x = fct_rev(model), y = auc)) +
  geom_boxplot(fill = "#3B7EA1", alpha = 0.8, width = 0.6,
               outlier.size = 0.7, outlier.alpha = 0.5) +
  geom_hline(yintercept = base_auc, linetype = "dashed", colour = "#C0392B") +
  annotate("text", x = 1.3, y = base_auc, label = "age + sex + BMI baseline",
           hjust = 0, vjust = -0.7, size = 3, colour = "#C0392B") +
  coord_flip() +
  labs(title = "RQ3: adding diet, activity and socioeconomic blocks barely moves discrimination",
       subtitle = sprintf("Out-of-sample AUC across %d x %d-fold cross-validation, penalty tuned inside each training fold",
                          N_REPEATS, N_FOLDS),
       x = NULL, y = "Cross-validated AUC",
       caption = "Elastic-net logistic regression (alpha = 0.5). Outcome: 2 or more of five biomarker risk factors, excluding waist and BMI.")

save_fig(p_auc, "rq3_01_auc_by_model", width = 10, height = 6)

p_diff <- paired |>
  filter(metric == "auc") |>
  ggplot(aes(x = observed_diff, y = fct_rev(model))) +
  geom_vline(xintercept = 0, linetype = "dashed", colour = "grey40") +
  geom_pointrange(aes(xmin = lcl, xmax = ucl),
                  colour = "#C0392B", size = 0.4) +
  labs(title = "Change in AUC relative to the age + sex + BMI baseline",
       subtitle = "Paired bootstrap over individuals, 2,000 resamples, 95% percentile intervals",
       x = "Difference in cross-validated AUC", y = NULL,
       caption = CAPTION)

save_fig(p_diff, "rq3_02_auc_differences", width = 9, height = 5.5)

# ROC curves from the first replicate's out-of-fold predictions.
roc_points <- function(score, label, model) {
  o <- order(-score)
  tp <- cumsum(label[o] == 1) / sum(label == 1)
  fp <- cumsum(label[o] == 0) / sum(label == 0)
  tibble(model = model, fpr = c(0, fp), tpr = c(0, tp))
}

p_roc <- imap_dfr(oof_store[c("M0: age + sex", baseline, "M6: all blocks")],
                  \(p, m) roc_points(p, y, m)) |>
  mutate(model = factor(model, levels = names(MODELS))) |>
  ggplot(aes(x = fpr, y = tpr, colour = model)) +
  geom_abline(slope = 1, intercept = 0, linetype = "dashed", colour = "grey55") +
  geom_line(linewidth = 0.75) +
  coord_equal() +
  scale_colour_brewer(palette = "Dark2", name = NULL) +
  labs(title = "Out-of-fold ROC curves",
       subtitle = "The three curves are nearly indistinguishable: the extra blocks add little rank information",
       x = "False positive rate", y = "True positive rate", caption = CAPTION)

save_fig(p_roc, "rq3_03_roc", width = 7.5, height = 7)

# Calibration of the full model.
p_calib <- tibble(p = oof_store[["M6: all blocks"]], y = y) |>
  mutate(bin = ntile(p, 10)) |>
  group_by(bin) |>
  summarise(predicted = mean(p), observed = mean(y), n = n(),
            se = sqrt(observed * (1 - observed) / n), .groups = "drop") |>
  ggplot(aes(x = predicted, y = observed)) +
  geom_abline(slope = 1, intercept = 0, linetype = "dashed", colour = "grey45") +
  geom_pointrange(aes(ymin = observed - 1.96 * se, ymax = observed + 1.96 * se),
                  colour = "#3B7EA1") +
  geom_line(colour = "#3B7EA1") +
  scale_x_continuous(labels = percent) + scale_y_continuous(labels = percent) +
  labs(title = "Calibration of the full model, out of fold",
       subtitle = "Deciles of predicted risk against observed prevalence",
       x = "Mean predicted probability", y = "Observed proportion",
       caption = CAPTION)

save_fig(p_calib, "rq3_04_calibration", width = 7, height = 6)

write_csv(cv, file.path(TAB_DIR, "rq3_00_cv_raw.csv"))
message("\nRQ3 complete.")
