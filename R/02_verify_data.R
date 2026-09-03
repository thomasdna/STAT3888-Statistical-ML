# Data integrity checks before any analysis.
#
# 1. Every CSV listed in the ABS documentation is present and has the expected
#    number of records and variables.
# 2. Record identifiers are unique at their stated level.
# 3. The NNPAS levels (person / biomedical / food / supplement / ADG) link on
#    ABSPID without loss.
# 4. ABS sentinel codes are quantified for the variables we intend to use.
#
# Output: outputs/tables/verify_*.csv and a printed report.

source("00_setup.R", chdir = TRUE)

report <- function(...) cat(..., "\n", sep = "")
rule   <- function(title) cat("\n", strrep("-", 72), "\n", title, "\n", strrep("-", 72), "\n", sep = "")

# ---- 1. File inventory -------------------------------------------------------

rule("1. FILE INVENTORY")

expected <- read_excel(file.path(RAW_DIR, "File-2.variables.xlsx"), sheet = "Files") |>
  select(survey = 1, file = 2, exp_records = 3, exp_variables = 4) |>
  mutate(file = str_squish(str_remove(file, "-biomedical")))

actual <- tibble(path = list.files(CSV_DIR, pattern = "\\.csv$", full.names = TRUE)) |>
  mutate(
    file = str_remove(basename(path), "\\.csv$"),
    obs_records   = map_int(path, \(p) nrow(fread(p, select = 1L, showProgress = FALSE))),
    obs_variables = map_int(path, \(p) ncol(fread(p, nrows = 1, showProgress = FALSE)))
  )

inventory <- expected |>
  full_join(actual |> select(-path), by = "file") |>
  mutate(
    present        = !is.na(obs_records),
    records_match  = obs_records == exp_records,
    # Files exported with a row-name column carry one extra variable.
    variables_match = obs_variables %in% c(exp_variables, exp_variables + 1L)
  ) |>
  arrange(survey, file)

print(as.data.frame(inventory |>
  select(file, exp_records, obs_records, exp_variables, obs_variables,
         present, records_match, variables_match)))

report("\nfiles expected: ", nrow(expected),
       " | present: ", sum(inventory$present, na.rm = TRUE),
       " | record counts matching: ", sum(inventory$records_match, na.rm = TRUE),
       " | variable counts matching: ", sum(inventory$variables_match, na.rm = TRUE))
save_tab(inventory, "verify_file_inventory")

# ---- 2 & 3. NNPAS key uniqueness and linkage --------------------------------

rule("2. NNPAS KEY UNIQUENESS")

npa_person <- fread(file.path(CSV_DIR, "AHSnpa11bp.csv"), showProgress = FALSE)
npa_biomed <- fread(file.path(CSV_DIR, "AHSnpa11bb.csv"), showProgress = FALSE)
npa_food   <- fread(file.path(CSV_DIR, "AHSnpa11bf.csv"),
                    select = c("ABSHID", "ABSPID", "ABSFID", "DAYNUM", "ENERGYWF"),
                    showProgress = FALSE)
npa_supp   <- fread(file.path(CSV_DIR, "AHSnpa11bs.csv"),
                    select = c("ABSPID", "ABSSID", "DAYNUM"), showProgress = FALSE)
npa_adg    <- fread(file.path(CSV_DIR, "AHSnpa11ba.csv"),
                    select = c("ABSPID", "ABSLFID", "DAYNUM", "ADGSRV"), showProgress = FALSE)

keys <- tribble(
  ~level,        ~rows,               ~unique_key,
  "person",      nrow(npa_person),    uniqueN(npa_person$ABSPID),
  "biomedical",  nrow(npa_biomed),    uniqueN(npa_biomed$ABSPID),
  "food",        nrow(npa_food),      uniqueN(npa_food[, .(ABSPID, ABSFID, DAYNUM)]),
  "supplement",  nrow(npa_supp),      uniqueN(npa_supp[, .(ABSPID, ABSSID, DAYNUM)]),
  "ADG summary", nrow(npa_adg),       uniqueN(npa_adg[, .(ABSPID, ABSLFID, DAYNUM)])
) |>
  mutate(key_is_unique = rows == unique_key)

print(as.data.frame(keys))

rule("3. LINKAGE TO THE PERSON FILE (ABSPID)")

persons <- npa_person$ABSPID
linkage <- tibble(
  level = c("biomedical", "food", "supplement", "ADG summary"),
  persons_in_level = c(uniqueN(npa_biomed$ABSPID), uniqueN(npa_food$ABSPID),
                       uniqueN(npa_supp$ABSPID), uniqueN(npa_adg$ABSPID)),
  matched_to_person = c(
    length(intersect(npa_biomed$ABSPID, persons)),
    length(intersect(npa_food$ABSPID, persons)),
    length(intersect(npa_supp$ABSPID, persons)),
    length(intersect(npa_adg$ABSPID, persons))
  )
) |>
  mutate(orphans = persons_in_level - matched_to_person,
         coverage_of_persons = matched_to_person / length(persons))

print(as.data.frame(linkage))
save_tab(linkage, "verify_linkage")

report("\npersons in the NNPAS person file: ", length(persons))
report("day-1 food records present for: ", uniqueN(npa_food[DAYNUM == 1]$ABSPID), " persons")
report("day-2 food records present for: ", uniqueN(npa_food[DAYNUM == 2]$ABSPID), " persons")

# Cross-check the person file's own day-1 energy total against the food file.
food_kj <- npa_food[DAYNUM == 1, .(food_kj = sum(ENERGYWF)), by = ABSPID]
check <- merge(food_kj, npa_person[, .(ABSPID, ENERGYF1)], by = "ABSPID")
check[, diff := food_kj - ENERGYF1]

rule("3b. CONSISTENCY: food-file day-1 energy vs person-file ENERGYF1")
report("persons compared: ", nrow(check))
report("max absolute discrepancy (kJ): ", round(max(abs(check$diff)), 2))
report("correlation: ", format(cor(check$food_kj, check$ENERGYF1), digits = 10))

# ---- 4. Sentinel codes in the variables we plan to use ----------------------

rule("4. ABS SENTINEL CODES IN KEY VARIABLES")

sentinels <- tribble(
  ~variable,  ~codes,             ~note,
  "BMISC",    c(0, 98, 99),       "BMI: not applicable / not measured / not known",
  "PHDKGWBC", c(0, 998, 999),     "measured weight",
  "PHDCMHBC", c(0, 998, 999),     "measured height",
  "PHDCMWBC", c(0, 998, 999),     "measured waist",
  "EXLEVELN", c(0, 8),            "physical activity level",
  "SMKSTAT",  c(0),               "smoker status",
  "SF2SA1QN", c(),                "SEIFA quintile",
  "ADTOTSE",  c(9996, 9999),      "sitting time (mins/week); 9996 = aged under 18",
  "SLPTIME",  c(9998, 9999),      "sleep duration (mins)",
  "FDSECQ1",  c(8),               "ran out of food",
  "CHOLRESB", c(97, 98),          "total cholesterol band",
  "HDLCHREB", c(7, 8),            "HDL band (single-digit sentinels)",
  "LDLRESB",  c(97, 98),          "LDL band",
  "TRIGRESB", c(97, 98),          "triglycerides band",
  "GLUCFREB", c(97, 98),          "fasting glucose band",
  "HBA1PREB", c(7, 8),            "HbA1c band (single-digit sentinels)"
)

pool <- merge(npa_person, npa_biomed[, !c("ABSHID", "ABSLFID"), with = FALSE], by = "ABSPID")

sentinel_summary <- sentinels |>
  filter(variable %in% names(pool)) |>
  rowwise() |>
  mutate(
    n            = nrow(pool),
    n_sentinel   = sum(pool[[variable]] %in% codes),
    pct_sentinel = round(100 * n_sentinel / n, 1),
    n_usable     = n - n_sentinel
  ) |>
  ungroup() |>
  select(variable, note, n, n_sentinel, pct_sentinel, n_usable)

print(as.data.frame(sentinel_summary))
save_tab(sentinel_summary, "verify_sentinel_codes")

rule("VERDICT")
ok <- all(inventory$present, na.rm = TRUE) &&
  all(inventory$records_match, na.rm = TRUE) &&
  all(keys$key_is_unique) &&
  all(linkage$orphans == 0)
report(if (ok) "PASS - all files present, keys unique, levels link without orphans."
       else "CHECK - see the tables above for the failing rows.")
