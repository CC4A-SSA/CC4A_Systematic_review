# What it does: Checks included records against the defined practices
#   (catalogues/vocab_practices.csv) with a GPT model. The title and abstract
#   screening judged "practice studied" against the 15 broader search keyword
#   groups, so it kept papers on, for example, plain manure or fertiliser
#   rates. This asks, for each record, which defined practices the study
#   evaluates, given each practice's definition and what does not count. Code
#   then decides:
#     keep                         fits at least one in scope practice
#     exclude: practice not taken forward or out of scope
#                                  fits only practices the review does not take
#     exclude: no defined practice fits none
#   By default only the included records whose title and abstract name no
#   practice synonym (R/03_screen/tag_practices.R) are checked.
# Reads: outputs/03_screen/screen_scope.csv       decisions, the model's reason
#        outputs/03_screen/record_practices.csv   synonym tags
#        catalogues/vocab_practices.csv           the definitions
# Writes: outputs/03_screen/practice_check.csv    one row per checked record:
#                                                 practices, reason, decision,
#                                                 tokens and cost
# Flags: --dry          estimate tokens and cost, call nothing
#        --limit=       check at most this many records, for a test run
#        --max-usd=     stop before a batch would pass this many US dollars
#                       (default MAX_USD_DEFAULT)
#        --model=       the OpenAI model (default MODEL_DEFAULT)
#        --all-included check every included record, not only the untagged ones
#
# Run with:
#   Rscript R/03_screen/classify_practices.R --dry
#   Rscript R/03_screen/classify_practices.R --limit=40
#   Rscript R/03_screen/classify_practices.R
# Picks up where it left off: records already in the output are skipped.

root <- rprojroot::find_root(rprojroot::has_file("CC4A.Rproj"))
source(file.path(root, "R/00_shared/paths.R"))
source(file.path(root, "R/00_shared/utils.R"))
readRenviron(file.path(root, ".Renviron"))

MODEL_DEFAULT <- "gpt-4.1-mini"
# US$ per million tokens: input, output, cached input.
PRICE <- c(0.40, 1.60, 0.10)
MAX_USD_DEFAULT <- 3
BATCH_SIZE <- 100
MAX_ACTIVE <- 20
MAX_ABSTRACT_CHARS <- 3000
MAX_ANSWER_TOKENS <- 200
OUT_FILE <- FILE_PRACTICE_CHECK

flags <- parse_flags()
model <- flag(flags, "model", MODEL_DEFAULT)
max_usd <- as.numeric(flag(flags, "max-usd", MAX_USD_DEFAULT))

vocab <- read_csv_safe(FILE_VOCAB_PRACTICES)
vocab <- vocab[vocab$scope %in% c("in_scope", "not_taken_forward", "out_of_scope"), ]
CODES <- c(vocab$practice_code, "none")

system_prompt <- paste0(
  "You check papers for a review of the costs, returns, adoption and carbon income of ",
  "climate adaptation practices in African agriculture. A first screen kept each paper below. ",
  "Decide which of the defined practices the paper studies as an intervention (its costs, ",
  "returns, adoption or carbon income), not one it only mentions. A paper fits a practice only ",
  "when the practice matches the definition and none of its exclusions. Studies of plain ",
  "fertiliser or manure rates, general irrigation, improved varieties, crop diversification or ",
  "technology packages without a defined practice fit none. Return every practice that fits, ",
  "or [\"none\"]. Give a reason of at most 25 words.\n\nThe defined practices:\n\n",
  paste0("- ", vocab$practice_code, " (", vocab$label, "): ", vocab$definition,
         ifelse(is.na(vocab$notes), "", paste0(" Does not count: ", vocab$notes)),
         collapse = "\n"))

SCHEMA <- list(
  type = "object", additionalProperties = FALSE, required = list("practices", "reason"),
  properties = list(
    practices = list(type = "array", items = list(type = "string", enum = as.list(CODES))),
    reason = list(type = "string")
  )
)

record_prompt <- function(title, abstract, reason) {
  paste0("Title: ", title, "\n\nAbstract: ",
         substr(dplyr::coalesce(abstract, ""), 1, MAX_ABSTRACT_CHARS),
         "\n\nThe first screen's reason for keeping it: ", dplyr::coalesce(reason, ""))
}

openai_request <- function(prompt) {
  polite_request("https://api.openai.com/v1/chat/completions") |>
    httr2::req_auth_bearer_token(Sys.getenv("OPENAI_API_KEY")) |>
    httr2::req_body_json(list(
      model = model, temperature = 0, max_tokens = MAX_ANSWER_TOKENS,
      messages = list(list(role = "system", content = system_prompt),
                      list(role = "user", content = prompt)),
      response_format = list(type = "json_schema",
                             json_schema = list(name = "practice_check", strict = TRUE,
                                                schema = SCHEMA)))) |>
    httr2::req_timeout(120)
}

#' One answer, or NULL when the request failed (not billed, tried next run).
read_answer <- function(resp) {
  if (!inherits(resp, "httr2_response") || httr2::resp_status(resp) >= 400) return(NULL)
  body <- tryCatch(httr2::resp_body_json(resp), error = function(e) NULL)
  if (is.null(body)) return(NULL)
  u <- body$usage
  cached <- u$prompt_tokens_details$cached_tokens %||% 0
  a <- tryCatch(jsonlite::fromJSON(body$choices[[1]]$message$content, simplifyVector = FALSE),
                error = function(e) list())
  p <- unlist(a$practices)
  list(practices = if (length(p)) paste(unique(p), collapse = "; ") else "unreadable",
       reason = a$reason %||% "",
       input_tokens = (u$prompt_tokens %||% 0) - cached, cached_input_tokens = cached,
       output_tokens = u$completion_tokens %||% 0)
}

#' keep / exclude from the practices the model returned.
decide <- function(practices) {
  scope <- setNames(vocab$scope, vocab$practice_code)
  vapply(strsplit(practices, "; ", fixed = TRUE), function(p) {
    s <- scope[p]
    if (any(s %in% "in_scope")) "keep"
    else if (any(!is.na(s))) "exclude: practice not taken forward or out of scope"
    else if (identical(p, "unreadable")) "keep: unreadable answer"
    else "exclude: no defined practice"
  }, "")
}

log_step("Check included records against the defined practices")

screen <- read_csv_safe(FILE_SCREEN)
qc <- tolower(trimws(dplyr::coalesce(screen$qc_decision, "")))
qc <- ifelse(startsWith(qc, "inc"), "include", ifelse(startsWith(qc, "ex"), "exclude",
             ifelse(startsWith(qc, "uns"), "unsure", NA)))
final <- ifelse(!is.na(screen$qc_sample) & !is.na(qc), qc, screen$decision)
todo <- screen[final %in% "include", ]
if (!isTRUE(flag(flags, "all-included", FALSE))) {
  tags <- read_csv_safe(FILE_RECORD_PRACTICES)
  todo <- todo[todo$record_id %in% tags$record_id[tags$practice_code == "none"], ]
}
done <- read_csv_safe(OUT_FILE)
if (nrow(done)) todo <- todo[!todo$record_id %in% done$record_id, ]
limit <- flag(flags, "limit", NULL)
if (!is.null(limit)) todo <- utils::head(todo, as.integer(limit))
log_msg(nrow(todo), " records to check with ", model)

if (isTRUE(flag(flags, "dry", FALSE))) {
  chars_sys <- nchar(system_prompt)
  chars_rec <- mean(nchar(record_prompt(todo$title, todo$abstract, todo$reason)))
  tok_sys <- chars_sys / 4
  tok_rec <- chars_rec / 4
  est <- nrow(todo) * (tok_sys * PRICE[3] + tok_rec * PRICE[1] + 60 * PRICE[2]) / 1e6
  est_nocache <- nrow(todo) * ((tok_sys + tok_rec) * PRICE[1] + 60 * PRICE[2]) / 1e6
  log_msg(sprintf("about %.0f instruction tokens + %.0f per record", tok_sys, tok_rec))
  log_msg(sprintf("about US$%.2f with the instructions cached, US$%.2f without", est,
                  est_nocache), level = "done")
  quit(save = "no")
}

cost <- 0
n_done <- 0
for (b in split(seq_len(nrow(todo)), ceiling(seq_len(nrow(todo)) / BATCH_SIZE))) {
  per_record <- if (n_done) cost / n_done else 0.002
  if (cost + per_record * length(b) > max_usd) {
    log_msg(sprintf("Spending cap of US$%.2f reached; %d records left", max_usd,
                    nrow(todo) - n_done), level = "warn")
    break
  }
  batch <- todo[b, ]
  reqs <- lapply(record_prompt(batch$title, batch$abstract, batch$reason), openai_request)
  resps <- httr2::req_perform_parallel(reqs, on_error = "continue", progress = FALSE,
                                       max_active = MAX_ACTIVE)
  answers <- lapply(resps, read_answer)
  ok <- !vapply(answers, is.null, TRUE)
  if (!any(ok)) {
    log_msg("every request in the batch failed", level = "warn")
    next
  }
  rows <- dplyr::bind_rows(lapply(answers[ok], tibble::as_tibble))
  rows <- dplyr::bind_cols(batch[ok, c("record_id", "title")], rows)
  rows$practice_decision <- decide(rows$practices)
  rows$cost_usd <- (rows$input_tokens * PRICE[1] + rows$cached_input_tokens * PRICE[3] +
                      rows$output_tokens * PRICE[2]) / 1e6
  rows$model <- model
  rows$checked_on <- as.character(Sys.Date())
  write_csv_safe(rows, OUT_FILE, append = TRUE)
  n_done <- n_done + nrow(rows)
  cost <- cost + sum(rows$cost_usd)
  log_msg(sprintf("%d/%d checked, %d failed in this batch, US$%.3f so far", n_done,
                  nrow(todo), sum(!ok), cost))
}

all <- read_csv_safe(OUT_FILE)
log_msg(sprintf("%d records checked in total, US$%.2f this run", nrow(all), cost), level = "done")
print(table(all$practice_decision))
