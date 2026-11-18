# What it does: Lists the records included for full text, with the defined
#   practices each one studies and the outcome folder it goes in. The same
#   rules as the progress report: a person's QC decision overrides the
#   model's, and the model's includes that the practice check
#   (R/03_screen/classify_practices.R) excluded are dropped.
#   The outcome folder comes from what the screening model read in the
#   abstract (reports_adoption, reports_cost, reports_carbon_income = yes):
#   one outcome goes to its own folder, two or more to "Multiple outcomes",
#   none to "Outcome unclear". So each paper sits in one outcome folder per
#   practice.
# Reads: outputs/03_screen/screen_scope.csv
#        outputs/03_screen/record_practices.csv
#        outputs/03_screen/practice_check.csv
#        outputs/01_search/search_records_vs_wb2022.csv   the metadata
#        catalogues/vocab_practices.csv
# Writes: outputs/04_fulltext/included_records.csv   one row per record
# Flags: none
#
# Run with:
#   Rscript R/04_fetch/list_included.R

root <- rprojroot::find_root(rprojroot::has_file("CC4A.Rproj"))
source(file.path(root, "R/00_shared/paths.R"))
source(file.path(root, "R/00_shared/utils.R"))

# The outcome folders, keyed by the screening column that says the paper
# reports the outcome.
OUTCOME_FOLDERS <- c(reports_adoption = "Adoption",
                     reports_cost = "Costs, returns and incentives",
                     reports_carbon_income = "Carbon finance")
MULTIPLE_FOLDER <- "Multiple outcomes"
UNCLEAR_FOLDER <- "Outcome unclear"
NO_PRACTICE <- "none"

log_step("List the records included for full text")

screen <- read_csv_safe(FILE_SCREEN)
qc <- tolower(trimws(dplyr::coalesce(screen$qc_decision, "")))
qc <- ifelse(startsWith(qc, "inc"), "include", ifelse(startsWith(qc, "ex"), "exclude",
             ifelse(startsWith(qc, "uns"), "unsure", NA)))
checked <- !is.na(screen$qc_sample) & !is.na(qc)
final <- ifelse(checked, qc, screen$decision)

check <- read_csv_safe(FILE_PRACTICE_CHECK)
check_excluded <- check$record_id[startsWith(check$practice_decision, "exclude")]
# A person's include stands; the practice check applies to the model's.
keep <- final %in% "include" & (checked | !screen$record_id %in% check_excluded)
inc <- screen[keep, ]

# Practices: the synonym tags, with the practice check's answer replacing
# "none" for the records it read.
tags <- read_csv_safe(FILE_RECORD_PRACTICES)
check_tags <- tidyr::separate_rows(check[, c("record_id", "practices")], practices,
                                   sep = ";[[:space:]]*")
check_tags <- check_tags[!check_tags$practices %in% c(NO_PRACTICE, "unreadable"), ]
tags <- dplyr::bind_rows(
  tags[!(tags$record_id %in% check_tags$record_id & tags$practice_code == NO_PRACTICE),
       c("record_id", "practice_code")],
  dplyr::rename(check_tags, practice_code = practices)
)
vocab <- read_csv_safe(FILE_VOCAB_PRACTICES)
tags <- tags[tags$practice_code %in% c(vocab$practice_code, NO_PRACTICE), ]
practices <- tags |>
  dplyr::distinct() |>
  dplyr::filter(record_id %in% inc$record_id) |>
  dplyr::group_by(record_id) |>
  # A record with a defined practice drops its "none".
  dplyr::summarise(practices = paste(setdiff(sort(unique(practice_code)), NO_PRACTICE),
                                     collapse = "; "))
practices$practices[practices$practices == ""] <- NO_PRACTICE

yes <- sapply(names(OUTCOME_FOLDERS), function(col) inc[[col]] %in% "yes")
n_yes <- rowSums(yes)
inc$outcomes <- apply(yes, 1, function(r) paste(OUTCOME_FOLDERS[r], collapse = "; "))
inc$outcome_folder <- ifelse(n_yes == 0, UNCLEAR_FOLDER,
                             ifelse(n_yes > 1, MULTIPLE_FOLDER,
                                    OUTCOME_FOLDERS[max.col(yes, ties.method = "first")]))

meta <- read_csv_safe(FILE_SEARCH_MATCHED)[, c("record_id", "authors", "journal", "type",
                                                "is_oa", "oa_url")]
out <- inc[, c("record_id", "doi", "title", "abstract", "publication_year", "outcomes",
               "outcome_folder")] |>
  dplyr::left_join(practices, by = "record_id") |>
  dplyr::left_join(meta, by = "record_id") |>
  dplyr::mutate(practices = dplyr::coalesce(practices, NO_PRACTICE),
                doi = normalise_doi(doi), qc_checked = checked[keep])

write_csv_safe(out, FILE_INCLUDED)
log_msg(nrow(out), " included records, ", sum(!is.na(out$doi)), " with a DOI, ",
        sum(nzchar(dplyr::coalesce(out$oa_url, ""))), " with an open access link",
        level = "done")
print(table(out$outcome_folder))
