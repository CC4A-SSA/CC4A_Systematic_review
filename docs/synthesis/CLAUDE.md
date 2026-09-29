# Context for an AI session working in this folder

You are assisting the evidence synthesis for **Activity 2 of INV-089367** (Gates Foundation; Alliance of Bioversity International and CIAT): the evidence that produces practice recipes, the loss matrix, a shared cost table, an adoption and extent table and a dataset register for a geospatial engine estimating production and adaptation benefits of carbon-crediting practices across sub-Saharan Africa.

Read `README.md`, then `00-…`, `02-…` and `04-…` before doing anything.

## Hard rules

- **Never produce a number without a verbatim quote and a locator from the source document itself.** Not from memory, not from an abstract when the paper is available, not from a secondary summary. If you cannot find the text, say so; do not paraphrase a quote into existence. The only exception: values imported from ERA carry `quote_basis = era_record` and the ERA record id.
- **Write the claim so it can be false.** Name the treatment, comparator, season, site, outcome and unit.
- **Extract every arm and season relevant to the practice, including null and negative results.** Omitting an unfavourable arm is a failure the verifier checks for.
- **Extract cell means (treatment/control × season) wherever reported**, and fill `site_season` with coordinates and dates even when the effect is pooled.
- **Do not classify seasons.** `classified_hazard` and `classified_severity` are filled by S5 from the hazard stack. Record the authors' description in `author_condition`.
- **Do not assign the final evidence tier.** Propose it with its basis; the reviewer confirms.
- **Signed coefficients.** Never truncate a negative effect to zero. Keep the meanings apart: Δₛ < 0 is worse than the control under stress; b < 0 is a shrinking advantage; b = −p is no buffering (`02` §3.2).
- **Do not hand-compute published coefficients.** They come from the pre-specified model in `02` §3.3.
- **Link companion papers.** Give every physical trial one `trial_id`, including its ERA record.
- **If you are verifying, do not edit extraction rows.** Write verification rows; log failures with a failure mode.
- **Stay in scope.** No suitability, yield-response or profitability *method* literature; no NEB computation; no mitigation figures.
- **A field that lands in no target object does not belong in the extraction.** Put it in `source.note`.

## Verification sessions

When asked to verify, you are the independent pass. You receive the source file and the quote rows. For each: check A (does the verbatim text exist at the locator), check B (does it support the claim, reading the surrounding context, table notes and methods), and, for the sampled fields, check C (read the value blind before looking at the extracted one). Output verification rows in the schema.

## Where things live

- Schema: `extraction_schema.csv` (authoritative), `extraction_template.xlsx`.
- Recipe layout: `biochar_recipe_ILLUSTRATIVE.yaml` (numbers invented).
- Method: `Workplans/alliance geospatial team/workplans_claude/02-method.md` and the work plan v0.2, Section 3.2 and Annex B.
- Indicator: `Technical Development/Adaptation & Production/2026-07-08 ClimateImpactAreaIndicator-Adaptation-v3.0.docx`.
- era-aom vocabulary: https://github.com/ERAgriculture/era-aom, `data/pilot/`.
