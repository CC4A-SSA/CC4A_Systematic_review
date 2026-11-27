# What it does: Shows each paper's full text extraction status in the shared
#   Zotero group, for the papers that have been extracted (status "extracted"
#   or "qc_done" in extractions/fulltext/status.csv, written by py/batch.py). Each outcome
#   folder (Adoption; Carbon finance; Costs, returns and incentives; ...)
#   gets two subfolders, and each paper is moved out of its outcome folder
#   into one:
#     1. Extracted   kept at the full text screen
#     2. Rejected    excluded at the full text screen, with a tag naming the
#                    reason
#   and taken out of the other, so it is in only one. Folders outside its
#   outcome folder are kept. Tags added: "batch: 001",
#   "full text excluded: <reason>", "needs a person: <why>" when status.csv's
#   needs_person is filled (a supplementary table to find, a value to
#   settle), and "found: <outcome>" for each outcome the extraction found, so
#   outcomes the title and abstract screening missed show too.
#   Papers never extracted because every practice they are tagged with is out
#   of scope (extractions/fulltext/scope_excluded.csv, from py/batch.py scope)
#   go to "2. Rejected" too, tagged "excluded: practice out of scope: <tags>".
#   Synced papers are dated in zotero_synced; a later run sends only papers
#   extracted since, or with --all every extracted paper again (run it after
#   a person's check changes a decision, so the paper moves folder).
# Reads: extractions/fulltext/status.csv
#        extractions/fulltext/scope_excluded.csv
#        outputs/04_fulltext/zotero_items.csv   the Zotero item of each record
# Writes: the Zotero group library (the items' folders and tags)
#         extractions/fulltext/status.csv     the zotero_synced column
#         extractions/fulltext/scope_excluded.csv   the zotero_synced column
# Flags: --dry  print what would change, send nothing
#        --all  sync every extracted paper again
# Needs in .Renviron: ZOTERO_API_KEY (write access) and ZOTERO_GROUP_ID.
#
# Run with:
#   Rscript R/04_fetch/zotero_status.R --dry
#   Rscript R/04_fetch/zotero_status.R

root <- rprojroot::find_root(rprojroot::has_file("CC4A.Rproj"))
source(file.path(root, "R/00_shared/paths.R"))
source(file.path(root, "R/00_shared/utils.R"))
source(file.path(root, "R/00_shared/zotero.R"))
readRenviron(file.path(root, ".Renviron"))

STATUS_FOLDERS <- c(include = "1. Extracted", exclude = "2. Rejected")
OUTCOME_LABELS <- c(cost_return = "Costs and returns", adoption = "Adoption",
                    carbon = "Carbon finance")
# Tags this script owns; they are replaced on every sync, others are kept.
OWN_TAG <- "^(batch: |full text excluded: |excluded: |needs a person: |found: )"

flags <- parse_flags()
dry <- isTRUE(flag(flags, "dry", FALSE))
if (!dry) zotero_check_env()

log_step("Sync the full text status to Zotero")

status <- read.csv(FILE_EXTRACT_STATUS, colClasses = "character", na.strings = NULL)
items <- read_csv_safe(FILE_ZOTERO_ITEMS)
todo <- status[status$status %in% c("extracted", "qc_done") &
                 (isTRUE(flag(flags, "all", FALSE)) | status$zotero_synced == ""), ]
todo$item_key <- items$item_key[match(todo$record_id, items$record_id)]
if (any(is.na(todo$item_key))) {
  log_msg("not in Zotero, skipped: ", paste(todo$record_id[is.na(todo$item_key)],
                                            collapse = ", "), level = "warn")
  todo <- todo[!is.na(todo$item_key), ]
}
todo$folder <- todo$decision
todo$file <- rep("status", nrow(todo))
scope_all <- as.data.frame(read_csv_safe(FILE_SCOPE_EXCLUDED))
scope <- scope_all
if (nrow(scope)) {
  scope <- scope[isTRUE(flag(flags, "all", FALSE)) | is.na(scope$zotero_synced), , drop = FALSE]
  scope$item_key <- items$item_key[match(scope$record_id, items$record_id)]
  if (any(is.na(scope$item_key))) {
    log_msg("out of scope, not in Zotero, skipped: ", sum(is.na(scope$item_key)), level = "warn")
    scope <- scope[!is.na(scope$item_key), ]
  }
  scope$folder <- rep("exclude", nrow(scope))
  scope$file <- rep("scope", nrow(scope))
  todo <- rbind(todo[, c("record_id", "outcome_folder", "item_key", "folder", "file")],
                scope[, c("record_id", "outcome_folder", "item_key", "folder", "file")],
                make.row.names = FALSE)
}
log_msg(nrow(todo), " papers to sync (", sum(todo$file == "scope"), " out of scope)")
print(table(todo$outcome_folder, STATUS_FOLDERS[todo$folder], useNA = "ifany"))
if (dry || !nrow(todo)) quit(save = "no")

# The outcome folders, and the three status subfolders inside each.
existing <- list_collections()
outcome_key <- ensure_folders(sort(unique(todo$outcome_folder)), "", existing)
sub_key <- lapply(outcome_key, function(k) {
  keys <- ensure_folders(unname(STATUS_FOLDERS), k, list_collections())
  setNames(keys, names(STATUS_FOLDERS))
})

for (i in seq_len(nrow(todo))) {
  r <- todo[i, ]
  if (r$file == "scope") {
    sc <- scope[scope$record_id == r$record_id, ]
    new_tags <- paste0("excluded: practice out of scope: ", gsub("_", " ", sc$practices))
  } else {
    r <- cbind(r, status[status$record_id == r$record_id,
                         setdiff(names(status), names(r))])
    new_tags <- c(sprintf("batch: %03d", as.integer(r$batch)),
                  if (r$decision == "exclude")
                    paste0("full text excluded: ", gsub("_", " ", r$exclude_reason)),
                  if (r$needs_person != "") paste0("needs a person: ", r$needs_person),
                  paste0("found: ", OUTCOME_LABELS[trimws(strsplit(r$outcomes_found, ";")[[1]])]))
    new_tags <- new_tags[!grepl("found: NA$", new_tags)]
  }
  item <- httr2::resp_body_json(zotero(paste0("/items/", r$item_key)))
  own <- sub_key[[r$outcome_folder]]
  collections <- setdiff(unlist(item$data$collections),
                         c(outcome_key[[r$outcome_folder]], own))
  collections <- c(collections, own[[r$folder]])
  tags <- Filter(function(t) !grepl(OWN_TAG, t$tag), item$data$tags)
  tags <- c(tags, lapply(new_tags, function(t) list(tag = t)))
  zotero(paste0("/items/", r$item_key), "PATCH",
         list(collections = as.list(unname(collections)), tags = tags),
         headers = list(`If-Unmodified-Since-Version` = item$version))
  if (r$file == "scope") {
    scope_all$zotero_synced[scope_all$record_id == r$record_id] <- as.character(Sys.Date())
  } else {
    status$zotero_synced[status$record_id == r$record_id] <- as.character(Sys.Date())
  }
  if (i %% 10 == 0 || i == nrow(todo)) {
    write.csv(status, FILE_EXTRACT_STATUS, row.names = FALSE, na = "")
    if (nrow(scope_all)) write.csv(scope_all, FILE_SCOPE_EXCLUDED, row.names = FALSE, na = "")
    log_msg(sprintf("%d/%d synced", i, nrow(todo)))
  }
}
log_msg("done", level = "done")
