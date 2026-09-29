# Evidence tier rubric

Taken from the CGIAR Climate Impact Area Indicator for adaptation (v3.0, `Technical Development/Adaptation & Production/2026-07-08 ClimateImpactAreaIndicator-Adaptation-v3.0.docx`), not invented. Where the indicator leaves a parameter undecided, this file says so and states the provisional value we use, so it can be replaced when the indicator settles. Our method interoperates with the indicator; it does not adopt it wholesale (see `workplans_claude/02-method.md`).

---

## 1. What the indicator says

Locators refer to sections of the v3.0 docx: the parameter definitions (g_stress, W), the data-sources matrix, "Data requirements by teams" (Impact assessment, Adaptation Factors and Climate team roles), Note 2 (living reference database), Note 3 (temporal basis — P_stress, W, N), Note 6 (data sources by parameter) and "Other parameters – need to be defined" (evidence tier).

- **Three tiers** ("Other parameters"). *Tier 1 literature default; Tier 2 regionally calibrated; Tier 3 measured in context.*
- **Fallback lowers the tier** (Note 6, g_stress and g_norm, routine-reporting fallback). Coarser agro-ecological match, then regional default, then global default, each lowering the recorded tier; then not reportable.
- **Low-tier fallbacks** (Note 6, impact-assessment fallback). Single-season studies paired across seasons; structured expert elicitation with a documented protocol.
- **N governs tier, not arithmetic** (Note 3; g_stress definition). N is the number of site-seasons a study spans, counted in site-seasons rather than years (12 sites × 3 years = 36), with "at least 2 or 3 distinct stress events represented so the estimate does not rest on one unusual year". A study with too few stress observations "produces a low-tier entry or none". The indicator marks the exact N as undecided.
- **Measurement window W.** The seasons of outcome accumulated in each effect. One season suits production-domain effects; two to three suit recovery-based interventions. W ≤ 1 / P_stress, so consecutive episodes do not count the same recovery twice.
- **Season classification is a precondition.** "A rigorous evaluation with no season classification cannot be used at all."
- **Tiers are assigned centrally**, "not by the team who submitted the study", using a common rubric.
- **What the database records** alongside each entry: share of seasons qualifying, episodes per decade, W applied, site-seasons observed, stress site-seasons observed, climate reference dataset used; plus evidence tier, extraction method (study design), hazard benchmark, value domain, geographic and agro-ecological validity, source studies, reversal-risk flag, review date and reviewer.
- **Named pitfalls.** Season classification absent; on-station management inflating effects relative to farmer conditions; selection bias in observational adoption; truncating negative values.

## 2. How we apply it

The indicator reports realised impact in a context; we compute technical potential across sub-Saharan Africa. So "in context" is read as **in the stratum the value is applied to** (production system × agro-ecological class, as set by the route C evidence classes). The same coefficient can therefore be Tier 3 where it is applied inside the stratum it was measured in and Tier 2 where it is transferred to an analogous one. Tier is recorded per value × stratum, not once per practice.

### 2.1 Entry conditions for a buffering coefficient (adaptation)

A trial contributes to `adaptation.buffering[h][s]` only if all hold:

1. Its seasons are classified — by S5 against the fixed Atlas thresholds, or provisionally by the authors (see 2.3).
2. It reports treatment and control outcomes separately for stress and normal seasons (or site-seasons that can be so sorted), and **at least one site has both a normal and a stress season** (otherwise site and season are confounded).
3. It has a stated comparator and dose.
4. It spans **at least 2 distinct stress events** for that hazard. *Provisional; the indicator says 2–3 and has not decided.* A distinct event is a stress season in a different year, or in the same year at sites far enough apart to be climatically independent (S5 judges).
5. For livestock: it has an **animal outcome** (not forage only), and equal stocking rates across arms or outcomes per hectare (`02` §5).

Trials failing any condition are **not dropped**: they are extracted, they may still inform production and mechanism, and each failure is recorded as a `gap` row with its reason and its `adverse_signal`.

### 2.2 Tier assignment

"Trials" means independent trials (`trial_id`), not papers.

| Tier | Buffering coefficient (adaptation) | Production effect | Loss matrix |
|---|---|---|---|
| **3 — measured in context** | Meets all entry conditions; **≥ 2 independent trials** and **≥ 3 distinct stress events** at the severity in question (provisional); within the stratum it is applied to | Normal-season effect (not pooled) from **≥ 2 independent trials** within the stratum | Silver-calibrated in the system and region, or gold |
| **2 — regionally calibrated** | Meets entry conditions within the stratum but with one trial or only 2 distinct events; or meets them from an analogous stratum in the same region | One trial within the stratum; or normal-season or pooled effect from an analogous stratum in the region; or a regional meta-analytic estimate | Bronze with a documented regional anchor (managed-stress trial or event data from the region) |
| **1 — literature default** | Meets entry conditions only out of region (global default); or the indicator's low-tier fallback — single-season studies paired across seasons; or forage-only livestock evidence through S4's translation | Global meta-analytic default; pooled-only effects from outside the region | Bronze on generic anchors only |
| **Elicited** (Tier 1, flagged) | Structured expert elicitation with a documented protocol, where no trial qualifies | Same | Same |
| **Not reportable** | Nothing qualifies and no elicitation → **route D** or no adaptation layer for that hazard, with a `gap` row | Route D upper bound | Row left empty, flagged |

### 2.3 Downgrades (one tier each, cumulative, not below Tier 1)

| Condition | Applies to | Why |
|---|---|---|
| `contrast_type` = `partial_bundle` or `confounded` | All | Effect not attributable to the practice |
| No farmer-managed evidence (all on-station or on-farm researcher-managed) | Production, buffering | Researcher-managed effects commonly exceed farmer-managed ones substantially |
| All evidence on-station (a further tier, on top of the row above) | Production, buffering | Indicator pitfall: on-station management inflates effects further |
| `design` = observational or `survey_single_round` | All | Selection into the practice |
| **High risk of bias** — any trial contributing > 25 % of the weight rated `high` on assignment, confounding or selective reporting | All | Internal validity |
| **Imprecision** — the 80 % interval for b includes the no-buffering reference −p (`02` §3.2), or for production includes zero | Buffering, production | Cannot distinguish an effect from none |
| **Inconsistency** — independent trials disagree in sign | All | Heterogeneity the pooled value hides; report τ² |
| `confounded_with_establishment` (`02` §3.3) | Buffering | Stress indistinguishable from trial year |
| Dose not farm-feasible (`dose_farm_feasible = no`) for most of the weight | Production, buffering | The effect is of a practice farmers would not implement |
| Seasons classified by authors only, not yet by S5 | Buffering | Benchmark not comparable across entries |
| Coordinates geocoded or admin centroids, not reported | Buffering | Classification less certain |
| `analogue_domain = extrapolated` (out of SSA) | All | Transfer |

Beyond the table there are no upgrades. Adding trials raises a tier only by meeting a condition in the table; a larger number of trials that each fail a condition narrows the interval but does not raise the tier.

### 2.4 Risk of bias

Each study gets five ratings (`study.rob_*`: assignment, confounding, comparator fidelity, outcome measurement, selective reporting), each low / some / high / unclear — a lightweight version of the CEE critical-appraisal approach, proportionate to the team. Two items are core for the pilots (assignment, selective reporting). Selective reporting includes presenting season-level results only for the "interesting" years.

### 2.5 Adverse signals

Evidence that points the wrong way but fails the entry conditions — a single negative event, trials that disagree in sign — does not enter the engine as a coefficient, but it **must not vanish**. Each such `gap` row carries an `adverse_signal`, which is copied to the recipe's `adaptation.adverse_signals` and shown on the published layer and in the country profiles ("one trial suggests the benefit reverses under severe drought"). Otherwise the published layer would show only the favourable evidence.

### 2.6 Measurement window

**W is set per practice**, not assumed. The default for crop practices is **W = 1 season** (a production-domain effect resolving within the season). Set W > 1 where a shock's consequences carry over: drought mortality and herd rebuilding for livestock; for CA, residues fed to livestock in a drought year and lost to the next season's soil cover. Where W > 1 the indicator's hazard-episode rule applies (consecutive stress seasons are one episode; W runs from the last). Record W and the episodes-per-decade count S5 supplies, and check W ≤ 1 / P_stress.

### 2.7 Who assigns the tier

The indicator assigns tiers centrally, not by the submitting team. Here: **Namita proposes, the review gate confirms.** The reviewer (task A7) sees the tier with the conditions it rests on and can lower it.

## 3. From tier to the grant's confidence rating

The investment document asks for a High / Medium / Low confidence tier per practice × layer on the published outputs. Proposed rule, to be agreed with S5 at schema freeze:

| Layer confidence | Rule (area-weighted over assessed area) |
|---|---|
| High | ≥ 50 % of assessed area at Tier 3, < 20 % at Tier 1, **≥ 3 independent trials** behind the layer, and no adverse signal |
| Medium | Otherwise, with ≥ 50 % at Tier 2 or above and ≥ 2 independent trials |
| Low | Everything else, including any elicited value on > 20 % of assessed area |

Route D practices are Low by definition.

**How it is published.** Every tier and confidence rating is shown with its evidence counts (independent trials, stress site-seasons, distinct events) and any adverse signal. Every layer is labelled *technical potential, not an attributable or creditable claim*. Confidence describes the evidence behind the estimate, not whether a project could claim it.

## 4. Fields that carry the tier

Every quantitative recipe value carries: `tier`, `tier_basis` (which conditions, which downgrades), `n_trials`, `site_seasons`, `stress_site_seasons`, `distinct_stress_events`, `tau2` (where ≥ 2 trials), `hazard_benchmark`, `climate_reference` (the dataset S5 classified against), `W`, and `sources`. See the worked example YAML for the layout.
