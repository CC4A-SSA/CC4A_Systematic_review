# What it does: Installs the R packages the pipeline needs. Run once after
#   cloning, and again when a new package is added to the list below.
# Reads: nothing.
# Writes: your R library.
# Flags: --check   list what is missing and install nothing
#
# Run with:
#   Rscript R/00_shared/install_packages.R
#   Rscript R/00_shared/install_packages.R --check

root <- rprojroot::find_root(rprojroot::has_file("CC4A.Rproj"))
source(file.path(root, "R/00_shared/paths.R"))

# Grouped by what they are for, so it is clear why each one is here.
PKGS <- c(
  # search and retrieval
  "httr2", "jsonlite", "curl", "fs",
  # full text
  "pdftools",
  # data handling
  "dplyr", "purrr", "tibble", "tidyr", "stringr", "readr", "glue",
  # duplicate detection
  "stringdist",
  # Excel output
  "openxlsx", "readxl", "zip",
  # model calls
  "ellmer",
  # console output and repo root
  "cli", "rprojroot"
)

# TODO: compare PKGS against rownames(installed.packages()), print what is
# missing, honour --check, install the rest from CRAN, then report the
# version of each one so a run can be reproduced.
stop("not implemented yet")
