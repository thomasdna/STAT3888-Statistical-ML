# STAT3888 / NUTM3888 — analysis notes

This is the working analysis write-up shipped with the Team 15 git package.
Start with [`../README.md`](../README.md) for how to run the code. The numbers
below match the tables in `outputs/tables/`.

---


Analysis of the ABS **Australian Health Survey 2011–13** Basic Confidentialised
Unit Record Files, focused on the **National Nutrition and Physical Activity
Survey (NNPAS 2011–12)**.

## Layout

```
STAT3888/
├── R/
│   ├── 00_setup.R           paths, packages, missing-code helpers, plot theme
│   ├── 01_build_codebook.R  parses the ABS .xls item lists into a searchable dictionary
│   ├── 02_verify_data.R     integrity checks: inventory, key uniqueness, linkage, sentinels
│   ├── 03_prepare_data.R    builds the clean person-level analysis dataset
│   ├── 04_eda.R             exploratory analysis and figures
│   ├── 05_repro_engelen.R   reproduction of Engelen et al. (2017)
│   ├── 06_cmr_outcome.R     biomarker cardiometabolic risk outcome + RQ1
│   ├── 07_rq2_interaction.R RQ2: what distinguishes elevated risk, by BMI class
│   ├── 08_rq3_prediction.R  RQ3: out-of-sample prediction beyond age/sex/BMI
│   ├── 09_diet_exposure_test.R  robustness of the diet null on food-level data
│   ├── 10_nhs_chol_build.R  National Health Survey cholesterol analysis dataset
│   ├── 11_chol_bmi_waist.R  BMI/waist as cholesterol screening indicators
│   ├── 12_chol_screening_eval.R  screening value and subgroup equity
│   └── run_all.R            runs 01 → 12 in order
├── papers/                  the six published AHS papers we are benchmarking against
├── data/
│   ├── original_data/       ABS files as downloaded (do not edit)
│   │   ├── all_files/       the 25 survey CSVs + item lists
│   │   ├── *.xls            ABS data item lists (variable + category definitions)
│   │   ├── File-2.variables.xlsx  variable-to-file map with descriptions
│   │   └── 2024_AHSData_3888.pdf  unit briefing on the survey structure
│   └── derived/             generated: codebook + analysis dataset
└── outputs/
    ├── figures/             generated PNGs
    └── tables/              generated CSVs
```

## Running it

```bash
cd R
Rscript run_all.R
```

Requires R ≥ 4.4 with `tidyverse`, `data.table`, `readxl`, `patchwork`, `scales`
and `mgcv` (for the GAM smooths in `04_eda.R`).

Each script can also be sourced individually from the `R/` directory; they read
from `data/` and write to `data/derived/` and `outputs/`.

## The data

The AHS combines four surveys. The files here cover three of them:

| Prefix | Survey | Files | Persons |
|---|---|---|---|
| `AHSnhs11b*` | National Health Survey 2011–12 | 8 | 20,426 |
| `AHSnpa11b*` | National Nutrition & Physical Activity Survey 2011–12 | 5 | 12,153 |
| `inp13b*` | National Aboriginal & Torres Strait Islander NPA Survey 2012–13 | 12 | 4,109 |

### NNPAS record structure

Files are hierarchical and link on ABS identifiers:

| Level | File | Records | Key |
|---|---|---|---|
| Person | `AHSnpa11bp.csv` | 12,153 | `ABSPID` |
| Biomedical | `AHSnpa11bb.csv` | 12,153 | `ABSPID` |
| Food occasion | `AHSnpa11bf.csv` | 341,897 | `ABSPID` + `ABSFID` + `DAYNUM` |
| Supplement | `AHSnpa11bs.csv` | 25,141 | `ABSPID` + `ABSSID` + `DAYNUM` |
| ADG summary | `AHSnpa11ba.csv` | 3,102,528 | `ABSPID` + `ABSLFID` + `DAYNUM` |

`ABSHID` + `ABSPID` gives the unique 14-digit person identifier.

## What verification established

`02_verify_data.R` passes on all checks:

- All 25 documented CSVs are present with the expected record and variable counts.
- Identifiers are unique at their stated level, with no orphan records at any level.
- All 12,153 persons link to the biomedical, food, supplement and ADG levels.
- Day-1 energy summed from the food file reproduces the person file's `ENERGYF1`
  to within 0.07 kJ (r = 1.000), so the levels are internally consistent.

Three properties of the data shape everything downstream:

1. **The person file already has what most analyses need.** Day-1 and day-2
   nutrient totals (`ENERGYT1`, `FIBRET1`, `SODIUMT1`, …), percentage-of-energy
   breakdowns (`SATPER1`, `PEFRESD1`, …) and Australian Dietary Guideline serves
   by food group (`VEGLEG1N`, `FRUIT1N`, …) are all pre-computed. The 226 MB food
   file is only needed for food-occasion or meal-composition questions.
2. **Subsamples are nested and shrink fast.** All 12,153 have a day-1 recall;
   7,735 (63.6%) gave a day-2 recall; 4,444 (36.6%) took part in the biomedical
   component; 3,375 (27.8%) have fasting lipids. Any diet–biomarker analysis is
   an *n* ≈ 3,000–4,000 study, not an *n* = 12,000 one.
3. **Biomarkers are ordered bands, not numbers.** The Basic CURF releases
   cholesterol, HDL, LDL, triglycerides, glucose and HbA1c as categories such as
   "5.0 to less than 5.5". `03_prepare_data.R` keeps the ordered factor and adds
   a band-midpoint approximation; prefer ordinal or binary methods for inference.

### Missing-value codes

The CURFs use sentinel integers rather than blanks, and the sentinel depends on
field width. `03_prepare_data.R` handles these explicitly:

| Variable | Sentinels | Meaning |
|---|---|---|
| `BMISC`, `BMICATHY` | 0, 98, 99 | not applicable / not measured / not known |
| `PHDKGWBC`, `PHDCMHBC`, `PHDCMWBC` | 0, 998, 999 | measurement not taken |
| `EXLEVELN` | 0, 8 | not applicable / not stated |
| `ADTOTSE` | 9996, 9999 | aged under 18 / not stated |
| `SLPTIME` | 9998, 9999 | not available / not stated |
| `EIBMR1`, `EIBMR2` | 997, 998 | not applicable / not available |
| `BMR` | 99998 | not available |
| `CHOLRESB`, `LDLRESB`, `TRIGRESB`, `GLUCFREB` | 97, 98 | not applicable / not reported |
| `HDLCHREB`, `HBA1PREB` | 7, 8 | not applicable / not reported (single-digit!) |

`AGEC` is top-coded at 85 and `SEIFA` labels carry footnote asterisks — both are
handled in the prep script.

## Derived dataset

`data/derived/npa_person.rds` — 12,153 rows × 95 columns, one row per person,
with lower-case snake-case names, labelled factors, sentinels converted to `NA`,
and derived measures (`bmi_class`, `waist_height_ratio`, `sodium_potassium_ratio`,
`meets_veg_target`, `implausible_recall`, band midpoints).

`data/derived/npa_person_codebook.csv` lists every derived variable with its type
and missingness. `data/derived/codebook_variables.csv` (3,438 rows) and
`codebook_levels.csv` (4,852 rows) cover all three surveys.

Two lookup helpers are defined in `01_build_codebook.R`:

```r
look("cholesterol")        # search variables by name or description
look("fibre", file = "npa")
levels_of("EXLEVELN")      # value labels for a coded variable
```

## Findings so far

Unweighted, day-1 recall, adults 18+ unless stated.

| | Male | Female |
|---|---|---|
| n | 4,329 | 5,106 |
| Mean BMI | 27.8 | 27.3 |
| Overweight or obese | 62.1% | 47.2% |
| Mean energy (kJ) | 9,743 | 7,397 |
| Mean fibre (g) | 24.5 | 21.2 |
| Mean sodium (mg) | 2,724 | 2,078 |
| Meets 5 veg serves | 20.5% | 16.7% |
| Meets 2 fruit serves | 30.4% | 28.4% |

- **Guideline adherence is very low.** Only 18.5% of adults reached 5 vegetable
  serves and 6.5% met both the fruit and vegetable targets on the recall day.
- **Sodium exceeds the target for most people.** 53.1% of adults recorded more
  than 2,000 mg from food alone, before any salt added at the table.
- **Energy under-reporting is differential.** Median energy intake ÷ BMR falls
  from 1.40 in the normal-BMI group to 1.05 in the obese group, and 22.1% of
  adults with a measured weight fall below the 0.9 plausibility cut-off. Raw
  diet–adiposity associations are therefore attenuated or even reversed: reported
  fibre and energy both *decrease* with BMI.
- **A single day is a noisy measure of usual intake.** Day-1 to day-2
  correlations are 0.43 for energy, 0.44 for fibre, 0.30 for sodium and 0.26 for
  vegetable serves.
- **Absolute nutrient intakes are strongly collinear** (energy–fat ρ = 0.83,
  fat–saturated fat ρ = 0.90), so energy adjustment is needed before regression
  or clustering.
- **Cardiometabolic gradients are clear in the biomedical subsample.** High
  triglycerides rise from 5.9% (normal BMI) to 26.3% (obese); low HDL from 13.0%
  to 34.4%.

## Reproduction: Engelen et al. (2017)

`R/05_repro_engelen.R` reproduces Engelen L, Gale J, Chau JY, Hardy LL, Mackey M,
Johnson N, Shirley D, Bauman A (2017), "Who is at risk of chronic disease?
Associations between risk profiles of physical activity, sitting and
cardio-metabolic disease in Australian adults", *Aust NZ J Public Health*
41(2):178–183.

The paper cross-classifies NNPAS adults into four physical-activity × sitting-time
groups at the weighted medians, then uses logistic regression to relate group
membership to cardiovascular disease, diabetes and metabolic syndrome.

### Sample and exposure — exact

| Quantity | Published | Ours |
|---|---|---|
| Adults 18+ | 9,435 | 9,435 |
| Analytical n | 9,403 | 9,403 |
| Biomedical adults | 3,803 | 3,803 |
| Total PA, weighted median (min/wk) | 160 | 160 |
| Total PA, weighted mean | 284 | 282 |
| Sitting, weighted mean (h/wk) | 38.8 | 38.8 |
| Sitting, weighted median (h/wk) | 36.0 | 36.0 |
| Sitting, weighted IQR (h/wk) | 23.0–52.5 | 23.0–52.5 |

Two details had to be inferred because the paper does not state them:

- **Total physical activity.** The Active Australia score is walking + moderate +
  2 × vigorous minutes. `EXLWTBC` is the ABS total of walking + moderate +
  vigorous, so the score is `EXLWTBC + EXLWVBC`. This reproduces the published
  mean, median and quartile cut-points.
- **Missing exposure handling.** The published analytical n of 9,403 is exactly
  9,435 minus the 32 records with missing sitting time, so the 107 records with
  missing PA minutes must have been set to zero rather than dropped.

Group sizes come within 0.5–1.1% of the published counts (2,298 vs 2,323 for the
high-risk group). The residual difference is tie-handling at the median
cut-points, where PA of exactly 160 min/wk and sitting of exactly 2,160 min/wk
are ambiguous.

### Table 2 — all 36 odds ratios reproduced

**Every one of the 36 published odds ratios falls inside our 95% confidence
interval.** The median absolute log ratio between our estimate and the published
one is 0.042, i.e. about 4%. See `outputs/figures/repro_engelen_01_forest.png`
and `outputs/tables/engelen_04_table2_comparison.csv`.

The headline results replicate in direction, magnitude and significance: relative
to the high PA–low sitting reference group, the low PA–high sitting group has
1.38× the odds of cardiovascular disease (published 1.41) and 2.37× the odds of
metabolic syndrome (published 2.37), while no PA–sitting combination is
significantly associated with diabetes.

### Where the reproduction is approximate

- **Outcome prevalence differs.** We get CVD 21.5% against 24.1% published, and
  diabetes 5.9% against 5.1%. The paper says only that participants were
  classified as having a condition if "a health professional had told them on at
  least one occasion"; it never lists which conditions count as CVD. Our
  definition is any of the six circulatory conditions in the CURF (`HYPBC`,
  `ISCHBC`, `HFOBC`, `CEREVBC`, `OEDBC`, `ANGBC`). Adding high cholesterol gives
  27.1% and hypertension alone gives 18.2%, so 24.1% sits between plausible
  definitions. The odds ratios are insensitive to this because the exposure–outcome
  gradient survives the definitional shift.
- **Diabetes cannot be restricted to type 2.** `DIABBC` covers diabetes mellitus
  generally.
- **Metabolic syndrome is bracketed, not point-identified.** The criterion needs
  fasting triglycerides ≥ 1.7 mmol/L, but the Basic CURF releases triglycerides
  only in bands (1.5–2.0, 2.0–2.5, …), so 1.7 falls *inside* a band. Using ≥ 2.0
  gives MetS prevalence 13.4%; using ≥ 1.5 gives 18.5%. The published 16.1% lies
  inside that interval, which is the strongest statement the Basic CURF supports.
- **Standard errors now use the same estimator Engelen used.** An earlier version
  of this README claimed the Basic CURF supplies replicate weights only in the
  biomedical file. That was wrong: the NNPAS person file carries 60 delete-a-group
  jackknife replicate weights as `WPM0101`–`WPM0160` (plus `W2M0101`–`W2M0160`
  for day 2). All four CVD and diabetes models now use `svrepdesign()` on those
  weights instead of `svydesign(ids = ~1)`, and the resulting intervals line up
  closely with the published ones (e.g. Model 3 Low PA–Low Sit: 1.27, 1.00–1.62
  against the published 1.26, 1.01–1.58).

## Main analysis: cardiometabolic health beyond BMI

Three research questions, built on the Engelen reproduction. Engelen is the
anchor because it is the only one of the six papers with a cardiometabolic
*outcome*, it uses the same biomedical subsample, its covariate block is the one
these questions need, and — most importantly — it explicitly treats waist
circumference as "a proxy measure of abdominal obesity (BMI)". RQ1 tests whether
that substitution is defensible. The other five papers are dietary-intake
description studies; they justify the *exposures* used in RQ2 and RQ3, not the
outcome.

### The outcome (`06_cmr_outcome.R`)

`cmr_elevated` is TRUE when two or more of five biomarker risk factors are
present:

| Risk factor | Definition | Source variable |
|---|---|---|
| Raised blood pressure | ≥130/85 mmHg or reported hypertension | `SYSTOL`, `DIASTOL`, `HYPBC` |
| Dysglycaemia | fasting glucose >6.0, HbA1c ≥6.0%, or reported diabetes | `GLUCFPD`, `DIAHBRSK`, `DIABBC` |
| Low HDL | <1.0 (M) / <1.3 (F) mmol/L | `HDLCHSEX` |
| High total cholesterol | ≥5.5 mmol/L | `CHOLNTR` |
| Elevated liver enzymes | abnormal ALT or GGT | `ALTNTR`, `GGTNTR` |

Three design decisions matter:

1. **The ABS `*NTR` status flags are used instead of the banded values.** Each
   flag already sits on a clinical cut-point, which avoids the
   band-interpolation problem that forced the metabolic-syndrome figure in
   `05_repro_engelen.R` to be bracketed rather than point-identified.
2. **No fasting-dependent marker is in the core score.** LDL, triglycerides and
   fasting glucose exist only for the ~3,180 who fasted 8+ hours; excluding them
   keeps n at 3,525 instead of ~2,950. A seven-marker version on the fasting
   subsample is reported as a sensitivity analysis.
3. **Waist and BMI are excluded from the outcome by construction**, so RQ1 is
   not tautological.

Analysis sample: 3,525 adults 18+ with all five markers and a measured BMI;
3,421 after requiring complete predictors and non-zero reported energy.

### RQ1 — BMI agrees only weakly with biomarker risk

Cohen's κ = **0.245**. As a test for elevated risk, BMI ≥ 25 has sensitivity
0.81, specificity 0.45, PPV 0.53.

| BMI category | n | elevated risk | % |
|---|---|---|---|
| Underweight | 37 | 7 | 18.9 |
| Normal | 1,140 | 276 | 24.2 |
| Overweight | 1,336 | 614 | 46.0 |
| Obese | 1,012 | 626 | 61.9 |

Discrimination (AUC) for elevated risk: age 0.705, waist 0.701, BMI 0.688,
BMI ≥ 25 as a binary 0.630. **Age out-discriminates both adiposity measures**,
which reframes RQ3: the "age, sex and BMI" baseline is mostly an age model.

Robust to specification — the seven-marker score on the fasting subsample gives
κ = 0.195, i.e. slightly worse agreement.

### RQ2 — only age, BMI, smoking and self-rated health survive (`07_rq2_interaction.R`)

Fitted on the full sample with BMI-class × predictor interactions rather than on
the normal-BMI stratum alone: 1,487 events instead of 269, and an interaction is
the direct test of whether a predictor carries information BMI does not already
encode. Survey-weighted with the 60 jackknife replicate weights.

Joint Wald tests, Holm-adjusted across 18 predictors:

| Predictor | p (Holm) |
|---|---|
| BMI category | 1.4 × 10⁻⁸ |
| Age | 9.9 × 10⁻⁸ |
| Smoking status | 0.0074 |
| Self-rated health | 0.041 |
| everything else | 1.00 |

**No dietary or physical-activity variable is associated with elevated risk
after adjustment, and no BMI-class interaction survives correction** (smallest
interaction p = 0.185, all Holm-adjusted p = 1.00). The interaction model's
normal-BMI simple slopes agree with a genuinely normal-BMI-only model
(`rq2_05_normal_only_crosscheck.csv`), confirming the pooled model is not
hiding stratum-specific effects.

Total energy is deliberately excluded: it correlates 0.89 with the
energy-intake-to-BMR ratio (VIF 6.0 and 5.6 together). Nutrients enter as
densities per MJ or as percentage of energy, and the energy-to-BMR ratio adjusts
for the differential under-reporting documented in `04_eda.R`.

### RQ3 — the extra blocks add 13% of what BMI alone adds (`08_rq3_prediction.R`)

Elastic-net logistic regression, 20 × 5-fold cross-validation with the penalty
tuned inside each training fold. Uncertainty comes from a 2,000-resample
bootstrap **over individuals**, not over folds — comparing AUCs across CV
replicates measures only fold-assignment noise and would manufacture arbitrarily
small p-values.

| Model | predictors | CV AUC | Δ vs baseline | 95% CI | p |
|---|---|---|---|---|---|
| M0: age + sex | 2 | 0.704 | −0.052 | −0.063, −0.040 | <0.001 |
| **M1: + BMI (baseline)** | 3 | **0.755** | — | — | — |
| M2: + activity & sleep | 6 | 0.757 | +0.002 | −0.001, +0.004 | 0.15 |
| M3: + diet | 10 | 0.754 | −0.001 | −0.002, +0.001 | 0.55 |
| M4: + socioeconomic | 12 | 0.757 | +0.002 | −0.001, +0.005 | 0.18 |
| M5: + smoking | 5 | 0.760 | +0.005 | +0.001, +0.009 | 0.013 |
| M6: all blocks | 24 | 0.762 | +0.007 | +0.003, +0.012 | 0.002 |
| M7: all except BMI | 23 | 0.721 | −0.033 | −0.045, −0.021 | <0.001 |

The answer to RQ3 is essentially no. Adding BMI to age and sex buys +0.051 AUC;
adding 21 further diet, activity and socioeconomic variables buys +0.007, which
is 13% of the BMI gain and almost entirely attributable to smoking. The diet
block on its own is indistinguishable from zero. And 23 predictors without BMI
cannot recover what BMI provides (0.721 vs 0.755), so BMI is a weak proxy that
is nonetheless not replaceable by what else the survey measures.

### Robustness: the diet null is not an exposure-definition artefact (`09_diet_exposure_test.R`)

The obvious objection to RQ2 and RQ3 is that the diet block was thin. A review of
the other five papers surfaced two much better exposures already in the Basic
CURF, so the diet block was rebuilt from the food file:

- **`DISCFLG`**, a food-level discretionary-food flag. Aggregated to a
  person-level energy share it gives 35.44%, matching the ABS published figure of
  ~35% exactly, and it tracks the ultra-processed gradient in Machado et al.
  (2019) on seven of eight nutrients.
- **ABS's ADG food-group gram columns** (`RMTTGM`, `FISHGM`, `WGGM`, `VEGGM` and
  so on), which are ABS's own mixed-dish disaggregation. 18% of all meat grams
  come from foods outside the meat and fish major groups, so these reach meat
  inside pizza and lasagne that a food-group serve variable misses.

Thirteen new exposures were added — % energy from discretionary food, energy
density of solid food, and eleven food groups as grams per MJ. Results:

| Test | Result |
|---|---|
| Best single exposure (energy density) | OR 0.815, raw p = 0.028, **Holm p = 0.365** |
| Joint Wald test of all 13 | **F = 1.09 on 13 and 17 df, p = 0.424** |
| RQ3 AUC change, food-file diet block | **−0.0007** (95% CI −0.0026, +0.0012), p = 0.43 |
| RQ3 AUC change, both diet blocks | −0.0001 (−0.0023, +0.0021), p = 0.89 |
| Unadjusted prevalence by discretionary quintile | 40.7 / 44.9 / 42.8 / 45.6 / 43.3% — flat |

The quintile gradient is not an age artefact: standardised mean age is within
0.09 SD of the sample mean in every quintile. This isolates measurement error in
the 24-hour recall as the remaining explanation for the null.

### Reproducibility of the other five papers

| Paper | Verdict | Binding constraint |
|---|---|---|
| Engelen 2017, ANZJPH | **Reproduced** | 36/36 published ORs covered |
| Lei 2016, Br J Nutr | Largely reproducible | Exact n = 8,202 recovered; total sugars, energy and macronutrients match in all 8 age groups. Only the bespoke added-sugar composition database is missing; free sugars matches within 0.5% |
| Sui 2017, BMC Nutrition | Partially | Totals match within 1–3% (pre-disaggregation fish exact at 26.0 g/d), but meat-type detail inside mixed dishes and all nutrient-contribution tables are unrecoverable |
| Machado 2019, BMJ Open | Partially | NOVA food-code lookup unpublished ("No data are available") and the AUSNUT recipe file is absent. `DISCFLG` is a validated proxy |
| Sui 2017, Public Health Nutrition | Partially | `EATOCC`/`EATTIMEC` complete and proportions match within 1–3 points, but the "popular choices" table rests on undocumented manual dish-name coding |
| Brand-Miller & Barclay 2017, AJCN | **Not reproducible** | Every Table 1 cell is a 1995→2011 change; the 1995 survey, FAOSTAT, ABS apparent-consumption and proprietary Nielsen data are all absent. The 2011-12 endpoint alone matches on 18 of 21 statistics |

Two corrections to earlier assumptions in this README's history: the food file
**does** carry added and free sugars per food item (`ADDSGGRM`, `FRESGGRM`, which
sum to the person-level totals within 0.007 g), and it **does** carry ABS's ADG
food-group disaggregation. The highest-value cheap unlock is the free FSANZ
AUSNUT 2011-13 food-name file, since our codebook has no text labels for any of
the 4,712 food codes.

### How to read the negative results

These are findings about *measurement*, not about biology. A single 24-hour
recall attenuates diet–outcome associations severely: `04_eda.R` puts the
day-1/day-2 correlation at roughly 0.4 for energy, so true associations are
biased towards the null by a large and quantifiable factor. The honest
conclusion is that NNPAS-grade dietary data cannot detect diet–biomarker
associations at this sample size, not that diet is unrelated to cardiometabolic
risk. The day-1/day-2 subsample (n = 2,663 here) supports a measurement-error
correction that would put a number on the attenuation.

## Second candidate: unrecognised high cholesterol (`10`–`12`)

Assessment of the team's proposal in `STAT3888_Candidate_Q1.pdf`:

> RQ1 — How accurately can routinely available non-laboratory characteristics
> identify Australian adults with measured high cholesterol who do not report
> having high cholesterol?
> RQ2 — Does that ability differ across age, sex and socioeconomic groups?

This runs on a **different survey** from everything above. The proposal names
NHS variables (`AGEB`, `INCDECPN`, `SF2SA1DN`, `EXLEVELN`, `SMKSTAT`), so
scripts `10`–`12` use the National Health Survey files, which give a larger
biomedical sample (5,761 adults 18+ against 4,444 in NNPAS) plus smoking,
exercise-level and cholesterol-testing items. The cost is that the NHS has **no
dietary data at all**, so nothing from scripts `03`–`09` transfers directly.

### Data-structure findings the proposal needs

| Issue | Detail |
|---|---|
| Person key | `ABSPID` is **not** unique in the NHS (it runs 1–6, the person number *within* household). The key is `ABSLID` + `ABSPID`. One household has a duplicate pair, dropped. |
| Self-reported high cholesterol | There is **no person-level flag** in the NHS. It must be derived from the long-format conditions file: `EVERCURF == 14693` ("High cholesterol") with `CONDSTAT` for currency. 2,368 adults have such a record. |
| `CVDMEDST` is fasting-only | All 4,353 valid records are `FASTSTAD == 1`; every one of the 1,358 non-fasting participants is coded "not applicable". Using the medication-aware outcome costs 23% of the sample. |
| Testing history exists | `CHOL5YR` and `CHOLEST` record whether and when cholesterol was last checked. Not in the proposal, and the only variables that speak directly to "prioritising people for lipid testing". |
| `CHOL5YR` is age-gated | Asked universally only from age 45 (85–97% "not applicable" below that), so any testing-history analysis is a 45+ analysis. n = 3,954 in the biomedical sample. |
| Sample size | Our funnel gives 5,761 adults 18+, 5,683 with measured cholesterol. The proposal's table quotes 5,443; no filter tried reproduces it, though the missing-data percentages match closely. Worth reconciling. |

### The outcome definition is the weak point

The proposal's motivating statistic — "approximately 89% of participants with
measured high cholesterol did not report a diagnosis" — reproduces exactly
(88.3%). But it does not mean what it appears to mean:

- Of the 2,368 adults with a high-cholesterol condition record, **788 report it
  as "ever told, not current"**. They have been made aware of it, so counting
  them as unrecognised is wrong, yet the strict definition does exactly that.
- Among adults who *do* report current high cholesterol, only **34.2%** measure
  high — because **75.5%** of those whose medication status is known are on
  lipid-lowering medication and it is working. Self-report and measurement are
  answering different questions.
- Prevalence of high total cholesterol **falls** after age 65 (men 47% at 45–54
  → 26% at 65+). That is treatment, not biology, and any outcome built on
  measured levels alone inherits the bias.

`CVDMEDST == 3` ("not using lipid medication and has abnormal results") is the
medication-aware alternative and is what a screening target should be. Its
problem is the opposite one: **52.0% of fasted adults meet it**, because the
ABS definition counts any abnormal lipid. A condition affecting half the
population is not a screening target.

### Answers to the assigned BMI/waist task (`11_chol_bmi_waist.R`)

Weighted prevalence of measured high total cholesterol:

| BMI category | Prevalence | | Waist category | Prevalence |
|---|---|---|---|---|
| Underweight | 13.6% | | Not at risk | 27.3% |
| Normal | 28.4% | | Increased risk | 40.1% |
| Overweight | 38.1% | | Substantially increased | 37.5% |
| Obese I | 37.2% | | | |
| Obese II–III | 39.5% | | | |

The gradient is real but shallow and flat above "overweight", and it is
non-monotonic for waist. **BMI beats waist on every outcome tested**, contrary
to the usual expectation that abdominal measures do better — so the proposal's
plan to compare them has a clear answer, just not the anticipated one.

Discrimination (weighted AUC, single markers):

| Outcome | BMI | Waist | Age |
|---|---|---|---|
| High total cholesterol | 0.572 | 0.565 | **0.605** |
| Low HDL (sex-specific) | **0.657** | 0.621 | 0.493 |
| High LDL (fasting) | 0.575 | 0.574 | 0.568 |
| Untreated dyslipidaemia | **0.593** | 0.573 | 0.498 |

**Which lipid you choose decides whether adiposity is useful at all.** BMI is
worth something for HDL (age-/sex-adjusted OR 1.73 per 5 kg/m²) and nearly
nothing for total cholesterol (OR 1.13). This is the same pattern script `06`
found in NNPAS: blood pressure, dysglycaemia and low HDL track BMI; total
cholesterol barely does. Two independent surveys, same conclusion.

By age and sex: the association differs strongly by **age** (BMI × age
*p* = 4 × 10⁻⁹) and not by sex (*p* = 0.31). Stratified, the odds ratio per
5 kg/m² is 1.46 at 18–34 but 0.80–0.91 at 55+, i.e. it **reverses** — again
consistent with treatment being concentrated in heavier older adults.

### Answers to RQ1 and RQ2 (`12_chol_screening_eval.R`)

Out-of-sample weighted AUC, 5 × 10-fold CV, elastic-net logistic regression:

| Outcome | Age + sex | + BMI & waist | + BP | + smoking & PA | + income & SES |
|---|---|---|---|---|---|
| High total cholesterol | 0.597 | 0.598 | 0.599 | 0.597 | 0.592 |
| **High + not self-reported** (their RQ1) | 0.581 | 0.582 | 0.583 | 0.580 | 0.576 |
| Untreated dyslipidaemia | 0.478 | 0.588 | 0.590 | 0.583 | 0.588 |
| Low HDL | 0.564 | 0.693 | 0.699 | 0.702 | **0.708** |

For the proposal's own outcome, **every non-laboratory variable together adds
nothing to age and sex** (0.581 → 0.576, i.e. slightly worse). The honest answer
to RQ1 as written is "not accurately, and no better than asking someone's age".

The decisive test is against the rule Australia already uses. Sizing each policy
to test the same ~50% of the population as "test everyone aged 45+":

| Outcome | Age-45 rule | Full model | Difference |
|---|---|---|---|
| High total cholesterol | 60.4% of cases | 59.3% | **−1.1 pp** |
| High + not self-reported | 58.8% | 58.6% | −0.2 pp |
| Untreated dyslipidaemia | 50.5% | 57.1% | +6.6 pp |
| Low HDL | 46.5% | **72.3%** | **+25.8 pp** |

A non-laboratory model cannot beat an age cut-off for total cholesterol, but
beats it decisively for HDL.

**RQ2 (equity) is the stronger half of the proposal** and the results are
substantive:

- At a fixed threshold flagging the riskiest 40% of adults, **1.4%** of 18–34
  year-olds are flagged against **96.8%** of over-65s. The model is an age
  cut-off in disguise.
- Within-age-band AUC: 0.601 (18–34), 0.539, 0.507, 0.458, 0.468 (65+). Inside
  the two oldest bands it is **worse than random**.
- The model discriminates worst in the **most disadvantaged areas** (AUC 0.521 in
  SEIFA Q1 against 0.596–0.618 elsewhere) — a real fairness finding.

Who actually goes untested (45+, `CHOL5YR`, n = 3,720, 8.9% untested):

| Predictor | OR | 95% CI | *p* |
|---|---|---|---|
| Age (per year) | 0.969 | 0.941–0.997 | 0.032 |
| BMI (per kg/m²) | 0.927 | 0.886–0.971 | 0.002 |
| SEIFA decile (per decile) | 0.900 | 0.829–0.976 | 0.012 |
| Current smoker | 1.667 | 0.910–3.052 | 0.096 |

**Higher BMI predicts being *more* likely to have been tested** (32% lower odds
of going untested per 5 kg/m²). Clinicians already use body size to decide who
gets a lipid panel, which is precisely why BMI has no headroom left as a
screening variable. Disadvantage runs the other way: the most disadvantaged
areas are the least tested.

### Verdict on the candidate

Feasible and cleanly executable, but RQ1 as written is answerable in one
sentence and the answer is negative. The salvageable versions, in order of
strength:

1. **Reframe onto HDL / untreated dyslipidaemia.** This is where non-laboratory
   information genuinely works (AUC 0.708, +25.8 pp over the age rule) and it
   answers the team-chat question about HDL versus LDL. Note the HDL/LDL *ratio*
   the chat asked for is not computable: both are released only in bands.
2. **Make RQ2 the primary question.** "Which groups does a non-laboratory
   screening rule systematically miss?" is novel, has clean answers, and the
   SEIFA and age results are strong.
3. **Study testing behaviour, not lipid levels.** `CHOL5YR` makes "who goes
   untested" a directly answerable question, and it is closer to the stated
   purpose (prioritising people for testing) than modelling cholesterol itself.

Keep the framing associational. Nothing here supports the causal language in the
chat about "which factor may be causing the high cholesterol": this is a single
cross-sectional survey, and the treatment effects above show the arrow can
easily point backwards.

## Known limitations

- **The EDA in `04_eda.R` is unweighted.** `weight_person`, `weight_day2` and
  `weight_biomed` are carried in the derived dataset but only `05_repro_engelen.R`
  uses them. Treat every number in `04_eda.R` as describing the sample, not the
  Australian population.
- **Replicate weights are available at both levels.** The person file has
  `WPM0101`–`WPM0160` (and `W2M0101`–`W2M0160` for day 2); the biomedical file has
  `RPWGT01`–`RPWGT60`. Use `svrepdesign(type = "JK1", scale = 59/60)` with
  whichever matches the analysis sample. The NHS files follow the same pattern
  (`NHSFINWT` + `WPM01**` at person level, `NHMSPERW` + `RPWGT**` at biomedical
  level).
- **Band midpoints are approximations.** Fine for plots, not for inference.
- **Cross-sectional.** No causal claims about diet and biomarkers.
- Fasting lipids (LDL, triglycerides, glucose) exist only for respondents who
  fasted 8+ hours, which is a further non-random restriction.
- **The RQ3 prediction models are unweighted.** The question is how well an
  individual's risk can be predicted, not what the population mean is, so
  cross-validation ignores the survey weights. Population-level calibration
  would need them.
- **The blood-pressure and dysglycaemia risk factors count treated conditions**
  (`HYPBC`, `DIABBC`), which is standard for metabolic syndrome but means
  self-reported conditions cannot also serve as predictors without circularity.
  The RQ2 and RQ3 predictor sets are diet, activity and socioeconomic only.
- **Self-rated health is arguably a consequence of elevated risk**, not a cause,
  so its RQ2 association should not be read causally.
- **The two candidates use different surveys and do not share a sample.** Scripts
  `03`–`09` use NNPAS (diet, no smoking or exercise-level items); scripts `10`–`12`
  use the NHS (smoking, exercise level, cholesterol testing, but no diet). The
  `inp13b*` files are a third survey again. Do not pool them.
- **Lipid outcomes are confounded by treatment.** Roughly 18% of fasted adults are
  on lipid-lowering medication, concentrated at older ages, so measured cholesterol
  understates underlying risk exactly where risk is highest. Only `CVDMEDST`
  accounts for this, and only for fasted respondents.
- **HDL/LDL ratios are not computable.** `HDLCHREB` and `LDLRESB` are released as
  ordered bands, so any ratio inherits two layers of banding error. Use the
  status variables (`HDLCHSEX`, `LDLNTR`) instead.

## Possible research questions

1. Does dietary pattern (from clustering or PCA on energy-adjusted food-group
   serves) predict abnormal lipid status, controlling for BMI, age, sex and
   under-reporting status?
2. Does the sodium-to-potassium ratio associate with self-reported hypertension
   better than sodium alone?
3. Is a socio-economic gradient in guideline adherence explained by food
   insecurity (`ran_out_of_food`) or by household income?
4. How much does adjusting for energy under-reporting change the estimated
   diet–BMI relationship? A methods-flavoured question that suits STAT3888.
5. Using the day-1/day-2 subsample, how much attenuation does within-person
   variability cause, and what does a measurement-error correction do to the
   estimates?
6. Do meal-level patterns from the food file (eating occasions, timing via
   `EATTIMEC`, energy density) relate to adiposity independently of total energy?

## Sources

- ABS, *Australian Health Survey: Users' Guide, 2011–13* (cat. 4363.0.55.001)
- ABS, *Microdata: Australian Health Survey, Nutrition and Physical Activity,
  2011–12 Basic CURF* (cat. 4324.0.55.002)
- NHMRC, *Australian Dietary Guidelines* (2013) and *Nutrient Reference Values
  for Australia and New Zealand*
