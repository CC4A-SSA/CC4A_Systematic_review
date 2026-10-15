# What it does: Draws a random sample of screened records for a person to
#   check, the same number from each decision (include, unsure, exclude), so
#   the check covers what the model keeps and what it drops. By default the
#   sheet is blind: the model's decisions are written to a separate key file,
#   so the person's call is not steered by them. With --compare it reads the
#   person's filled-in sheet back and reports agreement.
# Reads: outputs/03_screen/screen_scope.csv           the model's decisions
#        outputs/review/screen_qc_sample.csv          with --compare: the filled sheet
# Writes: outputs/review/screen_qc_sample.csv         the sheet to fill in
#         outputs/03_screen/screen_qc_key.csv         the model's decisions for the sample
# Flags: --n=               records per decision (default N_PER_DECISION)
#        --show-decisions   put the model's decision and reason in the sheet
#        --compare          compare a filled sheet with the model's decisions
#
# Run with:
#   Rscript R/03_screen/qc_sample.R
#   Rscript R/03_screen/qc_sample.R --compare

root <- rprojroot::find_root(rprojroot::has_file("CC4A.Rproj"))
source(file.path(root, "R/00_shared/paths.R"))
source(file.path(root, "R/00_shared/utils.R"))

N_PER_DECISION <- 50
QC_SEED <- 2026

flags <- parse_flags()
log_step("Screening QC sample")

if (isTRUE(flag(flags, "compare", FALSE))) {
  sheet <- read_csv_safe(FILE_SCREEN_QC_SAMPLE)
  key <- read_csv_safe(FILE_SCREEN_QC_KEY)
  d <- dplyr::inner_join(sheet[, c("record_id", "your_decision")], key, by = "record_id")
  d$your_decision <- tolower(trimws(d$your_decision))
  d <- d[d$your_decision %in% c("include", "exclude", "unsure"), ]
  if (!nrow(d)) stop("No decisions found in ", FILE_SCREEN_QC_SAMPLE,
                     ": fill your_decision with include, exclude or unsure")
  print(table(model = d$decision, you = d$your_decision))
  agree <- mean(d$decision == d$your_decision)
  tab <- table(factor(d$decision, levels = c("include", "unsure", "exclude")),
               factor(d$your_decision, levels = c("include", "unsure", "exclude")))
  pe <- sum(rowSums(tab) * colSums(tab)) / sum(tab)^2
  kappa <- (agree - pe) / (1 - pe)
  kept_by_you <- d$your_decision != "exclude"
  cat(sprintf("\n%d records checked. Agreement %.0f%%, Cohen's kappa %.2f (protocol target 0.7)\n",
              nrow(d), 100 * agree, kappa))
  cat(sprintf("Of the records you would keep, the model kept %.0f%% (recall)\n",
              100 * mean(d$decision[kept_by_you] != "exclude")))
  cat(sprintf("Of the records the model included, you would keep %.0f%%\n",
              100 * mean(kept_by_you[d$decision == "include"])))
  quit(save = "no")
}

screened <- read_csv_safe(FILE_SCREEN)
if (!nrow(screened)) stop("No screening results yet in ", FILE_SCREEN)
records <- read_csv_safe(FILE_SEARCH_MATCHED)[, c("record_id", "abstract")]
n <- as.integer(flag(flags, "n", N_PER_DECISION))

set.seed(QC_SEED)
pick <- screened |>
  dplyr::group_by(decision) |>
  dplyr::slice_sample(n = n) |>
  dplyr::ungroup() |>
  dplyr::slice_sample(prop = 1) |>
  dplyr::left_join(records, by = "record_id")

sheet <- dplyr::transmute(pick, record_id, title, abstract, your_decision = "", your_note = "")
if (isTRUE(flag(flags, "show-decisions", FALSE))) {
  sheet$model_decision <- pick$decision
  sheet$model_reason <- pick$reason
}
write_csv_safe(sheet, FILE_SCREEN_QC_SAMPLE)
write_csv_safe(pick[, c("record_id", "decision", "decision_rule", "verdict", "reason",
                        "in_africa", "practices", "practice_tested", "reports_cost",
                        "reports_adoption", "reports_carbon_income", "study_type")],
               FILE_SCREEN_QC_KEY)
log_msg(nrow(sheet), " records (", paste(names(table(pick$decision)), table(pick$decision),
                                         collapse = ", "), ") written to ",
        FILE_SCREEN_QC_SAMPLE, level = "done")
log_msg("fill your_decision with include, exclude or unsure, then run with --compare")
