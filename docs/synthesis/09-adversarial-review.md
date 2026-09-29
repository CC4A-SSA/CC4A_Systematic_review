# Adversarial review of this pack

Four independent reviews, 27 September 2026. Each reviewer was an AI session given the pack, the session brief and `workplans_claude/02-method.md`, told to act in one role and to find what is wrong, not what is right. None saw the others' findings or the drafting conversation.

| Reviewer | Brief |
|---|---|
| **A — Academic** | Agricultural systems and adaptation science; scientific validity, causal identification, the buffering coefficient |
| **P — Practitioner** | Fifteen years running farmer programmes and trials in Kenya, Ethiopia and Nigeria; whether a junior analyst can run this and whether the definitions match real farms |
| **C — Carbon financier** | Investment lead financing agricultural carbon projects in Africa; whether the outputs are decision-useful and defensible to an investor or verifier |
| **M — Meta-analysis** | Systematic-review methods; estimation, independence, screening reliability, bias, reproducibility — at proportionate rigour for a 0.5 FTE team |

**Disposition key:** *Addressed* — the pack now handles it, and where. *Partly* — handled in part, remainder stated. *To Pete* — a decision, now an open question in `00`. *Not taken* — with the reason.

---

## 1. What the reviews agreed on

Four themes came from more than one reviewer. They were the major issues and all are addressed.

1. **The buffering coefficient needed a pre-specified estimator and an honest reading of its sign** (A1, A2, A4, M1). A ratio of two noisy differences, pooled by an unstated method, with no variance, and with a zero point that is not zero. Now: a site-season mixed model on log yield, trial-level bootstrap intervals, a denominator guard, a proportionality test, and b reported with b_rel and its no-buffering reference −p (`02` §3.2–3.3). The scale choice itself is Q8.
2. **Tiers were too generous, and one trial could look like strong evidence** (A8, C4, M4, P2). Now: Tier 3 needs two independent trials; downgrades for researcher-managed evidence, high risk of bias, imprecision, inconsistency and establishment-year confounding; a five-item risk-of-bias rating; adverse signals carried onto the published layer; evidence counts published with every tier; layers labelled technical potential (`05`). The worked example's values fall from Tiers 2–3 to Tier 1, which is the intended result.
3. **Non-independence and ERA double counting** (M2, P1, M7). Now: `trial_id` links companion papers and ERA records; the model has trial and site random effects; shared controls are handled; ERA imports have their own quote basis with a 20 % source check (`02` §2, `04` §1).
4. **Farm reality** (P3, P7–P11, C3). The worked example used a dose no smallholder could apply; several definitions did not match how practices exist on farms or in carbon methodologies. Now addressed in `01` and `06`.

## 2. Effort

The fixes add steps (protocol registration, screening QC, risk of bias, estimator runs). Most are automated in the AI-first working model (`07` §3); the human cost is calibration and adjudication.

---

## 3. Findings and dispositions

### A — Academic

| # | Sev. | Finding | Disposition |
|---|---|---|---|
| A1 | Major | b's zero point is scale-dependent: a practice with a constant proportional gain p and no buffering has b = −p, not 0. The example's "negative" severe b (−0.13 vs p = 0.10) is nearly that case | **Addressed** — `02` §3.2 sign table; b, b_rel and p recorded for every coefficient; worked example reports b against −p. Scale choice → **Q8** |
| A2 | Major | Transfer of b to a different local loss assumes proportional buffering; b is an unstable ratio; the L < 0.05 cut is arbitrary | **Addressed** — Finlay–Wilkinson proportionality test with slope recorded and flagged; model-based estimation; guard raised to L < 0.10 (`02` §3.3) |
| A3 | Major | Stress seasons confounded with site, year and years since establishment (severe = year 3 of a declining char effect) | **Addressed** — years since establishment in the model; a trial contributes to b only with normal and stress seasons at the same site; `confounded_with_establishment` flag and downgrade; worked example now shows the confound |
| A4 | Major | "Negative b = worse than the baseline" is a misreading | **Addressed** — `02` §3.2 separates Δₛ < 0, b < 0 and b = −p; `06`, `CLAUDE.md` corrected |
| A5 | Moderate | Severity classes from coarse gridded indices are unvalidated; "conservative at moderate" looks like hand-tuning | **Partly** — S5 checks classes against control-arm yield anomalies; continuous index kept; b reported with ±1-class sensitivity (`02` §3.3). The conservatism is **not taken** out: it applies to the loss magnitude L in the bronze matrix, not to the thresholds, and is a deliberate work-plan decision |
| A6 | Moderate | Compound (e.g. hot and dry) seasons double-counted across hazards | **Addressed** — `classified_compound` filled by S5; compound seasons excluded from single-hazard coefficients and counted |
| A7 | Moderate | Forage biomass is a weak proxy; per-head gains confounded with stocking rate | **Addressed** — forage-only evidence is mechanism evidence, not buffering; livestock b needs an animal outcome and equal stocking or per-ha outcomes (`02` §5, `05` §2.1) |
| A8 | Moderate | Tier 3 from one study; site-seasons treated as independent; no heterogeneity | **Addressed** — ≥ 2 independent trials for Tier 3; trial-level random effects; τ² reported; inconsistency downgrade |
| A9 | Moderate | Stress-term search favours studies that found buffering | **Addressed** — parallel multi-season search without the stress block, seasons classified afterwards, the two compared (`03` §1.1 step 4a) |
| A10 | Moderate | A changed mechanism variable does not show it caused the yield effect | **Addressed** — `mechanism.stress_season_difference`; "supports" requires a stress-season difference |
| A11 | Moderate | Trial control arms are not farmer losses; mixing them with event data | **Addressed** — control-arm loss rows linked by `derived_from_effect_id`, a separate stratum, never pooled with event reports |
| A12 | Minor | Several stated facts unverifiable by the reviewer | **Addressed** — `06` separates invented from real and checkable items. The era-aom counts and codes were read directly from the repository's `data/pilot/` files on 26 September; the Literature folder contents were listed from the project folder; NDWS thresholds and the methodology names in `01` §5 are marked *confirm* |
| A13 | Minor | W = 1 for all crop practices ignores carry-over | **Addressed** — W set per practice (`05` §2.6) |

### P — Practitioner

| # | Sev. | Finding | Disposition |
|---|---|---|---|
| P1 | Major | Pack tells her to take ERA means and also demands verbatim quotes ERA cannot give | **Addressed** — `quote_basis = era_record`; 20 % of ERA trials checked against source (`02` §2, `04` §1, `CLAUDE.md`) |
| P2 | Major | On-farm researcher-managed trials treated as farmer-managed | **Addressed** — `study.management`; downgrade where there is no farmer-managed evidence; management is a stratum |
| P3 | Major | Worked-example dose (10 t/ha) infeasible for smallholders; charcoal fines excluded | **Addressed** — example rebased to 2 t/ha pit-kiln char; `dose_farm_feasible` on every study; charcoal fines and pit/Kon-Tiki char admitted with stated source |
| P4 | Major | Effort optimistic; check C on every boundary field doubles verification; Stream 4 should come off her line now | **Partly** — check C now numeric only (`04` §2). Time burden handled through the AI-first working model (`07` §3). Stream 4 ownership → **Q2** |
| P5 | Major | 190 fields too heavy; one trial generates ~100 quote rows | **Partly** — 74 core fields mandatory for pilots, the rest filled where reported and reviewed after the pilots; one quote may cover a table block. The total field count rose (to 232) because the other reviews added fields; the core set is the answer to the burden, and the pilot review should cut further |
| P6 | Major | Real project costs not captured: in-kind, subsidy, overhead, labour timing and by sex | **Addressed** — `in_kind_items`, `subsidy_share`, `cost_basis_source`, `labour_months`, `labour_by_sex`, project-level cost classes |
| P7 | Moderate | Fodder-bank definition excludes the original herbaceous fodder banks | **Addressed** — defined by function (reserved dry-season feed plot), woody or herbaceous (`01` §2.8) |
| P8 | Moderate | Rotational grazing on communal land is by-law reserves and enclosures, not paddocks; wrong comparator | **Addressed** — communal forms included; comparator uncontrolled communal grazing with mobility; `herd_mobility`, `enforcement_note`; unit = grazing unit |
| P9 | Moderate | In SSA rice schemes the scheme, not the farmer, controls water | **Addressed** — `water_control_level`; farmers' actual regime allowed as comparator |
| P10 | Moderate | Residues grazed off after harvest: farmer "CA" fails the bundle test | **Addressed** — `residue_cover_at_planting` measured, not intended; weed-control method recorded |
| P11 | Moderate | No livestock stress definition — dry-season feeding gains would be booked as buffering | **Addressed** — normal dry season is not a hazard; normal-year dry-season gains are production (`02` §5, `01` §4); body condition and herd change added; mortality per event vs per year |
| P12 | Moderate | Adoption figures inflated (trainees as adopters, ever vs current, partial use) | **Addressed** — `reporter`, `ever_vs_current`, `intensity` |
| P13 | Minor | Acronyms and common words will flood searches | **Addressed** — strings hit-tested at calibration; acronyms combined with crop terms (`03` §0) |
| P14 | Minor | Input access lost when enablers were struck | **To Pete** — noted under **Q1**; partly covered by `dose_farm_feasible` and `water_control_level` |

### C — Carbon financier

| # | Sev. | Finding | Disposition |
|---|---|---|---|
| C1 | Major | Farm-level costs only; project costs (aggregation, MRV, verification, registry, farmer payments) and their timing missing | **Addressed** — project-level `cost_class` values, `n_farmers_covered`, `area_ha_covered`, `project_year`, `crediting_period_years`; PDDs and monitoring reports named as sources; cost search string extended. Farm-level costs stay the priority |
| C2 | Major | Adoption data cannot support additionality | **Addressed** — `context` (baseline / within project / non-project), `methodology_match`. Telling Activity 4 that benefit applies only above baseline is for Pete to carry into the Activity 4 hand-off |
| C3 | Major | Definitions anchored to ERA and the Crosswalk, not to crediting methodologies (e.g. credited biochar needs controlled pyrolysis) | **Addressed** — `01` §5 methodology alignment table (names and conditions marked *confirm*); `study.meets_methodology_definition` as a stratum and flag |
| C4 | Major | Tiers will be read as "safe to claim"; negative evidence disappears; loose threshold reading | **Addressed** — stricter tiers, adverse signals on published layers, evidence counts with every tier, "technical potential, not a creditable claim" label (`05` §2.5, §3). Threshold reading → **Q7**, with the recommendation to use percentage points for investor-facing outputs |
| C5 | Moderate | No per-household translation | **Addressed** — `mean_farm_size_ha`, `area_under_practice_per_hh_ha` on `study` |
| C6 | Moderate | Benefit timing not aligned with crediting cash flows | **Addressed** — benefits binned by years since establishment in the recipe; costs by `project_year` |
| C7 | Moderate | Permanence and reversal evidence thin | **Addressed** — disadoption required with period when reported, reason recorded; `persistence_after_payments_end`; every `reversal_risk` needs a source |
| C8 | Minor | No evidence for benefit-sharing claims | **Partly** — `farmer_payment` cost class captures payments where reported; no separate benefit-sharing search (outside the synthesis's scope) |
| C9 | Minor | Grazing cost units do not reconcile | **Addressed** — `stocking_rate_tlu_ha` and area with rotational-grazing cost rows |
| C10 | Minor | Cost defaults for the investor tool need the same provenance as effects | **Addressed** — `02` §6 |

### M — Meta-analysis

| # | Sev. | Finding | Disposition |
|---|---|---|---|
| M1 | Major | b estimator under-specified; no variance; ratio-of-means vs mean-of-ratios undecided | **Addressed** — `02` §3.3 primary model, trial-level cluster bootstrap, lnRR with small-sample correction for summary-level production effects, risk differences for low-mortality outcomes left to S4's conversion |
| M2 | Major | Non-independence: shared controls, repeated site-seasons, companion papers, ERA duplicates | **Addressed** — `trial_id`, `shared_control_group`, random effects, de-duplication on trial |
| M3 | Major | AI-screening QC underpowered | **Addressed** — kappa ≥ 0.7 before routine AI screening; ≥ 95 % recall on a known-includes set; two independent AI screens with disagreements to a human; 150 double-excluded records checked per pilot practice (`03` §0) |
| M4 | Major | No risk-of-bias tool; tiers not a certainty rating | **Addressed** — five-item risk of bias; imprecision, inconsistency and risk-of-bias downgrades (`05` §2.3–2.4) |
| M5 | Major | No frozen, timestamped protocol | **Addressed** — protocol v1.0 frozen and registered at the 16 October schema freeze, dated amendment log (`07`). Venue → **Q9** |
| M6 | Moderate | Mixed weighting rule | **Addressed** — model weights; replication-based weights and imputation for summary data, with a sensitivity run excluding imputed variances |
| M7 | Moderate | No error-rate statistics; same-model verifier; ERA exception undefined | **Addressed** — Wilson intervals per batch and cumulatively; planted-error test of verifier sensitivity (≥ 80 %); different model where available; ERA rule defined (`04`) |
| M8 | Moderate | Search sensitivity and publication bias | **Addressed** — string recall ≥ 90 % against the known-includes set; grey vs peer-reviewed as a moderator; small-study test where ≥ 10 trials, otherwise stated as unassessable; multi-season search without the stress block |
| M9 | Moderate | Moderators built on one or two studies | **Addressed** — meta-regression only with ≈ 10 trials per moderator; otherwise `hypothesised` (reflected in the example YAML) |
| M10 | Minor | Saturation stop rule depends on reading order | **Addressed** — time box primary, citation closure reported |
| M11 | Minor | Reproducibility | **Addressed** — exports and API queries archived; estimator code in the repository; ROSES/PRISMA checklist at release |
| M12 | Minor | Partial bundles never used even for sensitivity | **Addressed** — `contrast_type` as a moderator in a sensitivity analysis |
| M13 | Minor | Control-arm rows used for both b and silver calibration | **Addressed** — `derived_from_effect_id`; never used to validate the b they came from |

---

## 4. Not changed, on purpose

- **Severity classes stay the primitive; fixed thresholds stay.** Both are work-plan decisions checked against the indicator (`02-method.md`). The reviews asked for validation of the classes, which is added; not for their replacement.
- **Enablers stay out** (decision D3) until Pete answers Q1.
- **The synthesis still does not compute NEB or source prices.** Several carbon-finance points are for Chun's analysis; the synthesis now captures what he needs.
