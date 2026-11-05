# What it does: Tags every searched record with the defined practices
#   (catalogues/vocab_practices.csv) its title or abstract names. The searches
#   and the screening model work with the 15 broader keyword groups of
#   docs/synthesis/key-words.xlsx; this puts each record under the practices
#   the review actually defines, so the progress report counts by those.
#   A record counts under a practice when its title or abstract contains one
#   of that practice's synonyms: whole words, any case, hyphens read as
#   spaces, a plural s allowed. Synonyms written in capitals (AWD, SRI, DSR,
#   ISFM) must match in capitals, so "Sri Lanka" is not SRI. Bare terms that
#   need livestock in view count only next to a livestock term: hay or
#   supplementation for feed management (the vocabulary's own rule), and
#   shade trees for silvopasture (otherwise every shade coffee or cocoa paper
#   lands there). A record naming no practice is tagged "none". Rules only, no
#   model, no cost.
# Reads: outputs/01_search/search_records_vs_wb2022.csv  titles and abstracts
#        catalogues/vocab_practices.csv                  practices and synonyms
# Writes: outputs/03_screen/record_practices.csv  one row per record and
#                                                 practice, with the terms
#                                                 that matched
# Flags: none.
#
# Run with:
#   Rscript R/03_screen/tag_practices.R
# Rerun after a new search, or after synonyms change in the vocabulary.

root <- rprojroot::find_root(rprojroot::has_file("CC4A.Rproj"))
source(file.path(root, "R/00_shared/paths.R"))
source(file.path(root, "R/00_shared/utils.R"))

# Synonyms that count only next to a livestock term (see the header).
NEEDS_LIVESTOCK <- c(feed_mgmt = "hay|supplementation", silvopasture = "shade trees")
LIVESTOCK_TERMS <- paste0("\\b(livestock|cattle|cows?|dairy|goats?|sheep|ruminants?|",
                          "heifers?|calves|calf|beef|milk|animals?|herds?|steers?|bulls?)\\b")

#' Text in one shape for matching: hyphens and slashes read as spaces.
flatten_text <- function(x) {
  x <- gsub("[-/]", " ", dplyr::coalesce(x, ""))
  gsub("[[:space:]]+", " ", x)
}

#' The pattern for one synonym. Capitals stay case sensitive.
synonym_pattern <- function(term) {
  term <- trimws(term)
  acronym <- grepl("^[A-Z0-9]{2,}$", term)
  body <- flatten_text(if (acronym) term else tolower(term))
  body <- gsub("([][{}()+*.^$|?\\\\])", "\\\\\\1", body)
  list(acronym = acronym,
       pattern = paste0("(?<![A-Za-z0-9])", body, "(s|es)?(?![A-Za-z0-9])"))
}

log_step("Tag records with the defined practices")

records <- read_csv_safe(FILE_SEARCH_MATCHED)
vocab <- read_csv_safe(FILE_VOCAB_PRACTICES)
vocab <- vocab[!is.na(vocab$synonyms) & nzchar(vocab$synonyms), ]

text <- flatten_text(paste(records$title, records$abstract))
lower <- tolower(text)
has_livestock <- stringi::stri_detect_regex(lower, LIVESTOCK_TERMS)

tags <- list()
for (i in seq_len(nrow(vocab))) {
  code <- vocab$practice_code[i]
  terms <- trimws(strsplit(vocab$synonyms[i], ";", fixed = TRUE)[[1]])
  terms <- terms[nzchar(terms)]
  matched <- vapply(terms, function(t) {
    p <- synonym_pattern(t)
    stringi::stri_detect_regex(if (p$acronym) text else lower, p$pattern)
  }, logical(nrow(records)))
  matched <- matrix(matched, nrow = nrow(records))
  hit <- rowSums(matched) > 0
  if (code %in% names(NEEDS_LIVESTOCK)) {
    bare <- grepl(paste0("^(", NEEDS_LIVESTOCK[[code]], ")$"), tolower(terms))
    only_bare <- hit & rowSums(matched[, !bare, drop = FALSE]) == 0
    hit <- hit & (!only_bare | has_livestock)
  }
  idx <- which(hit)
  if (!length(idx)) next
  tags[[code]] <- tibble::tibble(
    record_id = records$record_id[idx],
    practice_code = code,
    matched_terms = apply(matched[idx, , drop = FALSE], 1,
                          function(m) paste(terms[m], collapse = "; "))
  )
  log_msg(sprintf("%-28s %6d records", code, length(idx)))
}

tagged <- dplyr::bind_rows(tags)
none <- setdiff(records$record_id, tagged$record_id)
out <- dplyr::bind_rows(
  tagged,
  tibble::tibble(record_id = none, practice_code = "none", matched_terms = "")
)
write_csv_safe(out, FILE_RECORD_PRACTICES)
log_msg(length(unique(tagged$record_id)), " of ", nrow(records),
        " records name at least one defined practice; ", length(none),
        " name none. Written to ", FILE_RECORD_PRACTICES, level = "done")
