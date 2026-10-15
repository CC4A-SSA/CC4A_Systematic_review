# What it does: Title and abstract screening with a GPT model, after the ERA
#   workflow (eragriculture.github.io/AI-Powered-Meta-Analysis-Automation,
#   Screening_GPT): the model answers one question per criterion, and code
#   turns the answers into include, exclude or unsure, so every decision can
#   be traced to the criterion that set it. The model's own verdict is kept
#   beside the coded one. Papers human reviewers included in the 2022 World
#   Bank NbS review are shown to the model as examples, and used to measure
#   how many relevant papers it keeps (recall).
# Reads: outputs/01_search/search_records_vs_wb2022.csv   the records to screen
#        catalogues/screening_prompt.md                   the questions and rules
#        docs/synthesis/key-words.xlsx                    the practice list
#        data/wb_nbs_extraction_2022.xlsx                 Refs sheet: human includes
# Writes: outputs/03_screen/screen_scope.csv     one row per screened record
#         outputs/03_screen/progress.txt         live progress, rewritten every batch
#         outputs/03_screen/calibration_<model>.csv  with --calibrate
#         outputs/review/screen_calibration_for_person.csv  with --calibrate: a
#                                                random sample for a person to screen,
#                                                blind (the model's answers are not shown)
# Flags: --calibrate   screen the 2022 human includes found by the search plus a
#                      random sample, report recall, write the sample for a person
#        --dry         estimate tokens and cost, call nothing
#        --model=      the OpenAI model (default SCREEN_MODEL_DEFAULT)
#        --limit=      screen at most this many records, for a test run
#        --refresh     screen again records already in the output
#
# Run with:
#   Rscript R/03_screen/screen_scope.R --dry
#   Rscript R/03_screen/screen_scope.R --calibrate --model=gpt-4.1-mini
#   Rscript R/03_screen/screen_scope.R --limit=100
#   Rscript R/03_screen/screen_scope.R
# Watch a run: open outputs/03_screen/progress.txt (it refreshes every batch).

root <- rprojroot::find_root(rprojroot::has_file("CC4A.Rproj"))
source(file.path(root, "R/00_shared/paths.R"))
source(file.path(root, "R/00_shared/utils.R"))
readRenviron(file.path(root, ".Renviron"))

SCREEN_MODEL_DEFAULT <- "gpt-4.1-mini"

# US$ per million tokens: input, output, cached input (OpenAI price list,
# October 2026). The instructions are the same for every record, so after the
# first call OpenAI bills them at the cached price.
PRICES <- list(
  "gpt-4.1-mini" = c(0.40, 1.60, 0.10), "gpt-4.1-nano" = c(0.10, 0.40, 0.025),
  "gpt-5-nano" = c(0.05, 0.40, 0.005), "gpt-5-mini" = c(0.25, 2.00, 0.025),
  "gpt-5.4-nano" = c(0.20, 1.25, 0.02), "gpt-5.4-mini" = c(0.75, 4.50, 0.075),
  "gpt-5.6-luna" = c(0.20, 1.20, 0.02), "gpt-4o-mini" = c(0.15, 0.60, 0.075)
)

# Words of each practice's keyword string shown to the model, and characters
# of each example abstract: enough to define the practice and show the kind
# of paper; more only adds cost to every record.
PRACTICE_TERMS_SHOWN <- 8
EXAMPLE_CHARS <- 600

# Records sent to the model at once, and in parallel. Results are saved after
# every batch, so a stopped run loses at most one batch.
BATCH_SIZE <- 200
MAX_ACTIVE <- 20

# Abstracts are cut to this many characters; the opening carries what
# screening needs, and a few abstracts are pasted-in full texts.
MAX_ABSTRACT_CHARS <- 3000

# Longest answer allowed, in tokens (reasoning models get four times this,
# for their hidden reasoning).
MAX_ANSWER_TOKENS <- 700

# Calibration: how many 2022 human includes become examples in the prompt
# (they are then left out of the recall test), and how many random records a
# person screens to measure what the model wrongly keeps.
N_PROMPT_EXAMPLES <- 4
N_PERSON_SAMPLE <- 150
CALIBRATION_SEED <- 2026

# The 2022 status that means a person included the paper at title and
# abstract, for its economic outcomes. "Already in ERA - Extracted" papers are
# not counted: they were in ERA for yield data, not for costs.
WB_POSITIVE_PATTERN <- "^Included"
WB_EXTRACTOR_SHEETS <- c("Babra", "Brayden", "Elijah", "Gabi", "Lolita", "Namita",
                         "Pete", "Todd")

# ---- the prompt ---------------------------------------------------------------

practice_block <- function() {
  kw <- readxl::read_excel(FILE_KEYWORDS_XLSX, col_types = "text")
  names(kw) <- tolower(trimws(names(kw)))
  kw <- kw[!is.na(kw$keyword) & !kw$practice_group %in% "geography" &
             !grepl("^outcome", kw$practice_group), ]
  terms <- vapply(strsplit(gsub('"', "", kw$keyword), " OR "), function(t)
    paste(utils::head(trimws(t), PRACTICE_TERMS_SHOWN), collapse = ", "), "")
  paste0("- **", trimws(kw$practice_group), "**: ", kw$practice_label, " (", terms, ")",
         collapse = "\n")
}

#' The 2022 references: their status, whether a person included them at
#' title and abstract, whether economic data were then extracted from them,
#' their region, and their abstract (OpenAlex lacks a third of these).
wb_refs <- function() {
  r <- readxl::read_excel(FILE_WB2022, sheet = "Refs", col_types = "text")
  r <- r[!duplicated(r$ID), ]
  extracted <- unique(unlist(lapply(WB_EXTRACTOR_SHEETS, function(s) {
    readxl::read_excel(FILE_WB2022, sheet = s, col_types = "text",
                       .name_repair = "unique_quiet")$StudyID
  })))
  tibble::tibble(
    wb_ref_id = r$ID, wb_status = r$data_source_name,
    wb_positive = grepl(WB_POSITIVE_PATTERN, r$data_source_name),
    wb_extracted = r$ID %in% extracted,
    wb_africa = grepl("africa", r$gpt_region, ignore.case = TRUE),
    title = r$Title, abstract = r$Abstract
  )
}

#' Examples for the prompt: African papers the 2022 reviewers included that
#' the current search did not find, so the recall test is not shown its own
#' answers. One per practice group in the 2022 statuses, picked at random.
prompt_examples <- function(refs, searched_ids) {
  set.seed(CALIBRATION_SEED)
  pool <- refs[refs$wb_positive & refs$wb_africa & !refs$wb_ref_id %in% searched_ids &
                 nchar(dplyr::coalesce(refs$abstract, "")) > 400, ]
  pool <- pool[sample(nrow(pool)), ]
  pool <- pool[!duplicated(pool$wb_status), ]
  ex <- utils::head(pool, N_PROMPT_EXAMPLES)
  list(ids = ex$wb_ref_id,
       text = paste0("- *", ex$title, "*: ", substr(ex$abstract, 1, EXAMPLE_CHARS),
                     ifelse(nchar(ex$abstract) > EXAMPLE_CHARS, " ...", ""), collapse = "\n\n"))
}

build_system_prompt <- function(examples_text) {
  p <- paste(readLines(FILE_SCREEN_PROMPT, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  p <- sub("{practices}", practice_block(), p, fixed = TRUE)
  sub("{examples}", examples_text, p, fixed = TRUE)
}

record_prompt <- function(title, abstract) {
  abstract <- ifelse(is.na(abstract) | !nzchar(abstract), "(no abstract available)",
                     substr(abstract, 1, MAX_ABSTRACT_CHARS))
  paste0("Title: ", title, "\n\nAbstract: ", abstract)
}

# ---- the answers --------------------------------------------------------------

yn <- function(what) ellmer::type_enum(c("yes", "no", "unclear"), what)
SCREEN_TYPE <- ellmer::type_object(
  countries = ellmer::type_array(ellmer::type_string(), "Countries named, or empty"),
  in_africa = yn("Done in Africa"),
  practices = ellmer::type_array(ellmer::type_string(), "Practice codes from the list, or empty"),
  practice_tested = yn("Produces evidence on a listed practice"),
  reports_cost = yn("Reports costs or profitability of the practice"),
  reports_adoption = yn("Reports adoption or its drivers"),
  reports_carbon_income = yn("Reports carbon credits, payments or benefit sharing"),
  study_type = ellmer::type_enum(c("field_experiment", "farm_survey", "project_evaluation",
                                   "economic_analysis", "modelling_only",
                                   "review_or_meta_analysis", "other"), "Study type"),
  evidence_quote = ellmer::type_string("Words copied from the abstract, or empty"),
  reason = ellmer::type_string("One sentence"),
  verdict = ellmer::type_enum(c("include", "exclude", "unsure"), "The model's own call")
)

#' The coded decision, applied in this order. The first rule that fires sets
#' the decision and is named in decision_rule.
decide <- function(d) {
  outcome_yes <- d$reports_cost == "yes" | d$reports_adoption == "yes" |
    d$reports_carbon_income == "yes"
  outcome_no <- d$reports_cost == "no" & d$reports_adoption == "no" &
    d$reports_carbon_income == "no"
  primary <- d$study_type %in% c("field_experiment", "farm_survey", "project_evaluation",
                                 "economic_analysis")
  rule <- dplyr::case_when(
    d$in_africa == "no" ~ "exclude: not in Africa",
    d$study_type == "review_or_meta_analysis" ~ "exclude: review (keep for citation chasing)",
    d$practice_tested == "no" ~ "exclude: no listed practice studied",
    outcome_no ~ "exclude: no cost, adoption or carbon income evidence",
    d$study_type == "other" ~ "exclude: not a field, survey, evaluation or economic study",
    d$in_africa == "yes" & d$practice_tested == "yes" & outcome_yes & primary ~ "include",
    TRUE ~ "unsure: something unclear"
  )
  # Without an abstract the model sees only a title: never exclude on that alone.
  rule <- ifelse(d$no_abstract & startsWith(rule, "exclude") &
                   !rule %in% "exclude: not in Africa", "unsure: title only", rule)
  list(decision = sub(":.*$", "", rule), decision_rule = rule)
}

flatten <- function(res) {
  res |>
    dplyr::mutate(countries = vapply(countries, function(x) paste(unlist(x), collapse = "; "), ""),
                  practices = vapply(practices, function(x) paste(unlist(x), collapse = "; "), ""))
}

# ---- progress you can watch ---------------------------------------------------

write_progress <- function(state) {
  elapsed <- as.numeric(difftime(Sys.time(), state$start, units = "mins"))
  rate <- if (state$done_now > 0) elapsed / state$done_now else NA
  left <- if (!is.na(rate)) rate * (state$total - state$done) else NA
  lines <- c(
    paste("CC4A title and abstract screening:", state$label),
    paste("Model:", state$model, "| started", format(state$start, "%H:%M"),
          "| last update", format(Sys.time(), "%H:%M:%S")),
    "",
    sprintf("Screened:   %s of %s (%.1f%%)", format(state$done, big.mark = ","),
            format(state$total, big.mark = ","), 100 * state$done / max(state$total, 1)),
    sprintf("Include:    %s", format(state$counts[["include"]], big.mark = ",")),
    sprintf("Unsure:     %s", format(state$counts[["unsure"]], big.mark = ",")),
    sprintf("Exclude:    %s", format(state$counts[["exclude"]], big.mark = ",")),
    sprintf("Errors:     %s (retried on the next run)", state$errors),
    sprintf("Cost so far (this run): about US$%.2f", state$cost),
    sprintf("Time left:  %s", if (is.na(left)) "estimating..." else
      paste0("about ", ceiling(left), " min")),
    "",
    if (state$finished) "FINISHED." else "Running. This file refreshes after every batch."
  )
  dir.create(dirname(FILE_SCREEN_PROGRESS), recursive = TRUE, showWarnings = FALSE)
  writeLines(lines, FILE_SCREEN_PROGRESS)
  log_msg(sprintf("%s/%s screened, %s include, %s unsure, US$%.2f",
                  state$done, state$total, state$counts[["include"]],
                  state$counts[["unsure"]], state$cost))
}

# ---- screening ------------------------------------------------------------------

#' Screen a set of prompts in parallel. When one answer cannot be read (the
#' model now and then writes broken JSON), the whole call fails; the set is
#' then split in half and each half tried again, down to single records, so
#' one bad answer costs one record, not a batch. Returns the answers for the
#' records that worked, and `keep`, TRUE for those and NA for the rest.
screen_batch <- function(chat, prompts) {
  res <- tryCatch(
    ellmer::parallel_chat_structured(chat, prompts, SCREEN_TYPE, include_tokens = TRUE,
                                     max_active = MAX_ACTIVE),
    error = function(e) {
      if (length(prompts) == 1) log_msg("record failed, retried next run: ",
                                        substr(conditionMessage(e), 1, 120), level = "warn")
      NULL
    }
  )
  if (!is.null(res)) return(list(res = res, keep = rep(TRUE, length(prompts))))
  if (length(prompts) == 1) return(list(res = NULL, keep = NA))
  half <- seq_len(length(prompts)) <= length(prompts) / 2
  a <- screen_batch(chat, prompts[half])
  b <- screen_batch(chat, prompts[!half])
  list(res = dplyr::bind_rows(a$res, b$res), keep = c(a$keep, b$keep))
}

screen_records <- function(records, chat, model, out_file, label) {
  price <- PRICES[[model]] %||% c(NA, NA)
  done_before <- read_csv_safe(out_file)
  if (!nrow(done_before)) done_before <- tibble::tibble(record_id = character(), decision = character())
  todo <- records[!records$record_id %in% done_before$record_id, ]
  state <- list(label = label, model = model, start = Sys.time(), total = nrow(records),
                done = nrow(records) - nrow(todo), done_now = 0, errors = 0, cost = 0,
                finished = FALSE,
                counts = c(include = sum(done_before$decision == "include"),
                           unsure = sum(done_before$decision == "unsure"),
                           exclude = sum(done_before$decision == "exclude")))
  write_progress(state)
  for (b in split(seq_len(nrow(todo)), ceiling(seq_len(nrow(todo)) / BATCH_SIZE))) {
    batch <- todo[b, ]
    prompts <- as.list(record_prompt(batch$title, batch$abstract))
    ok <- screen_batch(chat, prompts)
    failed <- is.na(ok$keep)
    state$errors <- state$errors + sum(failed)
    if (all(failed)) {
      write_progress(state)
      next
    }
    # A record whose answer could not be read is left out, and screened again
    # on the next run.
    batch <- batch[!failed, ]
    res <- flatten(ok$res)
    res$no_abstract <- is.na(batch$abstract) | !nzchar(dplyr::coalesce(batch$abstract, ""))
    dec <- decide(res)
    rows <- dplyr::bind_cols(
      batch[, intersect(c("record_id", "doi", "title", "publication_year", "found_by",
                          "in_wb2022", "wb_ref_id", "wb_status", "wb_positive",
                          "wb_extracted", "wb_africa", "abstract_source"),
                        names(batch))],
      res, tibble::tibble(decision = dec$decision, decision_rule = dec$decision_rule,
                          model = model, screened_on = as.character(Sys.Date()))
    )
    cached <- if ("cached_input_tokens" %in% names(rows)) dplyr::coalesce(rows$cached_input_tokens, 0) else 0
    rows$cost_usd <- (rows$input_tokens * price[1] + cached * price[3] +
                        rows$output_tokens * price[2]) / 1e6
    write_csv_safe(dplyr::mutate(rows, dplyr::across(dplyr::everything(), as.character)),
                   out_file, append = TRUE)
    state$done <- state$done + nrow(batch)
    state$done_now <- state$done_now + nrow(batch)
    state$cost <- state$cost + sum(rows$cost_usd, na.rm = TRUE)
    for (k in names(state$counts)) state$counts[[k]] <- state$counts[[k]] + sum(rows$decision == k)
    write_progress(state)
  }
  state$finished <- TRUE
  write_progress(state)
  read_csv_safe(out_file)
}

# ---- run ------------------------------------------------------------------------

flags <- parse_flags()
model <- flag(flags, "model", SCREEN_MODEL_DEFAULT)
limit <- flag(flags, "limit", NULL)
log_step(paste("Step 3: title and abstract screening with", model))

records <- read_csv_safe(FILE_SEARCH_MATCHED)
if (!"abstract_source" %in% names(records)) records$abstract_source <- NA_character_
refs <- wb_refs()
records <- records |>
  dplyr::mutate(wb_ref_id = sub("[.]0$", "", wb_ref_id)) |>
  dplyr::select(-dplyr::any_of("wb_status")) |>
  dplyr::left_join(dplyr::select(refs, wb_ref_id, wb_status, wb_positive, wb_extracted,
                                 wb_africa, wb_abstract = abstract),
                   by = "wb_ref_id") |>
  # The search step fills missing abstracts from the 2022 refs; this repeats
  # it for a record file made before it did.
  dplyr::mutate(
    abstract_source = dplyr::case_when(
      nzchar(dplyr::coalesce(abstract, "")) ~ dplyr::coalesce(abstract_source, "openalex"),
      nzchar(dplyr::coalesce(wb_abstract, "")) ~ "wb2022",
      TRUE ~ "none"),
    abstract = ifelse(abstract_source == "wb2022" & !nzchar(dplyr::coalesce(abstract, "")),
                      wb_abstract, abstract)
  ) |>
  dplyr::select(-wb_abstract)
ex <- prompt_examples(refs, records$wb_ref_id)
system_prompt <- build_system_prompt(ex$text)
log_msg(nrow(records), " records; prompt examples: 2022 refs ", paste(ex$ids, collapse = ", "))

if (isTRUE(flag(flags, "calibrate", FALSE))) {
  set.seed(CALIBRATION_SEED)
  # Every record the 2022 review had any status for (so all can be compared),
  # plus a random sample of the rest for a person to screen.
  known <- records[!is.na(records$wb_status), ]
  others <- records[is.na(records$wb_status) & records$abstract_source != "none", ]
  sample_person <- others[sample(nrow(others), min(N_PERSON_SAMPLE, nrow(others))), ]
  records <- dplyr::bind_rows(dplyr::mutate(known, calibration_set = "2022 reference"),
                              dplyr::mutate(sample_person, calibration_set = "random sample"))
  out_file <- screen_calibration_file(model)
  label <- "calibration"
} else {
  out_file <- FILE_SCREEN
  label <- "full run"
}
if (!is.null(limit)) records <- utils::head(records, as.integer(limit))
if (isTRUE(flag(flags, "refresh", FALSE)) && file.exists(out_file)) file.remove(out_file)

if (isTRUE(flag(flags, "dry", FALSE))) {
  # About four characters a token. The instructions are billed at the cached
  # price after the first call; each record and about 250 output tokens are
  # billed in full. Reasoning models (gpt-5 family) add hidden reasoning
  # tokens on top, so their real cost can be several times this.
  sys_tok <- nchar(system_prompt) / 4
  rec_tok <- sum(nchar(record_prompt(records$title, records$abstract)) / 4)
  est <- function(p) (nrow(records) * sys_tok * p[3] + rec_tok * p[1] + nrow(records) * 250 * p[2]) / 1e6
  log_msg(sprintf("%s records; instructions about %s tokens, records about %s tokens in total",
                  nrow(records), round(sys_tok), format(round(rec_tok), big.mark = ",")),
          level = "done")
  for (m in names(PRICES)) cat(sprintf("  %-14s about US$%6.2f\n", m, est(PRICES[[m]])))
  quit(save = "no")
}

# A normal answer is about 120 tokens. The cap stops the rare runaway answer
# (the model looping inside a string) within seconds instead of minutes.
chat <- ellmer::chat_openai(
  system_prompt = system_prompt, model = model,
  params = if (grepl("^gpt-5", model)) ellmer::params(max_tokens = MAX_ANSWER_TOKENS * 4)
           else ellmer::params(temperature = 0, max_tokens = MAX_ANSWER_TOKENS)
)
result <- screen_records(records, chat, model, out_file, label)

if (label == "calibration") {
  r <- dplyr::left_join(result, dplyr::distinct(records, record_id, calibration_set), by = "record_id")
  # Recall: of the papers a person kept in 2022, how many the model keeps
  # (include or unsure). Outside Africa the CC4A rule excludes them by design,
  # so the Africa figure is the one that counts; the practice and cost
  # questions are checked on all of them.
  recall <- function(d, set) {
    af <- d[d$wb_africa %in% "TRUE", ]
    cat(sprintf("\n  %s: %d papers (%d in Africa)\n", set, nrow(d), nrow(af)))
    cat(sprintf("    practice studied (yes or unclear):     %3.0f%%\n", 100 * mean(d$practice_tested != "no")))
    cat(sprintf("    cost evidence (yes or unclear):        %3.0f%%\n", 100 * mean(d$reports_cost != "no")))
    cat(sprintf("    kept in Africa (include or unsure):    %3.0f%%  (protocol target 95%%)\n",
                100 * mean(af$decision != "exclude")))
  }
  ref <- r[r$calibration_set == "2022 reference", ]
  cat("\nCalibration with", model, "\n")
  recall(ref[ref$wb_positive %in% "TRUE", ], "Included by a person at title and abstract in 2022")
  recall(ref[ref$wb_extracted %in% "TRUE", ], "Economic data extracted in 2022")
  cat(sprintf("\n  Random sample for a person: %d records; model includes %d, unsure %d, excludes %d\n",
              sum(r$calibration_set == "random sample"),
              sum(r$calibration_set == "random sample" & r$decision == "include"),
              sum(r$calibration_set == "random sample" & r$decision == "unsure"),
              sum(r$calibration_set == "random sample" & r$decision == "exclude")))
  cat(sprintf("  Cost of this calibration: US$%.2f\n", sum(as.numeric(r$cost_usd), na.rm = TRUE)))
  person <- r[r$calibration_set == "random sample", ] |>
    dplyr::left_join(dplyr::select(records, record_id, abstract), by = "record_id") |>
    dplyr::transmute(record_id, title, abstract,
                     your_decision = "", your_note = "")
  write_csv_safe(person, FILE_SCREEN_HUMAN_SAMPLE)
  log_msg("random sample for a person written to ", FILE_SCREEN_HUMAN_SAMPLE, level = "done")
}
