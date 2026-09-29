# Traceability and adversarial verification

AI-assisted extraction fails in a specific and quiet way. This protocol is designed around the two failure modes, which are different and need different checks:

1. **A fabricated quotation.** The quoted text does not exist in the source, or not at the locator given. The obvious failure, and the easier to catch.
2. **A real quotation that does not say what the extraction claims.** The text exists, but it refers to a different treatment, a different season, the pooled mean rather than the drought year, soil moisture rather than yield, a pot trial rather than the field trial, or a figure that means something else in context. The more common failure, and the harder to catch.

A check that only confirms quotes exist will pass the second failure every time. So there are two checks, run separately, plus a blind re-extraction on the fields that matter most.

---

## 1. At extraction: what every value carries

Every extracted number — and every mechanism statement, cost boundary statement and adoption definition — has at least one row in the `quote` table:

| Field | Rule |
|---|---|
| `verbatim` | Copied from the document, not retyped or paraphrased. For a table cell: the row label, the column header and the cell value, exactly as printed. For a figure: the caption, the axis labels and a description of the point read |
| `locator` | Enough for someone else to find it without searching: page, table or figure number, row and column, section. Supplementary material named by file |
| `claim` | One sentence stating what the extraction asserts on the strength of this quote. Written so it can be false. *"Under drought (2017 short rains, Embu), maize grain yield with 10 t/ha biochar was 2.1 t/ha against 1.4 t/ha without."* — not *"biochar improved yield"* |
| `record_ref` | The exact extracted field it supports (`effect.EFF-0012.treatment_mean`) |
| `computation` | For any value not printed in the source (a mean of two seasons, a unit conversion, a difference): the formula, and the quote ids of every input. Each input has its own quote |
| `extractor` | Person, plus AI tool and version |

Figure-digitised values: record the tool, and read each point twice; if the two readings differ by more than 5 % of the axis range, flag the value.

Sources are stored in the project folder and `source.file_path` points at the file, so the verifier opens the same version the extractor used.

**ERA-imported values** are the one exception to the verbatim rule: they carry `quote_basis = era_record` and the ERA record id as locator. ERA is itself a secondary extraction, so **20 % of ERA-imported trials** (at least two per practice) go through checks A–C against the original paper. If that sample finds errors above the batch threshold in §4, all ERA rows for the practice are checked.

## 2. The verification pass

Run by someone — or an AI session — **independent of the extraction.** Independent means: a different person, or a fresh AI session that has not seen the extraction conversation, is given only the source file and the rows to check, and has instructions written for verification, not extraction. An AI verifier from the same model as the extractor can share its blind spots; use a different model where one is available, and rely on the planted-error test (§4) to measure what the verifier actually catches.

### Check A — does the quote exist as quoted?

1. Open the source at the locator.
2. Compare the verbatim text. For text-layer PDFs, do this programmatically first: normalise whitespace, hyphenation and ligatures, then fuzzy-match the quote against the page text. A match score below the threshold (start at 0.95) goes to manual check. Tables and figures are always checked by eye.
3. Record `check_a_exists`: `exact`, `minor_difference` (whitespace, encoding), `not_found`, or `locator_wrong` (text exists elsewhere).

### Check B — does the quote support the claim?

The verifier reads the claim, the quote **and the surrounding context** (the paragraph, the table's notes and headers, the methods describing that treatment), and answers:

- Is this the treatment and the comparator the claim says?
- Is this the season, site, year and condition the claim says — the stress season, not the pooled mean?
- Is this the outcome and unit the claim says — yield, not biomass; grain, not stover; field, not pot?
- Is the number the one the claim uses?
- Does anything in the context qualify it (a footnote, an "excluding site 3", a note that the season was irrigated)?

Record `check_b_supports`: `supports`, `partially`, `does_not_support`, or `contradicts`, and on any failure a `failure_mode` from the list in the schema (`misattributed_quote`, `wrong_arm`, `wrong_season`, `pooled_as_stress`, `context_stripped`, `wrong_unit`, …).

### Check C — blind re-extraction

For the fields that drive the result, the verifier reads the value from the source **before** seeing the extracted value, and records it in `blind_value`. Compared afterwards: `match`, `within_tolerance` (±2 % or digitising tolerance), or `mismatch`.

Blind re-extraction is applied to:

- **every** stress-season and normal-season treatment and control mean that feeds a buffering coefficient;
- **every** `site_season` coordinate and date used for classification;
- **every** loss-matrix value;
- every numeric cost value and labour figure;
- a random **20 %** of all other extracted numbers.

Categorical fields (cost boundary flags, design, contrast type) are covered by check B, not re-extracted blind.

## 3. Mismatches are logged, not silently corrected

The verifier never edits the extraction. On any failure:

1. The verification row records what failed and how.
2. The record goes back to the extractor, who either corrects it (`extractor_corrected`, with a new quote row) or withdraws it (`record_withdrawn`).
3. If extractor and verifier disagree, the adjudicator (E1, or Pete where E1 extracted) decides (`disputed_to_adjudicator`). Nobody resolves a dispute over their own extraction.
4. The failed row stays in the log. Corrections are new rows; nothing is overwritten.

This matters because the failure *rate* is itself evidence about the extraction process, and a log that has been cleaned up cannot tell you it.

## 4. Batch rules

Verification runs in batches (a practice, or a source set of 10–20 studies).

| Observed in a batch | Action |
|---|---|
| Any `fabricated_quote` | Re-verify the **whole batch** with check C on every number, and review the extraction prompt or procedure that produced it |
| `does_not_support` or `contradicts` on more than 5 % of checked quotes | Re-verify the whole batch |
| Any failure on a buffering-coefficient input | That coefficient does not enter the recipe until resolved |

Report per batch: quotes checked, failures by mode, and the failure rate **with a 95 % Wilson interval**, plus time spent; keep a cumulative tally per practice. With batches of about 40 quotes a single failure moves the rate by 2.5 points, so trends in the cumulative rate matter more than any one batch. The tally goes in the recipe's governance block as a data-quality statement.

**Planted errors.** In each pilot batch, the adjudicator plants 5–10 known errors (a wrong arm, a pooled value labelled as a stress season, a changed digit, a quote moved to the wrong locator) before verification, flagged `planted_error` afterwards. The share the verifier catches is the verifier's measured sensitivity. If it is below 80 %, revise the verification instructions before the next batch.

## 5. Human audit

Independently of the verification pass, a second person (Pete, or a reviewer from the E4 pool) audits a random **10 % of records end to end** — source to quote to claim to extracted value to recipe entry — for each pilot practice, and 5 % thereafter. The audit is recorded in the verification table with `verifier = audit:<name>`.

## 6. The review gate

The recipe review gate (work plan task A7: a named reviewer who did not write the recipe signs off adaptation logic and production logic) sits **after** verification. The reviewer receives the recipe, the verification tally and the gap rows, and checks judgement — mechanism, routing, tier, whether the numbers are plausible — not transcription. Transcription is what this protocol is for.

## 7. What every study records, so effects can transfer

Verification checks these are present and supported, because an effect without them cannot be moved to another context:

- **design** (experimental, survey, modelled, project evaluation, observational);
- **spatial replication** — sites, and site-seasons rather than years;
- **temporal replication** — seasons, and which were hazard seasons;
- **plot size or study area**;
- **comparator** — what the effect was measured against;
- **dose or intensity** of the practice as implemented.

## 8. Null and negative findings

A practice that performs worse under stress than the baseline it replaces is a finding this work exists to surface. Verification checks that null and negative results in a source were extracted, not only the positive ones: for each verified study, the verifier confirms that every treatment arm and season relevant to the practice appears in the extraction, and records any that do not as `failure_mode = omitted_arm_season`, with `record_ref` pointing at the study (no quote exists for an omission).
