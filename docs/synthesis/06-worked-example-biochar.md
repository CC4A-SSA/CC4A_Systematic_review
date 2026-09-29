# Worked example — biochar, end to end

> **Every number, study, quote, count and coordinate in this example is invented.** It shows the mechanics: what goes where, in what order, and what the checks catch. No real extraction has been done. Invented items carry the suffix `ILL`.
>
> **Real, and checkable:** the contents of the project's `Literature/Biochar/` folder named in Step 2 (listed from the folder on 26 September; their contents have not been read for this pack); the era-aom codes `b28` and `h10`; the Crosswalk and Alliance-tab rows; and the drought severity thresholds (NDWS days 15 / 20 / 25), which are the Atlas thresholds the work plan uses — confirm against the hazard specification (F3) when it is issued.

Biochar is the template because it exercises the generic rainfed-drought method (AWD uses a separate water-supply method), a route B routing decision, ERA coverage, and the maize × drought row of the loss matrix that is due first.

The recipe this example ends in is `biochar_recipe_ILLUSTRATIVE.yaml`.

---

## Step 1 — Definition

From `01` §2.2: field application of pyrolysed biomass (`b28`), compared with the same field and fertiliser regime without biochar (`h10`). Pot and incubation studies give mechanism only. Biochar–compost blends and biochar-based fertilisers are `partial_bundle` unless the char is isolated. Dose: rate, feedstock, pyrolysis temperature, particle size, application year.

Hazard hypotheses to test (`01` §4): drought (plant-available water), possibly waterlogging (drainage). No heat or flood mechanism is expected.

## Step 2 — Before searching

1. **Adaptation Insights.** Ask whether their synthesis has biochar effects separated by stress and normal season (`08`). *Illustrative answer: no biochar entries.* Proceed.
2. **Seed set.** `Literature/Biochar/` already holds ten documents, including global meta-analyses, a Kenya study (Namaswa 2026) and a Nigeria suitability study (Zubairu 2025). Read these first for mechanism, moderators and primary studies to chase. Note that the Kern 2025 folder includes a `.tif` — a possible existing maize response product. That is a **reuse-before-rebuild** candidate for route B: record it in `routing.depends_on.reuse_candidates` and assess provenance, licence, vintage and fit.
3. **ERA.** Query ERA for `b28` in SSA. *Illustrative: 38 studies, of which 9 report ≥ 2 seasons with coordinates.* Those nine go straight to `site_season` and `effect` from ERA, flagged with `era_study_code`, and a sample is verified against the papers.

## Step 3 — Search

Stress-season string, from `03` §1.3:

```
(biochar OR "bio-char" OR "pyrolysed biomass" OR "charcoal amendment")
AND (drought OR "dry spell" OR "water stress" OR "moisture stress" OR "low rainfall" OR "dry year" OR "yield stability" OR resilien*)
AND (yield OR productivity OR "grain yield")
AND (Africa OR "sub-Saharan" OR Kenya OR Ethiopia OR Nigeria OR …)
```

*Illustrative flow* (recorded in the search log and screening counts):

| Stage | Records |
|---|---|
| Identified (Scopus, CAB, Scholar top 200, CGSpace) | 412 |
| After de-duplication | 297 |
| Excluded at title/abstract | 241 (pot/incubation 88; not biochar in soil 57; mitigation only 49; method papers 21; other 26) |
| Full texts assessed | 56 |
| Excluded at full text | 39 (no season data 17; no comparator 6; confounded with fertiliser 9; duplicate of ERA 7) |
| Included | 17 (of which 3 report site-season means with coordinates) |
| Plus from ERA (Step 2), counted separately | 9 multi-season studies with coordinates |
| **Total included** | **26, of which 12 have season-level data** |

Stop rule: saturation — the last 20 full texts added no new stress site-seasons.

## Step 4 — Extraction (one study)

**SRC-ILL-01** — a three-year on-farm, researcher-managed trial at four sites in a humid highland maize zone. Biochar at 2 t/ha from a pit kiln, maize stover and tree prunings, applied once in 2019 (year 1), same NPK in both arms. Soil moisture measured. The dose is chosen to be farm-feasible: at 25–35 % char yield, 2 t/ha needs 6–8 t of feedstock, which a household can assemble from residues and prunings; 10 t/ha would need 30–40 t.

`study` row (abridged):

| Field | Value |
|---|---|
| trial_id | TRL-ILL-01 |
| management | on_farm_researcher_managed |
| design | experiment_on_farm_researcher |
| n_sites / n_seasons / n_site_seasons | 4 / 3 / 12 |
| comparator | same NPK, no biochar (`h10`) |
| contrast_type | isolated |
| dose | 2 t/ha, pit kiln, stover + prunings, applied 2019 only |
| dose_farm_feasible | yes (feedstock from own residues and prunings) |
| meets_methodology_definition | unclear (pit-kiln char may not meet a credited biochar specification — `01` §5) |
| rob_assignment / rob_selective_reporting | low (randomised plots) / low (all seasons and sites reported) |
| finding_direction | mixed |

Twelve `site_season` rows with reported coordinates, planting and harvest dates, and the authors' own season description. Twelve `effect` rows with treatment and control grain yield per site-season (t/ha). Every number gets a `quote` row, for example:

| Field | Value |
|---|---|
| record_ref | `effect.EFF-ILL-07.treatment_mean` |
| verbatim | `[ILL] Table 3 … row "Site 2, 2021 SR" … column "BC2+NPK" … 1.62` |
| locator | `p. 6, Table 3, row "Site 2, 2021 SR", column "BC2+NPK"` |
| claim | *At site 2 in the 2021 short rains, maize grain yield with 2 t/ha biochar plus NPK was 1.62 t/ha, against the NPK-only control in the same table.* |
| extraction_method | table |

A `mechanism` row (drought, soil moisture 0–30 cm higher under biochar in dry spells, `support = measured`). Two `cost` rows (below). One `characteristic` row (yield effect declines after year 3).

## Step 5 — Season classification (S5)

S5 takes the 12 site-seasons' coordinates and dates and classifies each against the fixed Atlas drought thresholds (NDWS days: moderate 15, severe 20, extreme 25). *Illustrative result:*

| Class | Site-seasons | Distinct stress events |
|---|---|---|
| Normal | 7 | — |
| Moderate | 3 (sites 1–2 in 2019; site 3 in 2021) | 2 |
| Severe | 2 (sites 1–2 in 2021, neighbouring) | 1 |
| Extreme | 0 | 0 |

The authors had called 2021 "a drought year" at all sites; S5 agrees for sites 1–3 and classes site 4 as normal. Logged as a classification disagreement; S5's classification stands.

## Step 6 — From means to coefficients

In the real synthesis these are **fitted cell means from the `02` §3.3 mixed model** across all qualifying trials, with years since application as a covariate and intervals from a trial-level bootstrap. For one trial the arithmetic is easier to follow on raw means, so this example shows them (t/ha):

| | Control Ȳ(C) | Treatment Ȳ(T) | Increment Δ |
|---|---|---|---|
| Normal | 3.00 | 3.30 | Δₙ = 0.30 |
| Moderate drought | 2.40 | 2.85 | Δₛ = 0.45 |
| Severe drought | 1.50 | 1.60 | Δₛ = 0.10 |

**Production effect** p = 0.30 ÷ 3.00 = **0.10** (normal-season basis). So the **no-buffering reference** on the absolute scale is b = −p = **−0.10** (`02` §3.2): a practice that only raised yield by 10 % in every season would score −0.10, not 0.

**Moderate drought**
- Climate-specific increment: 0.45 − 0.30 = 0.15 t/ha (150 kg/ha)
- Control-arm loss: L = (3.00 − 2.40) ÷ 3.00 = 0.20 → also a `loss_obs` row (maize × drought × moderate, method = `field_trial_control_arm`)
- Buffering: b = 0.15 ÷ 0.60 = **0.25** — a quarter of the moderate-drought loss is avoided; well above the no-buffering reference of −0.10
- Relative scale: b_rel = ln(2.85/2.40) − ln(3.30/3.00) = 0.172 − 0.095 = **+0.077** — the proportional advantage grows under moderate drought
- Check: L × b × Ȳ(C,n) = 0.20 × 0.25 × 3.00 = 0.15 ✓

**Severe drought**
- Increment: 0.10 − 0.30 = **−0.20** t/ha. The treatment still out-yields the control (1.60 vs 1.50, so Δₛ > 0 — **not** maladaptation), but its advantage shrinks from 0.30 to 0.10 t/ha.
- Control-arm loss: 3.00 − 1.50 = 1.50 t/ha (L = 0.50).
- b = −0.20 ÷ 1.50 (the control-arm loss) = **−0.13**, against a no-buffering reference of −0.10. b_rel = ln(1.60/1.50) − 0.095 = **−0.031**: the proportional advantage shrinks slightly. Signed, recorded, not truncated.
- **Confounding check:** both severe site-seasons fall in 2021, year 3 after application — and the trial reports the biochar effect declining after year 3. The shrinking advantage may be drought, age of the char, or both. With one event it cannot be separated: flag `confounded_with_establishment`.
- One distinct event fails the entry condition (≥ 2, `05` §2.1). So it does **not** enter the engine as a coefficient: it becomes `GAP-ILL-05` (reason `below_entry_conditions`, `adverse_signal = negative_b`). The adverse signal is copied to the recipe and shown on the published layer (`05` §2.5), so the favourable moderate value is never published alone.

**Extreme drought** — no observations → `GAP-ILL-06` (`no_stress_seasons`).

## Step 7 — Verification

Batch VB-ILL-01 covers SRC-ILL-01 and two others: 41 quotes checked.

- Check A (exists): 41/41 exact or minor difference.
- Check B (supports): **1 failure.** The severe-season treatment mean for site 1 was quoted from the row labelled "BC2" in a second table that, per its footnote, reports an *unfertilised* biochar arm against an unfertilised control — not the isolated contrast the claim describes. The quote is real; it does not support the claim. `failure_mode = wrong_arm`.
- Check C (blind): the verifier's reading of the correct arm differs from the extracted value.

The verifier does not edit the record. The failure is logged; the extractor replaces the value with the correct table's cell and adds a new quote row; the original rows stay in the log. Because the failed value fed a (severe) coefficient input, that coefficient was held until resolution. The batch failure rate is 1/41 ≈ 2.4 % (95 % Wilson interval roughly 0.4–13 %) — under the 5 % trigger, but the interval shows why the cumulative rate across batches is what matters. The same batch carried 6 planted errors; the verifier caught 5 (83 %), above the 80 % bar.

This is the failure the protocol is built for: a genuine quote, from the right paper, about the wrong thing.

## Step 8 — Tier

| Value | Tier | Why |
|---|---|---|
| Buffering, drought, moderate | **1** | Meets entry conditions (classified, a site with both normal and stress seasons, comparator and dose, 2 events) → base Tier 2 (one trial). Downgrade: no farmer-managed evidence (researcher-managed) → **Tier 1**. Interval 0.05–0.45 excludes the no-buffering reference −0.10, so no imprecision downgrade |
| Production effect, normal season | **1** | One trial within the stratum → base Tier 2. Downgrade: researcher-managed only → **Tier 1** |
| Longevity | **1** | Single literature statement |

The reviewer at the gate can lower these. Everything landing at Tier 1 from one good trial is the intended result: one researcher-managed trial is not strong evidence, however clean, and a published layer built on it should read Low confidence with the evidence count beside it.

## Step 9 — Routing

Evidence count and spread: 26 included studies, 12 with season-level data, clustered in two agro-ecological classes; response strongly moderated by soil pH and SOC, which are mapped. That fits **route B** (drivers known and mappable, trials too sparse to transfer by analogue) rather than route C. And a candidate existing product is in hand, so the first B task is to assess it, not to build a surface.

## Step 10 — The rest of the recipe

- **Risk reduction:** `g_risk = 0`. Mechanism test: would this gain exist in a climate with no shocks? No behavioural response to reduced risk is claimed or measured, and the indicator places the risk channel with insurance, weather-indexed credit and advisory services. Recorded with the reasoning.
- **Costs** (shared table, Chun sets defaults):

| cost_id | class | item | value | basis | currency / year | labour incl. | family labour costed | equipment | boundary quote |
|---|---|---|---|---|---|---|---|---|---|
| CST-ILL-01 | establishment_fixed | Biochar production (pit kiln) and application, 2 t/ha | 95 | per_ha | USD / 2020 stated | yes, 14 person-days at local wage, Jan–Feb | no | none (pit kiln) | QTE-ILL-88 |
| CST-ILL-02 | variable_running | None after year 1 | 0 | per_ha_per_year | — | — | — | — | QTE-ILL-89 |

  `cost_basis_source = trial_record`. Feedstock opportunity cost: `unstated` — flagged for Chun, because stover has feed and soil-cover uses (the Crosswalk requires feedstock assumptions to align across biochar, cover crops and livestock feed).
- **Temporal:** production and adaptation benefits from year 1; effect declines after year 3; re-application not evidenced.
- **Adoption:** nothing usable found; one `adoption_obs` row logging a project report with an enrolled-farmer count (project lower bound, not extent).

## Step 11 — What the engine does with it

For one maize pixel with, say, P(moderate drought) = 0.15 and a bronze loss-matrix value L(maize, drought, moderate) = 0.10 (deliberately below the trial's 0.20: trial controls are not farmers adapted to their climate, and the loss matrix is conservative at moderate severity), and baseline 2.0 t/ha:

Expected avoided loss (moderate class only) = 0.15 × 0.10 × 0.25 × 2.0 = **0.0075 t/ha/yr**.

Severe and extreme classes have no coefficient, so the pixel carries reason codes for them and the adaptation value is a partial (moderate-only) estimate — which the published layer must say.

For the indicator, the per-severity increments feed Equation 2 per pixel. With only the moderate class populated, the merged factor can be served only together with P restricted to the populated class (P = 0.15 here), flagged as partial. Serving it with the full P_stress,h (0.15 + 0.05 + 0.02) would break the exactness of P_stress,h × AF_h and would silently assume severe and extreme seasons behave like moderate ones — the opposite of what the one severe event suggests.

The grant's threshold (> 5 % reduced yield loss) needs a stated reading before it is applied. Read as *share of the hazard loss avoided*, b = 0.25 clears it. Read as *yield loss reduced by more than 5 percentage points of yield*, it does not: 0.25 × 0.10 = 2.5 points in a moderate season. Pete and S1 should fix the reading at schema freeze (`00` Q7); the evidence summary reports both until then. For anything investor-facing the percentage-point reading is the safer one — the looser reading lets most practices pass.

## What to copy from this example

1. Definition → dose and comparator fixed before searching.
2. Ask Adaptation Insights and query ERA before running a single new search.
3. Fill `site_season` even when you are not sure a study will qualify.
4. Four cell means per class, not a percentage.
5. Signed coefficients; entry conditions decide use; failures become `gap` rows.
6. Every number quoted and located; verification by someone else; failures logged, not fixed in place.
7. Tier proposed with its basis; the reviewer confirms.
