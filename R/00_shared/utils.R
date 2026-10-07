# What it does: Small helpers every step uses. Console logging, command line
#   flag parsing, polite HTTP fetching with retries, safe CSV reading and
#   writing, and the one way to normalise a DOI or a title for comparison.
# Reads: nothing.
# Writes: nothing. Callers write their own files.
# Flags: none. This file is sourced, not run.
#
# Sourced with:
#   root <- rprojroot::find_root(rprojroot::has_file("CC4A.Rproj"))
#   source(file.path(root, "R/00_shared/paths.R"))
#   source(file.path(root, "R/00_shared/utils.R"))

# ---- console output ----------------------------------------------------

#' Print a timestamped line to the console.
#' @param ... parts of the message, pasted together
#' @param level one of "info", "warn", "error", "done"
log_msg <- function(..., level = "info") {
  msg <- paste0(format(Sys.time(), "%H:%M:%S"), "  ", paste0(...))
  switch(level,
    warn  = cli::cli_alert_warning(msg),
    error = cli::cli_alert_danger(msg),
    done  = cli::cli_alert_success(msg),
    cli::cli_alert_info(msg)
  )
  invisible(msg)
}

#' Print the header of a step so a long run is readable in the log.
#' @param title the step name
log_step <- function(title) {
  cli::cli_rule(left = title, right = format(Sys.time(), "%Y-%m-%d %H:%M"))
}

# ---- command line flags ------------------------------------------------

#' Read the --name=value flags a script was called with.
#' Bare flags such as --dry come back as TRUE.
#' @param args the raw vector, defaults to commandArgs(trailingOnly = TRUE)
#' @return a named list
parse_flags <- function(args = commandArgs(trailingOnly = TRUE)) {
  args <- args[startsWith(args, "--")]
  out <- list()
  for (a in sub("^--", "", args)) {
    if (grepl("=", a, fixed = TRUE)) {
      name <- sub("=.*$", "", a)
      value <- sub("^[^=]*=", "", a)
      if (tolower(value) %in% c("true", "false")) value <- tolower(value) == "true"
    } else {
      name <- a
      value <- TRUE
    }
    out[[name]] <- value
  }
  out
}

#' Read one flag with a default, so scripts do not repeat the same check.
#' @param flags the list from parse_flags()
#' @param name the flag name without dashes
#' @param default returned when the flag was not given
flag <- function(flags, name, default = NULL) {
  if (is.null(flags[[name]])) default else flags[[name]]
}

# ---- http --------------------------------------------------------------

#' Fetch a URL politely. One place for the delay between calls, the retry on
#' a 429 or a 5xx, the user agent, and the contact email the APIs ask for.
#' @param url the address
#' @param ... passed to the underlying request
#' @param max_tries how many times to retry before giving up
#' @return the response, or NULL when every try failed
fetch_polite <- function(url, ..., max_tries = 4) {
  contact <- Sys.getenv("OPENALEX_EMAIL", Sys.getenv("UNPAYWALL_EMAIL"))
  agent <- if (nzchar(contact)) {
    paste0("CC4A evidence synthesis (mailto:", contact, ")")
  } else {
    "CC4A evidence synthesis"
  }
  req <- httr2::request(url) |>
    httr2::req_url_query(...) |>
    httr2::req_user_agent(agent) |>
    httr2::req_retry(
      max_tries = max_tries,
      is_transient = function(resp) httr2::resp_status(resp) %in% c(429, 500, 502, 503, 504),
      backoff = function(i) 2^i
    ) |>
    httr2::req_error(is_error = function(resp) FALSE)
  resp <- tryCatch(httr2::req_perform(req), error = function(e) {
    log_msg("request failed: ", conditionMessage(e), level = "warn")
    NULL
  })
  if (is.null(resp)) return(NULL)
  if (httr2::resp_status(resp) >= 400) {
    log_msg("HTTP ", httr2::resp_status(resp), " for ", url, level = "warn")
    return(NULL)
  }
  resp
}

# ---- identifiers -------------------------------------------------------

#' Put a DOI in one shape so two of them can be compared.
#' Lower case, no https://doi.org/ prefix, no trailing punctuation.
#' @param x a character vector of DOIs
#' @return a character vector, NA where the input was not a DOI
normalise_doi <- function(x) {
  x <- tolower(trimws(as.character(x)))
  x <- sub("^https?://(dx[.])?doi[.]org/", "", x)
  x <- sub("^doi:[[:space:]]*", "", x)
  x <- sub("[[:space:].,;]+$", "", x)
  ifelse(!is.na(x) & startsWith(x, "10."), x, NA_character_)
}

#' Put a title in one shape for fuzzy comparison in step 2.
#' Lower case, accents folded, punctuation dropped, whitespace collapsed.
#' @param x a character vector of titles
#' @return a character vector
normalise_title <- function(x) {
  x <- stringi::stri_trans_general(as.character(x), "Latin-ASCII")
  x <- tolower(x)
  x <- gsub("[^a-z0-9 ]", " ", x)
  x <- trimws(gsub("[[:space:]]+", " ", x))
  ifelse(is.na(x) | x == "", NA_character_, x)
}

# ---- files -------------------------------------------------------------

#' Read a CSV with every column as character, so identifiers and units are
#' never guessed at by the parser. Returns an empty tibble when the file is
#' missing, so a first run does not stop.
#' @param path the file
read_csv_safe <- function(path) {
  if (!file.exists(path)) return(tibble::tibble())
  readr::read_csv(path, col_types = readr::cols(.default = readr::col_character()),
                  na = "", progress = FALSE, show_col_types = FALSE)
}

#' Write a CSV, making the folder first, always UTF-8, no row names.
#' @param x the data frame
#' @param path the file
#' @param append add rows to an existing file instead of replacing it; the
#'   header is written only when the file is new
write_csv_safe <- function(x, path, append = FALSE) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  readr::write_csv(x, path, na = "", append = append && file.exists(path))
  invisible(path)
}

#' Stamp a run so outputs from different runs never overwrite each other.
#' @return a string such as "2026-09-22_1412"
run_stamp <- function() {
  format(Sys.time(), "%Y-%m-%d_%H%M")
}
