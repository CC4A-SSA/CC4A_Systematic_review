# What it does: Renders the interactive explorer of the 2022 World Bank NbS
#   extraction (R/00_prep/explore_wb2022.Rmd) to one self-contained HTML file
#   that opens in any browser. Finds pandoc in RStudio or Quarto when R
#   cannot see it on its own.
# Reads: R/00_prep/explore_wb2022.Rmd
#        data/wb_nbs_extraction_2022_cc4a.xlsx (through the Rmd)
# Writes: docs/reports/wb2022_explorer.html
# Flags: none
#
# Run with:
#   Rscript R/00_prep/render_wb2022_explorer.R
# Or open the Rmd in RStudio and press Knit (the HTML then lands next to it).

root <- rprojroot::find_root(rprojroot::has_file("CC4A.Rproj"))
source(file.path(root, "R/00_shared/paths.R"))

# Places pandoc is commonly installed alongside RStudio or Quarto on Windows,
# tried in order when rmarkdown does not find it.
PANDOC_CANDIDATES <- c(
  file.path(dirname(Sys.which("quarto")), "tools"),
  file.path(Sys.getenv("LOCALAPPDATA"), "Programs", "Quarto", "bin", "tools"),
  "C:/Program Files/Quarto/bin/tools",
  "C:/Program Files/RStudio/resources/app/bin/quarto/bin/tools",
  "C:/Program Files/RStudio/bin/quarto/bin/tools"
)

if (!rmarkdown::pandoc_available()) {
  found <- PANDOC_CANDIDATES[file.exists(file.path(PANDOC_CANDIDATES, "pandoc.exe")) |
                               file.exists(file.path(PANDOC_CANDIDATES, "pandoc"))]
  if (!length(found)) {
    stop("pandoc not found. Install Quarto or RStudio, or knit the Rmd from RStudio.")
  }
  Sys.setenv(RSTUDIO_PANDOC = found[1])
}

dir.create(DIR_REPORTS, recursive = TRUE, showWarnings = FALSE)
rmarkdown::render(
  FILE_WB2022_EXPLORER_RMD,
  output_file = basename(FILE_WB2022_EXPLORER_HTML),
  output_dir = DIR_REPORTS,
  intermediates_dir = tempdir(),
  knit_root_dir = root,
  quiet = TRUE
)
message("Written: ", FILE_WB2022_EXPLORER_HTML)
