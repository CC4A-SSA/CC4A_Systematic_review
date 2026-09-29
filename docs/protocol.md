# CC4A review protocol

The protocol is the evidence synthesis handover pack in `docs/synthesis/`,
written by Pete Steward for Activity 2 of INV-089367, plus one addendum
covering what Chun Song's net economic benefit analysis needs. This file is
the index to it and the record of changes.

Draft. Frozen as protocol v1.0 at the schema freeze on 16 October 2026 (see
`docs/synthesis/07-sequencing-and-effort.md`), with a dated amendment log
after that.

## 1. What the synthesis produces

The synthesis feeds a pipeline, not a report. Every extracted number lands in
one of these tables, with its evidence tier, sources, verbatim quote and
locator.

| Table | Read by | Defined in |
|---|---|---|
| Practice recipe, one YAML per practice | Geospatial recipe engine | `synthesis/02` §4, `synthesis/biochar_recipe_ILLUSTRATIVE.yaml` |
| Loss matrix | Geospatial recipe engine | `synthesis/02` `loss_obs`, `synthesis/03` §3 |
| Cost parameter table, shared | Chun Song, NEB | `synthesis/02` §6, `synthesis/10` §3.4 |
| Adoption and extent table | Activity 4; Chun | `synthesis/02` `adoption_obs`, `synthesis/03` §4 |
| Adoption drivers and payment response | Chun | `synthesis/10` §3.2, §3.3 |
| Benefit sharing | Chun | `synthesis/10` §3.1 |
| Dataset register | S5, season classification | `synthesis/02` `dataset`, `synthesis/03` §2 |

## 2. The pack, in reading order

| File | What it settles |
|---|---|
| `synthesis/_START HERE - one-page summary.md` | The whole thing on a page |
| `synthesis/README.md` | Map of the pack |
| `synthesis/00-scope-decisions-and-open-questions.md` | Decisions of 26 September, out of scope items, the line with Chun, open questions Q1 to Q9 |
| `synthesis/01-practice-definitions.md` | Thirteen practices in scope, anchored to era-aom codes and the Crosswalk; bundle and comparator rules; practices not taken forward |
| `synthesis/02-extraction-schema.md` | Every table and field, and the recipe field each one fills |
| `synthesis/extraction_schema.csv` | The same schema, machine readable. Authoritative when the three copies drift |
| `synthesis/extraction_template.xlsx` | Empty workbook, one sheet per table |
| `synthesis/03-search-strategy.md` | Sources, strings, inclusion rules and screening per stream |
| `synthesis/04-verification-protocol.md` | Checks A (the quote exists), B (the quote supports the claim) and C (blind re-extraction); batch rules; planted errors |
| `synthesis/05-evidence-tiers.md` | Tier rubric from the CGIAR adaptation indicator |
| `synthesis/06-worked-example-biochar.md` | One practice end to end. Numbers invented |
| `synthesis/07-sequencing-and-effort.md` | Dates, working model, handover note |
| `synthesis/08-request-to-adaptation-insights.md` | What to ask Andreea Nowak's team for |
| `synthesis/09-adversarial-review.md` | Four reviews of the pack and what was done about each finding |
| `synthesis/10-chun-requirements-addendum.md` | What Chun needs that the pack did not carry, and the flat export he reads |
| `synthesis/CLAUDE.md` | Rules for an AI session doing synthesis work |
| `synthesis/PROMPT - design the evidence synthesis handover for Namita.md` | The brief the pack was written from |

The pack refers to material that stays in the project OneDrive: the work plan
v0.2 and `workplans_claude/02-method.md`, the CGIAR adaptation indicator
v3.0, the Crosswalk in `NCS activities data for Gates.xlsx`, and the seed
PDFs in `Literature/`.

## 3. How this repository relates to the pack

The pack says what to extract and how to check it. The R pipeline under `R/`
is the machinery that does the volume: search, screening, full text
retrieval, extraction with verbatim quotes, verification, and export into the
tables above. The pack's working model (`synthesis/07` §3) assigns volume to
AI and judgement to people; the pipeline is where the AI part runs, logged
and repeatable.

The pipeline is being moved from its first scope (cost and adoption only) to
this protocol in phases. See `README.md` §9.

## 4. Copy of record

From this commit, the copy in this repository is the copy of record. Changes
go through a pull request and are logged in §6. The SharePoint Synthesis
folder is a mirror for people who do not use GitHub.

## 5. Questions from the first protocol, now settled

The first draft of this file ended with four open questions. The pack
answers all of them.

| Question | Answer |
|---|---|
| How to treat a meta-analysis without counting studies twice | Independence is counted on trials, not papers: one `trial_id` per physical trial, shared by companion papers and the ERA record (`synthesis/02` §2) |
| Whether a cost per household can be used without an area | Recorded with `unit_basis = per_farm` and `n_farmers_covered`; Chun decides whether it is usable (`synthesis/02` §6) |
| Base year and deflator for currency | Not ours. Currency and price year are recorded as reported; Chun converts (`synthesis/00`, D5) |
| Whether grey literature belongs in the corpus | Yes. Grey literature, project evaluations and carbon project documents carry much of the cost detail (`synthesis/03`) |

Open questions now live in `synthesis/00` (Q1 to Q9, for Pete) and
`synthesis/10` §6 (for Chun).

## 6. Amendment log

| Date | Change | By |
|---|---|---|
| 2026-09-29 | Pack adopted as the protocol; Chun addendum (`synthesis/10`) added as a proposal | Namita Joshi |
