# What it does: Puts the included records into the shared Zotero group
#   library through the Zotero web API, with the PDFs
#   R/04_fetch/fetch_fulltext.R found.
#   One folder (collection) per outcome: Adoption, Costs, returns and
#   incentives, Carbon finance, Multiple outcomes or Outcome unclear (from
#   R/04_fetch/list_included.R), so each paper sits in exactly one. Each
#   defined practice the paper studies is a tag, "practice: <name>". Each
#   record is one Zotero item, never a copy.
#   Items with no PDF yet are tagged "cc4a_no_pdf_yet": select that tag in
#   Zotero desktop, run Find Available PDFs in batches of a few hundred,
#   and fetch what is still missing by hand.
# Reads: outputs/04_fulltext/included_records.csv
#        outputs/04_fulltext/fulltext_index.csv
#        outputs/04_fulltext/pdf/<record_id>.pdf
#        catalogues/vocab_practices.csv
# Writes: the Zotero group library
#         outputs/04_fulltext/zotero_items.csv   record_id, item and
#           attachment keys, so a stopped run resumes and nothing is added twice
# Flags: --dry       print the folders and counts, send nothing
#        --limit=    upload at most this many records, for a test run
#        --pdfs-only only upload the PDFs of records already in Zotero (after
#                    a new fetch)
# Needs in .Renviron: ZOTERO_API_KEY (with write access to the group) and
#   ZOTERO_GROUP_ID (the number in the group's URL on zotero.org).
#
# Run with:
#   Rscript R/04_fetch/zotero_upload.R --dry
#   Rscript R/04_fetch/zotero_upload.R --limit=20
#   Rscript R/04_fetch/zotero_upload.R

root <- rprojroot::find_root(rprojroot::has_file("CC4A.Rproj"))
source(file.path(root, "R/00_shared/paths.R"))
source(file.path(root, "R/00_shared/utils.R"))
readRenviron(file.path(root, ".Renviron"))

ZOTERO_BASE <- "https://api.zotero.org"
# Each practice is a tag, "practice: Biochar"; click tags in Zotero's tag
# selector to filter, two tags to see the papers with both.
PRACTICE_TAG <- "practice: "
NO_PRACTICE_LABEL <- "No defined practice"
NO_PDF_TAG <- "cc4a_no_pdf_yet"
# The API takes at most 50 objects per write.
WRITE_BATCH <- 50
# OpenAlex work types to Zotero item types; anything else is a "document".
ITEM_TYPES <- c(article = "journalArticle", review = "journalArticle",
                `book-chapter` = "bookSection", book = "book", dissertation = "thesis",
                `conference-paper` = "conferencePaper", report = "report",
                preprint = "preprint", dataset = "dataset")
# The field the journal or publisher name goes in, per item type.
VENUE_FIELD <- c(journalArticle = "publicationTitle", bookSection = "bookTitle",
                 conferencePaper = "proceedingsTitle", thesis = "university",
                 report = "institution", preprint = "repository", book = "publisher",
                 dataset = "repository", document = "publisher")

flags <- parse_flags()
dry <- isTRUE(flag(flags, "dry", FALSE))
key <- Sys.getenv("ZOTERO_API_KEY")
group <- Sys.getenv("ZOTERO_GROUP_ID")
if (!dry && (!nzchar(key) || !nzchar(group))) {
  stop("Set ZOTERO_API_KEY and ZOTERO_GROUP_ID in .Renviron.", call. = FALSE)
}
prefix <- paste0(ZOTERO_BASE, "/groups/", group)

#' A request to the group library. Waits when the server asks it to back off.
#' @param headers further headers, such as the version a PATCH expects
#' @param ... query parameters
zotero <- function(path, method = "GET", body = NULL, headers = list(), ...) {
  req <- polite_request(paste0(prefix, path), ...) |>
    httr2::req_headers(`Zotero-API-Key` = key, `Zotero-API-Version` = "3", !!!headers) |>
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

templates <- list()
#' The empty item of a type, from the API, so only valid fields are sent.
template <- function(type, ...) {
  id <- paste(type, ...)
  if (is.null(templates[[id]])) {
    templates[[id]] <<- httr2::resp_body_json(
      httr2::request(paste0(ZOTERO_BASE, "/items/new")) |>
        httr2::req_url_query(itemType = type, ...) |>
        httr2::req_perform())
  }
  templates[[id]]
}

#' A Zotero item for one record.
make_item <- function(r, collections, tags) {
  type <- unname(dplyr::coalesce(ITEM_TYPES[r$type], "document"))
  item <- template(type)
  set <- function(field, value) {
    if (field %in% names(item) && !is.na(value) && nzchar(value)) item[[field]] <<- value
  }
  set("title", r$title)
  set("abstractNote", r$abstract)
  set("date", r$publication_year)
  set("DOI", r$doi)
  set("url", if (!is.na(r$doi)) paste0("https://doi.org/", r$doi) else r$oa_url)
  set(VENUE_FIELD[[type]], r$journal)
  extra <- paste0("OpenAlex: ", r$record_id)
  if (!is.na(r$doi) && !"DOI" %in% names(item)) extra <- paste0(extra, "\nDOI: ", r$doi)
  item$extra <- extra
  authors <- trimws(strsplit(dplyr::coalesce(r$authors, ""), ";")[[1]])
  item$creators <- lapply(authors[nzchar(authors)], function(a) {
    parts <- strsplit(a, " ")[[1]]
    if (length(parts) == 1) return(list(creatorType = "author", name = a))
    list(creatorType = "author", firstName = paste(utils::head(parts, -1), collapse = " "),
         lastName = utils::tail(parts, 1))
  })
  item$collections <- as.list(unname(collections))
  item$tags <- lapply(tags, function(t) list(tag = t))
  item
}

#' Upload one PDF as a stored attachment of an item; the attachment key.
upload_pdf <- function(parent, record_id) {
  path <- file.path(DIR_PDF, paste0(record_id, ".pdf"))
  att <- template("attachment", linkMode = "imported_file")
  att$parentItem <- parent
  att$title <- "Full Text PDF"
  att$contentType <- "application/pdf"
  att$filename <- basename(path)
  att_key <- zotero_write("/items", list(att))
  if (is.na(att_key)) return(NA_character_)
  md5 <- unname(tools::md5sum(path))
  auth <- polite_request(paste0(prefix, "/items/", att_key, "/file")) |>
    httr2::req_headers(`Zotero-API-Key` = key, `Zotero-API-Version` = "3",
                       `If-None-Match` = "*") |>
    httr2::req_body_form(md5 = md5, filename = basename(path), filesize = file.size(path),
                         mtime = round(as.numeric(file.mtime(path)) * 1000)) |>
    httr2::req_perform() |>
    httr2::resp_body_json()
  if (!isTRUE(auth$exists == 1)) {
    body <- c(charToRaw(auth$prefix), readBin(path, "raw", file.size(path)),
              charToRaw(auth$suffix))
    httr2::request(auth$url) |>
      httr2::req_body_raw(body, type = auth$contentType) |>
      httr2::req_perform()
    polite_request(paste0(prefix, "/items/", att_key, "/file")) |>
      httr2::req_headers(`Zotero-API-Key` = key, `Zotero-API-Version` = "3",
                         `If-None-Match` = "*") |>
      httr2::req_body_form(upload = auth$uploadKey) |>
      httr2::req_perform()
  }
  att_key
}

log_step("Upload the included records to Zotero")

records <- read_csv_safe(FILE_INCLUDED)
if (!nrow(records)) stop("Run R/04_fetch/list_included.R first.", call. = FALSE)
index <- read_csv_safe(FILE_FETCH_INDEX)
has_pdf <- records$record_id %in% index$record_id[index$status %in% "ok"]
vocab <- read_csv_safe(FILE_VOCAB_PRACTICES)
scope_note <- c(in_scope = "", not_taken_forward = " (not taken forward)",
                out_of_scope = " (out of scope)")
practice_tag <- setNames(paste0(PRACTICE_TAG, vocab$label,
                                dplyr::coalesce(scope_note[vocab$scope], "")),
                         vocab$practice_code)
practice_tag <- c(practice_tag, none = paste0(PRACTICE_TAG, NO_PRACTICE_LABEL))

if (dry) {
  log_msg(nrow(records), " records, ", sum(has_pdf), " with a PDF to upload")
  print(table(records$outcome_folder))
  tags <- unlist(strsplit(records$practices, "; "))
  print(sort(table(practice_tag[tags]), decreasing = TRUE))
  quit(save = "no")
}

done <- read_csv_safe(FILE_ZOTERO_ITEMS)
folder_key <- ensure_folders(sort(unique(records$outcome_folder)), "", list_collections())

# Items
todo <- records[!records$record_id %in% done[["record_id"]], ]
limit <- flag(flags, "limit", NULL)
if (!is.null(limit)) todo <- utils::head(todo, as.integer(limit))
if (isTRUE(flag(flags, "pdfs-only", FALSE))) todo <- todo[0, ]
log_msg(nrow(todo), " records to add")
for (b in split(seq_len(nrow(todo)), ceiling(seq_len(nrow(todo)) / WRITE_BATCH))) {
  batch <- todo[b, ]
  items <- lapply(seq_len(nrow(batch)), function(i) {
    r <- batch[i, ]
    tags <- c(unname(practice_tag[strsplit(r$practices, "; ")[[1]]]),
              if (!r$record_id %in% index$record_id[index$status %in% "ok"]) NO_PDF_TAG)
    make_item(r, folder_key[[r$outcome_folder]], tags)
  })
  keys <- zotero_write("/items", items)
  rows <- data.frame(record_id = batch$record_id, item_key = keys, attachment_key = NA,
                     added_on = as.character(Sys.Date()))[!is.na(keys), ]
  write_csv_safe(rows, FILE_ZOTERO_ITEMS, append = TRUE)
  log_msg(sprintf("%d/%d items added", max(b), nrow(todo)))
}

# PDFs, for items that have none uploaded yet
done <- read_csv_safe(FILE_ZOTERO_ITEMS)
need <- done[is.na(done$attachment_key) &
               done$record_id %in% index$record_id[index$status %in% "ok"], ]
log_msg(nrow(need), " PDFs to upload")
for (i in seq_len(nrow(need))) {
  att <- tryCatch(upload_pdf(need$item_key[i], need$record_id[i]), error = function(e) {
    log_msg(need$record_id[i], ": ", conditionMessage(e), level = "warn")
    NA_character_
  })
  if (!is.na(att)) {
    done$attachment_key[done$record_id == need$record_id[i]] <- att
    # The tag no longer applies once the PDF is there.
    item <- httr2::resp_body_json(zotero(paste0("/items/", need$item_key[i])))
    tags <- Filter(function(t) t$tag != NO_PDF_TAG, item$data$tags)
    zotero(paste0("/items/", need$item_key[i]), "PATCH", list(tags = tags),
           headers = list(`If-Unmodified-Since-Version` = item$version))
  }
  if (i %% 25 == 0 || i == nrow(need)) {
    write_csv_safe(done, FILE_ZOTERO_ITEMS)
    log_msg(sprintf("%d/%d PDFs uploaded", i, nrow(need)))
  }
}
log_msg(sprintf("%d records in Zotero, %d with a PDF", nrow(done),
                sum(!is.na(done$attachment_key))), level = "done")
