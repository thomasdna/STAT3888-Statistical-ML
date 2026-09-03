# Exploratory analysis and visualisation of the NNPAS person-level dataset.
#
# Figures land in outputs/figures/, summary tables in outputs/tables/.
# Each block is independent, so you can run them one at a time interactively.

source("00_setup.R", chdir = TRUE)

dat <- readRDS(file.path(DERIVED, "npa_person.rds"))
adults <- dat |> filter(is_adult)

message("persons: ", nrow(dat), " | adults: ", nrow(adults))

# ============================================================================
# 1. Who is in the sample, and which subsamples exist?
# ============================================================================
# The NNPAS is nested: everyone has a day-1 recall, ~64% also gave a day-2
# recall, and only biomedical participants have blood results. Any analysis
# combining diet with biomarkers is restricted to the smallest of these.

flow <- tibble(
  stage = factor(
    c("Day-1 recall (all persons)", "Day-2 recall", "Biomedical participant",
      "Fasting lipids available", "Measured BMI"),
    levels = c("Day-1 recall (all persons)", "Day-2 recall",
               "Biomedical participant", "Fasting lipids available",
               "Measured BMI")
  ),
  n = c(nrow(dat), sum(dat$has_day2), sum(dat$biomed_participant),
        sum(!is.na(dat$ldl_mmol)), sum(!is.na(dat$bmi)))
) |>
  mutate(pct = n / nrow(dat))

p_flow <- ggplot(flow, aes(x = fct_rev(stage), y = n)) +
  geom_col(fill = "#2C5F8A", width = 0.65) +
  geom_text(aes(label = paste0(comma(n), "  (", percent(pct, accuracy = 0.1), ")")),
            hjust = -0.08, size = 3.4) +
  coord_flip() +
  scale_y_continuous(labels = comma, expand = expansion(mult = c(0, 0.22))) +
  labs(title = "Nested subsamples in the NNPAS 2011-12",
       subtitle = "Diet-biomarker analyses are limited by the biomedical subsample, not the full 12,153 respondents",
       x = NULL, y = "Respondents", caption = CAPTION)

save_fig(p_flow, "01_subsample_flow", width = 9, height = 4.5)
save_tab(flow, "01_subsample_flow")

# Missingness in the variables we are most likely to use.
key_vars <- c("bmi", "waist_cm", "activity_level", "smoker_status",
              "sitting_mins_week", "sleep_mins", "income_decile",
              "energy_kj_d1", "fibre_g_d1", "sodium_mg_d1", "serves_veg_d1",
              "chol_mmol", "hdl_mmol", "ldl_mmol", "gluc_mmol", "hba1c_pct")

miss <- dat |>
  select(all_of(key_vars), is_adult) |>
  pivot_longer(-is_adult, names_to = "variable", values_to = "value",
               values_transform = list(value = as.character)) |>
  group_by(variable, group = if_else(is_adult, "Adults 18+", "Under 18")) |>
  summarise(pct_missing = mean(is.na(value)), .groups = "drop")

p_miss <- ggplot(miss, aes(x = group, y = fct_reorder(variable, pct_missing),
                           fill = pct_missing)) +
  geom_tile(colour = "white", linewidth = 0.6) +
  geom_text(aes(label = percent(pct_missing, accuracy = 1)), size = 3,
            colour = "grey15") +
  scale_fill_gradient(low = "#EAF2F8", high = "#C0392B", labels = percent,
                      name = "Missing") +
  labs(title = "Missingness differs sharply between adults and children",
       subtitle = "Physical activity, sitting time and biomarkers are only collected above certain ages",
       x = NULL, y = NULL, caption = CAPTION)

save_fig(p_miss, "02_missingness", width = 8, height = 6)

# ============================================================================
# 2. Demographic structure
# ============================================================================

pyramid <- dat |>
  count(age_group, sex) |>
  mutate(n_signed = if_else(sex == "Male", -n, n))

p_pyramid <- ggplot(pyramid, aes(x = n_signed, y = age_group, fill = sex)) +
  geom_col(width = 0.8) +
  scale_x_continuous(labels = \(x) comma(abs(x))) +
  scale_fill_manual(values = c(Male = "#2C5F8A", Female = "#C0392B"), name = NULL) +
  labs(title = "Age and sex structure of the NNPAS sample",
       x = "Respondents", y = "Age group", caption = CAPTION)

p_seifa <- dat |>
  count(seifa_quintile, sex) |>
  filter(!is.na(seifa_quintile)) |>
  ggplot(aes(x = seifa_quintile, y = n, fill = sex)) +
  geom_col(position = "dodge", width = 0.75) +
  scale_fill_manual(values = c(Male = "#2C5F8A", Female = "#C0392B"), name = NULL) +
  scale_y_continuous(labels = comma) +
  labs(title = "Socio-economic distribution (SEIFA IRSD quintile)",
       x = NULL, y = "Respondents") +
  theme(axis.text.x = element_text(angle = 20, hjust = 1))

save_fig(p_pyramid | p_seifa, "03_demographics", width = 12, height = 5)

# ============================================================================
# 3. Dietary intake: energy and macronutrient composition
# ============================================================================

p_energy <- adults |>
  ggplot(aes(x = energy_kj_d1, fill = sex)) +
  geom_histogram(bins = 60, alpha = 0.75, position = "identity") +
  scale_fill_manual(values = c(Male = "#2C5F8A", Female = "#C0392B"), name = NULL) +
  scale_x_continuous(labels = comma, limits = c(0, 25000)) +
  labs(title = "Day-1 energy intake is right-skewed and differs by sex",
       x = "Energy including fibre (kJ)", y = "Adults")

macro <- adults |>
  select(sex, age_group,
         Protein = pct_energy_protein_d1, Fat = pct_energy_fat_d1,
         `Saturated fat` = pct_energy_satfat_d1, Carbohydrate = pct_energy_carb_d1,
         `Total sugars` = pct_energy_sugars_d1, Alcohol = pct_energy_alcohol_d1) |>
  pivot_longer(-c(sex, age_group), names_to = "nutrient", values_to = "pct_energy")

# Acceptable Macronutrient Distribution Ranges / national targets for reference.
targets <- tibble(
  nutrient = c("Protein", "Fat", "Saturated fat", "Carbohydrate", "Total sugars"),
  lower = c(15, 20, NA, 45, NA),
  upper = c(25, 35, 10, 65, NA)
)

p_macro <- ggplot(macro, aes(x = pct_energy, y = fct_rev(nutrient), fill = sex)) +
  geom_boxplot(outlier.alpha = 0.06, outlier.size = 0.5, width = 0.7) +
  geom_vline(data = targets |> filter(!is.na(upper)),
             aes(xintercept = upper), linetype = "dashed",
             colour = "grey30", linewidth = 0.35) +
  scale_fill_manual(values = c(Male = "#2C5F8A", Female = "#C0392B"), name = NULL) +
  labs(title = "Macronutrient contribution to energy, adults",
       subtitle = "Dashed lines mark the upper bound of the NHMRC acceptable range (10% for saturated fat)",
       x = "% of total energy", y = NULL)

save_fig(p_energy / p_macro, "04_energy_and_macronutrients", width = 10, height = 9)

# ============================================================================
# 4. Food groups against Australian Dietary Guideline targets
# ============================================================================
# Adult targets: 5 serves of vegetables and 2 serves of fruit per day.

adg <- adults |>
  filter(!is.na(sex)) |>
  group_by(age_group, sex) |>
  summarise(
    n = n(),
    veg = mean(meets_veg_target, na.rm = TRUE),
    fruit = mean(meets_fruit_target, na.rm = TRUE),
    both = mean(meets_veg_target & meets_fruit_target, na.rm = TRUE),
    .groups = "drop"
  ) |>
  pivot_longer(c(veg, fruit, both), names_to = "target", values_to = "prop") |>
  mutate(target = recode(target,
                         veg = "5+ serves vegetables",
                         fruit = "2+ serves fruit",
                         both = "Both targets"))

p_adg <- ggplot(adg, aes(x = age_group, y = prop, fill = sex)) +
  geom_col(position = "dodge", width = 0.75) +
  facet_wrap(~target) +
  scale_y_continuous(labels = percent, limits = c(0, 0.75)) +
  scale_fill_manual(values = c(Male = "#2C5F8A", Female = "#C0392B"), name = NULL) +
  labs(title = "Very few adults meet the vegetable guideline on a single day",
       subtitle = "Proportion meeting the Australian Dietary Guideline target, day-1 recall",
       x = "Age group", y = "Proportion meeting target", caption = CAPTION)

save_fig(p_adg, "05_adg_targets", width = 11, height = 4.8)

serves_long <- adults |>
  select(sex,
         Grains = serves_grains_d1, Vegetables = serves_veg_d1,
         Fruit = serves_fruit_d1, Dairy = serves_dairy_d1,
         `Meat & alternatives` = serves_meat_d1, `Nuts & seeds` = serves_nuts_d1) |>
  pivot_longer(-sex, names_to = "group", values_to = "serves")

p_serves <- ggplot(serves_long, aes(x = serves, y = fct_rev(group), fill = sex)) +
  geom_boxplot(outlier.alpha = 0.05, outlier.size = 0.4, width = 0.7) +
  coord_cartesian(xlim = c(0, 12)) +
  scale_fill_manual(values = c(Male = "#2C5F8A", Female = "#C0392B"), name = NULL) +
  labs(title = "Serves consumed by ADG food group, adults (day 1)",
       subtitle = "Distributions are zero-inflated for fruit, nuts and seeds",
       x = "Serves", y = NULL, caption = CAPTION)

save_fig(p_serves, "06_food_group_serves", width = 9, height = 5.5)

# ============================================================================
# 5. Sodium against the suggested dietary target
# ============================================================================

sdt <- 2000  # mg/day suggested dietary target for adults

p_sodium <- adults |>
  ggplot(aes(x = sodium_mg_d1, fill = sex)) +
  geom_density(alpha = 0.5, colour = NA) +
  geom_vline(xintercept = sdt, linetype = "dashed", colour = "grey20") +
  annotate("text", x = sdt * 1.05, y = Inf, label = "SDT 2,000 mg", vjust = 1.8,
           hjust = 0, size = 3.2, colour = "grey20") +
  scale_x_continuous(labels = comma, limits = c(0, 8000)) +
  scale_fill_manual(values = c(Male = "#2C5F8A", Female = "#C0392B"), name = NULL) +
  labs(title = "Most adults exceed the sodium target from food alone",
       subtitle = paste0(percent(mean(adults$sodium_mg_d1 > sdt, na.rm = TRUE), accuracy = 0.1),
                         " of adults recorded more than 2,000 mg on day 1 (discretionary salt excluded)"),
       x = "Sodium (mg, day 1)", y = "Density", caption = CAPTION)

save_fig(p_sodium, "07_sodium", width = 9, height = 5)

# ============================================================================
# 6. Adiposity and its correlates
# ============================================================================

p_bmi_hist <- adults |>
  filter(!is.na(bmi)) |>
  ggplot(aes(x = bmi, fill = sex)) +
  geom_histogram(bins = 55, alpha = 0.75, position = "identity") +
  geom_vline(xintercept = c(18.5, 25, 30), linetype = "dashed",
             colour = "grey30", linewidth = 0.35) +
  scale_fill_manual(values = c(Male = "#2C5F8A", Female = "#C0392B"), name = NULL) +
  labs(title = "Measured BMI, adults", x = expression(BMI~(kg/m^2)), y = "Adults")

p_bmi_seifa <- adults |>
  filter(!is.na(bmi_class), !is.na(seifa_quintile)) |>
  count(seifa_quintile, bmi_class) |>
  group_by(seifa_quintile) |>
  mutate(prop = n / sum(n)) |>
  ggplot(aes(x = seifa_quintile, y = prop, fill = bmi_class)) +
  geom_col(width = 0.78) +
  scale_y_continuous(labels = percent) +
  scale_fill_brewer(palette = "RdYlBu", direction = -1, name = NULL) +
  labs(title = "BMI class by socio-economic quintile",
       x = NULL, y = "Proportion of adults") +
  theme(axis.text.x = element_text(angle = 20, hjust = 1))

p_bmi_act <- adults |>
  filter(!is.na(bmi), !is.na(activity_level)) |>
  ggplot(aes(x = activity_level, y = bmi, fill = activity_level)) +
  geom_boxplot(width = 0.65, outlier.alpha = 0.1, outlier.size = 0.5,
               show.legend = FALSE) +
  scale_fill_brewer(palette = "YlOrRd", direction = -1) +
  coord_cartesian(ylim = c(15, 55)) +
  labs(title = "BMI by physical activity level",
       x = NULL, y = expression(BMI~(kg/m^2))) +
  theme(axis.text.x = element_text(angle = 20, hjust = 1))

save_fig((p_bmi_hist | p_bmi_seifa) / p_bmi_act, "08_adiposity", width = 12, height = 9)

# ============================================================================
# 7. Diet-adiposity relationships, and why they look weak
# ============================================================================
# Reported energy intake is *negatively* associated with BMI, which is
# implausible biologically and is the signature of differential
# under-reporting. The EI:BMR ratio makes this explicit.

p_ei_bmr <- adults |>
  filter(!is.na(ei_bmr_d1), !is.na(bmi_class)) |>
  ggplot(aes(x = bmi_class, y = ei_bmr_d1, fill = bmi_class)) +
  geom_hline(yintercept = 1.35, linetype = "dashed", colour = "grey25") +
  geom_boxplot(width = 0.65, outlier.alpha = 0.1, outlier.size = 0.5,
               show.legend = FALSE) +
  scale_fill_brewer(palette = "RdYlBu", direction = -1) +
  coord_cartesian(ylim = c(0, 3.5)) +
  labs(title = "Reported energy intake relative to basal metabolic rate",
       subtitle = "Falls steadily as BMI rises: heavier respondents under-report more, so raw diet-BMI associations are biased",
       x = "BMI class", y = "Energy intake / BMR (day 1)")

diet_bmi <- adults |>
  filter(!is.na(bmi)) |>
  select(bmi, sex,
         `Fibre (g)` = fibre_g_d1,
         `% energy from saturated fat` = pct_energy_satfat_d1,
         `% energy from free sugars` = pct_energy_freesug_d1,
         `Vegetable serves` = serves_veg_d1) |>
  pivot_longer(-c(bmi, sex), names_to = "measure", values_to = "value")

p_diet_bmi <- ggplot(diet_bmi, aes(x = value, y = bmi)) +
  geom_point(alpha = 0.05, size = 0.4, colour = "#2C5F8A") +
  geom_smooth(method = "gam", formula = y ~ s(x, bs = "cs"),
              colour = "#C0392B", linewidth = 0.8) +
  facet_wrap(~measure, scales = "free_x") +
  coord_cartesian(ylim = c(15, 50)) +
  labs(title = "Dietary measures versus measured BMI, adults",
       subtitle = "Smooths are GAM fits; associations are weak and partly confounded by under-reporting",
       x = NULL, y = expression(BMI~(kg/m^2)), caption = CAPTION)

save_fig(p_ei_bmr, "09_energy_underreporting", width = 9, height = 5.5)
save_fig(p_diet_bmi, "10_diet_vs_bmi", width = 10, height = 7)

# ============================================================================
# 8. Correlation structure among dietary variables
# ============================================================================
# Nutrient intakes are strongly collinear because they all scale with total
# energy. This matters for any regression or clustering the team plans.

nutri <- adults |>
  select(Energy = energy_kj_d1, Protein = protein_g_d1, Fat = fat_g_d1,
         `Sat. fat` = satfat_g_d1, Carbohydrate = carb_g_d1,
         Sugars = sugars_g_d1, `Free sugars` = free_sugars_g_d1,
         Fibre = fibre_g_d1, Sodium = sodium_mg_d1, Potassium = potassium_mg_d1,
         Calcium = calcium_mg_d1, Iron = iron_mg_d1, Alcohol = alcohol_g_d1) |>
  drop_na()

cor_mat <- cor(nutri, method = "spearman")

cor_long <- as_tibble(cor_mat, rownames = "x") |>
  pivot_longer(-x, names_to = "y", values_to = "r") |>
  mutate(across(c(x, y), \(v) factor(v, levels = colnames(cor_mat))))

p_cor <- ggplot(cor_long, aes(x, y, fill = r)) +
  geom_tile(colour = "white", linewidth = 0.4) +
  geom_text(aes(label = number(r, accuracy = 0.01)), size = 2.5, colour = "grey15") +
  scale_fill_gradient2(low = "#2166AC", mid = "white", high = "#B2182B",
                       midpoint = 0, limits = c(-1, 1), name = "Spearman") +
  labs(title = "Absolute nutrient intakes are highly collinear",
       subtitle = "Everything scales with total energy, so consider energy adjustment (densities or residuals) before modelling",
       x = NULL, y = NULL, caption = CAPTION) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1),
        panel.grid = element_blank())

save_fig(p_cor, "11_nutrient_correlations", width = 9.5, height = 8.5)
save_tab(as_tibble(cor_mat, rownames = "variable"), "11_nutrient_correlations")

# ============================================================================
# 9. Biomarkers
# ============================================================================
# Biomarkers are released as ordered bands, not continuous values. Band
# midpoints are used for the scatter-style views, with the caveat noted.

biomed <- dat |> filter(biomed_participant)

BAND_VARS <- c(
  "Total cholesterol (mmol/L)" = "chol_band",
  "HDL (mmol/L)"               = "hdl_band",
  "LDL (mmol/L)"               = "ldl_band",
  "Triglycerides (mmol/L)"     = "trig_band",
  "Fasting glucose (mmol/L)"   = "gluc_band",
  "HbA1c (%)"                  = "hba1c_band"
)

# Each band variable has its own level ordering, which pivot_longer would
# discard, so tabulate marker by marker and carry the level index through.
bands <- imap_dfr(BAND_VARS, \(var, label) {
  x <- biomed[[var]]
  tibble(marker = label, band = levels(x), order = seq_along(levels(x))) |>
    left_join(as_tibble(table(x), .name_repair = ~ c("band", "n")) |>
                mutate(n = as.integer(n)), by = "band") |>
    mutate(n = coalesce(n, 0L), prop = n / sum(n))
})

p_bands <- ggplot(bands, aes(x = reorder(band, order), y = prop)) +
  geom_col(fill = "#2C5F8A", width = 0.75) +
  facet_wrap(~marker, scales = "free_x", ncol = 3) +
  scale_y_continuous(labels = percent) +
  labs(title = "Biomarkers are supplied as ordered bands, not continuous values",
       subtitle = "Distribution among biomedical participants; plan analyses that respect the ordinal scale",
       x = NULL, y = "Proportion", caption = CAPTION) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1, size = 7))

save_fig(p_bands, "12_biomarker_bands", width = 12, height = 7)

lipids <- dat |>
  filter(biomed_participant, is_adult, !is.na(bmi_class)) |>
  select(bmi_class, sex,
         `High total cholesterol` = chol_abnormal,
         `Low HDL` = hdl_abnormal,
         `High LDL` = ldl_abnormal,
         `High triglycerides` = trig_abnormal) |>
  pivot_longer(-c(bmi_class, sex), names_to = "marker", values_to = "abnormal") |>
  filter(!is.na(abnormal)) |>
  group_by(marker, bmi_class) |>
  summarise(prop = mean(abnormal), n = n(), .groups = "drop") |>
  mutate(se = sqrt(prop * (1 - prop) / n))

p_lipids <- ggplot(lipids, aes(x = bmi_class, y = prop)) +
  geom_col(fill = "#C0392B", width = 0.7, alpha = 0.85) +
  geom_errorbar(aes(ymin = prop - 1.96 * se, ymax = prop + 1.96 * se),
                width = 0.18, colour = "grey25") +
  facet_wrap(~marker) +
  scale_y_continuous(labels = percent) +
  labs(title = "Abnormal lipid prevalence rises with BMI class",
       subtitle = "Adult biomedical participants; ABS abnormality definitions; bars show 95% CI (unweighted)",
       x = "BMI class", y = "Prevalence", caption = CAPTION)

save_fig(p_lipids, "13_lipids_by_bmi", width = 10, height = 6.5)

# Diet versus a biomarker, on the subsample where both exist.
p_diet_lipid <- dat |>
  filter(biomed_participant, is_adult, !is.na(hdl_mmol)) |>
  mutate(fibre_q = ntile(fibre_g_d1, 5)) |>
  group_by(fibre_q, sex) |>
  summarise(hdl = mean(hdl_mmol), se = sd(hdl_mmol) / sqrt(n()), n = n(),
            .groups = "drop") |>
  ggplot(aes(x = factor(fibre_q), y = hdl, colour = sex, group = sex)) +
  geom_line(linewidth = 0.7) +
  geom_pointrange(aes(ymin = hdl - 1.96 * se, ymax = hdl + 1.96 * se)) +
  scale_colour_manual(values = c(Male = "#2C5F8A", Female = "#C0392B"), name = NULL) +
  labs(title = "HDL cholesterol across quintiles of dietary fibre intake",
       subtitle = "Band-midpoint HDL; adult biomedical participants only, so precision is limited",
       x = "Fibre intake quintile (day 1)", y = "Mean HDL (mmol/L)", caption = CAPTION)

save_fig(p_diet_lipid, "14_fibre_vs_hdl", width = 9, height = 5)

# ============================================================================
# 10. Within-person variability: one day is not usual intake
# ============================================================================

d12 <- dat |>
  filter(has_day2, !is.na(energy_kj_d1), !is.na(energy_kj_d2))

r_energy <- cor(d12$energy_kj_d1, d12$energy_kj_d2)

p_d12 <- ggplot(d12, aes(x = energy_kj_d1, y = energy_kj_d2)) +
  geom_point(alpha = 0.08, size = 0.5, colour = "#2C5F8A") +
  geom_abline(slope = 1, intercept = 0, linetype = "dashed", colour = "grey30") +
  geom_smooth(method = "lm", colour = "#C0392B", linewidth = 0.8) +
  scale_x_continuous(labels = comma, limits = c(0, 25000)) +
  scale_y_continuous(labels = comma, limits = c(0, 25000)) +
  labs(title = "Day-1 versus day-2 energy intake in the same person",
       subtitle = paste0("Pearson r = ", number(r_energy, accuracy = 0.01),
                         " across ", comma(nrow(d12)),
                         " repeat recalls: a single 24-hour recall is a noisy measure of usual intake"),
       x = "Day 1 energy (kJ)", y = "Day 2 energy (kJ)", caption = CAPTION)

save_fig(p_d12, "15_day1_vs_day2", width = 8, height = 6.5)

within_between <- tibble(
  nutrient = c("Energy (kJ)", "Fibre (g)", "Sodium (mg)", "Vegetable serves"),
  r = c(
    cor(d12$energy_kj_d1, d12$energy_kj_d2, use = "complete.obs"),
    cor(d12$fibre_g_d1,   d12$fibre_g_d2,   use = "complete.obs"),
    cor(d12$sodium_mg_d1, d12$sodium_mg_d2, use = "complete.obs"),
    cor(d12$serves_veg_d1, d12$serves_veg_d2, use = "complete.obs")
  )
)
save_tab(within_between, "15_day1_day2_reliability")
print(as.data.frame(within_between))

# ============================================================================
# 11. Headline summary table
# ============================================================================

summarise_num <- function(x) {
  tibble(n = sum(!is.na(x)), mean = mean(x, na.rm = TRUE),
         sd = sd(x, na.rm = TRUE),
         p25 = quantile(x, 0.25, na.rm = TRUE),
         median = median(x, na.rm = TRUE),
         p75 = quantile(x, 0.75, na.rm = TRUE))
}

summary_tbl <- adults |>
  select(bmi, waist_cm, energy_kj_d1, protein_g_d1, fibre_g_d1, sodium_mg_d1,
         pct_energy_satfat_d1, pct_energy_freesug_d1, serves_veg_d1,
         serves_fruit_d1, sitting_hours_day, sleep_hours, ei_bmr_d1,
         chol_mmol, hdl_mmol, ldl_mmol, gluc_mmol) |>
  imap_dfr(\(x, nm) summarise_num(x) |> mutate(variable = nm, .before = 1)) |>
  mutate(across(where(is.numeric), \(v) round(v, 2)))

print(as.data.frame(summary_tbl))
save_tab(summary_tbl, "16_adult_summary")

by_sex <- adults |>
  group_by(sex) |>
  summarise(
    n = n(),
    mean_bmi = mean(bmi, na.rm = TRUE),
    pct_overweight_obese = mean(bmi_class %in% c("Overweight", "Obese"), na.rm = TRUE),
    mean_energy_kj = mean(energy_kj_d1),
    mean_fibre_g = mean(fibre_g_d1),
    mean_sodium_mg = mean(sodium_mg_d1),
    pct_meeting_veg = mean(meets_veg_target),
    pct_meeting_fruit = mean(meets_fruit_target),
    .groups = "drop"
  ) |>
  mutate(across(where(is.numeric), \(v) round(v, 3)))

print(as.data.frame(by_sex))
save_tab(by_sex, "17_adult_summary_by_sex")

message("\nEDA complete. Figures in outputs/figures/, tables in outputs/tables/.")
