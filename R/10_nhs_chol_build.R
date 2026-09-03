# ---------------------------------------------------------------------------
# 10_nhs_chol_build.R
#
# Builds the person-level analysis dataset for the team's candidate question
# ("identifying unrecognised dyslipidaemia from non-laboratory information").
#
# This uses the NATIONAL HEALTH SURVEY component (AHSnhs11b*), not the
# nutrition survey (AHSnpa11b*) that scripts 03-09 use. The team's proposal
# names NHS variables (AGEB, INCDECPN, SF2SA1DN, EXLEVELN, SMKSTAT), and the
# NHS buys a larger biomedical sample plus smoking, exercise-level and
# cholesterol-testing-history items that the nutrition survey does not carry.
# The cost is that the NHS has no dietary data at all.
#
# Output: data/derived/nhs_chol.csv
# ---------------------------------------------------------------------------

source("00_setup.R")

message("== 10_nhs_chol_build ==")

# ---------------------------------------------------------------------------
# 1. Load. The NHS person key is the household id plus the within-household
#    person number; ABSPID alone only runs 1-6 and is NOT unique.
# ---------------------------------------------------------------------------

person <- fread(file.path(CSV_DIR, "AHSnhs11bsp.csv"))
biomed <- fread(file.path(CSV_DIR, "AHSnhs11bbi.csv"))
house  <- fread(file.path(CSV_DIR, "AHSnhs11bhh.csv"))
conds  <- fread(file.path(CSV_DIR, "AHSnhs11bcn.csv"))

mk_pid <- function(d) d[, pid := paste(ABSLID, ABSPID, sep = "_")][]
person <- mk_pid(person); biomed <- mk_pid(biomed); conds <- mk_pid(conds)

# One household contributes two records under person number 6 (a 2-year-old
# and a 17-year-old). Both are children, so the adult sample is unaffected,
# but drop them so the key is genuinely unique.
dup_pid <- person$pid[duplicated(person$pid)]
if (length(dup_pid)) {
  message("dropping ", length(dup_pid), " non-unique person key(s): ",
          paste(dup_pid, collapse = ", "))
  person <- person[!pid %in% dup_pid]
  biomed <- biomed[!pid %in% dup_pid]
}

rep_cols <- sprintf("RPWGT%02d", 1:60)

# ---------------------------------------------------------------------------
# 2. Self-reported high cholesterol.
#
#    The NHS has NO person-level "told you have high cholesterol" flag (unlike
#    HCHOLBC in the nutrition survey). It has to be derived from the long-format
#    conditions file: ICD-10 group 14693 = "High cholesterol", with CONDSTAT
#    giving currency. This is the answer to Stacy's open task.
#
#    CONDSTAT is kept separate rather than collapsed, because the distinction
#    drives the outcome definition:
#      1 ever told, still current and long-term   (n = 1514)
#      2 ever told, still current, not long-term  (n =   65)
#      3 ever told, NOT current                   (n =  788)  <- the awkward group
#      4 not/never told but condition current     (n =    1)
# ---------------------------------------------------------------------------

chol_cond <- conds[EVERCURF == 14693, .(
  sr_condstat_min = min(CONDSTAT)
), by = pid]

# "Current" = still has it now. "Ever" additionally counts people who say they
# were told in the past but that it is no longer current -- they have still
# been made aware of it, so they are not "unrecognised" in any useful sense.
chol_cond[, `:=`(
  sr_current = sr_condstat_min %in% c(1, 2, 4),
  sr_ever    = sr_condstat_min %in% c(1, 2, 3, 4)
)]

message("persons with a high-cholesterol condition record: ", nrow(chol_cond),
        " (current ", sum(chol_cond$sr_current),
        ", ever-but-not-current ", sum(chol_cond$sr_ever & !chol_cond$sr_current), ")")

# ---------------------------------------------------------------------------
# 3. Merge person + biomedical + household(SEIFA) + self-report.
# ---------------------------------------------------------------------------

p_keep <- c("pid", "ABSLID", "AGEB", "SEX", "BMISC", "BMICATHY", "PHDCMWBC",
            "PHDWCATM", "PHDWCATF", "SMKSTAT", "EXLEVELN", "SYSTOL", "DIASTOL",
            "INCDECPN", "CHOL5YR", "CHOLEST", "HYPBPRTM", "NHSFINWT")
p_keep <- intersect(p_keep, names(person))

b_keep <- c("pid", "BIORESPC", "FASTSTAD", "NHMSPERW", "CHOLNTR", "CHOLRESB",
            "HDLCHSEX", "HDLCHREB", "LDLNTR", "LDLRESB", "TRIGNTR",
            "CVDMEDST", "GLUCFPD", "HBA1PREB", rep_cols)
b_keep <- intersect(b_keep, names(biomed))

raw <- merge(person[, ..p_keep], biomed[, ..b_keep], by = "pid")
raw <- merge(raw, house[, .(ABSLID, SF2SA1DN)], by = "ABSLID", all.x = TRUE)

message("person x biomed x household rows: ", nrow(raw))

# ---------------------------------------------------------------------------
# 4. Restrict to adults who actually took part in the biomedical component.
#    AGEB is banded: code 5 = 18-19 years, so 18+ is AGEB >= 5.
# ---------------------------------------------------------------------------

adults <- raw[AGEB >= 5]
message("adults 18+: ", nrow(adults))
bio <- adults[BIORESPC == 2]
message("  of whom biomedical participants: ", nrow(bio))
message("  with total cholesterol measured: ", sum(bio$CHOLNTR %in% 1:2))
message("  fasted 8h+ (required for CVDMEDST/LDL): ", sum(bio$FASTSTAD == 1))
# The team's predictor table quotes a base of 5,443. No filter tried here
# reproduces it exactly (18+ gives 5,761; 20+ gives 5,693; cholesterol-measured
# gives 5,683), though their missing-data percentages match ours closely, so
# the samples are near-identical. Worth reconciling with Gordon.

# ---------------------------------------------------------------------------
# 5. Recode. ABS sentinels differ per field width, so they are set per variable.
# ---------------------------------------------------------------------------

AGE_MID <- c("5" = 18.5, "6" = 22, "7" = 27, "8" = 32, "9" = 37, "10" = 42,
             "11" = 47, "12" = 52, "13" = 57, "14" = 62, "15" = 67, "16" = 72,
             "17" = 77, "18" = 82, "19" = 87)

# Ranged lipid bands -> midpoints. Open top band gets a conservative value.
CHOL_MID <- c("1" = 3.75, "2" = 4.25, "3" = 4.75, "4" = 5.25, "5" = 5.75,
              "6" = 6.25, "7" = 6.75, "8" = 7.4)

d <- bio |>
  transmute(
    pid, ABSLID,

    # --- design -----------------------------------------------------------
    weight_biomed = NHMSPERW,
    weight_person = NHSFINWT,
    fasted        = FASTSTAD == 1,

    # --- non-laboratory predictors ---------------------------------------
    age_band = factor(AGEB, levels = names(AGE_MID),
                      labels = c("18-19", "20-24", "25-29", "30-34", "35-39",
                                 "40-44", "45-49", "50-54", "55-59", "60-64",
                                 "65-69", "70-74", "75-79", "80-84", "85+")),
    age      = unname(AGE_MID[as.character(AGEB)]),
    age_grp  = cut(age, c(17, 34, 44, 54, 64, 200),
                   labels = c("18-34", "35-44", "45-54", "55-64", "65+")),
    sex      = factor(SEX, 1:2, c("Male", "Female")),

    bmi = ahs_na(BMISC, c(98, 99)),
    # BMICATHY codes 4 and 5 are both "normal range"; 8 and 9 are obese II/III.
    bmi_class = factor(
      case_when(
        BMICATHY %in% 1:3 ~ "Underweight",
        BMICATHY %in% 4:5 ~ "Normal",
        BMICATHY == 6     ~ "Overweight",
        BMICATHY == 7     ~ "Obese I",
        BMICATHY %in% 8:9 ~ "Obese II-III"
      ),
      levels = c("Underweight", "Normal", "Overweight", "Obese I", "Obese II-III")
    ),

    waist = ahs_na(PHDCMWBC, c(998, 999)),
    # Sex-specific thresholds live in two variables; combine into one factor.
    waist_class = factor(
      case_when(
        SEX == 1 & PHDWCATM == 1 ~ "Not at risk",
        SEX == 1 & PHDWCATM == 2 ~ "Increased risk",
        SEX == 1 & PHDWCATM == 3 ~ "Substantially increased",
        SEX == 2 & PHDWCATF == 1 ~ "Not at risk",
        SEX == 2 & PHDWCATF == 2 ~ "Increased risk",
        SEX == 2 & PHDWCATF == 3 ~ "Substantially increased"
      ),
      levels = c("Not at risk", "Increased risk", "Substantially increased")
    ),

    smoking = factor(
      case_when(
        SMKSTAT %in% 1:3 ~ "Current",
        SMKSTAT == 4     ~ "Ex-smoker",
        SMKSTAT == 5     ~ "Never"
      ),
      levels = c("Never", "Ex-smoker", "Current")
    ),

    pa_level = factor(
      case_when(
        EXLEVELN == 1 ~ "High",
        EXLEVELN == 2 ~ "Moderate",
        EXLEVELN == 3 ~ "Low",
        EXLEVELN %in% 4:5 ~ "Sedentary"
      ),
      levels = c("High", "Moderate", "Low", "Sedentary")
    ),

    sbp = ahs_na(SYSTOL, 999),
    dbp = ahs_na(DIASTOL, 999),

    income_decile = ahs_na(INCDECPN, c(0, 98, 99)),
    seifa_decile  = ahs_na(SF2SA1DN, 0),
    seifa_q       = cut(seifa_decile, c(0, 2, 4, 6, 8, 10),
                        labels = c("Q1 (most disadv.)", "Q2", "Q3", "Q4",
                                   "Q5 (least disadv.)")),

    # --- cholesterol testing history (person file; not in the proposal) ---
    # CHOL5YR is only asked universally from age 45 (codes are "not applicable"
    # for 85-97% of 18-44 year olds), so anything built on it is a 45+ analysis.
    # CHOLEST adds timing but is a further subsample, so CHOL5YR is primary.
    testing_asked = CHOL5YR != 0,
    tested_5yr = case_when(
      CHOL5YR == 1 ~ TRUE,
      CHOL5YR == 5 ~ FALSE
    ),
    tested_when = factor(
      case_when(
        CHOLEST == 1 ~ "Within 12 months",
        CHOLEST == 2 ~ "1-5 years ago",
        CHOLEST == 3 ~ "Not in last 5 years"
      ),
      levels = c("Within 12 months", "1-5 years ago", "Not in last 5 years")
    ),

    # --- laboratory outcomes ---------------------------------------------
    chol_total = unname(CHOL_MID[as.character(ahs_na(CHOLRESB, c(97, 98)))]),
    chol_high  = case_when(CHOLNTR == 1 ~ FALSE, CHOLNTR == 2 ~ TRUE),
    hdl_low    = case_when(HDLCHSEX == 1 ~ FALSE, HDLCHSEX == 2 ~ TRUE),
    ldl_high   = case_when(LDLNTR == 1 ~ FALSE, LDLNTR == 2 ~ TRUE),
    trig_high  = case_when(TRIGNTR == 1 ~ FALSE, TRIGNTR == 2 ~ TRUE),

    # CVDMEDST is the only lipid variable that knows about medication.
    cvdmedst = ahs_na(CVDMEDST, c(0, 8)),
    on_lipid_med            = cvdmedst %in% 1:2 & !is.na(cvdmedst),
    dyslip_treated_abnormal = cvdmedst == 1,
    dyslip_treated_normal   = cvdmedst == 2,
    dyslip_untreated        = cvdmedst == 3,
    # `%in%` silently turns NA into FALSE, which would inflate the denominator.
    dyslip_any              = if_else(is.na(cvdmedst), NA, cvdmedst %in% 1:3),

    across(all_of(rep_cols))
  )

# Self-report is a left join; absence of a condition record means no report.
d <- as.data.table(d)
d <- merge(d, chol_cond[, .(pid, sr_current, sr_ever)], by = "pid", all.x = TRUE)
d[is.na(sr_current), sr_current := FALSE]
d[is.na(sr_ever),    sr_ever    := FALSE]

# ---------------------------------------------------------------------------
# 6. Outcome variants. These are the definitional choices the team has to make,
#    so all four are carried forward rather than resolved here.
# ---------------------------------------------------------------------------

d[, `:=`(
  # (A) the team's proposal, as written
  unrecognised_strict = chol_high & !sr_current,
  # (B) same, but people ever told also count as recognised
  unrecognised_ever   = chol_high & !sr_ever,
  # (C) medication-aware: abnormal lipids, on no lipid medication
  screening_target    = dyslip_untreated,
  # (D) medication- and testing-aware: abnormal lipids, no medication,
  #     and no cholesterol test in the last five years. `&` returns FALSE when
  #     one side is FALSE and the other NA, so the intersection is made explicit.
  never_screened_high = if_else(is.na(dyslip_untreated) | is.na(tested_5yr), NA,
                                dyslip_untreated & !tested_5yr)
)]

message("\n-- outcome variants (unweighted counts among biomedical adults) --")

# valid_n is the denominator with a determinate outcome; cases the positives.
n_and_k <- function(x, extra = NULL) {
  ok <- !is.na(x)
  if (!is.null(extra)) ok <- ok & !is.na(extra)
  c(valid_n = sum(ok), cases = sum(x[ok]))
}
rows <- list(
  "Measured high total cholesterol (CHOLNTR==2)" = n_and_k(d$chol_high),
  "(A) High + no current self-report"            = n_and_k(d$unrecognised_strict),
  "(B) High + never told at all"                 = n_and_k(d$unrecognised_ever),
  "Any dyslipidaemia (CVDMEDST 1-3, fasted)"     = n_and_k(d$dyslip_any),
  "(C) Untreated dyslipidaemia (CVDMEDST==3)"    = n_and_k(d$dyslip_untreated),
  "(D) Untreated + not tested in 5 years"        = n_and_k(d$never_screened_high, d$tested_5yr),
  "Low HDL (sex-specific)"                       = n_and_k(d$hdl_low),
  "High fasting LDL"                             = n_and_k(d$ldl_high)
)
outcome_tab <- tibble::tibble(
  outcome = names(rows),
  valid_n = vapply(rows, \(r) r[["valid_n"]], numeric(1)),
  cases   = vapply(rows, \(r) r[["cases"]],   numeric(1))
) |>
  mutate(pct = sprintf("%.1f%%", 100 * cases / valid_n))
print(as.data.frame(outcome_tab))
save_tab(outcome_tab, "10_outcome_variants")

message("\n-- predictor availability (compare with the team's table) --")
pred_tab <- tibble::tibble(
  predictor = c("Age band", "Sex", "BMI", "BMI category", "Waist circumference",
                "Waist category", "Smoking status", "Exercise level",
                "Systolic BP", "Diastolic BP", "Personal income decile",
                "Area SEIFA decile", "Cholesterol tested in last 5 yrs (45+)"),
  variable  = c("AGEB", "SEX", "BMISC", "BMICATHY", "PHDCMWBC",
                "PHDWCATM/F", "SMKSTAT", "EXLEVELN", "SYSTOL", "DIASTOL",
                "INCDECPN", "SF2SA1DN", "CHOL5YR"),
  usable_n  = c(sum(!is.na(d$age)), sum(!is.na(d$sex)), sum(!is.na(d$bmi)),
                sum(!is.na(d$bmi_class)), sum(!is.na(d$waist)),
                sum(!is.na(d$waist_class)), sum(!is.na(d$smoking)),
                sum(!is.na(d$pa_level)), sum(!is.na(d$sbp)), sum(!is.na(d$dbp)),
                sum(!is.na(d$income_decile)), sum(!is.na(d$seifa_decile)),
                sum(!is.na(d$tested_5yr)))
) |>
  mutate(missing = nrow(d) - usable_n,
         missing_pct = sprintf("%.1f%%", 100 * missing / nrow(d)))
print(as.data.frame(pred_tab))
save_tab(pred_tab, "10_predictor_availability")

fwrite(d, file.path(DERIVED, "nhs_chol.csv"))
message("\nwrote data/derived/nhs_chol.csv  (", nrow(d), " rows x ", ncol(d), " cols)")
