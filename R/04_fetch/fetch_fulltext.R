# What it does: Gets the free full text of every included record. Tries the
#   open access locations Unpaywall gives for the DOI, then the OpenAlex open
#   access URL, then the DOI itself, then the PDF link the publisher's page
#   declares (citation_pdf_url). Every downloaded file is checked before it
#   is kept: it has to be a PDF and it has to hold readable text. What is
#   left is for Zotero's Find Available PDF (with library access) and then a
#   person: see R/04_fetch/zotero_upload.R.
# Reads: outputs/04_fulltext/included_records.csv   by R/04_fetch/list_included.R
# Writes: outputs/04_fulltext/pdf/<record_id>.pdf
#         outputs/04_fulltext/fulltext_index.csv  one row per record, with
#           the file, the source that worked, or the reason none did
# Flags: --limit=   fetch this many, for a test run
#        --retry    try again for the records that failed last time
#        --dry      count what would be fetched, request nothing
#
# Run with:
#   Rscript R/04_fetch/fetch_fulltext.R --dry
#   Rscript R/04_fetch/fetch_fulltext.R --limit=20
#   Rscript R/04_fetch/fetch_fulltext.R
# Picks up where it left off: records already in the index are skipped.

root <- rprojroot::find_root(rprojroot::has_file("CC4A.Rproj"))
source(file.path(root, "R/00_shared/paths.R"))
source(file.path(root, "R/00_shared/utils.R"))
readRenviron(file.path(root, ".Renviron"))

UNPAYWALL_BASE <- "https://api.unpaywall.org/v2/"

# Records handled together: their lookups and downloads run in parallel,
# then the index is written, so a stopped run loses at most one batch.
BATCH_SIZE <- 20
MAX_ACTIVE <- 10
DOWNLOAD_TIMEOUT <- 60
# A file with less text than this is a scan or a cover page, not a paper.
MIN_TEXT_CHARS <- 1000
MIN_PAGES <- 2
# Candidate URLs tried per record, at most.
MAX_CANDIDATES <- 6

flags <- parse_flags()
email <- Sys.getenv("UNPAYWALL_EMAIL")
if (!nzchar(email)) stop("Set UNPAYWALL_EMAIL in .Renviron: Unpaywall needs it.", call. = FALSE)

#' Requests one record's candidates are tried with, in parallel per round.
download_request <- function(url) {
  polite_request(url, max_tries = 2) |>
    httr2::req_timeout(DOWNLOAD_TIMEOUT) |>
    httr2::req_options(followlocation = TRUE)
}

#' Why a downloaded file is not a usable PDF, or "" when it is.
pdf_problem <- function(path) {
  if (!file.exists(path) || file.size(path) < 1000) return("download_failed")
  con <- file(path, "rb")
  magic <- readBin(con, "raw", 1024)
  close(con)
  if (!length(grepRaw("%PDF", magic, fixed = TRUE))) return("not_a_pdf")
  info <- tryCatch(pdftools::pdf_info(path), error = function(e) NULL)
  if (is.null(info)) return("not_a_pdf")
  if (info$pages < MIN_PAGES) return("too_short")
  text <- tryCatch(pdftools::pdf_text(path), error = function(e) "")
  if (sum(nchar(text)) < MIN_TEXT_CHARS) return("scanned_no_text")
  ""
}

#' TRUE for each URL curl can parse. A source sometimes carries a malformed
#' one, which would stop the run.
valid_url <- function(urls) {
  vapply(urls, function(u) {
    !is.na(u) && nzchar(u) &&
      !is.null(tryCatch(curl::curl_parse_url(u), error = function(e) NULL))
  }, TRUE, USE.NAMES = FALSE)
}

#' The PDF link a publisher page declares, or NA.
declared_pdf <- function(resp) {
  if (!inherits(resp, "httr2_response") || httr2::resp_status(resp) >= 400) return(NA)
  type <- httr2::resp_header(resp, "Content-Type", "")
  if (!grepl("html", type)) return(NA)
  html <- tryCatch(xml2::read_html(httr2::resp_body_string(resp)), error = function(e) NULL)
  if (is.null(html)) return(NA)
  link <- xml2::xml_attr(xml2::xml_find_first(html, "//meta[@name='citation_pdf_url']"),
                         "content")
  if (is.na(link)) return(NA)
  xml2::url_absolute(link, httr2::resp_url(resp))
}

#' Unpaywall's PDF locations for each DOI, best first. NA DOIs give none.
unpaywall_urls <- function(dois) {
  has <- !is.na(dois)
  out <- vector("list", length(dois))
  if (!any(has)) return(out)
  reqs <- lapply(dois[has], function(d) {
    polite_request(paste0(UNPAYWALL_BASE, utils::URLencode(d, reserved = TRUE)),
                   email = email) |>
      httr2::req_timeout(30)
  })
  resps <- httr2::req_perform_parallel(reqs, on_error = "continue", progress = FALSE,
                                       max_active = MAX_ACTIVE)
  out[has] <- lapply(resps, function(r) {
    if (!inherits(r, "httr2_response") || httr2::resp_status(r) >= 400) return(character())
    b <- tryCatch(httr2::resp_body_json(r), error = function(e) list())
    locs <- c(list(b$best_oa_location), b$oa_locations)
    urls <- unlist(lapply(locs, function(l) l$url_for_pdf))
    unique(urls[nzchar(urls)])
  })
  out
}

log_step("Fetch the free full texts of the included records")

todo <- read_csv_safe(FILE_INCLUDED)
if (!nrow(todo)) stop("Run R/04_fetch/list_included.R first.", call. = FALSE)
index <- read_csv_safe(FILE_FETCH_INDEX)
if (nrow(index)) {
  redo <- if (isTRUE(flag(flags, "retry", FALSE))) index$record_id[index$status != "ok"] else
    character()
  todo <- todo[!todo$record_id %in% setdiff(index$record_id, redo), ]
  index <- index[!index$record_id %in% redo, ]
  write_csv_safe(index, FILE_FETCH_INDEX)
}
limit <- flag(flags, "limit", NULL)
if (!is.null(limit)) todo <- utils::head(todo, as.integer(limit))
log_msg(nrow(todo), " records to fetch, ", sum(!is.na(todo$doi)), " with a DOI")
if (isTRUE(flag(flags, "dry", FALSE))) quit(save = "no")

tmp_dir <- file.path(DIR_FULLTEXT, "tmp")
dir.create(tmp_dir, showWarnings = FALSE)
n_ok <- 0
for (b in split(seq_len(nrow(todo)), ceiling(seq_len(nrow(todo)) / BATCH_SIZE))) {
  batch <- todo[b, ]
  up <- unpaywall_urls(batch$doi)
  # Candidate URLs per record, in order, with the source each came from.
  cands <- lapply(seq_len(nrow(batch)), function(i) {
    urls <- c(up[[i]], batch$oa_url[i],
              if (!is.na(batch$doi[i])) paste0("https://doi.org/", batch$doi[i]))
    src <- c(rep("unpaywall", length(up[[i]])), "openalex_oa", if (!is.na(batch$doi[i])) "doi")
    ok <- valid_url(urls) & !duplicated(urls)
    utils::head(data.frame(url = urls[ok], source = src[ok]), MAX_CANDIDATES)
  })
  result <- data.frame(record_id = batch$record_id, status = "failed", source = NA,
                       url = NA, pages = NA,
                       reason = ifelse(lengths(lapply(cands, `[[`, "url")) == 0,
                                       ifelse(is.na(batch$doi), "no_doi", "no_oa_location"),
                                       "no_readable_pdf"))
  # Round k tries each unfinished record's k-th candidate. A publisher page
  # that is HTML can declare its PDF; that link is added to the record's
  # candidates for the next round.
  round <- 1
  while (TRUE) {
    pending <- which(result$status != "ok" & vapply(cands, nrow, 1L) >= round)
    if (!length(pending) || round > MAX_CANDIDATES) break
    urls <- vapply(pending, function(i) cands[[i]]$url[round], "")
    paths <- file.path(tmp_dir, paste0(result$record_id[pending], "_", round, ".bin"))
    resps <- httr2::req_perform_parallel(lapply(urls, download_request), paths = paths,
                                         on_error = "continue", progress = FALSE,
                                         max_active = MAX_ACTIVE)
    for (j in seq_along(pending)) {
      i <- pending[j]
      problem <- pdf_problem(paths[j])
      if (problem == "") {
        dest <- file.path(DIR_PDF, paste0(result$record_id[i], ".pdf"))
        file.copy(paths[j], dest, overwrite = TRUE)
        result$status[i] <- "ok"
        result$source[i] <- cands[[i]]$source[round]
        result$url[i] <- urls[j]
        result$pages[i] <- pdftools::pdf_info(dest)$pages
        result$reason[i] <- NA
      } else {
        result$reason[i] <- problem
        if (problem == "not_a_pdf" && file.exists(paths[j])) {
          r <- resps[[j]]
          if (inherits(r, "httr2_response")) {
            r$body <- readBin(paths[j], "raw", file.size(paths[j]))
            link <- declared_pdf(r)
            if (valid_url(link) && !link %in% cands[[i]]$url) {
              cands[[i]] <- rbind(cands[[i]], data.frame(url = link, source = "landing_page"))
            }
          }
        }
      }
      unlink(paths[j])
    }
    round <- round + 1
  }
  result$fetched_on <- as.character(Sys.Date())
  write_csv_safe(result, FILE_FETCH_INDEX, append = TRUE)
  n_ok <- n_ok + sum(result$status == "ok")
  log_msg(sprintf("%d/%d done, %d PDFs", max(b), nrow(todo), n_ok))
}
unlink(tmp_dir, recursive = TRUE)

index <- read_csv_safe(FILE_FETCH_INDEX)
log_msg(sprintf("%d of %d included records have a PDF", sum(index$status == "ok"),
                nrow(read_csv_safe(FILE_INCLUDED))), level = "done")
print(table(index$source[index$status == "ok"]))
print(table(index$reason[index$status != "ok"]))
