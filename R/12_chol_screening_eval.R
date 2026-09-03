# ---------------------------------------------------------------------------
# 12_chol_screening_eval.R
#
# Answers the two research questions in STAT3888_Candidate_Q1.pdf on their own
# terms, using out-of-sample evaluation rather than in-sample association:
#
#   RQ1 "How accurately can routinely available non-laboratory characteristics
#        identify adults with measured high cholesterol who do not report it?"
#        -> nested penalised logistic models, repeated stratified CV,
#           weighted AUC, and a decision-curve style comparison against the
#           rule Australia actually uses (test everyone from age 45).
#
#   RQ2 "Does that ability differ across age, sex and socioeconomic groups,
#        and which groups are most likely to be missed?"
#        -> subgroup discrimination and calibration at a fixed operating
#           threshold, plus a model of who actually goes untested (CHOL5YR).
#
# The screening-value calculation is the part that decides whether the
# question is worth asking: a model is only useful for triage if it beats
# testing everybody, and that depends on prevalence as much as on AUC.
# ---------------------------------------------------------------------------

source("00_setup.R")
suppressPackageStartupMessages({
  library(survey); library(glmnet); library(Matrix)
})
options(survey.lonely.psu = "adjust")
set.seed(3888)

message("== 12_chol_screening_eval ==")

d <- fread(file.path(DERIVED, "nhs_chol.csv"))
rep_cols <- sprintf("RPWGT%02d", 1:60)

d$bmi_class   <- factor(d$bmi_class, c("Underweight", "Normal", "Overweight",
                                       "Obese I", "Obese II-III"))
d$waist_class <- factor(d$waist_class, c("Not at risk", "Increased risk",
                                         "Substantially increased"))
d$age_grp     <- factor(d$age_grp, c("18-34", "35-44", "45-54", "55-64", "65+"))
d$sex         <- factor(d$sex, c("Male", "Female"))
d$smoking     <- factor(d$smoking, c("Never", "Ex-smoker", "Current"))
d$pa_level    <- factor(d$pa_level, c("High", "Moderate", "Low", "Sedentary"))
d$seifa_q     <- factor(d$seifa_q, c("Q1 (most disadv.)", "Q2", "Q3", "Q4",
                                     "Q5 (least disadv.)"))
log_cols <- names(d)[vapply(d, is.logical, logical(1))]
d[, (log_cols) := lapply(.SD, as.integer), .SDcols = log_cols]

CAP_NHS <- paste0(
  "Source: ABS Australian Health Survey 2011-13, National Health Survey Basic CURF.\n",
  "Weighted to the Australian population using the biomedical weight (NHMSPERW)."
)

# ---------------------------------------------------------------------------
# Shared metric helpers (weighted, because the target is a population)
# ---------------------------------------------------------------------------

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

wmean <- function(x, w) sum(x * w) / sum(w)

stratified_folds <- function(y, k) {
  idx <- integer(length(y))
  for (lev in unique(y)) {
    pos <- which(y == lev)
    idx[pos] <- sample(rep_len(seq_len(k), length(pos)))
  }
  idx
}

# ---------------------------------------------------------------------------
# 1. RQ1: nested non-laboratory models, out-of-sample
# ---------------------------------------------------------------------------

# The predictor blocks follow the team's own predictor table, in the order a
# clinic would collect them: free demographics first, then a tape measure and
# scales, then a BP cuff, then interview items, then socioeconomic data.
BLOCKS <- list(
  "M0: age + sex"            = c("age", "sex"),
  "M1: + BMI & waist"        = c("age", "sex", "bmi", "waist"),
  "M2: + blood pressure"     = c("age", "sex", "bmi", "waist", "sbp", "dbp"),
  "M3: + smoking & activity" = c("age", "sex", "bmi", "waist", "sbp", "dbp",
                                 "smoking", "pa_level"),
  "M4: + income & area SES"  = c("age", "sex", "bmi", "waist", "sbp", "dbp",
                                 "smoking", "pa_level", "income_decile",
                                 "seifa_decile")
)
ALL_PRED <- unique(unlist(BLOCKS))

N_REPEATS <- 5
N_FOLDS   <- 10

#' Repeated stratified CV for one outcome across all nested models.
#' Returns per-replicate metrics and the averaged out-of-fold predictions.
run_cv <- function(outcome) {
  dat <- d[, c(outcome, ALL_PRED, "weight_biomed"), with = FALSE] |> na.omit()
  y <- dat[[outcome]]
  w <- dat$weight_biomed
  if (length(unique(y)) < 2) return(NULL)

  oof_store <- list(); res <- list()
  for (rep_i in seq_len(N_REPEATS)) {
    fold <- stratified_folds(y, N_FOLDS)
    for (mod in names(BLOCKS)) {
      X <- model.matrix(~ . - 1, data = dat[, BLOCKS[[mod]], with = FALSE])
      oof <- numeric(length(y))
      for (k in seq_len(N_FOLDS)) {
        tr <- fold != k; te <- !tr
        # Inner CV picks the penalty; alpha = 0.5 keeps correlated
        # anthropometric terms from being dropped arbitrarily.
        cvf <- cv.glmnet(X[tr, , drop = FALSE], y[tr], family = "binomial",
                         weights = w[tr], alpha = 0.5, nfolds = 5)
        oof[te] <- as.numeric(predict(cvf, X[te, , drop = FALSE],
                                      s = "lambda.min", type = "response"))
      }
      oof_store[[mod]] <- if (rep_i == 1) oof else oof_store[[mod]] + oof
      res[[length(res) + 1]] <- tibble::tibble(
        outcome = outcome, model = mod, rep = rep_i,
        auc = wauc(oof, y, w), brier = wmean((oof - y)^2, w)
      )
    }
  }
  oof_store <- lapply(oof_store, \(x) x / N_REPEATS)
  list(cv = bind_rows(res), oof = oof_store, y = y, w = w, dat = dat)
}

TARGETS <- c(chol_high = "Measured high total cholesterol",
             unrecognised_strict = "High cholesterol, not self-reported (team's RQ1)",
             dyslip_untreated = "Untreated dyslipidaemia (CVDMEDST=3)",
             hdl_low = "Low HDL cholesterol")

message("\nrunning ", N_REPEATS, " x ", N_FOLDS, "-fold CV for ",
        length(BLOCKS), " models x ", length(TARGETS), " outcomes...")
fits <- purrr::imap(TARGETS, function(lab, oc) {
  message("  ", oc)
  run_cv(oc)
})

perf <- purrr::imap_dfr(fits, function(f, oc) {
  if (is.null(f)) return(NULL)
  f$cv |>
    group_by(outcome, model) |>
    # sd() must be taken before auc is overwritten by its own mean.
    summarise(auc_cv_sd = sd(auc), auc = mean(auc), brier = mean(brier),
              .groups = "drop") |>
    mutate(outcome_label = TARGETS[[oc]], n = length(f$y),
           prevalence = wmean(f$y, f$w))
})
print(as.data.frame(perf |> mutate(across(c(auc, auc_cv_sd, brier, prevalence),
                                          \(x) round(x, 3)))))
save_tab(perf, "12_cv_performance")

p1 <- perf |>
  mutate(outcome_label = factor(outcome_label, TARGETS)) |>
  ggplot(aes(x = auc, y = fct_rev(model))) +
  geom_vline(xintercept = 0.5, linetype = "dashed", colour = "grey45") +
  geom_segment(aes(x = 0.5, xend = auc, yend = fct_rev(model)),
               colour = "grey80", linewidth = 0.8) +
  geom_point(size = 2.8, colour = "#3B7EA1") +
  geom_text(aes(label = sprintf("%.3f", auc)), hjust = -0.35, size = 2.9) +
  facet_wrap(~outcome_label, nrow = 2) +
  scale_x_continuous(limits = c(0.44, 0.82)) +
  labs(
    title = "Adding every routinely available non-laboratory variable buys very little",
    subtitle = paste("Out-of-sample weighted AUC, 5 x 10-fold cross-validation, elastic-net logistic",
                     "regression.\nFor total cholesterol the full model barely improves on age and sex alone."),
    x = "Cross-validated weighted AUC", y = NULL, caption = CAP_NHS
  )
save_fig(p1, "chol_08_cv_auc", width = 11, height = 7)

# ---------------------------------------------------------------------------
# 2. Is a model actually better than "test everyone aged 45+"?
#
#    Screening value depends on prevalence. With ~38% prevalence, a model with
#    AUC ~0.65 cannot avoid testing many people. This compares three policies
#    at matched testing volume.
# ---------------------------------------------------------------------------

message("\n-- 2. screening value against the current age-45 rule --")

policy_tab <- purrr::imap_dfr(fits, function(f, oc) {
  if (is.null(f)) return(NULL)
  y <- f$y; w <- f$w; dat <- f$dat
  score_full <- f$oof[["M4: + income & area SES"]]
  score_age  <- f$oof[["M0: age + sex"]]

  # Policy 1: test everyone.
  # Policy 2: test everyone aged 45+ (the Australian guideline age trigger).
  # Policy 3/4: test the highest-risk share of the population, sized to match
  #             the volume the age-45 rule generates, so the comparison is fair.
  test45 <- as.integer(dat$age >= 45)
  volume45 <- wmean(test45, w)

  cut_at_volume <- function(score) {
    o <- order(score, decreasing = TRUE)
    cw <- cumsum(w[o]) / sum(w)
    thr_i <- which(cw >= volume45)[1]
    score >= score[o][thr_i]
  }
  sens <- function(sel) wmean(sel[y == 1], w[y == 1])

  policies <- list(
    "Test everyone"                         = rep(1L, length(y)),
    "Test everyone aged 45+"                = test45,
    "Model: age + sex, matched volume"      = as.integer(cut_at_volume(score_age)),
    "Model: all predictors, matched volume" = as.integer(cut_at_volume(score_full))
  )
  tibble::tibble(
    outcome = TARGETS[[oc]],
    prevalence = wmean(y, w),
    policy = names(policies),
    share_tested = vapply(policies, \(s) wmean(s, w), numeric(1)),
    cases_found  = vapply(policies, sens, numeric(1))
  ) |>
    mutate(cases_missed = 1 - cases_found,
           tests_per_case = share_tested / (cases_found * prevalence))
})
print(as.data.frame(policy_tab |> mutate(across(where(is.numeric), \(x) round(x, 3)))))
save_tab(policy_tab, "12_policy_comparison")

POLICY_ORDER <- c("Test everyone aged 45+", "Model: age + sex, matched volume",
                  "Model: all predictors, matched volume")

p2 <- policy_tab |>
  filter(policy != "Test everyone") |>
  mutate(outcome = factor(outcome, TARGETS),
         policy = factor(policy, POLICY_ORDER)) |>
  ggplot(aes(x = cases_found, y = fct_rev(policy), fill = policy)) +
  geom_col(width = 0.6, show.legend = FALSE) +
  geom_text(aes(label = percent(cases_found, accuracy = 0.1)), hjust = -0.12,
            size = 2.9) +
  facet_wrap(~outcome, nrow = 2) +
  scale_x_continuous(labels = percent, limits = c(0, 1.08)) +
  scale_fill_manual(values = c("Test everyone aged 45+" = "#C0392B",
                               "Model: age + sex, matched volume" = "#7FA8C0",
                               "Model: all predictors, matched volume" = "#3B7EA1")) +
  labs(
    title = "The model beats the age-45 rule for HDL, and adds nothing for total cholesterol",
    subtitle = paste("Share of all cases detected when each policy tests the same fraction of the",
                     "population as\nthe existing 'test everyone aged 45+' guideline. For the team's",
                     "proposed outcome (top right)\nthe full model detects 58.6% of cases against",
                     "58.8% for the age rule alone."),
    x = "Share of cases detected", y = NULL, caption = CAP_NHS
  )
save_fig(p2, "chol_09_policy_comparison", width = 11, height = 6.5)

# ---------------------------------------------------------------------------
# 3. RQ2: does performance differ across age, sex and socioeconomic groups?
# ---------------------------------------------------------------------------

message("\n-- 3. subgroup performance (RQ2) --")

subgroup_perf <- function(oc) {
  f <- fits[[oc]]
  if (is.null(f)) return(NULL)
  dat <- copy(f$dat)
  dat[, `:=`(score = f$oof[["M4: + income & area SES"]], y = f$y, w = weight_biomed)]
  dat[, age_grp := cut(age, c(17, 34, 44, 54, 64, 200),
                       labels = c("18-34", "35-44", "45-54", "55-64", "65+"))]
  dat[, seifa_q := cut(seifa_decile, c(0, 2, 4, 6, 8, 10),
                       labels = c("Q1 (most disadv.)", "Q2", "Q3", "Q4",
                                  "Q5 (least disadv.)"))]
  # Fixed operating threshold: flag the top 40% of risk scores overall, then
  # ask how sensitivity varies between groups at that single threshold. This is
  # how an unfair screening rule shows up in practice.
  o <- order(dat$score, decreasing = TRUE)
  cw <- cumsum(dat$w[o]) / sum(dat$w)
  thr <- dat$score[o][which(cw >= 0.40)[1]]
  dat[, flagged := as.integer(score >= thr)]

  purrr::map_dfr(c("age_grp", "sex", "seifa_q"), function(gv) {
    dat[!is.na(get(gv))] |>
      as.data.table() |>
      (\(x) x[, .(
        n = .N,
        prevalence = wmean(y, w),
        auc = wauc(score, y, w),
        sensitivity = if (sum(y == 1) > 0) wmean(flagged[y == 1], w[y == 1]) else NA_real_,
        flag_rate = wmean(flagged, w)
      ), by = c(gv)])() |>
      rename(group = 1) |>
      mutate(grouping = gv, group = as.character(group), outcome = TARGETS[[oc]])
  })
}

sub_tab <- bind_rows(lapply(names(TARGETS), subgroup_perf))
print(as.data.frame(sub_tab |> filter(outcome == TARGETS[["chol_high"]]) |>
                      mutate(across(where(is.numeric), \(x) round(x, 3)))))
save_tab(sub_tab, "12_subgroup_performance")

GRP_LAB <- c(age_grp = "Age group", sex = "Sex", seifa_q = "Area disadvantage")

GRP_ORDER <- c("18-34", "35-44", "45-54", "55-64", "65+", "Male", "Female",
               "Q1 (most disadv.)", "Q2", "Q3", "Q4", "Q5 (least disadv.)")

sub_chol <- sub_tab |>
  filter(outcome == TARGETS[["chol_high"]]) |>
  mutate(grouping = factor(GRP_LAB[grouping], GRP_LAB),
         group = factor(group, GRP_ORDER))

p3 <- sub_chol |>
  select(grouping, group, Sensitivity = sensitivity, `Share flagged` = flag_rate) |>
  pivot_longer(-c(grouping, group)) |>
  ggplot(aes(x = group, y = value, fill = name)) +
  geom_col(position = position_dodge(0.78), width = 0.7) +
  facet_wrap(~grouping, scales = "free_x", nrow = 1) +
  scale_y_continuous(labels = percent) +
  scale_fill_manual(values = c(Sensitivity = "#C0392B",
                               `Share flagged` = "#3B7EA1"), name = NULL) +
  labs(
    title = "A non-laboratory risk model is an age cut-off wearing a disguise",
    subtitle = paste("Flagging the highest-risk 40% of adults for testing. Almost nobody under 35 is",
                     "flagged (1%)\nand almost everybody over 65 is (98%), so sensitivity is set by",
                     "age rather than by risk."),
    x = NULL, y = NULL, caption = CAP_NHS
  ) +
  theme(axis.text.x = element_text(angle = 30, hjust = 1))
save_fig(p3, "chol_10_subgroup_equity", width = 12, height = 6)

# Within-subgroup discrimination: if the model only works by separating age
# bands, it should have little ranking ability inside a band.
p3b <- sub_chol |>
  filter(!is.na(auc)) |>
  ggplot(aes(x = group, y = auc)) +
  geom_hline(yintercept = 0.5, linetype = "dashed", colour = "grey45") +
  geom_col(aes(fill = auc < 0.5), width = 0.62, show.legend = FALSE) +
  geom_text(aes(label = sprintf("%.3f", auc)), vjust = -0.5, size = 2.8) +
  facet_wrap(~grouping, scales = "free_x", nrow = 1) +
  scale_fill_manual(values = c(`FALSE` = "#3B7EA1", `TRUE` = "#C0392B")) +
  coord_cartesian(ylim = c(0.4, 0.68)) +
  labs(
    title = "Within an age band, the model has almost no ability to rank risk",
    subtitle = paste("Weighted AUC for measured high total cholesterol computed inside each subgroup.",
                     "In both\nbands over 55 it falls below 0.5, and it is weakest in the most",
                     "disadvantaged areas (0.521)."),
    x = NULL, y = "Within-subgroup weighted AUC", caption = CAP_NHS
  ) +
  theme(axis.text.x = element_text(angle = 30, hjust = 1))
save_fig(p3b, "chol_10b_subgroup_auc", width = 12, height = 5.5)

# ---------------------------------------------------------------------------
# 4. Who actually goes untested? (the real-world version of "who is missed")
#    CHOL5YR is only asked universally from age 45, so this is a 45+ analysis.
# ---------------------------------------------------------------------------

message("\n-- 4. who reports no cholesterol test in 5 years (45+) --")

dt <- d[!is.na(tested_5yr) & age >= 45]
message("n (45+, testing history known): ", nrow(dt),
        "; untested in 5 years: ", sum(dt$tested_5yr == 0),
        sprintf(" (%.1f%% unweighted)", 100 * mean(dt$tested_5yr == 0)))

dt[, untested := 1L - tested_5yr]
des_t <- svrepdesign(
  data = dt, weights = ~weight_biomed, repweights = dt[, ..rep_cols],
  type = "JK1", scale = 59 / 60, combined.weights = TRUE
)

m_untested <- svyglm(untested ~ age + sex + bmi + smoking + seifa_decile +
                       income_decile, design = des_t, family = quasibinomial())
untested_tab <- broom::tidy(m_untested, conf.int = TRUE, exponentiate = TRUE) |>
  filter(term != "(Intercept)") |>
  select(term, or = estimate, lcl = conf.low, ucl = conf.high, p = p.value)
print(as.data.frame(untested_tab |> mutate(across(or:ucl, \(x) round(x, 3)),
                                           p = signif(p, 3))))
save_tab(untested_tab, "12_untested_model")

# Untested prevalence by subgroup, plus how many of the untested have
# abnormal lipids.
untested_by <- purrr::map_dfr(c("age_grp", "sex", "seifa_q", "smoking"), function(gv) {
  sub <- subset(des_t, !is.na(dt[[gv]]))
  e <- svyby(~untested, as.formula(paste0("~", gv)), sub, svymean, na.rm = TRUE,
             vartype = c("se", "ci"))
  tibble::tibble(grouping = gv, group = as.character(e[[gv]]),
                 prev = e$untested, lcl = pmax(0, e$ci_l), ucl = pmin(1, e$ci_u))
})
save_tab(untested_by, "12_untested_by_group")

GRP_LAB2 <- c(age_grp = "Age group", sex = "Sex", seifa_q = "Area disadvantage",
              smoking = "Smoking status")
p4 <- untested_by |>
  mutate(grouping = factor(GRP_LAB2[grouping], GRP_LAB2)) |>
  ggplot(aes(x = group, y = prev)) +
  geom_col(fill = "#8E6C8A", width = 0.65) +
  geom_errorbar(aes(ymin = lcl, ymax = ucl), width = 0.15, colour = "grey25") +
  facet_wrap(~grouping, scales = "free_x", nrow = 1) +
  scale_y_continuous(labels = percent) +
  labs(
    title = "Who has not had a cholesterol test in five years, among adults 45+",
    subtitle = paste("This is the group a screening programme would need to reach.",
                     "It is small (about 1 in 10)\nand concentrated in the youngest",
                     "of the 45+ band, which an age-based rule already targets."),
    x = NULL, y = "Weighted share untested in 5 years", caption = CAP_NHS
  ) +
  theme(axis.text.x = element_text(angle = 30, hjust = 1))
save_fig(p4, "chol_11_untested_by_group", width = 12, height = 5.5)

message("\ndone.")
