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
#        --refresh-filled  screen again the records screened on their title
#                      alone that have an abstract now (from
#                      R/01_search/fill_abstracts.R); their QC columns are kept
#        --max-usd=    stop before a batch would take the run past this many
#                      US dollars (default MAX_USD_DEFAULT)
#
# Run with:
#   Rscript R/03_screen/screen_scope.R --dry
#   Rscript R/03_screen/screen_scope.R --calibrate --model=gpt-4.1-mini
#   Rscript R/03_screen/screen_scope.R --limit=100
#   Rscript R/03_screen/screen_scope.R
#   Rscript R/03_screen/screen_scope.R --refresh-filled --dry
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

# A run stops before a batch would take it past this many US dollars. Raise
# it with --max-usd= once a --dry estimate says what a run needs.
MAX_USD_DEFAULT <- 5

# The QC columns a person fills in screen_scope.csv, carried over when a
# record is screened again.
QC_COLUMNS <- c("qc_sample", "qc_decision", "qc_note")

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

# The answer the model must give, as a JSON schema (OpenAI structured
# output, strict: every field present, nothing else).
yn <- function(what) list(type = "string", enum = list("yes", "no", "unclear"), description = what)
SCREEN_PROPERTIES <- list(
  countries = list(type = "array", items = list(type = "string"),
                   description = "Countries named, or empty"),
  in_africa = yn("Done in Africa"),
  practices = list(type = "array", items = list(type = "string"),
                   description = "Practice codes from the list, or empty"),
  practice_tested = yn("Produces evidence on a listed practice"),
  reports_cost = yn("Reports costs or profitability of the practice"),
  reports_adoption = yn("Reports adoption or its drivers"),
  reports_carbon_income = yn("Reports carbon credits, payments or benefit sharing"),
  study_type = list(type = "string", description = "Study type",
                    enum = list("field_experiment", "farm_survey", "project_evaluation",
                                "economic_analysis", "modelling_only",
                                "review_or_meta_analysis", "other")),
  evidence_quote = list(type = "string", description = "Words copied from the abstract, or empty"),
  reason = list(type = "string", description = "One sentence"),
  verdict = list(type = "string", enum = list("include", "exclude", "unsure"),
                 description = "The model's own call")
)
SCREEN_SCHEMA <- list(type = "object", properties = SCREEN_PROPERTIES,
                      required = as.list(names(SCREEN_PROPERTIES)),
                      additionalProperties = FALSE)

# What a record gets when the model's answer cannot be read: unsure, for a
# person. Its tokens are still counted, because they are still billed.
UNREADABLE_ANSWER <- list(
  countries = "", in_africa = "unclear", practices = "", practice_tested = "unclear",
  reports_cost = "unclear", reports_adoption = "unclear", reports_carbon_income = "unclear",
  study_type = NA_character_, evidence_quote = "",
  reason = "The model's answer could not be read; screen by hand.", verdict = "unsure"
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
    startsWith(d$reason, "The model's answer could not be read") ~ "unsure: model answer unreadable",
    TRUE ~ "unsure: something unclear"
  )
  # Without an abstract the model sees only a title: never exclude on that alone.
  rule <- ifelse(d$no_abstract & startsWith(rule, "exclude") &
                   !rule %in% "exclude: not in Africa", "unsure: title only", rule)
  list(decision = sub(":.*$", "", rule), decision_rule = rule)
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
    sprintf("Errors:     %s (not billed; retried on the next run)", state$errors),
    sprintf("Unreadable: %s (billed; kept as unsure, for a person)", state$unreadable),
    sprintf("Cost so far (this run): US$%.2f of the US$%.2f cap", state$cost, state$max_usd),
    sprintf("Time left:  %s", if (is.na(left)) "estimating..." else
      paste0("about ", ceiling(left), " min")),
    "",
    if (isTRUE(state$capped)) "STOPPED: the next batch would pass the spending cap (--max-usd=)."
    else if (state$finished) "FINISHED." else "Running. This file refreshes after every batch."
  )
  dir.create(dirname(FILE_SCREEN_PROGRESS), recursive = TRUE, showWarnings = FALSE)
  writeLines(lines, FILE_SCREEN_PROGRESS)
  log_msg(sprintf("%s/%s screened, %s include, %s unsure, US$%.2f",
                  state$done, state$total, state$counts[["include"]],
                  state$counts[["unsure"]], state$cost))
}

# ---- screening ------------------------------------------------------------------

#' One request to the OpenAI chat completions API for one record.
openai_request <- function(system_prompt, prompt, model) {
  body <- list(
    model = model,
    messages = list(list(role = "system", content = system_prompt),
                    list(role = "user", content = prompt)),
    response_format = list(type = "json_schema",
                           json_schema = list(name = "screening", strict = TRUE,
                                              schema = SCREEN_SCHEMA))
  )
  # Reasoning models (gpt-5 family) take no temperature, and get four times
  # the answer length for their hidden reasoning.
  if (grepl("^gpt-5", model)) {
    body$max_completion_tokens <- MAX_ANSWER_TOKENS * 4
  } else {
    body$temperature <- 0
    body$max_tokens <- MAX_ANSWER_TOKENS
  }
  polite_request("https://api.openai.com/v1/chat/completions") |>
    httr2::req_auth_bearer_token(Sys.getenv("OPENAI_API_KEY")) |>
    httr2::req_body_json(body) |>
    httr2::req_timeout(120)
}

#' Read one response. Each answer is parsed on its own, so a broken answer
#' costs its own record and nothing is sent twice. Returns the answer fields,
#' the billed tokens, and a status: "ok", "unreadable" (billed, kept as
#' unsure) or "failed" (the request itself failed: not billed, screened on
#' the next run).
read_answer <- function(resp) {
  if (is.null(resp)) return(list(status = "failed"))
  if (httr2::resp_status(resp) >= 400) {
    msg <- tryCatch(httr2::resp_body_json(resp)$error$message, error = function(e) "")
    log_msg("OpenAI HTTP ", httr2::resp_status(resp), ": ", substr(msg %||% "", 1, 150),
            level = "warn")
    return(list(status = "failed"))
  }
  body <- tryCatch(httr2::resp_body_json(resp), error = function(e) NULL)
  u <- body$usage
  cached <- u$prompt_tokens_details$cached_tokens %||% 0
  tokens <- c(input_tokens = (u$prompt_tokens %||% 0) - cached, cached_input_tokens = cached,
              output_tokens = u$completion_tokens %||% 0)
  content <- body$choices[[1]]$message$content
  a <- if (is.null(content)) NULL else
    tryCatch(jsonlite::fromJSON(content, simplifyVector = FALSE), error = function(e) NULL)
  if (is.null(a) || !all(names(SCREEN_PROPERTIES) %in% names(a))) {
    return(list(status = "unreadable", answer = UNREADABLE_ANSWER, tokens = tokens))
  }
  a$countries <- paste(unlist(a$countries), collapse = "; ")
  a$practices <- paste(unlist(a$practices), collapse = "; ")
  a <- lapply(a[names(SCREEN_PROPERTIES)], function(x) {
    if (is.null(x)) NA_character_ else as.character(x)
  })
  list(status = "ok", answer = a, tokens = tokens)
}

#' Screen a set of prompts in parallel. Returns one row per record whose
#' request succeeded (its answer read, or kept as unsure when unreadable),
#' and `failed`, TRUE for the records whose request failed.
screen_batch <- function(system_prompt, prompts, model) {
  reqs <- lapply(prompts, function(p) openai_request(system_prompt, p, model))
  resps <- httr2::req_perform_parallel(reqs, on_error = "continue", progress = FALSE,
                                       max_active = MAX_ACTIVE)
  answers <- lapply(resps, function(r) read_answer(if (inherits(r, "httr2_response")) r else NULL))
  failed <- vapply(answers, function(a) a$status == "failed", TRUE)
  rows <- dplyr::bind_rows(lapply(answers[!failed], function(a) {
    tibble::as_tibble(c(a$answer, as.list(a$tokens), list(answer_status = a$status)))
  }))
  list(res = rows, failed = failed)
}

#' Rows in the column order of the existing output file, so appended rows
#' line up with its header (a person may have added or moved columns). QC
#' columns a record had before it was screened again are put back.
align_to_file <- function(rows, out_file, carry) {
  if (!file.exists(out_file)) return(rows)
  header <- names(readr::read_csv(out_file, n_max = 0, show_col_types = FALSE,
                                  col_types = readr::cols(.default = readr::col_character())))
  for (col in setdiff(header, names(rows))) rows[[col]] <- NA_character_
  if (nrow(carry)) {
    hit <- match(rows$record_id, carry$record_id)
    for (col in intersect(QC_COLUMNS, names(carry))) {
      rows[[col]] <- ifelse(is.na(hit), rows[[col]], carry[[col]][hit])
    }
  }
  rows[, header]
}

screen_records <- function(records, system_prompt, model, out_file, label, max_usd,
                           carry = tibble::tibble()) {
  price <- PRICES[[model]] %||% c(NA, NA)
  done_before <- read_csv_safe(out_file)
  if (!nrow(done_before)) done_before <- tibble::tibble(record_id = character(), decision = character())
  todo <- records[!records$record_id %in% done_before$record_id, ]
  state <- list(label = label, model = model, start = Sys.time(), total = nrow(records),
                done = nrow(records) - nrow(todo), done_now = 0, errors = 0, unreadable = 0,
                cost = 0, max_usd = max_usd, capped = FALSE, finished = FALSE,
                counts = c(include = sum(done_before$decision == "include"),
                           unsure = sum(done_before$decision == "unsure"),
                           exclude = sum(done_before$decision == "exclude")))
  write_progress(state)
  for (b in split(seq_len(nrow(todo)), ceiling(seq_len(nrow(todo)) / BATCH_SIZE))) {
    # Stop before a batch that would pass the cap, judged on the cost per
    # record so far.
    per_record <- if (state$done_now > 0) state$cost / state$done_now else 0
    if (state$cost + per_record * length(b) > max_usd) {
      state$capped <- TRUE
      log_msg(sprintf("Spending cap of US$%.2f reached; %d records left for the next run",
                      max_usd, state$total - state$done), level = "warn")
      break
    }
    batch <- todo[b, ]
    prompts <- as.list(record_prompt(batch$title, batch$abstract))
    ok <- screen_batch(system_prompt, prompts, model)
    state$errors <- state$errors + sum(ok$failed)
    if (all(ok$failed)) {
      write_progress(state)
      next
    }
    # A record whose request failed is left out, and screened on the next run.
    batch <- batch[!ok$failed, ]
    res <- ok$res
    state$unreadable <- state$unreadable + sum(res$answer_status == "unreadable")
    res$no_abstract <- is.na(batch$abstract) | !nzchar(dplyr::coalesce(batch$abstract, ""))
    dec <- decide(res)
    rows <- dplyr::bind_cols(
      batch[, intersect(c("record_id", "doi", "title", "abstract", "publication_year", "found_by",
                          "in_wb2022", "wb_ref_id", "wb_status", "wb_positive",
                          "wb_extracted", "wb_africa", "abstract_source"),
                        names(batch))],
      dplyr::select(res, -answer_status),
      tibble::tibble(decision = dec$decision, decision_rule = dec$decision_rule,
                     model = model, screened_on = as.character(Sys.Date()))
    )
    rows$cost_usd <- (rows$input_tokens * price[1] + rows$cached_input_tokens * price[3] +
                        rows$output_tokens * price[2]) / 1e6
    rows <- dplyr::mutate(rows, dplyr::across(dplyr::everything(), as.character))
    write_csv_safe(align_to_file(rows, out_file, carry), out_file, append = TRUE)
    state$done <- state$done + nrow(batch)
    state$done_now <- state$done_now + nrow(batch)
    state$cost <- state$cost + sum(as.numeric(rows$cost_usd), na.rm = TRUE)
    for (k in names(state$counts)) state$counts[[k]] <- state$counts[[k]] + sum(rows$decision == k)
    write_progress(state)
  }
  state$finished <- !state$capped
  write_progress(state)
  read_csv_safe(out_file)
}

# ---- run ------------------------------------------------------------------------

flags <- parse_flags()
model <- flag(flags, "model", SCREEN_MODEL_DEFAULT)
max_usd <- as.numeric(flag(flags, "max-usd", MAX_USD_DEFAULT))
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

# --refresh-filled: the records screened on their title alone that have an
# abstract now are taken out of the output, so they are screened again; the
# rest are left as they are. Their QC columns are carried over.
carry <- tibble::tibble()
if (isTRUE(flag(flags, "refresh-filled", FALSE)) && label == "full run") {
  screened <- read_csv_safe(out_file)
  has_abstract <- records$record_id[nzchar(dplyr::coalesce(records$abstract, ""))]
  again <- screened$no_abstract %in% "TRUE" & screened$record_id %in% has_abstract
  log_msg(sum(again), " records screened on their title alone have an abstract now")
  if (isTRUE(flag(flags, "dry", FALSE))) {
    records <- records[records$record_id %in% screened$record_id[again], ]
  } else if (any(again)) {
    carry <- screened[again, intersect(c("record_id", QC_COLUMNS), names(screened))]
    write_csv_safe(screened[!again, ], out_file)
  }
}

if (isTRUE(flag(flags, "dry", FALSE))) {
  # About four characters a token. The instructions are billed at the cached
  # price after the first call; each record and about 250 output tokens are
  # billed in full. Reasoning models (gpt-5 family) add hidden reasoning
  # tokens on top, so their real cost can be several times this.
  # Records already screened are not sent again, so they are not counted.
  if (!isTRUE(flag(flags, "refresh-filled", FALSE))) {
    records <- records[!records$record_id %in% read_csv_safe(out_file)$record_id, ]
  }
  sys_tok <- nchar(system_prompt) / 4
  rec_tok <- sum(nchar(record_prompt(records$title, records$abstract)) / 4)
  est <- function(p) (nrow(records) * sys_tok * p[3] + rec_tok * p[1] + nrow(records) * 250 * p[2]) / 1e6
  log_msg(sprintf("%s records; instructions about %s tokens, records about %s tokens in total",
                  nrow(records), round(sys_tok), format(round(rec_tok), big.mark = ",")),
          level = "done")
  for (m in names(PRICES)) cat(sprintf("  %-14s about US$%6.2f\n", m, est(PRICES[[m]])))
  quit(save = "no")
}

if (!nzchar(Sys.getenv("OPENAI_API_KEY"))) stop("OPENAI_API_KEY is not set in .Renviron")
result <- screen_records(records, system_prompt, model, out_file, label, max_usd, carry)

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
