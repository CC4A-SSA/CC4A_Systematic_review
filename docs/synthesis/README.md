# Evidence synthesis for Activity 2 — handover pack

**For:** Namita Joshi (evidence synthesis lead, position E1)
**From:** Pete Steward
**Date:** 26 September 2026
**Project:** INV-089367, *Country Profiles to Support Agricultural Adaptation via Carbon Finance* — Activity 2, production and adaptation technical potentials

This pack is the plan for the evidence synthesis, not the synthesis itself. It contains the protocol, the schemas, the search strategy, the verification design and one worked example: everything needed to start, and enough for a second person to audit what comes out.

---

## The one idea that governs everything

**The synthesis is not a literature review that ends in a report. It feeds a pipeline.**

Every number you extract ends up in one of five objects that the geospatial engine or a downstream analysis reads:

| Target object | What it is | Who reads it |
|---|---|---|
| **Practice recipe** (one YAML per practice) | Mechanism, buffering coefficients per hazard × severity, production effect sizes, route, temporal profile, confidence | The recipe engine (Workstream B) |
| **Loss matrix** (one table) | Per cent of production lost per system × hazard × severity class | The recipe engine; multiplied by the buffering coefficient |
| **Cost parameter table** (one table, shared) | Establishment and running costs with explicit boundaries | Chun Song's net economic benefit (NEB) analysis |
| **Adoption and extent table** | Current adoption and trend by practice and geography | Activity 4 scaling scenarios B and C; the adoption layer |
| **Dataset register** | Long-term trials and large datasets that could yield stress-season evidence | S5 (season classification) and you, for prioritisation |

Every one of these carries confidence metadata: evidence tier, sources, verbatim quotations and locators.

**If an extraction field does not land in one of those five objects, or in the confidence metadata that travels with them, it is not in the schema.** When you are tempted to add a field, ask which object it lands in. If the answer is "none, but it's interesting", write it in the study's free-text note and move on.

---

## Files

| File | What it is | Read when |
|---|---|---|
| `README.md` | This file | First |
| `00-scope-decisions-and-open-questions.md` | What Pete decided on 26 September, what is out of scope, and the questions still open | First |
| `01-practice-definitions.md` | What counts as each practice and what does not, anchored to era-aom codes and Crosswalk rows; bundle rules; comparators | Before any search |
| `02-extraction-schema.md` | Every extraction table and field, its type, whether required, and the target-object field it populates | Before extracting |
| `extraction_schema.csv` | The same schema, machine-readable | When building tools or prompts |
| `extraction_template.xlsx` | Empty workbook, one sheet per extraction table, headers and drop-downs from the schema | When extracting |
| `03-search-strategy.md` | Sources, strings, inclusion and exclusion criteria and screening, per stream | Before searching |
| `04-verification-protocol.md` | The traceability and adversarial verification design | Before extracting — it shapes how you extract |
| `05-evidence-tiers.md` | The evidence tier rubric, from the CGIAR adaptation indicator, with the entry conditions | Before assigning any confidence |
| `06-worked-example-biochar.md` | Biochar taken end to end, definition → search → extraction → verification → recipe. **All numbers are illustrative** | As your template |
| `biochar_recipe_ILLUSTRATIVE.yaml` | The populated recipe the worked example ends in | Alongside the worked example |
| `07-sequencing-and-effort.md` | What happens when, tied to the geospatial plan's dates, and the AI-first working model | For planning with Pete |
| `08-request-to-adaptation-insights.md` | What to ask Andreea Nowak's team for before starting, and what we offer | Week one |
| `09-adversarial-review.md` | Four independent reviews of this pack (academic, practitioner, carbon finance, meta-analysis), every finding and what was done about it | Before changing the method |
| `CLAUDE.md` | Context for an AI session working in this folder | If you work with Claude or another assistant here |

---

## Four streams

1. **Practice evidence.** Per practice: adaptation mechanism, buffering per hazard and severity, risk reduction (almost always an explicit zero), production effect in a normal year, costs with boundaries, longevity, time to benefit, persistence. Crop and livestock outcomes. Lands in the recipe and the cost table.
2. **Long-term trials and large datasets.** Where the practice ran across years that include hazard years, so avoided loss can be estimated empirically. Lands in the dataset register, then — once seasons are classified — in the recipe.
3. **The loss matrix.** Practice-independent: how much production is lost at each severity of each hazard, per crop or livestock system. Its own literature and its own search.
4. **Adoption and current extent.** How much of each practice is already happening, where, and trending which way. Lands in the adoption and extent table for Activity 4.

## Boundaries you need to hold

- **Methods for predicting suitability, yield response or profitability are out.** That literature review is a separate strand. If a paper's contribution is a method, skip it; if it also reports primary data, extract the data only.
- **Net economic benefit is Chun Song's.** You extract cost and benefit parameters, with boundaries, into one shared table. You do not compute NEB, and Chun does not keep a second cost set. See `00-…` for the line.
- **Too little evidence is a finding.** A practice with no defensible adaptation mechanism, or no usable stress-season evidence, gets that recorded and is routed to D. It is not padded with a plausible number.

## Continuity

Namita leads the synthesis until mid-December 2026, when the work is handed over. The pack is built for that: everything lives in this folder with its logs, and a short status note at handover (`07` §4) tells the successor where each practice stands.

## Where to start

1. Read `00-…`, `01-…` and `04-…`.
2. Send the Adaptation Insights request (`08-…`) in week one. It may remove whole practices from your workload.
3. Read the worked example with the template open next to it.
4. Start the maize loss matrix (bronze) and the three pilot recipes in parallel — see `07-…`.

## Related material elsewhere in the project folder

- `Workplans/alliance geospatial team/` — the work plan v0.2 and `workplans_claude/02-method.md`. Section 3.2 and Annex B of the plan define the recipe; `02-method.md` explains the parts that are easy to get wrong.
- `Technical Development/Adaptation & Production/2026-07-08 ClimateImpactAreaIndicator-Adaptation-v3.0.docx` — the CGIAR adaptation indicator. The tier rubric, entry conditions and reference-database fields come from here.
- `Technical Development/2020.08 - Shared Data Documentation for Joint Review and Collaboration/NCS activities data for Gates.xlsx` — Crosswalk and Alliance adaptation tabs. **The live copy is on TNC's SharePoint** and is ahead of the local copy (it has the direct-seeded rice / SRI row).
- `Literature/` — seed PDFs for AWD, biochar and ERW.
- era-aom: https://github.com/ERAgriculture/era-aom — the ERA controlled vocabulary (data in `data/pilot/`).
