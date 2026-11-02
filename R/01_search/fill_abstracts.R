# What it does: Finds abstracts for the searched records that have none
#   (OpenAlex holds no abstract for them, nor does the 2022 Refs sheet), so
#   they can be screened on more than their title. Free sources only, tried in
#   order, each only for the records still missing one:
#     europepmc         Europe PMC by DOI (indexes much of the agricultural
#                       literature, through Agricola)
#     semantic_scholar  Semantic Scholar by DOI, 500 per request
#     crossref          Crossref by DOI (publishers that deposit abstracts)
#     landing_page      the publisher's page the DOI resolves to, from its
#                       citation_abstract or description tags; Elsevier is
#                       skipped, because it refuses automated requests
#     title_match       records with no DOI: Europe PMC, then Semantic
#                       Scholar, by title, kept only when the titles match
#                       exactly once normalised
#   Every lookup is recorded, so a second run tries only what is left.
# Reads: outputs/01_search/search_records_vs_wb2022.csv
#        outputs/01_search/abstract_lookup.csv        lookups already tried
# Writes: outputs/01_search/abstract_lookup.csv       one row per record and
#                                                     source tried: found, none
#                                                     or error, and the abstract
#         outputs/01_search/search_records_vs_wb2022.csv  abstract and
#                                                     abstract_source filled
# Flags: --source=   try one source only (one of SOURCES)
#        --limit=    try at most this many records per source, for a test
#        --retry     try again lookups that failed with an error (a lookup
#                    that found nothing is not tried again)
#
# Run with:
#   Rscript R/01_search/fill_abstracts.R --limit=50
#   Rscript R/01_search/fill_abstracts.R
# Then screen the records that now have an abstract:
#   Rscript R/03_screen/screen_scope.R --refresh-filled

root <- rprojroot::find_root(rprojroot::has_file("CC4A.Rproj"))
source(file.path(root, "R/00_shared/paths.R"))
source(file.path(root, "R/00_shared/utils.R"))
readRenviron(file.path(root, ".Renviron"))

SOURCES <- c("europepmc", "semantic_scholar", "crossref", "landing_page", "title_match")

# Shorter than this is a snippet or a site blurb, not an abstract.
MIN_ABSTRACT_CHARS <- 150

# Requests in flight at once, and records per chunk between saves.
MAX_ACTIVE <- 6
CHUNK_SIZE <- 200
S2_BATCH <- 500
# Semantic Scholar's free rate limit is shared by everyone without a key:
# one request a second at most, and a pause between DOI batches.
S2_PAUSE_SECONDS <- 1.1

# Elsevier's DOI prefix: its pages refuse automated requests.
SKIP_LANDING_PREFIXES <- c("10.1016/")

# Meta tags that carry an abstract on publisher pages, best first.
ABSTRACT_META <- c("citation_abstract", "dc.description", "og:description",
                   "twitter:description", "description")

# The same text on this many records or more is a site's own description.
GENERIC_REPEATS <- 3

flags <- parse_flags()
only_source <- flag(flags, "source", NULL)
limit <- as.integer(flag(flags, "limit", NA))
retry <- isTRUE(flag(flags, "retry", FALSE))
if (!is.null(only_source) && !only_source %in% SOURCES) {
  stop("--source must be one of ", paste(SOURCES, collapse = ", "))
}

log_step("Abstracts for records that have none")

# ---- helpers ---------------------------------------------------------------------

#' Tags removed, entities decoded, white space collapsed, and a leading
#' "Abstract" heading dropped. NA when what is left is too short.
clean_abstract <- function(x) {
  out <- vapply(x, function(s) {
    if (is.na(s) || !nzchar(s)) return(NA_character_)
    txt <- tryCatch(xml2::xml_text(xml2::read_html(paste0("<div>", s, "</div>"))),
                    error = function(e) gsub("<[^>]+>", " ", s))
    txt <- trimws(gsub("[[:space:]]+", " ", txt))
    sub("^(abstract|summary)[[:space:].:-]*", "", txt, ignore.case = TRUE)
  }, "", USE.NAMES = FALSE)
  ifelse(!is.na(out) & nchar(out) >= MIN_ABSTRACT_CHARS, out, NA_character_)
}

#' One row of the lookup file per record.
lookup_rows <- function(record_id, source, abstract, error = FALSE) {
  abstract <- clean_abstract(rep_len(abstract, length(record_id)))
  # Full length, so ifelse() below gives one status per record.
  error <- rep_len(error, length(record_id))
  tibble::tibble(
    record_id = record_id, source = source,
    status = ifelse(error, "error", ifelse(is.na(abstract), "none", "found")),
    abstract = abstract, looked_up_on = as.character(Sys.Date())
  )
}

#' Send requests in parallel. Returns a list of responses, NULL where the
#' request failed outright (a dropped connection after its retries).
perform_all <- function(reqs) {
  resps <- httr2::req_perform_parallel(reqs, on_error = "continue", progress = FALSE,
                                       max_active = MAX_ACTIVE)
  lapply(resps, function(r) if (inherits(r, "httr2_response")) r else NULL)
}

#' The parsed JSON body of a successful response, or NULL.
json_of <- function(resp) {
  if (is.null(resp) || httr2::resp_status(resp) >= 400) return(NULL)
  tryCatch(httr2::resp_body_json(resp), error = function(e) NULL)
}

# ---- the sources -----------------------------------------------------------------
# Each takes the records still missing an abstract (record_id, doi, title) and
# returns their lookup rows.

from_europepmc <- function(d) {
  reqs <- lapply(d$doi, function(doi) polite_request(
    "https://www.ebi.ac.uk/europepmc/webservices/rest/search",
    query = sprintf('DOI:"%s"', doi), resultType = "core", format = "json", pageSize = 5))
  resps <- perform_all(reqs)
  abstract <- mapply(function(resp, doi) {
    hits <- json_of(resp)$resultList$result
    for (h in hits) {
      if (identical(normalise_doi(h$doi), doi) && !is.null(h$abstractText)) return(h$abstractText)
    }
    NA_character_
  }, resps, d$doi)
  lookup_rows(d$record_id, "europepmc", abstract, error = vapply(resps, is.null, TRUE))
}

from_semantic_scholar <- function(d) {
  Sys.sleep(S2_PAUSE_SECONDS * 5)
  key <- Sys.getenv("SEMANTIC_SCHOLAR_API_KEY")
  req <- polite_request("https://api.semanticscholar.org/graph/v1/paper/batch",
                        fields = "abstract", max_tries = 6) |>
    httr2::req_body_json(list(ids = as.list(paste0("DOI:", d$doi))))
  if (nzchar(key)) req <- httr2::req_headers(req, `x-api-key` = key)
  body <- json_of(tryCatch(httr2::req_perform(req), error = function(e) NULL))
  if (is.null(body)) return(lookup_rows(d$record_id, "semantic_scholar", NA, error = TRUE))
  abstract <- vapply(body, function(p) if (is.null(p$abstract)) NA_character_ else p$abstract, "")
  lookup_rows(d$record_id, "semantic_scholar", abstract)
}

from_crossref <- function(d) {
  reqs <- lapply(d$doi, function(doi) polite_request(
    paste0("https://api.crossref.org/works/", utils::URLencode(doi, reserved = TRUE)),
    mailto = Sys.getenv("OPENALEX_EMAIL", Sys.getenv("UNPAYWALL_EMAIL"))))
  resps <- perform_all(reqs)
  abstract <- vapply(resps, function(r) {
    a <- json_of(r)$message$abstract
    if (is.null(a)) NA_character_ else a
  }, "")
  lookup_rows(d$record_id, "crossref", abstract, error = vapply(resps, is.null, TRUE))
}

from_landing_page <- function(d) {
  reqs <- lapply(d$doi, function(doi) {
    polite_request(paste0("https://doi.org/", doi), max_tries = 2) |>
      httr2::req_headers(Accept = "text/html") |>
      httr2::req_timeout(30)
  })
  resps <- perform_all(reqs)
  abstract <- vapply(resps, function(r) {
    if (is.null(r) || httr2::resp_status(r) >= 400) return(NA_character_)
    page <- tryCatch(xml2::read_html(httr2::resp_body_raw(r)), error = function(e) NULL)
    if (is.null(page)) return(NA_character_)
    metas <- xml2::xml_find_all(page, "//meta[@content]")
    names <- tolower(dplyr::coalesce(xml2::xml_attr(metas, "name"), xml2::xml_attr(metas, "property")))
    content <- xml2::xml_attr(metas, "content")
    for (m in ABSTRACT_META) {
      hit <- content[names %in% m & nchar(content) >= MIN_ABSTRACT_CHARS]
      if (length(hit)) return(hit[1])
    }
    NA_character_
  }, "")
  lookup_rows(d$record_id, "landing_page", abstract, error = vapply(resps, is.null, TRUE))
}

from_title_match <- function(d) {
  # Europe PMC first, in parallel.
  reqs <- lapply(d$title, function(t) polite_request(
    "https://www.ebi.ac.uk/europepmc/webservices/rest/search",
    query = sprintf('TITLE:"%s"', gsub('"', "", t)), resultType = "core", format = "json",
    pageSize = 5))
  resps <- perform_all(reqs)
  abstract <- mapply(function(resp, title) {
    for (h in json_of(resp)$resultList$result) {
      if (identical(normalise_title(h$title), normalise_title(title)) && !is.null(h$abstractText)) {
        return(h$abstractText)
      }
    }
    NA_character_
  }, resps, d$title)
  # Semantic Scholar for the rest, one a second (its free rate limit is low).
  # When it refuses for good, the rest are recorded as errors for --retry.
  error <- vapply(resps, is.null, TRUE)
  for (i in which(is.na(abstract))) {
    Sys.sleep(S2_PAUSE_SECONDS)
    resp <- tryCatch(
      fetch_polite("https://api.semanticscholar.org/graph/v1/paper/search/match",
                   query = d$title[i], fields = "title,abstract", max_tries = 3),
      error = function(e) "refused")
    if (identical(resp, "refused")) {
      log_msg("Semantic Scholar refused further requests; the rest are left for --retry",
              level = "warn")
      error[setdiff(which(is.na(abstract)), seq_len(i - 1))] <- TRUE
      break
    }
    p <- json_of(resp)$data[[1]]
    if (!is.null(p$abstract) && identical(normalise_title(p$title), normalise_title(d$title[i]))) {
      abstract[i] <- p$abstract
    }
  }
  lookup_rows(d$record_id, "title_match", abstract, error = error & is.na(abstract))
}

SOURCE_FUNCTIONS <- list(europepmc = from_europepmc, semantic_scholar = from_semantic_scholar,
                         crossref = from_crossref, landing_page = from_landing_page,
                         title_match = from_title_match)

# ---- run ---------------------------------------------------------------------------

records <- read_csv_safe(FILE_SEARCH_MATCHED)
if (!nrow(records)) stop("No search records in ", FILE_SEARCH_MATCHED, ": run openalex_search.R first")
missing <- records[!nzchar(dplyr::coalesce(records$abstract, "")), c("record_id", "doi", "title")]
missing$doi <- normalise_doi(missing$doi)
log_msg(format(nrow(missing), big.mark = ","), " records have no abstract (",
        sum(!is.na(missing$doi)), " with a DOI)")

for (src in if (is.null(only_source)) SOURCES else only_source) {
  tried <- read_csv_safe(FILE_ABSTRACT_LOOKUP)
  done <- if (nrow(tried)) tried$record_id[tried$status == "found"] else character()
  skip <- if (nrow(tried)) {
    tried$record_id[tried$source == src & (tried$status == "none" | !retry)]
  } else character()
  todo <- missing[!missing$record_id %in% c(done, skip), ]
  todo <- if (src == "title_match") todo[is.na(todo$doi), ] else todo[!is.na(todo$doi), ]
  if (src == "landing_page") {
    todo <- todo[!startsWith(todo$doi, SKIP_LANDING_PREFIXES), ]
  }
  if (!is.na(limit)) todo <- head(todo, limit)
  if (!nrow(todo)) {
    log_msg(src, ": nothing to look up")
    next
  }
  log_msg(src, ": looking up ", format(nrow(todo), big.mark = ","), " records")
  size <- if (src == "semantic_scholar") S2_BATCH else CHUNK_SIZE
  chunks <- split(todo, ceiling(seq_len(nrow(todo)) / size))
  found <- 0
  for (k in seq_along(chunks)) {
    rows <- SOURCE_FUNCTIONS[[src]](chunks[[k]])
    # A failed lookup is recorded too, so --retry can find it; an existing
    # row for the same record and source is replaced.
    tried <- read_csv_safe(FILE_ABSTRACT_LOOKUP)
    if (nrow(tried)) {
      tried <- tried[!paste(tried$record_id, tried$source) %in% paste(rows$record_id, rows$source), ]
    }
    write_csv_safe(dplyr::bind_rows(tried, rows), FILE_ABSTRACT_LOOKUP)
    found <- found + sum(rows$status == "found")
    log_msg(src, ": ", min(k * size, nrow(todo)), " of ", nrow(todo),
            " looked up, ", found, " abstracts found, ", sum(rows$status == "error"),
            " errors in this chunk")
  }
}

# A text found for many records is a site's own description, not an abstract.
tried <- read_csv_safe(FILE_ABSTRACT_LOOKUP)
if (nrow(tried)) {
  repeated <- names(which(table(tried$abstract[tried$status == "found"]) >= GENERIC_REPEATS))
  generic <- tried$status == "found" & tried$abstract %in% repeated
  if (any(generic)) {
    log_msg(sum(generic), " lookups returned a repeated site description; marked none",
            level = "warn")
    tried$status[generic] <- "none"
    tried$abstract[generic] <- NA
    write_csv_safe(tried, FILE_ABSTRACT_LOOKUP)
  }
}

before <- sum(nzchar(dplyr::coalesce(records$abstract, "")))
records <- apply_found_abstracts(records)
write_csv_safe(records, FILE_SEARCH_MATCHED)
after <- sum(nzchar(dplyr::coalesce(records$abstract, "")))
log_msg(format(after - before, big.mark = ","), " abstracts added; ",
        format(nrow(records) - after, big.mark = ","), " records still have none", level = "done")
print(table(records$abstract_source, useNA = "ifany"))
