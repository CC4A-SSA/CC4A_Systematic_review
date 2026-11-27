# What it does: Requests to the shared Zotero group library through the
#   Zotero web API, for R/04_fetch/zotero_upload.R and
#   R/04_fetch/zotero_status.R. Source after paths.R and utils.R.
# Reads: ZOTERO_API_KEY (write access to the group) and ZOTERO_GROUP_ID (the
#   number in the group's URL on zotero.org), from .Renviron.
# Writes: nothing by itself.

ZOTERO_BASE <- "https://api.zotero.org"
# The API takes at most 50 objects per write.
WRITE_BATCH <- 50

#' Stop unless the key and group are set.
zotero_check_env <- function() {
  if (!nzchar(Sys.getenv("ZOTERO_API_KEY")) || !nzchar(Sys.getenv("ZOTERO_GROUP_ID"))) {
    stop("Set ZOTERO_API_KEY and ZOTERO_GROUP_ID in .Renviron.", call. = FALSE)
  }
}

zotero_prefix <- function() paste0(ZOTERO_BASE, "/groups/", Sys.getenv("ZOTERO_GROUP_ID"))

#' A request to the group library. Waits when the server asks it to back off.
#' @param headers further headers, such as the version a PATCH expects
#' @param ... query parameters
zotero <- function(path, method = "GET", body = NULL, headers = list(), ...) {
  req <- polite_request(paste0(zotero_prefix(), path), ...) |>
    httr2::req_headers(`Zotero-API-Key` = Sys.getenv("ZOTERO_API_KEY"),
                       `Zotero-API-Version` = "3", !!!headers) |>
    httr2::req_method(method) |>
    httr2::req_timeout(120)
  if (!is.null(body)) req <- httr2::req_body_json(req, body, auto_unbox = TRUE, null = "null")
  resp <- httr2::req_perform(req)
  wait <- suppressWarnings(as.numeric(httr2::resp_header(resp, "Backoff", NA)))
  if (!is.na(wait)) Sys.sleep(wait)
  if (httr2::resp_status(resp) >= 400) {
    stop("Zotero ", method, " ", path, ": HTTP ", httr2::resp_status(resp), " ",
         httr2::resp_body_string(resp), call. = FALSE)
  }
  resp
}

#' Write objects in batches of 50; the keys created, in input order (NA where
#' Zotero refused one, with the reason logged).
zotero_write <- function(path, objects) {
  keys <- rep(NA_character_, length(objects))
  for (b in split(seq_along(objects), ceiling(seq_along(objects) / WRITE_BATCH))) {
    res <- httr2::resp_body_json(zotero(path, "POST", unname(objects[b])))
    for (i in names(res$successful)) keys[b[as.integer(i) + 1]] <- res$successful[[i]]$key
    for (i in names(res$failed)) log_msg("refused: ", res$failed[[i]]$message, level = "warn")
  }
  keys
}

#' Every collection in the group, as name, key and parent key.
list_collections <- function() {
  out <- list()
  start <- 0
  repeat {
    page <- httr2::resp_body_json(zotero("/collections", limit = 100, start = start))
    if (!length(page)) break
    out <- c(out, page)
    start <- start + 100
  }
  data.frame(name = vapply(out, function(x) x$data$name, ""),
             key = vapply(out, function(x) x$key, ""),
             parent = vapply(out, function(x) {
               p <- x$data$parentCollection
               if (isFALSE(p) || is.null(p)) "" else p
             }, ""))
}

#' The key of each folder named under a parent, made where missing.
ensure_folders <- function(names, parent, existing) {
  have <- existing[existing$parent == parent, ]
  missing <- setdiff(names, have$name)
  if (length(missing)) {
    new <- zotero_write("/collections", lapply(missing, function(n) {
      list(name = n, parentCollection = if (parent == "") FALSE else parent)
    }))
    have <- rbind(have, data.frame(name = missing, key = new, parent = parent))
  }
  setNames(have$key[match(names, have$name)], names)
}
