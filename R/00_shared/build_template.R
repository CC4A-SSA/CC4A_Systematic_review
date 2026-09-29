# What it does: Builds the Excel extraction template from the schema CSV, so
#   the two can never drift. One sheet per table, in the order the CSV lists
#   them, headers styled by whether the field is required, the field's
#   description as a header comment, and a drop-down on every enum field.
# Reads: docs/synthesis/extraction_schema.csv
# Writes: docs/synthesis/extraction_template.xlsx (overwritten)
# Flags: --dry   list the tables and field counts, write nothing
#
# Run with:
#   Rscript R/00_shared/build_template.R --dry
#   Rscript R/00_shared/build_template.R
#
# Rerun after every change to the schema CSV. Change the schema in the CSV,
# never in the workbook: this script overwrites the workbook.

root <- rprojroot::find_root(rprojroot::has_file("CC4A.Rproj"))
source(file.path(root, "R/00_shared/paths.R"))

# Header fills, matching the template Pete's pack shipped with. Required
# fields are bold on orange; conditional on pale orange; optional on grey.
FILL_REQUIRED    <- "#F4B183"
FILL_CONDITIONAL <- "#FCE4D6"
FILL_OPTIONAL    <- "#EDEDED"

# Drop-downs cover this many data rows. Moving it only changes how far down
# the sheet the drop-downs reach.
N_ROWS <- 2000

# Enum options live on a hidden sheet, because Excel caps an inline option
# list at 255 characters and some enums are longer.
LISTS_SHEET <- "_lists"

README_LINES <- c(
  "Extraction template, Activity 2 evidence synthesis (INV-089367)",
  "One sheet per extraction table. Headers carry the field description as a comment; required fields are bold on orange, conditional on pale orange, optional on grey.",
  "Enum fields have drop-downs. The schema is defined in extraction_schema.csv and 02-extraction-schema.md; change it there, not here. This workbook is rebuilt from the CSV by R/00_shared/build_template.R.",
  "Every extracted number needs a row in 'quote'. The 'verification' sheet is written by the verifier, never by the extractor.",
  "Fields marked 'FILLED BY S5' are left empty at extraction.",
  "CORE fields (comment starts [CORE for pilots]) are the minimum required during the three pilots; other required fields are filled where the source reports them and become mandatory after the pilot review."
)

REQUIRED_LABEL <- c(R = "required", C = "conditional", O = "optional")

dry <- "--dry" %in% commandArgs(trailingOnly = TRUE)

schema <- read.csv(FILE_SCHEMA, colClasses = "character", encoding = "UTF-8",
                   na.strings = character())
tables <- unique(schema$table)

if (dry) {
  counts <- table(factor(schema$table, levels = tables))
  print(data.frame(table = names(counts), fields = as.integer(counts)),
        row.names = FALSE)
  cat(sum(counts), "fields in", length(tables), "tables; nothing written\n")
  quit(save = "no")
}

wb <- openxlsx::createWorkbook()

openxlsx::addWorksheet(wb, "README")
openxlsx::writeData(wb, "README", README_LINES, colNames = FALSE)
openxlsx::addStyle(wb, "README", openxlsx::createStyle(textDecoration = "bold",
                   fontSize = 13), rows = 1, cols = 1)
openxlsx::setColWidths(wb, "README", cols = 1, widths = 120)

# An enum has a | separated option list. "(as study)" and similar pointers
# name another field's list rather than giving one.
is_list_enum <- function(x) grepl("|", x, fixed = TRUE)

# Enum lists shared by reference ("(as study)") resolve to the study field of
# the same name.
resolve_options <- function(field, allowed) {
  if (is_list_enum(allowed)) return(strsplit(allowed, "|", fixed = TRUE)[[1]])
  ref <- sub("^\\(as ([a-z_]+)\\)$", "\\1", allowed)
  if (!identical(ref, allowed)) {
    hit <- schema$allowed_values_or_unit[schema$table == ref &
                                           schema$field == field]
    if (length(hit) == 1 && is_list_enum(hit)) {
      return(strsplit(hit, "|", fixed = TRUE)[[1]])
    }
  }
  NULL
}

# Drop-downs are collected while the table sheets are written, then added
# once the hidden list sheet exists. The list sheet is created last, so no
# sheet has to be reordered (openxlsx's worksheetOrder breaks comment links).
dropdowns <- list()

for (tab in tables) {
  fields <- schema[schema$table == tab, ]
  openxlsx::addWorksheet(wb, tab)
  openxlsx::writeData(wb, tab, as.data.frame(t(fields$field)),
                      colNames = FALSE)
  openxlsx::freezePane(wb, tab, firstRow = TRUE)

  for (i in seq_len(nrow(fields))) {
    f <- fields[i, ]
    fill <- switch(f$required, R = FILL_REQUIRED, C = FILL_CONDITIONAL,
                   FILL_OPTIONAL)
    openxlsx::addStyle(wb, tab, openxlsx::createStyle(
      fgFill = fill, textDecoration = if (f$required == "R") "bold" else NULL
    ), rows = 1, cols = i)

    core <- if (identical(f$core_for_pilots, "yes")) "[CORE for pilots] " else ""
    note <- paste0(
      core, "[", REQUIRED_LABEL[[f$required]], "] ", f$type, "\n",
      f$description, "\n",
      "Allowed/unit: ", f$allowed_values_or_unit, "\n",
      "Lands in: ", f$lands_in
    )
    openxlsx::writeComment(wb, tab, col = i, row = 1,
                           comment = openxlsx::createComment(note,
                             author = "schema", visible = FALSE,
                             width = 4, height = 6))

    options <- if (f$type == "enum") {
      resolve_options(f$field, f$allowed_values_or_unit)
    }
    if (length(options) > 0) {
      dropdowns[[length(dropdowns) + 1]] <- list(tab = tab, col = i,
                                                 options = options)
    }
  }
  openxlsx::setColWidths(wb, tab, cols = seq_len(nrow(fields)),
                         widths = pmax(13, nchar(fields$field) + 4))
}

openxlsx::addWorksheet(wb, LISTS_SHEET, visible = FALSE)
for (k in seq_along(dropdowns)) {
  d <- dropdowns[[k]]
  openxlsx::writeData(wb, LISTS_SHEET, d$options, startCol = k)
  col_letter <- openxlsx::int2col(k)
  openxlsx::dataValidation(
    wb, d$tab, cols = d$col, rows = 2:(N_ROWS + 1), type = "list",
    value = sprintf("'%s'!$%s$1:$%s$%d", LISTS_SHEET, col_letter, col_letter,
                    length(d$options)),
    allowBlank = TRUE, showErrorMsg = FALSE
  )
}

openxlsx::saveWorkbook(wb, FILE_TEMPLATE, overwrite = TRUE)

# Two openxlsx habits that Excel tolerates but openpyxl, and so
# pandas.read_excel, does not. It links every sheet to a drawing part it
# never writes: drop every relationship and content type entry that points at
# a part the archive does not hold (the sheets never use those links). And it
# names the comment font with <name val=>, where the spec says <rFont val=>.
tidy_openxlsx_output <- function(path) {
  dir <- tempfile("xlsx_")
  utils::unzip(path, exdir = dir)
  parts <- list.files(dir, recursive = TRUE, all.files = TRUE)
  has_part <- function(p) p %in% parts

  # A relationship target is relative to the folder that holds the _rels
  # folder, or absolute from the archive root when it starts with "/".
  resolve <- function(base, target) {
    if (startsWith(target, "/")) return(sub("^/", "", target))
    segs <- c(if (base != ".") strsplit(base, "/")[[1]],
              strsplit(target, "/")[[1]])
    out <- character()
    for (s in segs) {
      if (s == "..") out <- utils::head(out, -1)
      else if (s != "." && s != "") out <- c(out, s)
    }
    paste(out, collapse = "/")
  }

  for (rels in parts[grepl("_rels/[^/]+\\.rels$", parts)]) {
    xml <- readLines(file.path(dir, rels), warn = FALSE, encoding = "UTF-8")
    xml <- paste(xml, collapse = "\n")
    base <- dirname(dirname(rels))
    entries <- regmatches(xml, gregexpr("<Relationship [^>]*/>", xml))[[1]]
    for (e in entries) {
      if (grepl("TargetMode=\"External\"", e, fixed = TRUE)) next
      target <- sub('.*Target="([^"]+)".*', "\\1", e)
      if (!has_part(resolve(base, target))) xml <- sub(e, "", xml, fixed = TRUE)
    }
    writeLines(xml, file.path(dir, rels), useBytes = TRUE)
  }

  ct_path <- file.path(dir, "[Content_Types].xml")
  ct <- paste(readLines(ct_path, warn = FALSE, encoding = "UTF-8"),
              collapse = "\n")
  overrides <- regmatches(ct, gregexpr("<Override [^>]*/>", ct))[[1]]
  for (o in overrides) {
    part <- sub('.*PartName="/([^"]+)".*', "\\1", o)
    if (!has_part(part)) ct <- sub(o, "", ct, fixed = TRUE)
  }
  writeLines(ct, ct_path, useBytes = TRUE)

  for (cm in parts[grepl("^xl/comments[0-9]*[.]xml$", parts)]) {
    xml <- readLines(file.path(dir, cm), warn = FALSE, encoding = "UTF-8")
    writeLines(gsub("<name val=", "<rFont val=", xml, fixed = TRUE),
               file.path(dir, cm), useBytes = TRUE)
  }

  unlink(path)
  zip::zip(path, files = parts, root = dir, mode = "mirror")
  unlink(dir, recursive = TRUE)
}
tidy_openxlsx_output(FILE_TEMPLATE)
cat("wrote", FILE_TEMPLATE, "with", length(tables), "tables and",
    nrow(schema), "fields\n")
