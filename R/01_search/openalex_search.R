# What it does: Runs the OpenAlex searches in the key-words file. For every
#   practice it runs one search per outcome block: practice AND geography AND
#   outcome1, then practice AND geography AND outcome2, and so on. Counts the
#   hits for every combination, downloads the records, and checks each record
#   against the references already screened in the 2022 World Bank NbS
#   extraction, so nothing is screened twice.
# Reads: docs/synthesis/key-words.xlsx       the search blocks
#        data/wb_nbs_extraction_2022.xlsx    its Refs sheet, for the duplicate check
# Writes: catalogues/search_raw.csv                    one row per record per search
#         outputs/01_search/search_log.csv             one row per search, as run
#         outputs/01_search/search_counts.csv          hits per search (also written by --dry)
#         outputs/01_search/search_records_vs_wb2022.csv  one row per unique record,
#                                                      marked if already in the 2022 refs
#         outputs/01_search/search_summary.xlsx        the tables to read: hits and new
#                                                      records per practice x outcome
# Flags: --dry            count the hits only, download nothing. Fast; run it first
#        --practice=      run only these practice_group codes, comma separated,
#                         for example --practice=water_management,soil_cover
#        --outcome=       run only these outcome codes, for example --outcome=outcome2
#        --skip-flagged   leave out the practices flagged NOT MOVING FORWARD
#        --limit=         stop each search after this many records, for a test run
#        --refresh        rerun searches already completed in the log
#        --from-year=     override YEAR_MIN from paths.R
#        --to-year=       override YEAR_MAX from paths.R
#
# Run with:
#   Rscript R/01_search/openalex_search.R --dry
#   Rscript R/01_search/openalex_search.R --practice=water_management --limit=200
#   Rscript R/01_search/openalex_search.R

root <- rprojroot::find_root(rprojroot::has_file("CC4A.Rproj"))
source(file.path(root, "R/00_shared/paths.R"))
source(file.path(root, "R/00_shared/utils.R"))

OPENALEX_BASE <- "https://api.openalex.org/works"

# OpenAlex returns at most 200 records a page. Raising it does nothing.
PER_PAGE <- 200

# Pause between requests. OpenAlex allows 10 a second; this keeps well under.
PAUSE_SECONDS <- 0.15

# Where the search terms are matched. title_and_abstract keeps out papers that
# only mention a term in passing in the full text.
SEARCH_FIELD <- "title_and_abstract.search"

# Practices carrying this text in the flag column are dropped by
# --skip-flagged. They are searched by default, so the counts can inform the
# decision.
NOT_FORWARD_PATTERN <- "NOT MOVING FORWARD"

# The sheet of the 2022 extraction that lists the screened references.
WB_REFS_SHEET <- "Refs"

SELECT_FIELDS <- paste(c(
  "id", "doi", "title", "publication_year", "primary_location",
  "authorships", "abstract_inverted_index", "type", "open_access",
  "cited_by_count"
), collapse = ",")

# Columns every search writes. Step 2 depends on this shape.
SEARCH_COLS <- c(
  "search_id",        # practice_group__outcome, the combination that found it
  "practice_group",
  "outcome",
  "record_id",        # OpenAlex work id, the short form such as W2741809807
  "doi",              # normalised, no https prefix
  "title",
  "abstract",
  "publication_year",
  "journal",
  "authors",          # semicolon separated
  "country_iso2",     # semicolon separated, from the authors' institutions
  "type",             # article, book-chapter, report, dissertation
  "is_oa",
  "oa_url",
  "cited_by_count",
  "retrieved_on"
)

# ---- the search blocks ----------------------------------------------------

#' Wrap each multi-word term in quotes unless it already has them.
#' OpenAlex reads bare words as separate terms: `carbon credit OR "carbon
#' market"` matches 4.6 million works, `"carbon credit" OR "carbon market"`
#' about 18 thousand. Returns the fixed string and the terms that changed.
quote_bare_phrases <- function(block) {
  terms <- trimws(strsplit(block, "[[:space:]]+OR[[:space:]]+")[[1]])
  bare <- !startsWith(terms, "\"") & grepl("[[:space:]]", terms)
  terms[bare] <- paste0("\"", terms[bare], "\"")
  list(text = paste(terms, collapse = " OR "), changed = terms[bare])
}

read_blocks <- function() {
  kw <- readxl::read_excel(FILE_KEYWORDS_XLSX, col_types = "text")
  names(kw) <- tolower(trimws(names(kw)))
  needed <- c("practice_group", "practice_label", "keyword", "flag")
  missing <- setdiff(needed, names(kw))
  if (length(missing)) {
    stop("key-words.xlsx is missing columns: ", paste(missing, collapse = ", "))
  }
  kw <- kw[!is.na(kw$keyword) & nzchar(trimws(kw$keyword)), needed]
  kw$practice_group <- trimws(kw$practice_group)
  kw$flag[is.na(kw$flag)] <- ""

  if (any(grepl(",", kw$keyword, fixed = TRUE))) {
    stop("A keyword contains a comma, which OpenAlex reads as the end of the ",
         "filter. Remove it in key-words.xlsx: ",
         paste(kw$practice_group[grepl(",", kw$keyword, fixed = TRUE)], collapse = ", "))
  }

  fixed <- lapply(kw$keyword, quote_bare_phrases)
  kw$keyword_sent <- vapply(fixed, `[[`, "", "text")
  kw$quoted_by_script <- vapply(fixed, function(f) paste(f$changed, collapse = "; "), "")
  for (i in which(nzchar(kw$quoted_by_script))) {
    log_msg("quoted for OpenAlex in ", kw$practice_group[i], ": ",
            kw$quoted_by_script[i], ". Worth fixing in key-words.xlsx", level = "warn")
  }

  geography <- kw[kw$practice_group == "geography", ]
  if (nrow(geography) != 1) stop("key-words.xlsx needs exactly one geography row")
  outcomes <- kw[grepl("^outcome", kw$practice_group), ]
  practices <- kw[!kw$practice_group %in% c("geography", outcomes$practice_group), ]
  list(all = kw, geography = geography, outcomes = outcomes, practices = practices)
}

#' Every practice crossed with every outcome, as the boolean string sent.
build_searches <- function(blocks) {
  grid <- expand.grid(p = seq_len(nrow(blocks$practices)),
                      o = seq_len(nrow(blocks$outcomes)))
  grid <- grid[order(grid$p, grid$o), ]
  p <- blocks$practices[grid$p, ]
  o <- blocks$outcomes[grid$o, ]
  tibble::tibble(
    search_id      = paste0(p$practice_group, "__", o$practice_group),
    practice_group = p$practice_group,
    practice_label = p$practice_label,
    practice_flag  = p$flag,
    outcome        = o$practice_group,
    query          = paste0("(", p$keyword_sent, ") AND (",
                            blocks$geography$keyword_sent, ") AND (",
                            o$keyword_sent, ")")
  )
}

# ---- OpenAlex ---------------------------------------------------------------

openalex_get <- function(params) {
  if (nzchar(Sys.getenv("OPENALEX_EMAIL"))) params$mailto <- Sys.getenv("OPENALEX_EMAIL")
  if (nzchar(Sys.getenv("OPENALEX_API_KEY"))) params$api_key <- Sys.getenv("OPENALEX_API_KEY")
  resp <- do.call(fetch_polite, c(list(OPENALEX_BASE), params))
  Sys.sleep(PAUSE_SECONDS)
  if (is.null(resp)) return(NULL)
  httr2::resp_body_json(resp, simplifyVector = FALSE)
}

search_filter <- function(query, year_from, year_to) {
  paste0(SEARCH_FIELD, ":", query, ",publication_year:", year_from, "-", year_to)
}

count_hits <- function(query, year_from, year_to) {
  res <- openalex_get(list(filter = search_filter(query, year_from, year_to),
                           `per-page` = 1, select = "id"))
  if (is.null(res)) NA_integer_ else as.integer(res$meta$count)
}

#' OpenAlex sends abstracts as an inverted index (word -> positions).
rebuild_abstract <- function(inv) {
  if (is.null(inv) || !length(inv)) return(NA_character_)
  words <- rep(names(inv), lengths(inv))
  pos <- unlist(inv, use.names = FALSE)
  paste(words[order(pos)], collapse = " ")
}

work_row <- function(w) {
  authors <- vapply(w$authorships, function(a) a$author$display_name %||% "", "")
  countries <- unique(unlist(lapply(w$authorships, function(a) a$countries)))
  tibble::tibble(
    record_id        = sub("^https://openalex.org/", "", w$id %||% NA_character_),
    doi              = normalise_doi(w$doi %||% NA_character_),
    title            = w$title %||% NA_character_,
    abstract         = rebuild_abstract(w$abstract_inverted_index),
    publication_year = as.character(w$publication_year %||% NA),
    journal          = w$primary_location$source$display_name %||% NA_character_,
    authors          = paste(authors, collapse = "; "),
    country_iso2     = paste(countries, collapse = ";"),
    type             = w$type %||% NA_character_,
    is_oa            = as.character(w$open_access$is_oa %||% NA),
    oa_url           = w$open_access$oa_url %||% NA_character_,
    cited_by_count   = as.character(w$cited_by_count %||% NA)
  )
}

#' Page through every result with a cursor. Offset paging silently stops at
#' 10 000 records; the cursor does not.
download_search <- function(query, year_from, year_to, limit) {
  cursor <- "*"
  pages <- list()
  n <- 0
  repeat {
    res <- openalex_get(list(filter = search_filter(query, year_from, year_to),
                             `per-page` = PER_PAGE, cursor = cursor,
                             select = SELECT_FIELDS))
    if (is.null(res)) return(list(rows = dplyr::bind_rows(pages), complete = FALSE))
    if (!length(res$results)) break
    pages[[length(pages) + 1]] <- dplyr::bind_rows(lapply(res$results, work_row))
    n <- n + length(res$results)
    if (!is.null(limit) && n >= limit) {
      rows <- dplyr::bind_rows(pages)
      return(list(rows = utils::head(rows, limit), complete = FALSE))
    }
    cursor <- res$meta$next_cursor
    if (is.null(cursor)) break
  }
  list(rows = dplyr::bind_rows(pages), complete = TRUE)
}

# ---- the 2022 references ------------------------------------------------------

read_wb_refs <- function() {
  if (!file.exists(FILE_WB2022)) {
    log_msg("2022 extraction not found at ", FILE_WB2022,
            "; records are not checked against it", level = "warn")
    return(NULL)
  }
  refs <- readxl::read_excel(FILE_WB2022, sheet = WB_REFS_SHEET, col_types = "text")
  tibble::tibble(
    wb_ref_id = refs$ID,
    doi_n     = normalise_doi(refs$DOI),
    title_n   = normalise_title(refs$Title)
  )
}

#' One row per unique record, marked when the 2022 refs already hold it.
#' DOI first; a normalised exact title for records without a DOI match.
match_wb <- function(raw, refs) {
  records <- raw |>
    dplyr::group_by(record_id) |>
    dplyr::summarise(
      found_by   = paste(sort(unique(search_id)), collapse = "; "),
      n_searches = dplyr::n_distinct(search_id),
      dplyr::across(c(doi, title, publication_year, journal, authors, type,
                      is_oa, oa_url), dplyr::first),
      .groups = "drop"
    )
  if (is.null(refs)) {
    records$in_wb2022 <- NA
    records$wb_ref_id <- NA_character_
    records$match_basis <- NA_character_
    return(records)
  }
  title_n <- normalise_title(records$title)
  by_doi <- match(records$doi, refs$doi_n, incomparables = NA)
  by_title <- match(title_n, refs$title_n, incomparables = NA)
  hit <- ifelse(!is.na(by_doi), by_doi, by_title)
  records$in_wb2022 <- !is.na(hit)
  records$wb_ref_id <- refs$wb_ref_id[hit]
  records$match_basis <- ifelse(!is.na(by_doi), "doi", ifelse(!is.na(by_title), "title", NA))
  records
}

# ---- the tables -----------------------------------------------------------------

wide <- function(long, value, searches) {
  out <- tidyr::pivot_wider(long[, c("practice_group", "outcome", value)],
                            names_from = outcome, values_from = dplyr::all_of(value))
  labels <- dplyr::distinct(searches, practice_group, practice_label, practice_flag)
  dplyr::left_join(labels, out, by = "practice_group")
}

write_summary <- function(counts, by_search = NULL, per_practice = NULL,
                          totals = NULL, blocks) {
  wb <- openxlsx::createWorkbook()
  bold <- openxlsx::createStyle(textDecoration = "bold")
  add <- function(name, x) {
    openxlsx::addWorksheet(wb, name)
    openxlsx::writeData(wb, name, x, headerStyle = bold)
    openxlsx::setColWidths(wb, name, cols = seq_len(ncol(x)), widths = "auto")
  }
  readme <- data.frame(about = c(
    "OpenAlex search results, one search per practice x outcome block.",
    "Each search is: practice terms AND geography terms AND outcome terms, matched in titles and abstracts.",
    "hits: works OpenAlex reports for the search. downloaded: records retrieved.",
    "in_wb2022: records already in the Refs sheet of the 2022 World Bank NbS extraction (by DOI, then by title).",
    "new: downloaded records not in the 2022 refs. A record found by several searches counts once per search.",
    "per_practice: unique records per practice across its outcome searches. totals: unique across everything.",
    paste("Run on", format(Sys.time(), "%Y-%m-%d %H:%M"), "by R/01_search/openalex_search.R.")
  ))
  add("README", readme)
  add("hits", wide(counts, "hits", counts))
  if (!is.null(by_search)) {
    add("new_records", wide(by_search, "new", by_search))
    add("by_search", by_search)
    add("per_practice", per_practice)
    add("totals", totals)
  }
  add("keywords_used", blocks$all[, c("practice_group", "practice_label", "flag",
                                      "keyword", "keyword_sent", "quoted_by_script")])
  openxlsx::saveWorkbook(wb, FILE_SEARCH_SUMMARY, overwrite = TRUE)
}

# ---- run ------------------------------------------------------------------------

flags <- parse_flags()
dry <- isTRUE(flag(flags, "dry", FALSE))
year_from <- as.integer(flag(flags, "from-year", YEAR_MIN))
year_to <- as.integer(flag(flags, "to-year", YEAR_MAX))
limit <- flag(flags, "limit", NULL)
if (!is.null(limit)) limit <- as.integer(limit)

log_step("Step 1: OpenAlex search")
blocks <- read_blocks()
searches <- build_searches(blocks)
all_ids <- searches$search_id   # every search in the key-words file, in order

if (!is.null(flag(flags, "practice"))) {
  keep <- trimws(strsplit(flag(flags, "practice"), ",")[[1]])
  unknown <- setdiff(keep, searches$practice_group)
  if (length(unknown)) stop("unknown practice_group: ", paste(unknown, collapse = ", "))
  searches <- searches[searches$practice_group %in% keep, ]
}
if (!is.null(flag(flags, "outcome"))) {
  keep <- trimws(strsplit(flag(flags, "outcome"), ",")[[1]])
  searches <- searches[searches$outcome %in% keep, ]
}
if (isTRUE(flag(flags, "skip-flagged", FALSE))) {
  searches <- searches[!grepl(NOT_FORWARD_PATTERN, searches$practice_flag, fixed = TRUE), ]
}
log_msg(nrow(searches), " searches: ", length(unique(searches$practice_group)),
        " practices x ", length(unique(searches$outcome)), " outcomes, ",
        year_from, "-", year_to)

# Hits for every search. Cheap: one request each.
searches$hits <- NA_integer_
for (i in seq_len(nrow(searches))) {
  searches$hits[i] <- count_hits(searches$query[i], year_from, year_to)
  log_msg(sprintf("%-45s %8s hits", searches$search_id[i],
                  format(searches$hits[i], big.mark = ",")))
}
counts <- searches
counts$year_from <- year_from
counts$year_to <- year_to
counts$counted_on <- as.character(Sys.Date())

# A run narrowed with --practice or --outcome updates its own rows and keeps
# the counts of every other search, so the tables always cover the whole
# key-words file. Searches no longer in the file are dropped.
old <- read_csv_safe(FILE_SEARCH_COUNTS)
if (nrow(old)) {
  old <- old[!old$search_id %in% counts$search_id & old$search_id %in% all_ids, ]
  counts <- dplyr::bind_rows(dplyr::mutate(old, dplyr::across(dplyr::everything(), as.character)),
                             dplyr::mutate(counts, dplyr::across(dplyr::everything(), as.character)))
}
counts$hits <- as.integer(counts$hits)
counts <- counts[order(match(counts$search_id, all_ids)), ]
write_csv_safe(counts, FILE_SEARCH_COUNTS)

if (dry) {
  write_summary(counts, blocks = blocks)
  log_msg("dry run: counts written to ", FILE_SEARCH_SUMMARY, ". Nothing downloaded",
          level = "done")
  print(as.data.frame(wide(counts, "hits", counts)), row.names = FALSE)
  quit(save = "no")
}

# Download, one search at a time, appending as each finishes so an
# interrupted run picks up where it stopped.
log_tbl <- read_csv_safe(FILE_SEARCH_LOG)
done <- if (nrow(log_tbl)) log_tbl$search_id[log_tbl$status == "complete"] else character()
refresh <- isTRUE(flag(flags, "refresh", FALSE))

for (i in seq_len(nrow(searches))) {
  s <- searches[i, ]
  if (s$search_id %in% done && !refresh) {
    log_msg(s$search_id, ": already downloaded, skipped (use --refresh to rerun)")
    next
  }
  log_msg(s$search_id, ": downloading ", format(s$hits, big.mark = ","), " records")
  got <- download_search(s$query, year_from, year_to, limit)
  rows <- got$rows
  if (nrow(rows)) {
    rows$search_id <- s$search_id
    rows$practice_group <- s$practice_group
    rows$outcome <- s$outcome
    rows$retrieved_on <- as.character(Sys.Date())
    rows <- rows[, SEARCH_COLS]
  }

  # Replace this search's earlier rows rather than stacking a second copy.
  raw <- read_csv_safe(FILE_SEARCH_RAW)
  if (nrow(raw)) raw <- raw[raw$search_id != s$search_id, ]
  write_csv_safe(dplyr::bind_rows(raw, rows), FILE_SEARCH_RAW)

  log_tbl <- read_csv_safe(FILE_SEARCH_LOG)
  if (nrow(log_tbl)) log_tbl <- log_tbl[log_tbl$search_id != s$search_id, ]
  entry <- tibble::tibble(
    search_id = s$search_id, practice_group = s$practice_group,
    practice_label = s$practice_label, practice_flag = s$practice_flag,
    outcome = s$outcome, query = s$query, filter = search_filter(s$query, year_from, year_to),
    hits = as.character(s$hits), downloaded = as.character(nrow(rows)),
    status = if (got$complete) "complete" else if (is.null(limit)) "failed" else "limited",
    run_date = as.character(Sys.time())
  )
  write_csv_safe(dplyr::bind_rows(log_tbl, entry), FILE_SEARCH_LOG)
  log_msg(s$search_id, ": ", nrow(rows), " records, ", entry$status,
          level = if (entry$status == "failed") "warn" else "done")
}

# Check every record against the 2022 references and build the tables.
raw <- read_csv_safe(FILE_SEARCH_RAW)
raw <- raw[raw$search_id %in% all_ids, ]
refs <- read_wb_refs()
records <- match_wb(raw, refs)
write_csv_safe(records, FILE_SEARCH_MATCHED)

flags_by_record <- records[, c("record_id", "in_wb2022")]
with_flag <- dplyr::left_join(raw[, c("search_id", "record_id")], flags_by_record,
                              by = "record_id")
by_search <- with_flag |>
  dplyr::group_by(search_id) |>
  dplyr::summarise(downloaded = dplyr::n_distinct(record_id),
                   in_wb2022 = sum(in_wb2022, na.rm = TRUE),
                   new = downloaded - in_wb2022, .groups = "drop")
by_search <- dplyr::left_join(
  counts[, c("search_id", "practice_group", "practice_label", "practice_flag",
             "outcome", "hits")],
  by_search, by = "search_id")

per_practice <- dplyr::left_join(raw[, c("practice_group", "record_id")],
                                 flags_by_record, by = "record_id") |>
  dplyr::distinct() |>
  dplyr::group_by(practice_group) |>
  dplyr::summarise(unique_records = dplyr::n_distinct(record_id),
                   in_wb2022 = sum(in_wb2022, na.rm = TRUE),
                   new = unique_records - in_wb2022, .groups = "drop")

totals <- tibble::tibble(
  searches_in_file = length(all_ids),
  searches_downloaded = dplyr::n_distinct(raw$search_id),
  record_rows = nrow(raw),
  unique_records = nrow(records),
  in_wb2022 = sum(records$in_wb2022, na.rm = TRUE),
  new = nrow(records) - sum(records$in_wb2022, na.rm = TRUE),
  wb2022_refs_checked = if (is.null(refs)) 0L else nrow(refs)
)

write_summary(counts, by_search, per_practice, totals, blocks)
log_msg(totals$unique_records, " unique records, ", totals$in_wb2022,
        " already in the 2022 refs, ", totals$new, " new. Tables in ",
        FILE_SEARCH_SUMMARY, level = "done")
