# What it does: Cleans the 2022 World Bank NbS extraction for CC4A. Combines
#   every extractor's sheet into one, maps the practice columns (O to AE:
#   reduced_tillage ... Other_practices) to CC4A practices with the rules in
#   catalogues/map_wb2022_practices.csv, and keeps the rows that carry at least
#   one CC4A practice. The original workbook is not touched.
# Reads: data/wb_nbs_extraction_2022.xlsx      the 2022 extraction
#        catalogues/map_wb2022_practices.csv   the mapping rules
# Writes: data/wb_nbs_extraction_2022_cc4a.xlsx  the cleaned copy
# Flags: --dry   report the counts, write nothing
#
# Run with:
#   Rscript R/00_prep/clean_wb2022.R --dry
#   Rscript R/00_prep/clean_wb2022.R

root <- rprojroot::find_root(rprojroot::has_file("CC4A.Rproj"))
source(file.path(root, "R/00_shared/paths.R"))
source(file.path(root, "R/00_shared/utils.R"))

# The extractors' sheets. Every other sheet (Outcomes, Refs, Lists ...) is
# copied across unchanged.
EXTRACTOR_SHEETS <- c("Babra", "Brayden", "Elijah", "Gabi", "Lolita", "Namita",
                      "Pete", "Todd")

# Fields the rules' text: and product: conditions search, case insensitive.
TEXT_FIELDS <- c("Product", "Treatment_Name", "Other_practices")
PRODUCT_FIELD <- "Product"

# When a row maps through several rules, the weakest fit is reported.
FIT_ORDER <- c("direct", "partial", "needs_review")

# The two arm-name columns appear twice in each sheet: once with the
# practice description, once again in the outcome block. The second copy gets
# this suffix so the two can sit side by side.
DUPLICATE_SUFFIX <- "_outcome"

# ---- read -----------------------------------------------------------------

read_sheet <- function(sheet) {
  d <- readxl::read_excel(FILE_WB2022, sheet = sheet, col_types = "text",
                          .name_repair = "minimal")
  nm <- names(d)
  dup <- duplicated(nm) & nzchar(nm)
  nm[dup] <- paste0(nm[dup], DUPLICATE_SUFFIX)
  blank <- !nzchar(nm) | is.na(nm)
  nm[blank] <- paste0("unnamed_", which(blank))
  names(d) <- nm
  d <- d[, !(blank & vapply(d, function(x) all(is.na(x)), TRUE)), drop = FALSE]
  tibble::add_column(d, extractor = sheet, .before = 1)
}

combine_extractors <- function() {
  sheets <- lapply(EXTRACTOR_SHEETS, read_sheet)
  cols <- lapply(sheets, names)
  if (!all(vapply(cols, identical, TRUE, cols[[1]]))) {
    stop("The extractor sheets do not share one column layout")
  }
  d <- dplyr::bind_rows(sheets)
  d[!is.na(d$StudyID) & nzchar(trimws(d$StudyID)), ]
}

# ---- map ------------------------------------------------------------------

present <- function(x) !is.na(x) & nzchar(trimws(x))

#' TRUE where a rule's `when` holds. Parts joined with " & " must all hold:
#' always, flag:<column> (that practice column is filled), text:<regex>
#' (matches product, treatment or other practices), product:<regex>.
rule_holds <- function(when, d, text, product) {
  ok <- rep(TRUE, nrow(d))
  for (part in trimws(strsplit(when, " & ", fixed = TRUE)[[1]])) {
    kind <- sub(":.*$", "", part)
    arg <- sub("^[^:]*:", "", part)
    ok <- ok & switch(kind,
      always  = rep(TRUE, nrow(d)),
      flag    = present(d[[arg]]),
      text    = grepl(arg, text, ignore.case = TRUE, perl = TRUE),
      product = grepl(arg, product, ignore.case = TRUE, perl = TRUE),
      stop("unknown condition in map_wb2022_practices.csv: ", part)
    )
  }
  ok
}

#' For every practice column and every row where it is filled, the first rule
#' that holds. Returns one long table: row, wb column, practice, fit, note.
apply_rules <- function(d, rules) {
  text <- do.call(paste, c(lapply(TEXT_FIELDS, function(f) ifelse(is.na(d[[f]]), "", d[[f]])),
                           sep = " | "))
  product <- ifelse(is.na(d[[PRODUCT_FIELD]]), "", d[[PRODUCT_FIELD]])
  out <- list()
  for (col in unique(rules$wb_column)) {
    if (!col %in% names(d)) stop("practice column not found in the sheets: ", col)
    todo <- present(d[[col]])
    for (r in which(rules$wb_column == col)) {
      hit <- todo & rule_holds(rules$when[r], d, text, product)
      if (any(hit)) {
        out[[length(out) + 1]] <- tibble::tibble(
          row = which(hit), wb_column = col,
          cc4a_practice = rules$cc4a_practice[r], fit = rules$fit[r],
          note = rules$note[r]
        )
      }
      todo <- todo & !hit
    }
  }
  dplyr::bind_rows(out)
}

# ---- run ------------------------------------------------------------------

flags <- parse_flags()
log_step("Clean the 2022 World Bank NbS extraction for CC4A")

rules <- read_csv_safe(FILE_MAP_WB2022)
rules$cc4a_practice[is.na(rules$cc4a_practice)] <- ""
d <- combine_extractors()
d$wb_row <- seq_len(nrow(d))
log_msg(nrow(d), " extracted rows from ", length(unique(d$StudyID)), " studies, ",
        length(EXTRACTOR_SHEETS), " extractors")

mapped <- apply_rules(d, rules)
practices <- sort(unique(mapped$cc4a_practice[nzchar(mapped$cc4a_practice)]))

per_row <- mapped |>
  dplyr::group_by(row) |>
  dplyr::summarise(
    cc4a_practices = paste(sort(unique(cc4a_practice[nzchar(cc4a_practice)])), collapse = "; "),
    cc4a_fit = {
      f <- fit[nzchar(cc4a_practice)]
      if (length(f)) FIT_ORDER[max(match(f, FIT_ORDER))] else ""
    },
    cc4a_mapping = paste0(wb_column, " -> ", ifelse(nzchar(cc4a_practice), cc4a_practice, "(none)"),
                          " [", fit, "]", collapse = "; "),
    cc4a_review_note = paste(unique(note[fit %in% c("partial", "needs_review")]), collapse = "; "),
    .groups = "drop"
  )

d$cc4a_practices <- ""
d$cc4a_fit <- ""
d$cc4a_mapping <- ""
d$cc4a_review_note <- ""
d[per_row$row, c("cc4a_practices", "cc4a_fit", "cc4a_mapping", "cc4a_review_note")] <-
  per_row[, c("cc4a_practices", "cc4a_fit", "cc4a_mapping", "cc4a_review_note")]
for (p in practices) {
  d[[paste0("cc4a_", p)]] <- ifelse(grepl(paste0("(^|; )", p, "($|;)"), d$cc4a_practices), "yes", "")
}

kept <- d[nzchar(d$cc4a_practices), ]
dropped <- d[!nzchar(d$cc4a_practices), ]
dropped$drop_reason <- ifelse(nzchar(dropped$cc4a_mapping), dropped$cc4a_mapping,
                              "no practice column filled")

# Tables to read the result by.
by_practice <- dplyr::bind_rows(lapply(practices, function(p) {
  k <- kept[kept[[paste0("cc4a_", p)]] == "yes", ]
  tibble::tibble(cc4a_practice = p, rows = nrow(k), studies = dplyr::n_distinct(k$StudyID),
                 rows_direct = sum(k$cc4a_fit == "direct"),
                 rows_partial = sum(k$cc4a_fit == "partial"),
                 rows_needs_review = sum(k$cc4a_fit == "needs_review"))
}))
by_rule <- mapped |>
  dplyr::count(wb_column, cc4a_practice, fit, note, name = "rows") |>
  dplyr::arrange(match(wb_column, unique(rules$wb_column)), dplyr::desc(rows))
by_extractor <- d |>
  dplyr::group_by(extractor) |>
  dplyr::summarise(rows = dplyr::n(), rows_kept = sum(nzchar(cc4a_practices)),
                   studies = dplyr::n_distinct(StudyID),
                   studies_kept = dplyr::n_distinct(StudyID[nzchar(cc4a_practices)]),
                   .groups = "drop")
totals <- tibble::tibble(
  rows_in = nrow(d), studies_in = dplyr::n_distinct(d$StudyID),
  rows_kept = nrow(kept), studies_kept = dplyr::n_distinct(kept$StudyID),
  rows_dropped = nrow(dropped)
)
review <- kept[kept$cc4a_fit %in% c("partial", "needs_review"),
               c("extractor", "wb_row", "StudyID", "Title", "Country", "Product",
                 "Treatment_Name", "Other_practices", "cc4a_practices", "cc4a_fit",
                 "cc4a_mapping", "cc4a_review_note")]

print(as.data.frame(totals), row.names = FALSE)
print(as.data.frame(by_practice), row.names = FALSE)
if (isTRUE(flag(flags, "dry", FALSE))) {
  log_msg("dry run: nothing written", level = "done")
  quit(save = "no")
}

wb <- openxlsx::createWorkbook()
bold <- openxlsx::createStyle(textDecoration = "bold")
add <- function(name, x, freeze = TRUE) {
  openxlsx::addWorksheet(wb, name)
  openxlsx::writeData(wb, name, x, headerStyle = bold)
  if (freeze) openxlsx::freezePane(wb, name, firstRow = TRUE)
}
readme <- data.frame(about = c(
  "The 2022 World Bank NbS extraction, cleaned for CC4A. The original workbook is unchanged.",
  "extracted_cc4a: every extractor's rows in one sheet (column 'extractor'), kept where at least one practice column maps to a CC4A practice.",
  "Mapping rules: practice_map (from catalogues/map_wb2022_practices.csv). cc4a_practices lists the CC4A practices per row; cc4a_<practice> columns are 'yes' per practice for filtering.",
  "cc4a_fit is the weakest fit among the row's mappings: direct, partial or needs_review. Partial and needs_review rows are listed in to_review with the reason.",
  "cc4a_mapping shows how each filled practice column was mapped. wb_row numbers the rows of the combined, unfiltered data.",
  "Treatment_Name_outcome and Control_Name_outcome are the second copies of those columns in the original sheets (the outcome block).",
  "dropped_rows: rows with no CC4A practice, and why. The original reference sheets (Outcomes, Refs, Lists ...) follow unchanged.",
  paste("Built", format(Sys.time(), "%Y-%m-%d %H:%M"), "by R/00_prep/clean_wb2022.R.")
))
add("README", readme, freeze = FALSE)
add("extracted_cc4a", kept)
add("summary_practice", by_practice)
add("summary_extractor", by_extractor)
add("summary_mapping", by_rule)
add("totals", totals)
add("to_review", review)
add("practice_map", rules)
add("dropped_rows", dropped[, c("extractor", "wb_row", "StudyID", "Title", "Country",
                                "Product", "Treatment_Name", "Other_practices", "drop_reason")])

for (sheet in setdiff(readxl::excel_sheets(FILE_WB2022), EXTRACTOR_SHEETS)) {
  x <- readxl::read_excel(FILE_WB2022, sheet = sheet, col_types = "text",
                          col_names = FALSE, .name_repair = "minimal")
  openxlsx::addWorksheet(wb, substr(paste0("orig_", trimws(sheet)), 1, 31))
  openxlsx::writeData(wb, substr(paste0("orig_", trimws(sheet)), 1, 31), x, colNames = FALSE)
}

openxlsx::saveWorkbook(wb, FILE_WB2022_CC4A, overwrite = TRUE)
log_msg(nrow(kept), " rows from ", totals$studies_kept, " studies kept; written to ",
        FILE_WB2022_CC4A, level = "done")
