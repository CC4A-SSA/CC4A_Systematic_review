# What it does: Holds the project's folder layout in one place. Every other
#   script sources this file and then refers to the objects it defines, so no
#   path is ever written twice. Also creates the output folders on first use.
# Reads: nothing. Environment variable CC4A_OUT_DIR if it is set.
# Writes: creates the outputs/ folders if they do not exist.
# Flags: none. This file is sourced, not run.
#
# Sourced with:
#   root <- rprojroot::find_root(rprojroot::has_file("CC4A.Rproj"))
#   source(file.path(root, "R/00_shared/paths.R"))

# ---- repo root ---------------------------------------------------------

# Found from this file's own location, so it works from RStudio, from
# Rscript, and from a working directory anywhere inside the repo.
CC4A_ROOT <- rprojroot::find_root(rprojroot::has_file("CC4A.Rproj"))

# ---- top level folders -------------------------------------------------

DIR_R          <- file.path(CC4A_ROOT, "R")
DIR_CATALOGUES <- file.path(CC4A_ROOT, "catalogues")
DIR_DOCS       <- file.path(CC4A_ROOT, "docs")
DIR_SYNTHESIS  <- file.path(DIR_DOCS, "synthesis")

# Everything the pipeline produces. Git ignored and safe to delete, because
# the scripts regenerate it. Redirect it with CC4A_OUT_DIR if you want runs
# on a shared drive.
DIR_OUTPUTS <- if (nzchar(Sys.getenv("CC4A_OUT_DIR"))) {
  Sys.getenv("CC4A_OUT_DIR")
} else {
  file.path(CC4A_ROOT, "outputs")
}

# ---- output folders, one per step --------------------------------------

DIR_SEARCH     <- file.path(DIR_OUTPUTS, "01_search")
DIR_DEDUP      <- file.path(DIR_OUTPUTS, "02_dedup")
DIR_SCREEN     <- file.path(DIR_OUTPUTS, "03_screen")
DIR_FULLTEXT   <- file.path(DIR_OUTPUTS, "04_fulltext")
DIR_PDF        <- file.path(DIR_FULLTEXT, "pdf")
DIR_EXTRACT    <- file.path(DIR_OUTPUTS, "05_extract")
DIR_HARMONISE  <- file.path(DIR_OUTPUTS, "06_harmonise")
DIR_PUBLISH    <- file.path(DIR_OUTPUTS, "07_publish")
DIR_REVIEW     <- file.path(DIR_OUTPUTS, "review")
DIR_LOGS       <- file.path(DIR_OUTPUTS, "logs")

CC4A_DIRS <- c(
  DIR_OUTPUTS, DIR_SEARCH, DIR_DEDUP, DIR_SCREEN, DIR_FULLTEXT, DIR_PDF,
  DIR_EXTRACT, DIR_HARMONISE, DIR_PUBLISH, DIR_REVIEW, DIR_LOGS
)

# ---- files the scripts read and write ----------------------------------

# Step 1 search
FILE_SEARCH_RAW    <- file.path(DIR_CATALOGUES, "search_raw.csv")
FILE_SEARCH_LOG    <- file.path(DIR_SEARCH, "search_log.csv")

# Step 2 dedup
FILE_DEDUP_CLEAN   <- file.path(DIR_DEDUP, "records_deduped.csv")
FILE_DEDUP_REPORT  <- file.path(DIR_DEDUP, "duplicate_register.csv")

# Step 3 screen
FILE_SCREEN        <- file.path(DIR_SCREEN, "screen_scope.csv")
FILE_SCREEN_RULED  <- file.path(DIR_SCREEN, "screen_ruled.csv")
FILE_SCREEN_UNSURE <- file.path(DIR_REVIEW, "screen_unsure.csv")
FILE_SCREEN_OVERRIDES <- file.path(DIR_CATALOGUES, "screen_overrides.csv")

# Step 4 fetch
FILE_FETCH_INDEX   <- file.path(DIR_FULLTEXT, "fulltext_index.csv")

# Step 5 extract
FILE_EXTRACT_RAW   <- file.path(DIR_EXTRACT, "extracted_verbatim.csv")
FILE_EXTRACT_AUDIT <- file.path(DIR_EXTRACT, "verification_report.csv")

# Step 6 harmonise
FILE_HARMONISED    <- file.path(DIR_HARMONISE, "extracted_harmonised.csv")
FILE_VOCAB_CACHE   <- file.path(DIR_CATALOGUES, "vocab_decisions.csv")
FILE_VOCAB_PROPOSED <- file.path(DIR_REVIEW, "proposed_vocab_terms.csv")

# Step 7 publish
FILE_PARAMETER_DB  <- file.path(DIR_PUBLISH, "cc4a_parameters_latest.xlsx")
FILE_COST_REPORT   <- file.path(DIR_PUBLISH, "cost_report.csv")

# Controlled vocabularies and the keyword list
FILE_VOCAB_PRACTICES <- file.path(DIR_CATALOGUES, "vocab_practices.csv")
FILE_VOCAB_UNITS     <- file.path(DIR_CATALOGUES, "vocab_units.csv")
FILE_KEYWORDS        <- file.path(DIR_CATALOGUES, "keyword_list.R")

# The extraction schema, the one definition of every table and field, and
# the Excel template built from it by R/00_shared/build_template.R. Both are
# part of the protocol, so they live in docs/synthesis/ rather than here.
FILE_SCHEMA   <- file.path(DIR_SYNTHESIS, "extraction_schema.csv")
FILE_TEMPLATE <- file.path(DIR_SYNTHESIS, "extraction_template.xlsx")

# The hand checked gold set used to score the pipeline in step 7.
FILE_GOLD_SET <- file.path(DIR_CATALOGUES, "gold_set.csv")

# ---- scope of the review -----------------------------------------------

# Publication window applied by R/03_screen/screen_rules.R. Widening the
# review is a two number change here, followed by a rerun of the rules. No
# record is screened again by a model. The protocol admits 1990 onwards, and
# long term trials of any date (docs/synthesis/03, section 1.4), so the
# screening rules exempt stream 2 records from YEAR_MIN.
YEAR_MIN <- 1990
YEAR_MAX <- 2026

# Africa. Used to filter the OpenAlex result set in step 1 and checked again
# in the screening rules. ISO 3166-1 alpha-2, 54 member states plus Western
# Sahara.
AFRICA_ISO2 <- c(
  "DZ", "AO", "BJ", "BW", "BF", "BI", "CV", "CM", "CF", "TD", "KM", "CG",
  "CD", "CI", "DJ", "EG", "GQ", "ER", "SZ", "ET", "GA", "GM", "GH", "GN",
  "GW", "KE", "LS", "LR", "LY", "MG", "MW", "ML", "MR", "MU", "MA", "MZ",
  "NA", "NE", "NG", "RW", "ST", "SN", "SC", "SL", "SO", "ZA", "SS", "SD",
  "TZ", "TG", "TN", "UG", "EH", "ZM", "ZW"
)

# ---- make sure the output folders exist --------------------------------

invisible(lapply(CC4A_DIRS, dir.create, recursive = TRUE, showWarnings = FALSE))
