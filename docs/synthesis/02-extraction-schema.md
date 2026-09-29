# Extraction schema

The schema is designed backwards from the objects the pipeline reads (README table). Every field below names the target field it populates. Fields that populate nothing are not here; that is deliberate.

The same schema is in `extraction_schema.csv` (machine-readable) and `extraction_template.xlsx` (one sheet per table, drop-downs for enumerations, the field description as a header comment). **Change the schema in one place** — the CSV is generated from the same specification as this file and the template; if the three drift, the CSV wins until they are regenerated.

---

## 1. Structure

```
source ─┬─ study ─┬─ site_season ──┐
        │         ├─ effect ───────┘ (effect links to a site_season where reported per season)
        │         ├─ mechanism
        │         ├─ cost             → shared cost parameter table (Chun)
        │         └─ characteristic   → recipe temporal block
        ├─ loss_obs                   → loss matrix (Stream 3)
        ├─ adoption_obs               → adoption and extent table (Stream 4)
        ├─ adoption_driver            → adoption driver table (Stream 4; Chun, 10)
        ├─ benefit_share              → benefit sharing table (Streams 1, 4; Chun, 10)
        └─ quote ── verification      (every extracted value; see 04)
dataset                               → Stream 2 register
gap                                   → route D statements, evidence-gap map
```

Required codes: **R** required, **C** conditional (required when the condition in the description holds), **O** optional.

## 2. Rules that shape extraction

**Core fields first.** 74 of the fields are marked *core* (● below; `core_for_pilots = yes` in the CSV). During the three pilots only core fields are mandatory; the other required fields are filled where the source reports them. After the pilot review (mid-November) the list is revisited against how long extraction actually took.

**Extract cell means, not just percentages.** The buffering coefficient needs four numbers per hazard × severity: treatment and control, stress and normal. A reported "+18 % under drought" cannot be turned back into those. Where the paper gives means by season or site-season, extract them and fill `site_season`. Where it gives only a relative effect, extract that, and it will serve the production layer at a lower tier but not the buffering coefficient.

**Fill `site_season` even when the effect is pooled.** Coordinates and planting and harvest dates are what let S5 classify seasons against the hazard stack afterwards. A study that reports site-season means with coordinates and dates is worth several times one that reports a pooled mean, even if the second is the more rigorous trial. The classification itself (`classified_hazard`, `classified_severity`, `classified_compound`, `hazard_index_value`) is done by S5, never at extraction; the authors' own description goes in `author_condition` so the two can be compared.

**One trial, one `trial_id`.** Companion papers and the ERA record of the same trial share a `trial_id`. Independence is counted on trials, not on papers.

**Quotes.** One quote row may cover a block of a table (list rows and columns in the locator) and support several extracted values. Values imported from ERA use `quote_basis = era_record` with the ERA record id as locator and no verbatim text; a 20 % sample of ERA-imported trials is checked against the paper (`04` §2).

**Irrigated rice is different.** For AWD, DSR and SRI the hazard is irrigation water scarcity, not rainfed drought. Record the season's water supply in `site_season.irrigation_supply_note`, the level of water control in `study.water_control_level`, and irrigation applied as an `effect` row with `outcome = water_use`; S5 classifies against the water-supply deficit classes in the hazard specification (F3), and the same §3 algebra applies with *h* = `water_supply`. Until F3 defines those classes, the AWD pilot is the test of whether this works.

## 3. How extracted numbers become recipe values

### 3.1 The quantities

For one practice, hazard *h* and severity class *s*, using site-seasons classified by S5 (normal *n*, stressed *s*):

| Quantity | Definition | Lands in |
|---|---|---|
| Normal-season increment | Δₙ = Ȳ(T,n) − Ȳ(C,n) | `indicator.g_norm_kg_ha` (as observed in the source stratum) |
| Stress-season increment | Δₛ = Ȳ(T,s) − Ȳ(C,s) | `indicator.g_stress_kg_ha[h][s]` (as observed) |
| Climate-specific increment | Δₛ − Δₙ = g(h,s) − g_norm | `indicator.observed_increment_kg_ha[h][s]`; per pixel the engine recomputes it as L × b × baseline and merges via Equation 2 |
| Production effect | p = Δₙ ÷ Ȳ(C,n) | `production.effect` (basis = normal season) |
| Control-arm loss | L(h,s) = [Ȳ(C,n) − Ȳ(C,s)] ÷ Ȳ(C,n) | a `loss_obs` row, method `field_trial_control_arm`, linked by `derived_from_effect_id` |
| Buffering coefficient (absolute scale) | b(h,s) = (Δₛ − Δₙ) ÷ [Ȳ(C,n) − Ȳ(C,s)] | `adaptation.buffering[h][s]` — what the engine multiplies |
| Relative-scale buffering | b_rel(h,s) = ln[Ȳ(T,s)/Ȳ(C,s)] − ln[Ȳ(T,n)/Ȳ(C,n)] | `adaptation.buffering_rel[h][s]` — for interpretation, transfer and the proportionality test |

The identity L × b × Ȳ(C,n) = Δₛ − Δₙ holds exactly, which is why Equation 1 of the work plan (loss × buffering × baseline production) reproduces the climate-specific increment. In the engine, *b* from the synthesis is combined with *L* from the loss matrix, not with the study's own control loss.

### 3.2 What the sign of b means — read this before interpreting any value

Three different statements, which must not be confused:

| Statement | Condition | Meaning |
|---|---|---|
| The practice does worse than the baseline it replaces under stress | Δₛ < 0 | Maladaptation in the indicator's sense (a negative g_stress). Always recorded, never truncated |
| The practice's advantage shrinks under stress | b < 0 (equivalently Δₛ < Δₙ) | The absolute increment is smaller in stress seasons |
| The practice buffers nothing beyond its proportional yield gain | b = −p (equivalently b_rel = 0) | A practice that raises yield by the same proportion *p* in every season has b = −p on the absolute scale, **not 0** — there is simply less yield in a bad season for the same percentage to act on |

So on the absolute scale the "no buffering" reference is −p, not zero, and a proportional-only practice gets a small *negative* adaptation value under the current Equation 1. That is arithmetically consistent with the indicator's absolute g_stress − g_norm, but it is a method choice with consequences for how practices read on the map, and it is open question **Q8** in `00`. Until Pete decides, record **b, b_rel and p** for every coefficient, and report b against its no-buffering reference −p.

### 3.3 The estimator — pre-specified, not chosen later

Pooled ratios of noisy differences are unstable, and site-seasons are not independent. So coefficients are estimated from a model fitted to all site-season cell means for the practice, not by averaging per-study ratios.

**Primary model** (per practice × hazard, all qualifying site-seasons):

```
log(yield) ~ treatment × severity_class + years_since_establishment × treatment
             + (1 | trial_id / site) + (1 | trial_id : year)
```

- Cell means for T and C in each class are back-transformed from the fitted model; b, b_rel and p are derived from them.
- **Intervals:** cluster bootstrap by `trial_id` (resample trials, refit, recompute b); report the 10th–90th and 2.5th–97.5th percentiles. These are the `low`/`high` in the recipe and feed the Monte Carlo.
- **Years since establishment is in the model**, because stress seasons are often confounded with trial year (a drought in year 3 of a biochar trial is also year 3 of a declining biochar effect). Where stress and establishment year cannot be separated — every stress season falls in one trial year — the coefficient is flagged `confounded_with_establishment` and downgraded (`05`).
- **Within-site contrasts preferred.** A trial contributes to b only if at least one site has both a normal and a stress season; otherwise site and season are confounded and the trial informs production only.
- **Proportionality test.** Where a practice has ≥ 8 site-seasons spanning a range of control yields, also fit treatment yield on control yield (a Finlay–Wilkinson / environmental-index regression). If the slope β differs from 1, buffering is not proportional to loss and transfer of b to a different local L is questionable — record the slope and flag it. This is the check on the engine's assumption that b travels.
- **Denominator guard.** Where the fitted control-arm loss is under 0.10, b is not reported for that class (the ratio is unstable); the increment Δₛ − Δₙ and b_rel are.
- **Weights** are implicit in the mixed model. For pooling summary-level effects that lack site-season data (production layer), use the log response ratio with the small-sample correction, and replication-based weights (nₜ·n_c ÷ (nₜ + n_c)) where variances are missing; rerun without imputed variances as a sensitivity check.
- **Low-incidence outcomes** (mortality near zero): use risk differences, not ratios; S4 converts to production loss.
- **Shared controls:** effect rows with the same `shared_control_group` enter with one dose per trial (the one closest to the farm-feasible dose), pre-specified; the others are a sensitivity analysis.
- **Moderators:** meta-regression only with about 10 or more independent trials per moderator. Below that, stratify descriptively and flag the moderator `hypothesised`.
- **Compound seasons** (`classified_compound` not `none`) are excluded from single-hazard coefficients. They are counted, and if they are common for a practice the recipe says so.
- **Bundles:** isolated and bundle contrasts are never pooled. `contrast_type` is run as a moderator in a sensitivity analysis to show whether the bundle rule changes the conclusion.
- **Pooled-only evidence:** where only a pooled effect exists, `production.basis = pooled` and the tier drops (pooled effects contain stress seasons).
- **Author-labelled seasons** are usable provisionally; S5's classification overrides and disagreements are logged. S5 also checks its classes against control-arm yield anomalies, and b is reported with its sensitivity to shifting class boundaries by one class, using `hazard_index_value`.
- **Risk reduction (g_risk)** is decided once per practice on the mechanism test: *would this gain exist in a climate with no shocks?* Yes → production; no → risk management. Expect **no** for every agronomic practice here. Record `g_risk = 0` with that reasoning. Only a study that reports a measured behavioural response to reduced risk fills `study.risk_channel_evidence`.

The model is written once, in code (R `lme4`/`metafor` or equivalent), in the project repository, and frozen with the protocol (`07`). Namita and S5 run it; nobody hand-computes a published coefficient.

## 4. Mapping to the recipe

Recipe blocks follow Annex B of the work plan. What the synthesis supplies and from where:

| Recipe field | Filled from | Notes |
|---|---|---|
| `identity.*` | `01-practice-definitions`, `study.era_codes`, `study.subtype` | |
| `routing.route`, `routing.justification` | Analyst judgement from the evidence count and spread | Route assignment is an output of the review (F7 routing table) |
| `routing.depends_on` | Drivers (route B) from the site covariates in `site_season` (reported, or attached by S5 from coordinates); evidence classes (route C) from S5's stratum assignment | Drivers stay even though separate enabler flags were struck (D3) |
| `adaptation.hazards`, `adaptation.mechanism` | `mechanism` | No defensible mechanism → no adaptation layer for that hazard, and a `gap` row |
| `adaptation.buffering[h][s]`, `buffering_rel`, `adverse_signals` | `effect` × `site_season` via the §3.3 model; `gap.adverse_signal` | With n independent trials, stress site-seasons, tier, sources |
| `production.effect[stratum]` | `effect` (normal-season or pooled) | central, low, high, unit, basis |
| `production.moderators` | `study.dose`, `effect.dose`, `study.years_since_establishment`, `study.water_regime`, `site_season` soil covariates | |
| `production.reused_products` | Search notes | Existing response or suitability products found — reuse before rebuild |
| `temporal.*` | `characteristic`, `study.years_since_establishment` | Time to benefit separately for production and adaptation |
| `economics.cost_refs` | `cost` ids in the shared cost table | Chun sets defaults |
| `uncertainty.distributions` | low/high and dispersion from `effect` | S5 fits distributions |
| `uncertainty.analogue_domain` | Evidence strata vs target strata | proven / extrapolated / unknown |
| `indicator.*` | §3, classified `site_season` rows (or `study.n_site_seasons` where rows are absent), S5 | hazard benchmark, W, site-seasons observed, stress site-seasons observed, evidence tier, reversal-risk flag |
| `governance.*` | `source`, `gap`, `study.finding_direction` | Evidence summary, gaps, reviewer |
| `extent.*` | **Not the synthesis** — computed by the engine | |

## 5. Livestock outcomes (decision D2)

**What counts as stress for livestock.** The dry season comes every year; it is not a hazard. A stress season is one S5 classifies as a hazard season against the fixed thresholds — a failed or poor rainy season (forage drought) or a THI exceedance — not the normal annual dry season. Gains from feeding a fodder bank or conserved feed through a *normal* dry season are **production**; only the extra gain in a *failed* season, beyond that, is **adaptation**. Without this rule, dry-season feeding benefits would be booked as buffering.

Extract in the unit reported, with species and production system, and let S4 convert. Preferred outcomes, in order:

| Outcome | Unit to record | Loss-matrix block |
|---|---|---|
| Milk yield | kg/head/day, or kg/lactation with lactation length | THI → milk |
| Liveweight gain | g/head/day, or kg over a stated period | THI → liveweight; drought → liveweight |
| Mortality | % of herd **per event** or **per year** — record which in `unit`; they are not interchangeable | Drought → mortality |
| Body condition score, herd-size change | score; % change | Record where reported (`outcome = other`, named in unit); informs mechanism and W |
| Forage biomass | kg DM/ha at a stated time in the season | Drought → forage |
| Reproduction (calving rate, calving interval) | — | Not extracted as a field. Note it in `source.note` if reported |

Record `commodity` as species (cattle, sheep, goats, camels) and the production system in the study note (pastoral, agro-pastoral, mixed, intensive dairy).

**Forage is mechanism evidence, not buffering evidence.** Standing biomass in a rested paddock is higher partly because less of it was eaten, and per-head gains are confounded with stocking rate. So: forage-only studies populate `mechanism`, not `adaptation.buffering`; a livestock buffering coefficient needs an animal outcome, and either equal stocking rates across arms (`study.stocking_rate_equal = yes`) or outcomes expressed per hectare. Where a recipe has only forage evidence, S4's forage-to-livestock translation is used at Tier 1 and the recipe says so.

**Communal land.** For rotational or deferred grazing on communal land, the unit of observation is the grazing unit or community, not the hectare; record `herd_mobility` and `enforcement_note`, because mobility and enforcement confound herd outcomes.

## 6. The shared cost parameter table (decision D5)

The `cost` table *is* the shared table. Agree its columns with Chun before the first extraction; the draft below is the proposal. The rule that matters: **a cost figure whose boundary is unstated is recorded with the boundary fields as `unstated` and flagged — it is not silently used, and it is not silently dropped.** `boundary_quote_id` points at the sentence that says what the figure includes; if there is no such sentence, it says `none`, and that is a finding.

Reported benefit–cost ratios, IRRs and NPVs are not extracted. They embed someone else's boundary and discount rate.

**Farm level first, project level when met.** Farm-level establishment and running costs are the priority. Carbon-project documents (PDDs, monitoring and verification reports) also report project-level costs an investor needs — setup, aggregation and extension, MRV, validation and verification, registry fees, farmer payments — and these are captured with their own `cost_class` values when found, with `n_farmers_covered`, `area_ha_covered` and `project_year` so they can be normalised and profiled over a crediting period. They are not searched for separately; Chun decides which enter NEB. `cost_basis_source` separates outturns (trial records, monitoring reports) from plans (budgets, PDD estimates).

Cost defaults Chun sets from this table carry the same tier and evidence counts as effect sizes, so the investor-facing tool never shows a cost with less provenance than a benefit.

## 7. Fields

### `source` — stream all

One row per document screened in at full text.

| Field | Core | Type | Req | Allowed / unit | Description | Lands in |
|---|---|---|---|---|---|---|
| `source_id` | ● | id | R | SRC-0001 | Unique id | governance.sources |
| `citation` | ● | string | R |  | Full citation | governance.sources |
| `doi_or_url` |  | string | C |  | DOI, or stable URL for grey literature. Required where one exists | governance.sources |
| `doc_type` | ● | enum | R | peer_reviewed \| grey_report \| project_evaluation \| thesis \| dataset \| carbon_project_document \| meta_analysis \| review | Document type | confidence metadata (tier) |
| `file_path` | ● | string | R |  | Path of the stored PDF or file in the project folder, so a verifier opens the same version | verification |
| `era_study_code` |  | string | O |  | ERA code if the study is already in ERA — avoids re-extracting what ERA holds | governance.sources |
| `streams` |  | enum-multi | R | 1 \| 2 \| 3 \| 4 | Streams this source feeds | screening log |
| `screened_by` |  | string | R |  | Who screened it in (person, and AI tool if used) | screening log |
| `note` |  | string | O |  | Free text. The home for anything interesting that lands in no target object | none |

### `study` — stream 1

One row per experiment, trial or evaluation within a source (a source can hold several).

| Field | Core | Type | Req | Allowed / unit | Description | Lands in |
|---|---|---|---|---|---|---|
| `study_id` | ● | id | R | STU-0001 | Unique id | all child tables |
| `source_id` | ● | id | R |  | Parent source | governance.sources |
| `trial_id` | ● | id | R | TRL-0001 | One id per physical trial or evaluation, shared by companion papers and by the ERA record of the same trial. De-duplicate and count independence on this, not on source or DOI | independence unit for pooling and tier (n independent trials) |
| `practice_id` | ● | enum | R | awd \| biochar \| rotational_grazing \| ca_bundle \| cover_crops \| nutrient_mgmt_b \| trees_in_farmlands \| fodder_banks \| feed_mgmt \| silvopasture \| dsr \| sri \| erw | Practice, per 01-practice-definitions | identity.practice_id |
| `subtype` |  | string | C |  | Sub-pathway tag where the definition requires one (parkland|alley; deferred; moderate|severe AWD) | identity.subtype |
| `era_codes` | ● | string | R | b28; h10 | era-aom leaf codes for treatment and control; 'none' plus nearest code where no leaf exists | identity.era_codes |
| `management` | ● | enum | R | on_station \| on_farm_researcher_managed \| on_farm_farmer_managed \| farmer_practice_observed \| modelled | Who managed the practice. Pooling stratum and tier downgrade (researcher-managed effects typically exceed farmer-managed) | tier; production.strata |
| `design` | ● | enum | R | experiment_on_station \| experiment_on_farm_researcher \| experiment_on_farm_farmer \| rct \| quasi_experimental \| panel \| survey_single_round \| modelled \| project_evaluation \| observational | Study design | confidence metadata (tier) |
| `country` | ● | string | R | ISO3; several separated by ; | Countries | production.strata; uncertainty.analogue_domain |
| `n_sites` |  | integer | R |  | Number of distinct sites | tier; cross-check of site_season rows (site-season counts in the recipe come from classified site_season rows) |
| `n_seasons` |  | integer | R |  | Number of cropping seasons (or grazing years) observed | tier; cross-check of site_season rows (site-season counts in the recipe come from classified site_season rows) |
| `n_site_seasons` | ● | integer | R |  | Site × season combinations actually observed (not sites × years if some are missing) | tier; indicator.site_seasons_observed where site_season rows are not reported |
| `plot_or_area` |  | string | R | m2 or ha; herd size; 'not reported' | Plot size, study area or herd size. Write 'not reported' rather than leaving it empty | confidence metadata |
| `comparator` | ● | string | R |  | What the effect was measured against, in words (for example 'continuous flooding, same variety and N') | production.comparator; adaptation.comparator |
| `comparator_era_code` |  | string | R | h48 | era-aom control code, or 'none' | identity.era_codes |
| `contrast_type` | ● | enum | R | isolated \| defined_bundle \| partial_bundle \| confounded | See 01 §1.2 | tier; pooling rule |
| `bundle_components` |  | string | C |  | Every component of the treatment where contrast_type is not isolated | governance.evidence_summary |
| `dose` | ● | string | R |  | Dose or intensity as implemented, using the descriptors listed for the practice in 01 (rate, threshold, stocking rate, density, age…) | production.moderators; uncertainty |
| `dose_farm_feasible` |  | enum | R | yes \| no \| unclear | Could smallholders apply this dose with locally available resources (feedstock, labour, seedlings, water control)? State the basis in note. Infeasible doses are kept but stratified | production.strata; tier |
| `meets_methodology_definition` |  | enum | R | yes \| no \| unclear | Does the practice as implemented meet the carbon methodology's practice definition (01 §5)? | identity.methodology_alignment; strata |
| `rob_assignment` | ● | enum | R | low \| some \| high \| unclear | Risk of bias: how treatment was assigned (randomised plots / matched / self-selected) | tier (risk-of-bias downgrade) |
| `rob_confounding` |  | enum | R | low \| some \| high \| unclear | Baseline differences between arms (soil, site history, farmer characteristics) | tier |
| `rob_comparator_fidelity` |  | enum | R | low \| some \| high \| unclear | Was the comparator what it claims (same fertiliser, same variety, same management)? | tier |
| `rob_outcome_measurement` |  | enum | R | low \| some \| high \| unclear | Measured (harvested, weighed) vs recalled or estimated outcome | tier |
| `rob_selective_reporting` | ● | enum | R | low \| some \| high \| unclear | Are some seasons, sites or arms reported and others dropped? Season-level results shown only for 'interesting' years count as high | tier |
| `mean_farm_size_ha` |  | number | O | ha | Mean farm size of participants, where reported | per-household translation (zone statistics) |
| `area_under_practice_per_hh_ha` |  | number | O | ha | Area under the practice per participating household | per-household translation |
| `years_since_establishment` | ● | number | C | years | Years since the practice started at the observation. Required for CA, trees, biochar, rotational grazing | temporal.ramp_up |
| `water_regime` | ● | enum | R | rainfed \| irrigated_full \| irrigated_supplemental \| mixed | Water regime | production.strata |
| `water_control_level` |  | enum | C | field \| block \| scheme \| none | Irrigated rice only: who controls water timing. In many SSA schemes the scheme sets rotations, not the farmer | AWD/DSR/SRI routing and strata |
| `residue_cover_at_planting` |  | string | C | % cover or t/ha | CA and cover crops only: residue cover MEASURED at planting (not intended). Post-harvest grazing often removes it | CA bundle test; production.moderators |
| `stocking_rate_equal` |  | enum | C | yes \| no \| unstated | Rotational grazing, silvopasture: were stocking rates equal across arms? If not, per-head gains are confounded | tier; buffering eligibility |
| `herd_mobility` |  | enum | C | sedentary \| seasonal_mobility \| highly_mobile \| unstated | Livestock on communal land: mobility confounds herd outcomes | strata; tier |
| `enforcement_note` |  | string | C |  | Communal grazing reserves: how rest is enforced (by-law, committee, customary) | governance.evidence_summary |
| `finding_direction` | ● | enum | R | positive \| null \| negative \| mixed | Overall direction for the practice on the primary outcome. Null and negative are recorded, never dropped | governance.evidence_summary |
| `risk_channel_evidence` |  | string | C |  | Only if the study reports a behavioural response to reduced risk (more fertiliser, credit, higher-value crops, more area). Otherwise leave empty — the practice-level g_risk determination is made once, in the recipe | indicator.g_risk |
| `adoption_logged` |  | boolean | O |  | Tick if the source also reports adoption or extent; add a row to adoption_obs | adoption table |

### `site_season` — stream 1, 2

One row per site × season. This is what lets S5 classify seasons against the hazard stack afterwards. Fill it whenever the study reports site-season detail, even if the effect is only reported pooled.

| Field | Core | Type | Req | Allowed / unit | Description | Lands in |
|---|---|---|---|---|---|---|
| `site_season_id` | ● | id | R | SS-0001 | Unique id | effect.site_season_id |
| `study_id` | ● | id | R |  | Parent study |  |
| `site_name` |  | string | R |  | As reported | verification |
| `lat` | ● | number | R | decimal degrees | Latitude | season classification → indicator.hazard_benchmark |
| `lon` | ● | number | R | decimal degrees | Longitude | season classification |
| `coord_source` | ● | enum | R | reported \| geocoded_place \| admin_centroid | How the coordinates were obtained. Geocoded values are recorded as such, never passed off as reported | classification confidence |
| `season_label` |  | string | R | for example 2019 long rains | Season as reported | season classification |
| `year` | ● | integer | R |  | Year of harvest | season classification |
| `planting_date` | ● | date | C | YYYY-MM-DD or YYYY-MM | Planting or sowing date, or start of grazing season. Required where reported; otherwise leave empty and S5 uses the crop calendar | season classification |
| `harvest_date` | ● | date | C | YYYY-MM-DD or YYYY-MM | Harvest date or end of season | season classification |
| `author_condition` | ● | enum | R | normal \| stress \| unknown | Season condition as the authors describe it (not our classification) | cross-check of classification |
| `author_condition_basis` |  | string | C |  | What the authors base it on (for example 'rainfall 310 mm vs 620 mm long-term mean'). Required if author_condition = stress | cross-check |
| `seasonal_rainfall_mm` |  | number | O | mm | If reported | cross-check |
| `irrigation_supply_note` |  | string | C |  | Irrigated rice (AWD, DSR, SRI) only: water supply or scheme allocation in the season as reported (for example 'canal closed six weeks', 'supply 60% of demand') | water-supply deficit classification (S5) |
| `soil_ph` |  | number | O |  | Reported site soil pH. Where not reported S5 attaches it from lat/lon (SoilGrids or the base-layer stack) | production.moderators; routing.depends_on.drivers; production.effect.stratum |
| `soil_organic_carbon_pct` |  | number | O | % | Reported SOC. Same rule | production.moderators; routing drivers |
| `texture_or_clay_pct` |  | string | O | texture class or % clay | Reported texture. Same rule | production.moderators; routing drivers |
| `aez_reported` |  | string | O |  | Agro-ecological zone as the authors state it. S5 assigns our stratum | production.effect.stratum (cross-check) |
| `classified_hazard` |  | enum | O | drought \| heat \| waterlogging \| flood \| water_supply | FILLED BY S5, not by extraction | adaptation.buffering[hazard] |
| `classified_severity` |  | enum | O | normal \| moderate \| severe \| extreme | FILLED BY S5 — against the fixed Atlas thresholds, or for water_supply against the deficit classes in the hazard specification (F3) | adaptation.buffering[hazard][severity] |
| `classified_compound` |  | string | O | none  \|  e.g. drought+heat | FILLED BY S5: other hazards exceeding a threshold in the same season. Compound seasons are excluded from single-hazard coefficients unless the estimator models them | per-hazard estimation; no cross-hazard double counting |
| `hazard_index_value` |  | number | O |  | FILLED BY S5: the continuous index value (for example NDWS days), kept so class-boundary sensitivity can be tested | sensitivity of b to ±1 class |

### `effect` — stream 1

One row per outcome contrast. Treatment and control means are preferred over reported percentages, because the buffering coefficient needs the four cell means.

| Field | Core | Type | Req | Allowed / unit | Description | Lands in |
|---|---|---|---|---|---|---|
| `effect_id` | ● | id | R | EFF-0001 | Unique id |  |
| `study_id` | ● | id | R |  | Parent study |  |
| `site_season_id` | ● | id | C |  | Required when the effect is reported per site-season. Empty for pooled effects | buffering (via classification) |
| `treatment_arm` | ● | string | R |  | Treatment arm label exactly as in the source (for example 'BC10+NPK') | verification (wrong_arm check); pooling |
| `control_arm` | ● | string | R |  | Control arm label exactly as in the source (for example 'NPK') | verification; production.comparator |
| `dose` |  | string | C |  | Required when this arm's dose differs from study.dose (multi-rate trials) | production.moderators |
| `aggregation` | ● | enum | R | site_season \| pooled_seasons \| pooled_sites \| pooled_all \| meta_analytic | Level at which the effect is reported | tier; production.basis |
| `reported_condition` | ● | enum | R | normal \| stress \| pooled \| unknown | Season condition the effect refers to, as reported | production (normal) vs buffering (stress) |
| `outcome` | ● | enum | R | crop_yield \| biomass_yield \| milk_yield \| weight_gain \| meat_yield \| animal_mortality \| animal_survival \| body_condition \| herd_size_change \| forage_biomass \| water_use \| soil_moisture \| other | era-aom outcome label (Productivity → Product Yield; Resilience → Animal Survival; Efficiency → Water Use; Soil Quality → Soil Moisture) | production.effect / adaptation.buffering for yield and livestock outcomes; soil_moisture → mechanism evidence; water_use → AWD/DSR/SRI water-demand ratio |
| `commodity` | ● | string | R | MapSPAM crop or livestock species | Crop or species | identity.commodities; loss matrix key |
| `unit` | ● | string | R | t/ha; kg/head/day; g/head/day; % mortality; kg DM/ha | Unit as reported | production.unit |
| `treatment_mean` | ● | number | C |  | Required unless only a relative effect is reported | g computation |
| `control_mean` | ● | number | C |  | Required unless only a relative effect is reported | g computation; loss matrix (silver) from control arm |
| `n_treatment` | ● | integer | C |  | Replicates or sample size in the treatment arm. Required where reported — used for replication-based weights when variance is missing | pooling weights; uncertainty |
| `n_control` | ● | integer | C |  | Same for the control arm | pooling weights |
| `shared_control_group` |  | string | C |  | Label shared by effect rows that use the same control (multi-rate trials), so the control is not counted several times | independence handling |
| `dispersion_type` |  | enum | O | sd \| se \| ci95 \| cv \| lsd \| none | Type of variance statistic | uncertainty.distributions |
| `dispersion_value` |  | number | O |  | Value | uncertainty.distributions |
| `relative_effect` |  | number | C | fraction, e.g. 0.12 = +12% | Only where means are not reported. Record which metric in relative_effect_type | production.effect |
| `relative_effect_type` |  | enum | C | pct_change \| log_response_ratio \| ratio \| difference | Metric of relative_effect |  |
| `extraction_method` |  | enum | R | text \| table \| figure_digitised \| computed | How the number was obtained. Figure-digitised and computed values carry extra verification | verification |

### `mechanism` — stream 1

One row per practice × hazard mechanism statement supported by the source.

| Field | Core | Type | Req | Allowed / unit | Description | Lands in |
|---|---|---|---|---|---|---|
| `mechanism_id` |  | id | R | MEC-0001 | Unique id |  |
| `study_id` |  | id | R |  | Parent study |  |
| `hazard` |  | enum | R | drought \| heat \| waterlogging \| flood \| water_supply | Hazard | adaptation.hazards |
| `pathway` |  | string | R |  | Causal pathway in one sentence (for example 'higher plant-available water in the 0–30 cm layer extends crop water supply during dry spells') | adaptation.mechanism[hazard] |
| `mechanism_variable` |  | string | O |  | Measured intermediate (soil moisture, canopy temperature, THI under shade…) | adaptation.mechanism evidence |
| `support` |  | enum | R | measured \| authors_inferred \| hypothesised | Whether the pathway was measured in this study or asserted | confidence |
| `stress_season_difference` |  | enum | R | yes \| no \| not_tested | Did the mechanism variable differ between arms IN STRESS SEASONS? A difference in normal seasons only does not support an adaptation mechanism | adaptation.mechanism (support rule) |
| `direction` |  | enum | R | supports \| null \| contradicts | Whether the evidence supports the mechanism. 'supports' requires stress_season_difference = yes and support = measured, or authors' analysis linking it to the yield difference | adaptation.mechanism |

### `cost` — stream 1

Shared with Chun Song. One row per cost item. A figure with no boundary statement is recorded with boundary fields 'unstated' and flagged; Chun decides whether it is usable.

| Field | Core | Type | Req | Allowed / unit | Description | Lands in |
|---|---|---|---|---|---|---|
| `cost_id` | ● | id | R | CST-0001 | Unique id | cost table |
| `source_id` | ● | id | R |  | Parent source. Cost-only grey reports need no study row | governance.sources |
| `study_id` |  | id | C |  | Parent study, where the cost comes from a study already extracted |  |
| `country` |  | string | R | ISO3 | Country the figure applies to (Chun sets defaults per practice × country) | cost table |
| `admin1` |  | string | O |  | Subnational unit if stated | cost table |
| `practice_id` | ● | enum | R | (as study) | Practice | cost table |
| `cost_class` | ● | enum | R | establishment_fixed \| variable_running \| replacement \| maintenance \| total \| project_setup \| aggregation_extension \| mrv_monitoring \| validation_verification \| registry_issuance \| farmer_payment | Farm level: establishment_fixed, variable_running, replacement, maintenance (era-aom Fixed/Variable Cost), and total for a reported total cost (`10` §3.4: alongside its components, never instead of them; set `author_computed`). Project level (carbon-project documents): project_setup … farmer_payment. Farm-level rows are the priority; project-level rows are captured when met, not searched for separately | cost table |
| `item` | ● | string | R |  | What the figure covers (for example 'biochar production, kiln and labour') | cost table |
| `value` | ● | number | R |  | As reported | cost table |
| `unit_basis` | ● | enum | R | per_ha \| per_ha_per_season \| per_ha_per_year \| per_head \| per_farm \| per_project \| per_tonne_input | Denominator | cost table |
| `currency` | ● | string | R | ISO 4217 | As reported. Not converted | cost table (Chun converts) |
| `price_year` | ● | integer | R |  | Year of the prices. If unstated, record publication year and set price_year_basis | cost table |
| `price_year_basis` |  | enum | R | stated \| assumed_publication_year \| assumed_data_year |  | cost table |
| `labour_included` | ● | enum | R | yes \| no \| unstated | Is labour in the figure? | cost table boundary |
| `labour_days` |  | number | C | person-days per unit_basis | Required if reported | cost table |
| `labour_rate` |  | string | C | value, currency, basis | Rate used and its basis (market wage, opportunity cost, minimum wage) | cost table boundary |
| `family_labour_costed` | ● | enum | R | yes \| no \| unstated | Is family labour valued? | cost table boundary |
| `inputs_included` |  | enum | R | yes \| no \| unstated | Materials and inputs | cost table boundary |
| `transport_included` |  | enum | R | yes \| no \| unstated |  | cost table boundary |
| `equipment_included` |  | enum | R | purchase \| hire \| depreciated \| no \| unstated | How equipment enters | cost table boundary |
| `training_included` |  | enum | R | yes \| no \| unstated | Training or extension | cost table boundary |
| `certification_mrv_included` |  | enum | R | yes \| no \| unstated | Certification, MRV, carbon-project costs | cost table boundary |
| `opportunity_cost_included` |  | enum | R | yes \| no \| unstated | Land, residue or feedstock opportunity cost | cost table boundary |
| `in_kind_items` |  | string | O |  | Inputs provided free or subsidised (seedlings, cuttings, kilns, herbicide) and by whom | cost table boundary |
| `subsidy_share` |  | number | O | fraction | Share of the cost covered by a programme or project | cost table (Chun) |
| `cost_basis_source` | ● | enum | R | trial_record \| farmer_recall \| project_budget \| project_monitoring_report \| pdd_estimate \| expert_estimate | Where the figure comes from — budgets and PDD estimates are plans, not outturns | cost table (confidence) |
| `labour_months` |  | string | O |  | When the labour falls (for example 'Feb–Mar, before planting') — peak-season labour matters more than totals | cost table; Chun |
| `labour_by_sex` |  | string | O |  | Who does the labour, where reported (for example weeding shifts to women under CA) | cost table; gender reporting |
| `n_farmers_covered` |  | integer | C |  | Required for per_project and per_farm figures so they can be normalised | cost table |
| `area_ha_covered` |  | number | C | ha | Required for per_project figures | cost table |
| `project_year` |  | integer | C |  | Year of the project or practice the cost falls in (1 = establishment). Required where reported, so costs over a crediting period can be profiled | cost table; temporal profile |
| `crediting_period_years` |  | number | O |  | For carbon-project documents | cost table |
| `stocking_rate_tlu_ha` |  | number | C | TLU/ha | Rotational grazing cost rows: stocking rate and grazing area, so costs convert to per ha | cost table |
| `cost_bearer` |  | enum | R | farmer \| programme \| project_developer \| mixed \| unstated | Who pays | cost table (Chun decides what enters NEB) |
| `author_computed` |  | enum | R | yes \| no | yes when the figure is the authors' own aggregate (a total, an annualised or discounted cost) rather than an itemised cost. Kept and flagged; Chun decides whether it is used (`10` §3.4) | cost table (confidence) |
| `discount_rate` |  | number | C | fraction | Required when the figure is discounted | cost table (Chun) |
| `horizon_years` |  | number | C | years | Planning horizon. Required when the figure is discounted or annualised | cost table (Chun) |
| `boundary_quote_id` | ● | id | R |  | Quote id for the sentence or table note that states what the figure includes. If none exists, record 'none' — that itself is the finding | verification |

### `characteristic` — stream 1

Practice characteristics. One row per characteristic reported.

| Field | Core | Type | Req | Allowed / unit | Description | Lands in |
|---|---|---|---|---|---|---|
| `char_id` |  | id | R | CHR-0001 | Unique id |  |
| `source_id` |  | id | R |  | Parent source | governance.sources |
| `study_id` |  | id | C |  | Parent study, where one exists |  |
| `characteristic` |  | enum | R | longevity_years \| replacement_cycle_years \| mortality_replanting_pct \| time_to_production_benefit_years \| time_to_adaptation_benefit_years \| years_to_steady_state \| persistence_after_cessation \| persistence_after_payments_end \| reversal_risk | Which characteristic. Time to benefit is recorded separately for production and adaptation. Disadoption goes in adoption_obs | temporal.* |
| `value` |  | number | C |  | Numeric value where one is given | temporal.* |
| `unit` |  | string | C |  |  | temporal.* |
| `description` |  | string | C |  | Where the finding is qualitative (for example reversal risk from tillage reversion) | temporal.reversal_risk; indicator.reversal_risk_flag |

### `loss_obs` — stream 3

Stream 3 — practice-independent loss evidence. One row per system × hazard × event or experiment.

| Field | Core | Type | Req | Allowed / unit | Description | Lands in |
|---|---|---|---|---|---|---|
| `loss_id` |  | id | R | LOS-0001 | Unique id | loss matrix sources |
| `source_id` |  | id | R |  | Parent source |  |
| `system` |  | enum | R | crop \| livestock |  | loss matrix key |
| `commodity` |  | string | R | MapSPAM crop; cattle \| sheep \| goats \| camels; dairy \| beef |  | loss matrix key |
| `livestock_metric` |  | enum | C | milk \| liveweight \| mortality \| forage_dm | Required for livestock | loss matrix key (livestock block) |
| `hazard` |  | enum | R | drought \| heat \| waterlogging \| flood \| water_supply | water_supply for irrigated rice under supply deficit | loss matrix key |
| `hazard_index` |  | string | R | for example SPI-3, NDWS days, NTx35 days, THI, flood duration days, % of normal rainfall | The index the loss is linked to | severity mapping |
| `hazard_index_value` |  | number | C |  | Value of that index in the event or treatment | severity mapping |
| `severity_reported` |  | string | O |  | Severity as the source describes it | cross-check |
| `severity_mapped` |  | enum | O | moderate \| severe \| extreme | Mapped to our classes by Pete/S5 against the Atlas thresholds — not by extraction | loss matrix key |
| `location` |  | string | R | country; admin1; lat/lon if given |  | loss matrix strata |
| `year` |  | string | R |  | Year or season | cross-check with hazard stack |
| `loss_value` |  | number | R | fraction (0.35 = 35% loss) | Production lost | loss matrix value |
| `loss_reference` |  | enum | R | vs_normal_season \| vs_long_term_mean \| vs_trend \| vs_potential \| vs_non_stressed_control | What the loss is measured against. Must be stated — see open question Q4 | loss matrix definition |
| `method` |  | enum | R | event_report \| managed_stress_trial \| field_trial_control_arm \| statistical_yield_weather \| crop_model \| expert_elicitation \| insurance_record | How the loss was established | loss matrix tier (bronze/silver/gold) |
| `attribution_note` |  | string | O |  | Confounders (conflict, prices, pests) the source mentions | confidence |
| `derived_from_effect_id` |  | id | C |  | Required when method = field_trial_control_arm. Such rows form a separate stratum, are never pooled with event reports, and are never used to validate the b they came from | loss matrix stratum; independence |

### `adoption_obs` — stream 4

Stream 4 — adoption and current extent. One row per practice × geography × year × measure.

| Field | Core | Type | Req | Allowed / unit | Description | Lands in |
|---|---|---|---|---|---|---|
| `adoption_id` |  | id | R | ADO-0001 | Unique id | adoption table |
| `source_id` |  | id | R |  | Parent source |  |
| `practice_id` |  | enum | R | (as study) |  | adoption table |
| `definition_used` |  | string | R |  | The source's definition of adoption, verbatim or close | adoption table |
| `definition_match` |  | enum | R | exact \| broader \| narrower \| different | Against our definition in 01. Survey 'minimum tillage' often means something else | adoption table (usability) |
| `methodology_match` |  | enum | R | yes \| no \| unclear | Against the carbon methodology's practice-change definition (01 §5) | adoption table (additionality screen) |
| `context` |  | enum | R | pre_project_baseline \| within_project \| non_project \| national_general | Whether the figure describes a baseline, a project population or the general population. Baseline adoption bears on additionality | adoption table; Activity 4 |
| `reporter` |  | enum | R | independent_survey \| implementer_self_report \| remote_sensing \| registry | Implementer self-reports tend to count trainees as adopters | adoption table (confidence) |
| `ever_vs_current` |  | enum | R | current \| ever \| unstated | Current use vs ever tried | adoption table |
| `intensity` |  | string | O |  | Share of plots or area under the practice among adopters; components used (partial adoption of bundles) | adoption table |
| `geography_level` |  | enum | R | national \| admin1 \| admin2 \| project \| site |  | adoption table |
| `geography` |  | string | R | ISO3; admin names |  | adoption table |
| `year` |  | integer | R |  | Reference year of the data | adoption table; Activity 4 scenario B/C |
| `measure` |  | enum | R | share_households \| share_area \| area_ha \| number_farmers \| number_animals |  | adoption table |
| `value` |  | number | R |  |  | adoption table |
| `denominator` |  | string | C |  | Denominator for shares (all farm households; rice growers…) | adoption table |
| `value_women` |  | number | O |  | Where sex-disaggregated (holder or manager — record which in note) | adoption table (grant requires women and men) |
| `value_men` |  | number | O |  |  | adoption table |
| `data_source_type` |  | enum | R | national_survey \| lsms_isa_panel \| agricultural_census \| project_records \| remote_sensing \| carbon_registry \| expert_estimate |  | adoption table (confidence) |
| `sample_size` |  | integer | O |  |  | adoption table (confidence) |
| `representative` |  | enum | R | national \| subnational \| project_only \| unknown |  | adoption table (confidence) |
| `disadoption` |  | number | C | fraction | Required where reported | adoption table; temporal.reversal_risk |
| `disadoption_period_years` |  | number | C | years | Period over which disadoption is measured. Required with disadoption | adoption table |
| `disadoption_reason` |  | string | O |  | Stated reasons (end of subsidy, labour, tenure…) | temporal.reversal_risk |

### `adoption_driver` — stream 4

Added for Chun's analysis (`10` §3.2, §3.3). What makes farmers adopt, including payment experiments and choice experiments. One row per driver per model. Null and non-significant drivers are extracted too.

| Field | Core | Type | Req | Allowed / unit | Description | Lands in |
|---|---|---|---|---|---|---|
| `driver_id` |  | id | R | ADR-0001 | Unique id | adoption driver table |
| `source_id` |  | id | R |  | Parent source | governance.sources |
| `practice_id` |  | enum | R | (as study) | Practice | adoption driver table |
| `country` |  | string | R | ISO3 |  | adoption driver table |
| `driver` |  | string | R |  | The factor, in the source's terms (credit access, tenure, extension contact, payment level) | adoption driver table |
| `driver_class` |  | enum | R | finance \| tenure \| information_extension \| payment_incentive \| labour \| market \| household \| other | For grouping across studies. Payment experiments and choice experiments use payment_incentive | adoption driver table |
| `stated_preference` |  | enum | R | yes \| no | yes for choice experiments and willingness-to-accept studies; no for observed behaviour, including randomised payment experiments. Never pooled | adoption driver table (confidence) |
| `effect_value` |  | number | R |  | As reported | adoption driver table |
| `effect_unit` |  | enum | R | percentage_points \| odds_ratio \| marginal_effect \| elasticity \| payment_level \| other | payment_level for a payment needed to induce participation; currency and basis in the quote | adoption driver table |
| `model` |  | string | R |  | Estimation model (probit, logit, double hurdle, RCT difference, conditional logit) | adoption driver table (confidence) |
| `significant` |  | enum | R | yes \| no \| unstated | At the level the source reports | adoption driver table |
| `sample_size` |  | integer | O |  |  | adoption driver table (confidence) |
| `quote_id` |  | id | R |  | Verbatim support | verification |

### `benefit_share` — streams 1, 4

Added for Chun's analysis (`10` §3.1). The share of carbon income that reaches farmers. Extracted when a document already opened for costs or adoption reports it, mostly carbon-project documents and their evaluations; no separate search.

| Field | Core | Type | Req | Allowed / unit | Description | Lands in |
|---|---|---|---|---|---|---|
| `benefit_share_id` |  | id | R | BSH-0001 | Unique id | benefit sharing table |
| `source_id` |  | id | R |  | Parent source | governance.sources |
| `practice_id` |  | enum | R | (as study) | Practice | benefit sharing table |
| `project_name` |  | string | O |  | Carbon project, where named | benefit sharing table |
| `country` |  | string | R | ISO3 |  | benefit sharing table |
| `share_value` |  | number | R | fraction | Share of carbon income that reaches farmers | benefit sharing table |
| `share_basis` |  | enum | R | gross_credit_revenue \| net_of_project_costs \| per_credit_fixed \| unstated | What the share is a share of | benefit sharing table |
| `payment_form` |  | enum | R | cash \| in_kind \| mixed \| unstated | How farmers receive it | benefit sharing table |
| `reporter` |  | enum | R | project_developer \| independent_evaluation \| registry \| academic_study | Who reports it. Developer figures are claims rather than outturns | benefit sharing table (confidence) |
| `year` |  | integer | R |  | Reference year | benefit sharing table |
| `quote_id` |  | id | R |  | Verbatim support | verification |

### `dataset` — stream 2

Stream 2 register — candidate long-term trials and large datasets.

| Field | Core | Type | Req | Allowed / unit | Description | Lands in |
|---|---|---|---|---|---|---|
| `dataset_id` |  | id | R | DAT-0001 | Unique id | register |
| `name` |  | string | R |  |  | register |
| `custodian` |  | string | R |  | Institution and programme | register |
| `contact` |  | string | C |  | Named person to ask | register |
| `practices` |  | string | R | practice_ids | Practices represented | register |
| `commodities` |  | string | R |  |  | register |
| `countries` |  | string | R |  |  | register |
| `years_span` |  | string | R | YYYY–YYYY |  | register |
| `n_sites` |  | integer | C |  |  | register |
| `has_coordinates` |  | enum | R | yes \| no \| unstated |  | usability |
| `has_dates` |  | enum | R | yes \| no \| unstated | Planting and harvest dates, or enough to use a crop calendar | usability |
| `has_control` |  | enum | R | yes \| no \| unstated | A without-practice comparator | usability |
| `season_classified` |  | enum | R | yes \| no \| unstated | Whether seasons are already labelled stress/normal | usability |
| `expected_stress_site_seasons` |  | string | O |  | Rough estimate once S5 has screened coordinates and years | priority |
| `access` |  | enum | R | open \| on_request \| restricted \| unknown |  | cost to obtain |
| `licence` |  | string | C |  |  | Global Access compliance |
| `effort_obtain_days` |  | number | R |  | Estimate | priority |
| `effort_use_days` |  | number | R |  | Estimate (cleaning, harmonising) | priority |
| `could_yield` |  | string | R |  | Which recipe or loss-matrix fields it could populate | priority |
| `priority` |  | enum | R | high \| medium \| low | See 03 §2.4 scoring | register |

### `quote` — stream all

Every extracted number and every mechanism, cost boundary and definition carries at least one quote row.

| Field | Core | Type | Req | Allowed / unit | Description | Lands in |
|---|---|---|---|---|---|---|
| `quote_id` | ● | id | R | QTE-00001 | Unique id | verification |
| `source_id` | ● | id | R |  |  | verification |
| `record_ref` | ● | string | R | table.record_id.field, e.g. effect.EFF-0012.treatment_mean; several separated by ; | The extracted value(s) this quote supports | verification |
| `quote_basis` | ● | enum | R | verbatim \| era_record \| dataset_row | verbatim for documents. era_record: values imported from ERA carry the ERA record id as locator and no verbatim text; 20% of ERA-imported trials are checked against the paper (04 §2). dataset_row: row id in an obtained dataset | verification |
| `verbatim` | ● | string | C |  | Required when quote_basis = verbatim. Exact text, copied not retyped. For tables: row label, column header and cell. One quote row may cover a block of a table (list the rows and columns in locator) and support several record_refs | verification check A |
| `locator_type` |  | enum | R | page \| table \| figure \| section \| supplement \| dataset_row |  | verification |
| `locator` | ● | string | R | for example 'p. 7, Table 3, row "B20", column "2019 LR"' | Enough for someone else to find it without searching | verification |
| `claim` | ● | string | R |  | The claim the extraction attaches to this quote, in one sentence. This is what check B tests | verification check B |
| `computation` |  | string | C |  | Formula and input quote ids where the value is computed | verification |
| `extractor` |  | string | R |  | Person, plus AI tool and version if used | audit |
| `extraction_date` |  | date | R |  |  | audit |

### `verification` — stream all

Written by the verifier, never by the extractor. Mismatches are logged, not silently corrected.

| Field | Core | Type | Req | Allowed / unit | Description | Lands in |
|---|---|---|---|---|---|---|
| `verification_id` | ● | id | R | VER-00001 | Unique id | audit |
| `quote_id` | ● | id | C |  | Required except for an omitted arm or season, which has no quote |  |
| `record_ref` |  | string | C | table.record_id or study_id | Required when quote_id is empty (omitted arm or season) |  |
| `verifier` |  | string | R |  | Person or independent AI session (with tool/version) | audit |
| `date` |  | date | R |  |  | audit |
| `check_a_exists` | ● | enum | R | exact \| minor_difference \| not_found \| locator_wrong | Does the quoted text exist as quoted at the locator? | audit |
| `check_b_supports` | ● | enum | R | supports \| partially \| does_not_support \| contradicts | Does the quote support the claim attached to it? | audit |
| `blind_value` |  | string | C |  | Verifier's own reading of the value, taken before seeing the extracted value (sampled fields — see 04) | audit |
| `value_match` |  | enum | C | match \| within_tolerance \| mismatch |  | audit |
| `failure_mode` | ● | enum | C | fabricated_quote \| misattributed_quote \| wrong_number \| wrong_unit \| wrong_arm \| wrong_season \| pooled_as_stress \| context_stripped \| omitted_arm_season \| other | Required when any check fails | audit metrics |
| `resolution` |  | enum | C | extractor_corrected \| record_withdrawn \| disputed_to_adjudicator \| no_action_needed |  | audit |
| `resolved_by` |  | string | C |  | Adjudicator (E1 or Pete); never the original extractor alone | audit |
| `planted_error` |  | boolean | O |  | True if this record carried a deliberately planted error (verifier sensitivity test, 04 §4) | audit metrics (verifier catch rate) |
| `note` |  | string | O |  |  |  |

### `gap` — stream 1, 3

Absence recorded as a finding. One row per practice × hazard (or system × hazard for the loss matrix) where the evidence does not support a value.

| Field | Core | Type | Req | Allowed / unit | Description | Lands in |
|---|---|---|---|---|---|---|
| `gap_id` | ● | id | R | GAP-0001 | Unique id | route D statements; evidence-gap map |
| `practice_or_system` | ● | string | R |  |  | governance.gaps |
| `hazard` | ● | enum | C | drought \| heat \| waterlogging \| flood \| water_supply \| n/a |  | governance.gaps |
| `reason` | ● | enum | R | no_mechanism \| mechanism_contradicted \| no_stress_seasons \| no_season_data \| no_ssa_evidence \| pooled_only \| below_entry_conditions \| no_evidence \| compound_only | Why no value | reason codes → null reason codes in layers |
| `studies_screened` |  | integer | R |  | How many studies were looked at before concluding this | governance.gaps |
| `adverse_signal` | ● | enum | R | none \| negative_b \| negative_delta_s \| sign_inconsistent | Whether the sub-threshold evidence points the wrong way. Anything other than none is carried to the recipe's adverse_signals and shown on the published layer | adaptation.adverse_signals; published layer |
| `fix` |  | string | O |  | What would close it (for example 'classify seasons in DAT-0004') | research-prioritisation output |
