# Working rules for AI coding sessions on this repo

Read this before writing anything. If a rule here disagrees with something in
`.claude/`, this file wins.

## Contents

1. [What this repo is](#1-what-this-repo-is)
2. [Standing rules](#2-standing-rules)
3. [Script anatomy](#3-script-anatomy)
4. [Style](#4-style)
5. [Adding a practice to the vocabulary](#5-adding-a-practice-to-the-vocabulary)
6. [Extending the keyword list](#6-extending-the-keyword-list)
7. [Adding a parameter or a schema field](#7-adding-a-parameter-or-a-schema-field)
8. [Known gotchas](#8-known-gotchas)
9. [Before you commit](#9-before-you-commit)

## 1. What this repo is

An R pipeline that runs the evidence synthesis for Activity 2 of INV-089367
(CC4A): it reads the literature for the production effect, avoided loss,
costs and adoption of carbon crediting practices in sub-Saharan Africa, checks
every value against its source, and delivers tables for the geospatial
recipe engine and for Chun Song's net economic benefit analysis. Seven steps,
one folder per step under `R/`.

**The protocol is `docs/synthesis/`**, indexed by `docs/protocol.md`. It
decides what is extracted, from what, and how it is checked. This file
decides how the code is written. On an analytical question the protocol
wins; on a coding question this file wins. `docs/synthesis/CLAUDE.md` holds
the rules for a session doing synthesis work (extracting or verifying)
rather than writing code; read it before touching extraction or verification
prompts.

The pipeline is being moved from its first scope (costs and adoption only)
to the protocol in phases, listed in `README.md` §9. Where the code or the
catalogues still reflect the first scope, the protocol is the target: do not
extend the old design.

What comes out of here gets multiplied by hectares and by years inside a
financial model, far from anyone who could check it against a paper. The
failure that matters is therefore a wrong number that looks reasonable. Most
of the rules below exist to make that failure loud.

## 2. Standing rules

**Spend a lookup before you spend a model call.** If a regular expression, a
synonym table or a cached decision can answer the question, it should. Where a
model is genuinely required, batch what you send it and keep what it says.

**A value without a verified page reference does not enter the data.** The
model answers in the paper's own words; code then searches the cited page for
those words. Anything it cannot locate is discarded. Do not weaken this test
to improve the yield, because yield is not the problem this review has.

**Reading and coding are separate jobs.** Step 5 opens the paper; step 6
chooses the controlled value. Opening papers is expensive and happens once.
Choosing is cheap and can be redone every time a vocabulary grows, without
touching a PDF. So keep vocabulary lists out of the extraction prompt, however
convenient it looks.

**Analytical decisions belong in files, not in code.** Practices, units,
keywords, the year window and the country list are read at run time from
`catalogues/` and `R/00_shared/paths.R`.

**Only `paths.R` knows a path.** No literal paths anywhere else. A new file is
declared there before anything writes to it.

**Uncertainty is escalated, not resolved quietly.** An unfamiliar practice, an
unmatched unit, a term with no home goes to `outputs/review/` for the team.
Where nothing in the vocabulary fits, the answer is NOT STATED and the cell is
left empty.

**Rejected does not mean deleted.** Merged duplicates keep a register entry,
the model's own verdict survives beside the audited one, and a person's
override in `catalogues/screen_overrides.csv` outranks both.

**Assume every run will be interrupted.** Append after each record rather than
at the end, and skip what is already done on restart.

**Any step that calls a model needs `--dry` before it needs anything else.**
It should plan and price the run without spending a cent.

## 3. Script anatomy

Every script opens with this block, filled in for real:

```r
# What it does: one or two sentences, plain language.
# Reads: every input file, by repo relative path
# Writes: every output file, by repo relative path
# Flags: --source=   what it does
#        --limit=    what it does
#        --dry       what it does
#
# Run with:
#   Rscript R/0X_step/script.R --dry
```

Then, always these two lines, in this order, before anything else:

```r
root <- rprojroot::find_root(rprojroot::has_file("CC4A.Rproj"))
source(file.path(root, "R/00_shared/paths.R"))
```

Anything else shared, `utils.R` included, is sourced after those two in the
same style. This works identically from RStudio, from `Rscript`, and from any
working directory inside the clone, which is why no script here calls
`setwd()`.

A placeholder script is not an empty file. It carries the real header, the
real constants and the real sourcing lines, with the logic left as a numbered
TODO and a closing `stop("not implemented yet")`. A stub that runs quietly and
produces nothing is the worse kind of lie.

## 4. Style

- Plain language, in code as much as in documents. Sentence case. No em
  dashes.
- Comments explain why. The code is already saying what.
- Constants in `SCREAMING_SNAKE_CASE` at the head of the file, each under a
  note on what moving it will do.
- Functions and variables in `snake_case`.
- Filenames in `snake_case.R`, unprefixed. The folder carries the step number
  so the file does not have to.
- One job per script. Two verbs in the description means two scripts.
- Tabular data wants a data frame, not a list of lists. Almost everything here
  is tabular.
- Commits follow the conventional style: `feat:`, `fix:`, `docs:`,
  `refactor:`.

## 5. Adding a practice to the vocabulary

Short version. The walkthrough is `.claude/skills/add-practice/SKILL.md`.

1. Add a row to `catalogues/vocab_practices.csv`: `practice_code` in
   snake_case, `label`, one sentence `definition`, semicolon separated
   `synonyms` covering every spelling the literature uses, `carbon_relevant`,
   and a `notes` field that says what the practice is not.
2. Add a group of the same name to `KW_PRACTICE` in
   `catalogues/keyword_list.R`.
3. Rerun step 1, then steps 2 to 5 for the new records only (they are
   resumable), then step 6 in full, then step 7.

Step 6 is rerun in full because the option list changed. Decisions taken
under the old list retire on their own, because each cached decision is
keyed to a fingerprint of the list it was taken from. Nothing already
extracted is read again.

Never add a practice code without its boundary note. The overlaps are where
the coding goes wrong.

## 6. Extending the keyword list

`catalogues/keyword_list.R` holds four blocks: the practices, and the cost,
adoption and carbon outcome terms. The search crosses a practice group with
an outcome block.

- Terms are matched against title and abstract.
- Prefer a term that promises a number (`cost per hectare`, `adoption rate`)
  over one that promises a topic (`farming`, `sustainability`).
- Include hyphenated, abbreviated and non-hyphenated forms. `no-till`,
  `no till` and `zero tillage` are three terms.
- Do not put country names in the keyword list. OpenAlex filters on country
  server side, and a name based filter misses most of the corpus.
- Test a new term on its own with `--dry` and look at the expected count. A
  query returning tens of thousands of records is too broad.
- Adding a term means rerunning step 1 only. Everything downstream is keyed
  to the record, not to the query.

## 7. Adding a parameter or a schema field

Under the protocol the schema is `docs/synthesis/extraction_schema.csv`, and
phase 2 makes it the one definition the scripts read. A new field is added
there, with the target it lands in (`lands_in`); a field that lands in no
target does not belong in the schema. Until phase 2 the old arrangement
below still describes the code.

The schema is the Excel column set. Its one definition is `SCHEMA_FIELDS` in
`R/05_extract/extract_verbatim.R`, and its publication order is
`SHEET_PARAMETERS` in `R/07_publish/export_results.R`. Both have to change
together.

- A new `parameter` value (a new kind of number) needs a line in the
  extraction prompt saying exactly what counts and what does not, plus an
  entry in `NEVER_A_PARAMETER` for the confusion it invites.
- A new schema field means step 5 is rerun, because the evidence for it was
  never asked for. This is the expensive kind of change. Be sure first.
- Tell the modellers before changing the column order. The carbon credit
  model reads that order.

## 8. Known gotchas

**OpenAlex rate limits.** Ten requests per second, 100,000 a day, and the
polite pool is faster and more reliable. Send a contact address on every
request (`OPENALEX_EMAIL`). Page with a cursor, never with an offset: deep
offset paging silently truncates. The abstract arrives as an inverted index
and has to be reconstructed. Country is on the author institution, not on
the study, so a paper about Kenya written in Wageningen carries NL, and the
screening has to catch it.

**Unpaywall needs an email on every request** and answers for a DOI only. A
record without a DOI has to go through another route. `is_oa = false` is not
proof there is no free copy: check the DOI directly and the publisher page
before writing `paywalled`.

**PDF encoding.** Table text scrambles when it is extracted, columns
interleave, and a number can lose its decimal point. Where a value comes
from a table, keep the table reference and treat the extracted text as a
hint, not as truth. Scanned PDFs hold no text at all, and `pdftools` returns
empty pages rather than failing, so check for text before spending a model
call. Ligatures and non-breaking spaces break exact string matching, so
normalise whitespace and unicode before verifying a quote.

**Windows paths.** Publisher filenames can be long enough to breach the 260
character limit once they sit inside a nested output folder. That is why
downloads are renamed `<record_id>.pdf`. Never preserve the original name.

**Prompt order is a cost decision.** Document text first, per call instruction
after it. That way the provider caches the expensive half and the several
extraction calls for one paper cost barely more than one. Slip an instruction
in ahead of the document and the bill roughly doubles for no benefit.

**Currency.** A cost is comparable only once the currency, the study year
and the area are all fixed. Record all three as the paper gives them. The
pipeline does not convert currency or deflate: under the protocol Chun does
(`docs/synthesis/00`, D5). Never ask the model to convert a currency.

**Person-days are not money.** Do not price labour. The carbon model does
that with its own wage assumptions.

**A review or a meta-analysis can double count.** The pooled figure and the
underlying studies can both enter the corpus, and so can an ERA record of the
same trial. The protocol counts independence on trials, not papers: one
`trial_id` per physical trial (`docs/synthesis/02` §2).

## 9. Before you commit

- The script runs end to end with `--dry`.
- Every new file path is in `paths.R`.
- Every new analytical term is in `catalogues/`, not in a script.
- The header block names every file the script reads and writes.
- No key, no absolute local path and no PDF is in the diff.
- The new script has an entry in the README's tour of the scripts.
