# CC4A: evidence synthesis for carbon crediting practices in Africa

Carbon Credits 4 Adaptation (CC4A), Activity 2 of INV-089367, needs to know
for every practice it might finance: how much it raises yield in a normal
year, how much loss it avoids when drought, heat or flood hits, what it
costs, and how widely it is already used. This repository is the machinery
that reads that evidence out of the literature, checks it, and hands it on
as tables: practice recipes and a loss matrix for the geospatial engine, and
a cost table, adoption tables and a benefit sharing table for Chun Song's net
economic benefit analysis.

**The protocol is `docs/synthesis/`**, the handover pack Pete Steward wrote,
plus an addendum for Chun's requirements. Start with `docs/protocol.md`,
which indexes it. Section 1 below explains how the review runs, in plain
terms. The pipeline is being moved to the protocol in phases (§10); until
then, parts of sections 2 to 9 describe the first design, which covered costs
and adoption only.

Contact: Namita Joshi, Alliance Bioversity International and CIAT
(n.joshi@cgiar.org). Namita leads the synthesis; this repository is the copy
of record for the protocol.

## Contents

1. [How the review runs](#1-how-the-review-runs)
2. [The seven steps](#2-the-seven-steps)
3. [What the repository carries](#3-what-the-repository-carries)
4. [A tour of the scripts](#4-a-tour-of-the-scripts)
5. [The extraction schema](#5-the-extraction-schema)
6. [Keywords and search strategy](#6-keywords-and-search-strategy)
7. [Installation and keys](#7-installation-and-keys)
8. [How to run it](#8-how-to-run-it)
9. [Output map](#9-output-map)
10. [Current state](#10-current-state)
11. [Extending it](#11-extending-it)
12. [House rules](#12-house-rules)

## 1. How the review runs

The whole review in one section: what we look for, the route a paper takes
from search to table, who does what, and what is automated today. The detail
behind each part is in the protocol file named in brackets.

### 1.1 Four questions, four searches

The review asks four questions. Each has its own search, its own literature
and its own screening funnel, and they run at the same time.

| Stream | Question | Main sources | Lands in |
|---|---|---|---|
| 1. Practice evidence | For each practice: how much does it raise yield in a normal year, how much loss does it avoid in a drought, heat or flood season, how does it work, what does it cost, how long does it last? | ERA, meta-analyses, field trials, project evaluations, grey literature | Practice recipes; cost table; benefit sharing (`03` §1) |
| 2. Long term trials and datasets | Which trials and datasets ran the practice across years that include bad seasons, so avoided loss can be measured rather than assumed? | ERA's multi-season studies, CGIAR and national long term trials, trial networks | Dataset register (`03` §2) |
| 3. The loss matrix | Without any practice: how much production is lost at moderate, severe and extreme drought, heat or flood, per crop and livestock system? | Managed stress trials, yield and weather studies, crop assessments after droughts | Loss matrix (`03` §3) |
| 4. Adoption | How widely is each practice used, what makes farmers adopt it, how do they respond to payments, and what share of carbon income reaches them? | Household surveys (LSMS-ISA), adoption studies, choice experiments, project and carbon project documents | Adoption, adoption driver and benefit sharing tables (`03` §4, `10`) |

The thirteen practices in scope, their definitions and their boundaries are
in `01-practice-definitions.md`, and as a table the scripts read in
`catalogues/vocab_practices.csv`. Three pilots go first: biochar, AWD rice and
rotational grazing.

### 1.2 The route a paper takes

Every practice goes through the same stages. "AI" means a model run from this
repository, or an AI session following `docs/synthesis/CLAUDE.md`, with every
call logged.

| # | Stage | What happens | Who | Output |
|---|---|---|---|---|
| 0 | Set up the practice | Read its definition (`01`). Build a known includes set: the seed papers plus ERA's trials for it. Test each search string: hit counts, and it must find at least 90% of the known includes | Namita | Tested strings; known includes set |
| 1 | Search | Sources in order: ERA first (it already holds treatment and control means with coordinates), then meta-analyses (to harvest their primary studies), then the database strings per stream, then grey literature and carbon project documents, then citation chasing from the best studies. Every search is logged with its exact string, date and hit count so anyone can rerun it | AI, with Namita choosing sources | Search log; raw records |
| 2 | Remove duplicates | One row per study. Companion papers and the ERA record of the same trial share one `trial_id`, so a trial is never counted twice | Code | Deduplicated records |
| 3 | Screen titles and abstracts | Calibration first: Namita and a second screener each screen the first 100 records; AI screening only becomes routine once they agree (kappa of at least 0.7) and the AI keeps at least 95% of the known includes. Then two independently prompted AI screens. Anything either includes, and every disagreement, goes to Namita. She also checks 150 records both screens excluded | AI twice, Namita decides | Screening log with reasons |
| 4 | Screen full texts | Read the paper; include, or exclude with a reason from the fixed list (not the practice, no comparator, pot trial only, method paper, and so on) | Namita | PRISMA style counts per practice |
| 5 | Extract | The AI fills the extraction template (`extraction_template.xlsx`): one row per study, site season, effect, cost and so on. Every number carries the verbatim text and the page, table or figure it came from. Treatment and control results are taken separately for bad and normal seasons, with coordinates and dates. Null and negative results are kept | AI, Namita spot checks and signs off each batch | Filled template, `quote` rows |
| 6 | Verify | A separate AI session, ideally a different model, that never saw the extraction. Check A: does the quoted text exist where it says? Check B: does it actually support the claim (right arm, right season, right unit)? Check C: read the key numbers blind and compare. Known errors are planted to measure how many the verifier catches. Failures are logged and sent back, never quietly fixed | AI verifier; adjudicator settles disputes; Pete or a reviewer audits 10% | `verification` rows; error rates |
| 7 | Classify seasons | S5 labels each site season as normal, moderate, severe or extreme from its coordinates and dates, against the hazard maps. Extraction never does this | S5 | Classified site seasons |
| 8 | Estimate and grade | S5's pre-specified model turns the season means into buffering and production coefficients. Namita proposes the evidence tier and the mechanism; the reviewer confirms | S5, Namita | Coefficients; proposed tiers |
| 9 | Review and publish | A named reviewer who did not write the recipe signs off its logic. The recipe, loss matrix and tables are released | Reviewer | Practice recipes and tables |

Stages 0 to 6 are the synthesis. Stages 7 to 9 are shared with S5 and the
reviewers. Streams 1 and 3 use all of them. Stream 2 is worked by hand from
ERA and the trial archives rather than by keyword search, and its site lists
go to S5 before any data are requested. Stream 4 stops at stage 6: adoption,
driver and benefit sharing rows need no season classification.


## 2. The seven steps

| Step | Folder | What happens |
|---|---|---|
| 1 | `R/01_search` | Keyword blocks are crossed into queries and sent to the OpenAlex works API. Africa and the publication window are filtered on the server, so only a plausible result set is ever downloaded. Each row remembers which query found it. |
| 2 | `R/02_dedup` | The result set collapses to one row per study. DOIs settle most of it; a fuzzy title comparison catches the rest. Rows that lose are not deleted, they are registered with the reason. |
| 3 | `R/03_screen` | A model reads title and abstract and answers whether the study is worth downloading: does it carry a number, is the subject an adaptation practice, is it set in Africa, is it inside the window. Code then audits the answer and sends the doubtful cases to a person. |
| 4 | `R/04_fetch` | Full text, chased through Unpaywall, then the DOI, then the publisher. Downloads are inspected before they are trusted, because a login page saved as a PDF is still a PDF. |
| 5 | `R/05_extract` | A model reads the paper and returns parameter rows in the paper's own words: the number, the unit as written, the page, the sentence. Code then looks for each sentence on the page it was attributed to. Anything it cannot find is discarded. |
| 6 | `R/06_harmonise` | Verified rows are mapped onto the controlled vocabularies and the units are made comparable. Lookup tables do most of it, a cache does the rest, and one batched model call handles the remainder. |
| 7 | `R/07_publish` | The Excel parameter database in schema order, a provenance sheet, a sheet of rows worth a second look, the bill for the run, and the score against the gold set. |

A diagram of this belongs in `docs/workflow_diagram.md`, which currently holds
the same seven steps as a sketch.

What the protocol changes, step by step:

| Step | Change | Protocol |
|---|---|---|
| 1 | ERA first, then databases; grey literature and carbon project documents taken in by hand; strings per stream | `synthesis/03` |
| 3 | Two independent model screens, kappa of at least 0.7 before screening goes routine, recall of at least 95% on a known includes set, a sample of double exclusions checked by a person | `synthesis/03` §0 |
| 5 | Linked tables (source, study, site season, effect, cost, quote) instead of one flat row per parameter; cell means by season with coordinates and dates | `synthesis/02` |
| new | Verification: does the quote exist, does it support the claim, blind re-extraction of key numbers, planted errors; failures logged, never silently fixed | `synthesis/04` |
| 6 | No currency conversion. Currency and price year are recorded as reported; Chun converts | `synthesis/00` D5 |
| 7 | Exports the filled extraction template, which Chun reads directly, and draft recipes | `synthesis/10` §4 |

## 3. What the repository carries

The repository carries scripts and the small tables those scripts read. It
carries no papers, no run output and no credentials.

| Here | Not here |
|---|---|
| `R/`, every script | Downloaded full texts, which land in `outputs/04_fulltext/pdf/` |
| `catalogues/`, the vocabularies, keyword list, gold set and decision cache | Everything under `outputs/`, git ignored and rebuilt by the scripts |
| `docs/protocol.md` and `docs/synthesis/`, the review protocol | `catalogues/search_raw.csv`, the raw result set, rebuilt by step 1 |
| `CLAUDE.md` and `.claude/`, notes for AI coding sessions | API keys, which live in `.Renviron` and are git ignored |

Layout is settled in one file, `R/00_shared/paths.R`. Scripts locate the
repository root from their own position using `rprojroot`, so the clone can
sit anywhere and no script has to change directory to work. Point
`CC4A_OUT_DIR` at a shared drive in `.Renviron` if run output should not live
inside the clone.

## 4. A tour of the scripts

### R/00_shared

| Script | What it is |
|---|---|
| `paths.R` | Every folder and every file the pipeline touches, named once. Also the publication window (`YEAR_MIN`, `YEAR_MAX`) and the list of African country codes, since both are scope decisions rather than code. Creates the output folders the first time it is sourced. Every other script begins by sourcing it. |
| `utils.R` | The shared plumbing: timestamped logging, flag parsing, a single HTTP fetcher that carries the delay and the retry logic, CSV reading and writing that never guesses a column type, and one canonical way to normalise a DOI or a title before comparing it. |
| `vocab_cache.R` | A memory of every mapping from a verbatim extract to a controlled value. Reruns of step 6 therefore reproduce themselves and cost almost nothing. Each entry is stamped with a fingerprint of the option list it was chosen from, so enlarging a vocabulary expires exactly the decisions it invalidates and leaves the others standing. Corrections made by hand in the cache file are respected. |
| `build_template.R` | Builds `docs/synthesis/extraction_template.xlsx` from the schema CSV: one sheet per table, required fields highlighted, each field's description as a header comment, a drop-down on every enum. Rerun after any change to the schema. `--dry` lists the tables. |
| `install_packages.R` | Installs what the pipeline needs. Run once after cloning. |

### R/01_search

| Script | What it is |
|---|---|
| `openalex_search.R` | Assembles queries from `catalogues/keyword_list.R`, sends them with the Africa and year filters applied server side, walks the results with a cursor, rebuilds each abstract from the inverted index OpenAlex returns, and records the query alongside every row. Picks up where it left off. `--block=` runs a single outcome block, `--limit=` keeps a trial small, `--dry` shows the queries and their expected yield without fetching. |

### R/02_dedup

| Script | What it is |
|---|---|
| `dedup_results.R` | DOIs first, then a Jaro-Winkler comparison of titles for rows with no DOI or a disagreeing one. Comparison is blocked by year and first author, which keeps it affordable on a large set. Where two rows describe one study the survivor is chosen by rule: a DOI beats no DOI, an open access link beats none, a longer abstract beats a shorter one. `--threshold=` moves the title distance, `--report` writes the register without touching anything else. |

### R/03_screen

| Script | What it is |
|---|---|
| `screen_scope.R` | The abstract level decision. Returns a verdict of in, out or unsure, a reason, the criterion that failed, the phrase evidencing a cost or adoption figure, the phrase naming the country, a guess at the practice, and a confidence. Picks up where it left off. `--limit=` for a trial, `--shard=k/n` to run in parallel, `--reask=` to revisit a named list, `--dry` to price it first. |
| `screen_rules.R` | The audit over those verdicts. Publication year and the Africa check are settled here from the record metadata rather than by the model, which is what makes the window cheap to move: two numbers in `paths.R` and a rerun, with no abstract read twice. A verdict of in whose quoted phrase contains no digit drops to unsure, as does anything the model marked low confidence, and a one word reason goes on the list to be asked again. Entries in `catalogues/screen_overrides.csv` override both the model and the rules. Writes the manual review queue. |

### R/04_fetch

| Script | What it is |
|---|---|
| `fetch_fulltext.R` | Works down four routes per record: the open access location Unpaywall reports for the DOI, the open access URL the search already carried, the DOI itself, then the publisher's landing page. A download survives only if the magic bytes say PDF, `pdftools` can open it, it holds real text rather than scanned images, and it runs past a single page. A record is labelled paywalled only once all four routes have failed, never on the strength of one refusal. `--retry` revisits failures, `--dry` reports the plan. |

### R/05_extract

| Script | What it is |
|---|---|
| `extract_verbatim.R` | Handles one paper. The page tagged text goes out once, and each parameter family (cost, adoption, carbon share) is asked about after it, so the provider's cache carries the document and the several calls cost barely more than one. Answers come back with a page and a sentence attached, and code then hunts for that sentence: on the cited page, elsewhere in the paper, or nowhere. The last case is thrown out and survives only in the audit file. A list of figures that can never be a parameter (a programme budget, an exchange rate, a yield) is enforced in code. The untouched model response is saved per record, so a disappointing run can be diagnosed without being paid for twice. |
| `run_corpus.R` | Drives the extractor across the corpus, taking only records that passed screening and yielded readable text. `--dry` measures real page sizes and prices the run before any of it is spent, `--practice=` narrows it, `--limit=` trials it, `--redo` forces a repeat. A broken PDF is caught and logged rather than allowed to end the run. |

### R/06_harmonise

| Script | What it is |
|---|---|
| `harmonize.R` | Works from the verified rows alone and never reopens a paper. Practice, unit, geography and study design are mapped onto their controlled values: the synonym lists settle most of it, the decision cache settles what it has seen before, and a single batched model call handles the remainder. Units are made comparable here, with local currency converted at the study year rate and deflated to the base year, and with person-days deliberately left as labour rather than priced. Where nothing fits, the row is marked NOT STATED, the cell is left empty, and the unmatched term goes on a list for the team instead of into the data. |

### R/07_publish

| Script | What it is |
|---|---|
| `export_results.R` | Writes the parameter database in schema order, a provenance sheet carrying page, sentence, table reference and the pre-conversion value and unit, and a third sheet of rows that deserve a human glance. Also scores the run field by field against the gold set, so no release goes out without a number attached to its own reliability. |
| `cost_report.R` | What has been spent on model calls and what the remaining corpus would cost, computed from prompt sizes already observed rather than from guesses. `--forecast` prices what is left. Worth running before a full extraction rather than after one. |

### catalogues/

Reference tables, read at run time. No analytical rule is written into a
script.

| File | What it is |
|---|---|
| `keyword_list.R` | The search strings of the protocol (`synthesis/03`) as blocks of terms: one practice block per practice code, then the stress, outcome, cost, loss matrix, adoption, driver, benefit sharing and geography blocks. `KW_SEARCHES` says which blocks each of the eight searches crosses, and which stream it belongs to. |
| `vocab_practices.csv` | The thirteen practices in scope from `synthesis/01`, plus the practices not taken forward or out of scope, so screening can name them. Each has its code (matching `practice_id` in the schema), Crosswalk row, era-aom codes, system, definition, comparator, synonyms, and a boundary note saying where a borderline paper goes instead. |
| `vocab_units.csv` | Unit codes, the dimension each belongs to, what it standardises to, and how the conversion is meant to work. |
| `vocab_decisions.csv` | The harmonisation cache, written by step 6 and reused by it. Corrections made by hand survive the next run. |
| `screen_overrides.csv` | Screening decisions made by a person. They outrank everything else. |
| `gold_set.csv` | Records extracted by hand, used to score the pipeline in step 7. |
| `search_raw.csv` | The raw result set. Git ignored, rebuilt by step 1. |

### docs/

`protocol.md` is the index to the protocol and its amendment log.
`synthesis/` is the protocol itself: Pete's handover pack (`00` to `09`,
the schema CSV and the Excel template) and the Chun addendum (`10`).
`workflow_diagram.md` is where the one page figure will go.

### outputs/

Git ignored and disposable; the scripts rebuild it. One folder per step, plus
`review/` for the queues people work from and `logs/` for the record of what
each run called and what it cost.

### .claude/ and CLAUDE.md

Notes for AI coding sessions on this repository: the standing rules, the
anatomy every script follows, the traps worth knowing, and a walkthrough for
adding a practice. Not needed to run anything.

## 5. The extraction schema

**The schema is `docs/synthesis/extraction_schema.csv`**: 15 linked tables
(source, study, site season, effect, mechanism, cost, characteristic, loss,
adoption, adoption driver, benefit sharing, dataset, quote, verification,
gap), 259 fields, 74 of them core for the pilots. Each field names the table
it lands in. `02-extraction-schema.md` explains it, and the Excel template is
built from the CSV by `R/00_shared/build_template.R`, so the CSV is the one
place a field is changed.

Chun's requirements are among these columns (`synthesis/10` §4): costs by
class including totals, with discount rate and horizon; adoption rates;
adoption drivers and payment response; the share of carbon income to
farmers.

The extraction scripts still carry the first design, described below, until
phase 4 moves step 5 onto the new schema.

These are the columns of the Excel parameter database. The set is defined
once, as `SCHEMA_FIELDS` in `R/05_extract/extract_verbatim.R`, and published
in the order given by `SHEET_PARAMETERS` in
`R/07_publish/export_results.R`.

| Column | What goes in it | Controlled |
|---|---|---|
| `parameter` | `adoption_rate`, `cost_total`, `cost_installation`, `cost_variable`, `carbon_share` | yes, fixed list |
| `definition` | Free text. What is being measured, in the paper's own terms | no |
| `practice` | `agroforestry`, `conservation_agriculture`, `improved_fallows`, `biochar`, `cover_crops`, `drought_tolerant_varieties`, `water_harvesting`, `other` | yes, `vocab_practices.csv` |
| `value` | The number as the paper reports it | no |
| `unit` | `%`, `USD/ha/yr`, `UGX/ha/yr`, `person-days/ha`, `person-days/ha/yr`, `other` | yes, `vocab_units.csv` |
| `geography` | Country or sub-region within Africa | yes, ISO 3166-1 alpha-2 or a named region |
| `literature_doi` | The paper's DOI, taken from the record and never from the model | no |
| `detail` | Sample size, discount rate, study context, currency and year | no |
| `study_design` | `RCT`, `observational`, `DCE`, `meta-analysis`, `review`, `other` | yes, fixed list |
| `sample_size` | Farmers, plots, or studies | no |

Alongside these, every published row carries its origin on the second sheet:
record id, page, the sentence, a table reference where the figure came from
one, the verification status, and the value and unit as they stood before
conversion. Any number in the database can be walked back to a sentence on a
page without opening the pipeline.

Two things here are easy to get wrong. A cost means nothing until the
currency, the study year and the area are all pinned down, so all three are
captured as written and the arithmetic happens later in code. And person-days
are a quantity of labour, not a price: the pipeline refuses to monetise them,
because the wage assumption belongs to the financial model and not to this
review.

## 6. Keywords and search strategy

**The protocol's strings are in `catalogues/keyword_list.R`.** Eight
searches across the streams (practice evidence in bad seasons, across many
seasons, and for costs; the loss matrix for crops and for livestock;
adoption, adoption drivers and benefit sharing), each with its own strings,
sources and inclusion rules: `synthesis/03`. Stream 2 is worked by hand. The
search step itself (phase 3) still follows the first design below. Two
things below change with it. Evidence from outside Africa is admitted for
mechanism, and for effect sizes where African evidence is thin
(`synthesis/01` §1.4), so the Africa filter can no longer be applied to every
query. And OpenAlex becomes one source among several, after ERA.

A query is a cross rather than a phrase. A record has to look like it is about
a practice and like it contains a figure.

```
practice term  AND  (cost term  OR  adoption term  OR  carbon term)
               AND  African country institution tie
               AND  publication year inside the window
```

The blocks live in `catalogues/keyword_list.R`.

| Block | What is in it |
|---|---|
| `KW_PRACTICE` | One group per practice code, carrying every spelling the literature uses: hyphenated, abbreviated, and local (`zai`, `tassa`, `FMNR`) |
| `KW_COST` | Terms that imply a figure: establishment cost, cost per hectare, gross margin, net present value, person-day |
| `KW_ADOPTION` | Adoption rate, uptake, dis-adoption, share of farmers, willingness to pay |
| `KW_CARBON` | Carbon revenue, benefit sharing, payment for ecosystem services, voluntary carbon market |

Three choices are worth explaining.

**Countries are not keywords.** OpenAlex can filter on the country of the
author's institution before anything is downloaded, which beats matching
country names in text for both speed and recall. It is also wrong sometimes:
fieldwork in Kenya written up in Wageningen is tagged NL. That is why
geography is judged from the abstract as well as from the metadata.

**A keyword should imply a number.** `cost per hectare` earns its place;
`sustainability` returns thousands of papers that discuss affordability
without ever quantifying it. Trial a new term alone with `--dry` and look at
the count before committing to it.

**The year window is not a question for the model.** It is applied afterwards
by `screen_rules.R` from the record's own publication year, which is why
extending the review backwards costs two edited numbers and a rerun rather
than a fresh pass over every abstract.

Each query is logged with the string sent, the filters, the date, and the
counts returned and kept, so the search can be repeated and the protocol can
report its funnel without reconstructing it from memory.

## 7. Installation and keys

**R.** Version 4.4 or later. Install dependencies once:

```
Rscript R/00_shared/install_packages.R
```

These are httr2, jsonlite, curl and fs for retrieval; pdftools for reading
PDFs; dplyr, purrr, tibble, tidyr, stringr, readr and glue for data handling;
stringdist for duplicate detection; openxlsx, readxl and zip for Excel; ellmer for
model calls; cli for console output; rprojroot for locating the repository
root.

**Keys.** Copy `.Renviron.example` to `.Renviron` in your R home folder and
fill it in. That file is git ignored. `Sys.getenv("HOME")` will tell you where
it belongs.

```
OPENAI_API_KEY=            # screening, extraction, harmonisation
ANTHROPIC_API_KEY=         # alternative provider
UNPAYWALL_EMAIL=           # required on every Unpaywall request
OPENALEX_EMAIL=            # optional, buys the faster polite pool
```

Optional: `SCREEN_MODEL`, `EXTRACT_MODEL` and `HARMONIZE_MODEL` swap the model
a step uses, and `CC4A_OUT_DIR` moves run output out of the clone.

**Folders.** Nothing to configure. `paths.R` locates the root from its own
position and builds the output folders when it is first sourced.

**On Windows.** Downloads are stored as `<record_id>.pdf` rather than under
the publisher's filename, because some of those filenames are long enough to
breach the 260 character path limit.

## 8. How to run it

One script per step, run from the repository root. Each script's header states
its inputs, its outputs and its flags. Every step that calls a model can be
planned and priced first with `--dry`.

```
# 1 search
Rscript R/01_search/openalex_search.R --dry           # queries and expected counts
Rscript R/01_search/openalex_search.R

# 2 dedup
Rscript R/02_dedup/dedup_results.R --report           # what would be merged
Rscript R/02_dedup/dedup_results.R

# 3 screen
Rscript R/03_screen/screen_scope.R --dry              # price it first
Rscript R/03_screen/screen_scope.R
Rscript R/03_screen/screen_rules.R                    # audit, overrides, review queue

# 4 fetch
Rscript R/04_fetch/fetch_fulltext.R --dry
Rscript R/04_fetch/fetch_fulltext.R

# 5 extract
Rscript R/05_extract/run_corpus.R --dry               # plan and price the corpus
Rscript R/05_extract/run_corpus.R --limit=10          # a small real run first
Rscript R/05_extract/run_corpus.R

# 6 harmonise
Rscript R/06_harmonise/harmonize.R

# 7 publish
Rscript R/07_publish/export_results.R
Rscript R/07_publish/cost_report.R
```

One paper can be put through the extractor on its own, which is the quickest
way to see what it actually does:

```
Rscript R/05_extract/extract_verbatim.R outputs/04_fulltext/pdf/W2741809807.pdf
```

Steps 1, 3, 4 and 5 all remember what they have already done and append after
every record, so an interrupted run continues rather than restarts.

## 9. Output map

| What | Where |
|---|---|
| Raw search results, one row per record per query | `catalogues/search_raw.csv` |
| Per query counts, for the protocol funnel | `outputs/01_search/search_log.csv` |
| One row per study after deduplication | `outputs/02_dedup/records_deduped.csv` |
| Rows merged away, with the reason each lost | `outputs/02_dedup/duplicate_register.csv` |
| Screening: model verdict, reason, quotes, and the audited verdict beside it | `outputs/03_screen/screen_ruled.csv` |
| The manual review queue | `outputs/review/screen_unsure.csv` |
| Screening decisions made by a person, which outrank the rules | `catalogues/screen_overrides.csv` |
| Downloaded full texts and a note of which route found each | `outputs/04_fulltext/` |
| Extracted rows and the page verification audit | `outputs/05_extract/` |
| Harmonised rows, with the original value and unit preserved | `outputs/06_harmonise/extracted_harmonised.csv` |
| Terms the vocabulary could not absorb, proposed to the team | `outputs/review/proposed_vocab_terms.csv` |
| The Excel parameter database | `outputs/07_publish/cc4a_parameters_latest.xlsx` |
| Quality score against the gold set, and what the run cost | `outputs/07_publish/` |

## 10. Current state

As of 29 September 2026.

| Measure | Value |
|---|---|
| Skeleton built, all seven steps | yes |
| Steps implemented | none yet |
| Protocol | adopted: `docs/synthesis/`, freezes 16 October 2026 |
| Practices in the vocabulary | 13 in scope, 8 named for screening out, plus `other` |
| Schema | 15 tables, 259 fields; template built from it |
| Searches defined | 8, across streams 1, 3 and 4 |
| Units in the vocabulary | 10, plus `other` |
| Records searched | 0 |
| Records extracted | 0 |
| Gold set records | 0, still to be extracted by hand |

Moving the pipeline to the protocol, one pull request per phase:

| Phase | What | Status |
|---|---|---|
| 1 | Protocol into `docs/`, Chun addendum, README and CLAUDE.md rescoped | done (#1) |
| 2 | Catalogues: practices from `synthesis/01` with era-aom codes and the not taken forward list; strings per stream from `synthesis/03`; Chun's fields in the schema; the template built from the schema CSV | this change |
| 3 | Steps 1 and 3: ERA query, manual intake of grey literature, second screen, kappa and recall | |
| 4 | Step 5 to linked tables, the verification step, step 6 without currency conversion, step 7 exports | |
| 5 | Biochar pilot end to end, costs and effects, to test the schema before it freezes | |

Open questions: `synthesis/00` (Q1, Q3 to Q9, for Pete). Q2 and Chun's
questions are settled (`synthesis/00`, D8 to D12). The four questions that ended the first protocol are settled;
see `docs/protocol.md` §5.

## 11. Extending it

**A practice.** Define it in `synthesis/01` first: that is the protocol. Then
add a row to `catalogues/vocab_practices.csv`, its code to the `practice_id`
list in the schema CSV, and a matching entry to `KW_PRACTICE` in
`catalogues/keyword_list.R`. Rerun step 1, let steps
2 to 5 pick up only the new records, then rerun step 6 in full and step 7.
Nothing already extracted is read again. Walkthrough:
`.claude/skills/add-practice/SKILL.md`.

**A search term.** Add it to its block and rerun step 1. Downstream work is
keyed to records rather than to queries, so anything new simply joins the
pool.

**A wider timeframe.** Edit `YEAR_MIN` and `YEAR_MAX` in
`R/00_shared/paths.R`, rerun `screen_rules.R`, then rerun the fetch and
extraction drivers, which will collect only what the wider window admitted.
No abstract is judged twice, because the model's verdict is stored apart from
the year rule.

**A unit.** Add a row to `catalogues/vocab_units.csv` with its dimension, its
target unit and its conversion note, then rerun step 6 alone. The option list
has changed, so decisions taken under the old one expire by themselves.

**A schema field.** The costly one. Step 5 has to run again, because nobody
ever asked the papers for that evidence. Add the field to
`docs/synthesis/extraction_schema.csv` with the table it lands in, describe
it in `02-extraction-schema.md`, rebuild the template with
`Rscript R/00_shared/build_template.R`, and log the change in
`docs/protocol.md`. After the 16 October freeze, every change is a dated
amendment.

**A different model.** Set `SCREEN_MODEL`, `EXTRACT_MODEL` or
`HARMONIZE_MODEL` in `.Renviron`. Price the swap with `--dry`, and score it
against the gold set before believing its output.

## 12. House rules

- Plain language in documents and script headers alike. Sentence case. No em
  dashes.
- Each script opens with a header stating what it does, what it reads, what it
  writes and what flags it accepts.
- Each script locates the repository root from its own position with
  `rprojroot::find_root(rprojroot::has_file("CC4A.Rproj"))` and then sources
  `R/00_shared/paths.R`. No script calls `setwd()`.
- Only `paths.R` knows a path. New output files are declared there before they
  are written anywhere.
- Analytical rules live in `catalogues/` and in `paths.R`, never inside a
  script.
- Look it up before asking a model, and where a model is unavoidable, batch
  the calls and keep the answers.
- Every extracted value carries a page and is tested against it. What cannot
  be found is dropped rather than kept on trust.
- Ambiguity goes to a review list, not into the data. Where nothing fits, the
  answer is NOT STATED and the cell stays empty.
- Rejected rows are registered rather than deleted, and the model's own
  verdict is always kept beside the audited one.
- Commits follow the conventional style: `feat:`, `fix:`, `docs:`,
  `refactor:`.
