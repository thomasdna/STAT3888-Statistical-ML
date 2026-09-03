# Turn the ABS "Data Item List" workbooks into a tidy, searchable codebook.
#
# Each sheet lists a variable's SAS name in column 1, then one row per category
# in column 2 formatted as "01. Label". Column 5 holds the ABS definition.
# Output: data/derived/codebook_variables.csv  (one row per variable)
#         data/derived/codebook_levels.csv     (one row per category)

source("00_setup.R", chdir = TRUE)

ITEM_LISTS <- c(
  nhs = "AHSnhsBasicCURFdataItemList.xls",
  npa = "AHSnpaBasicCURFdataItemList.xls",
  inp = "AHSinpBasicCURFdataItemList-2.xls"
)

# Sheets that describe classifications rather than data items.
SKIP_SHEETS <- c("Contents", "Index")

parse_sheet <- function(path, sheet) {
  raw <- suppressMessages(
    read_excel(path, sheet = sheet, col_names = FALSE, .name_repair = "minimal")
  )
  if (nrow(raw) == 0 || ncol(raw) < 2) return(NULL)

  raw <- as.data.frame(lapply(raw, as.character), stringsAsFactors = FALSE)
  names(raw) <- paste0("c", seq_len(ncol(raw)))

  sas   <- str_squish(raw$c1)
  item  <- str_squish(raw$c2)
  popn  <- if (ncol(raw) >= 3) str_squish(raw$c3) else NA_character_
  defn  <- if (ncol(raw) >= 5) str_squish(raw$c5) else NA_character_

  # A variable block starts on a row where column 1 looks like a SAS name and
  # column 2 carries its human-readable description.
  is_var <- !is.na(sas) & str_detect(sas, "^[A-Z][A-Z0-9_]{1,15}$") & !is.na(item)

  if (!any(is_var)) return(NULL)

  block <- cumsum(is_var)
  block[block == 0] <- NA

  vars <- tibble(
    sheet       = sheet,
    variable    = sas[is_var],
    description = item[is_var],
    population  = popn[is_var],
    definition  = defn[is_var],
    block       = block[is_var]
  )

  # Category rows: blank column 1, column 2 like "01. Some label".
  cat_rows <- which(!is_var & is.na(sas) & !is.na(item) &
                      str_detect(item, "^-?[0-9]+\\.\\s*\\S"))
  levels <- tibble(
    block = block[cat_rows],
    code  = str_extract(item[cat_rows], "^-?[0-9]+"),
    label = str_squish(str_remove(item[cat_rows], "^-?[0-9]+\\.\\s*"))
  ) |>
    filter(!is.na(block)) |>
    inner_join(vars |> select(block, variable, sheet), by = "block")

  list(variables = vars |> select(-block),
       levels    = levels |> select(sheet, variable, code, label))
}

parse_workbook <- function(survey, file) {
  path <- file.path(RAW_DIR, file)
  stopifnot(file.exists(path))
  sheets <- setdiff(excel_sheets(path), SKIP_SHEETS)
  message("parsing ", file, " (", length(sheets), " sheets)")
  out <- map(sheets, \(s) parse_sheet(path, s)) |> compact()
  list(
    variables = map_dfr(out, "variables") |> mutate(survey = survey, .before = 1),
    levels    = map_dfr(out, "levels")    |> mutate(survey = survey, .before = 1)
  )
}

parsed <- imap(ITEM_LISTS, \(file, survey) parse_workbook(survey, file))

codebook_vars <- map_dfr(parsed, "variables") |>
  distinct(survey, variable, .keep_all = TRUE)

codebook_levels <- map_dfr(parsed, "levels") |>
  mutate(code_num = suppressWarnings(as.integer(code))) |>
  distinct(survey, variable, code, .keep_all = TRUE)

# The File-2.variables workbook maps every variable to the CSV it lives in.
file_map <- read_excel(file.path(RAW_DIR, "File-2.variables.xlsx"), sheet = "Variables") |>
  rename(survey_long = Survey, file = File, variable = Variable, description = Description) |>
  mutate(across(everything(), str_squish))

codebook <- file_map |>
  left_join(codebook_vars |> select(variable, sheet, population, definition),
            by = "variable", relationship = "many-to-many") |>
  distinct(file, variable, .keep_all = TRUE)

write_csv(codebook,        file.path(DERIVED, "codebook_variables.csv"))
write_csv(codebook_levels, file.path(DERIVED, "codebook_levels.csv"))

message("\nvariables in dictionary: ", nrow(codebook))
message("variables with parsed categories: ", n_distinct(codebook_levels$variable))
message("category rows: ", nrow(codebook_levels))

# ---- Convenience lookups (available after sourcing this script) --------------

#' Search the codebook by variable name or description.
look <- function(pattern, file = NULL) {
  cb <- read_csv(file.path(DERIVED, "codebook_variables.csv"), show_col_types = FALSE)
  if (!is.null(file)) cb <- cb |> filter(str_detect(.data$file, file))
  cb |>
    filter(str_detect(variable, regex(pattern, ignore_case = TRUE)) |
             str_detect(description, regex(pattern, ignore_case = TRUE))) |>
    select(file, variable, description)
}

#' Print the value labels for a variable.
levels_of <- function(var) {
  read_csv(file.path(DERIVED, "codebook_levels.csv"), show_col_types = FALSE) |>
    filter(variable == toupper(var)) |>
    select(survey, variable, code, label)
}
