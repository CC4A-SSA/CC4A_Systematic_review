# Scope, decisions and open questions

## Decided by Pete, 26 September 2026

| # | Question | Decision | What it means for you |
|---|---|---|---|
| D1 | Is the loss matrix part of this synthesis? | **Yes — Stream 3.** | You own the loss-matrix evidence (work plan task A1), with Pete on severity definitions and hazard mapping. Its own search, separate from the practice search. |
| D2 | Are livestock outcome metrics in scope for Stream 1? | **Yes.** | Fodder banks, feed management, silvopasture and rotational grazing are extracted on livestock outcomes (milk, liveweight, mortality, forage dry matter), not just on crop or soil proxies. Granularity default in `02-extraction-schema.md` §5. |
| D3 | Mappable enablers and constraints as extraction fields? | **Not taken forward.** | No separate enabler/constraint extraction. What stays: the **drivers** a route B practice's suitability depends on and the **moderators** of production effect size (both needed by the engine). Annex B of the work plan still lists "enablers and constraints as mappable flags" in the recipe — resolve at schema freeze (Q1 below). |
| D4 | Adoption rates and current extent? | **In scope — Stream 4.** | Adoption and extent are searched and extracted here, into a table that feeds Activity 4 scenarios B (current extent) and C (2030 trend) and the enhancement-track adoption layer. |
| D5 | Where is the cost line with Chun? | **We extract, Chun owns.** | You extract establishment and running costs with explicit boundaries into one shared cost parameter table. Chun sets defaults, valuation and NEB from it. One cost set, not two. Agree the table's columns with Chun before the first extraction (it is drafted in `02-…` §6). |
| D6 | Worked example? | **Biochar, illustrative.** | `06-…` and the YAML use invented numbers, clearly marked. No real extraction has been done. |
| D7 | Continuity | **Namita leads until mid-December 2026; progress is taken stock of then and the work handed over.** | Pilots, loss matrix and dataset register first; remaining recipes breadth first; a status note at handover (`07` §4). Successor to be named |

Kept regardless, because the method breaks without them: stress-season and normal-season effects extracted separately; coordinates and dates captured so seasons can be classified; comparator and dose recorded for every effect; null and negative findings captured; practice definitions anchored to era-aom.

## Explicitly out of scope

- **Methods for predicting spatial suitability, yield response or profitability.** A separate strand. A paper whose contribution is a method is excluded at screening; if it also reports primary observations, extract the observations and ignore the method.
- **Net economic benefit analysis.** Chun Song. You supply cost and benefit parameters; you do not compute NEB, benefit–cost ratios or payback.
- **Mitigation.** TNC's side. Soil carbon or emissions figures are not extracted, except where a study reports them alongside an outcome you are extracting — then leave them.

## The line with Chun, precisely

| Item | Namita (synthesis) | Chun (NEB) |
|---|---|---|
| Establishment / fixed cost figures from literature | Extracts, with boundary statement and verbatim quote | Reads from the shared table |
| Variable running costs | Extracts, with boundary | Reads |
| Labour days and rates as reported | Extracts | Decides the labour valuation rule applied across practices |
| Asset lifetime, replacement cycle | Extracts (recipe temporal block) | Uses for annualisation |
| Currency conversion, deflation to base year | Records currency and year as reported; does not convert | Converts |
| Cost defaults per practice × country | Proposes candidate values with tier | **Sets** the default |
| Prices | Not extracted (price rule: 3–5 year producer price average, constant USD — F5, Chun and S2) | Owns |
| NEB, BCR, IRR, payback | Not computed. Reported BCRs from studies are **not** extracted (they embed someone else's boundary) | Computes |
| Adoption costs to farmers vs programme costs | Records which it is | Decides which enters NEB |

## Open questions for Pete

These are the ones where a wrong assumption would waste Namita's time.

**Q1. Enablers and constraints in the recipe.** Annex B of the work plan has "enablers and constraints as mappable flags" in the Adaptation block. D3 strikes them from extraction. Proposal: at schema freeze (mid-October) the recipe keeps route drivers (Routing block) and production moderators (Production block), and the enabler/constraint field is dropped from the MVP recipe rather than left empty. Confirm, or say which enablers must survive. The practitioner review (`09`) asks for at least a free-text note on input access (seedlings, kilns, herbicide, water control) so farm-level feasibility is not lost silently; the pack now records `dose_farm_feasible` and `water_control_level` but no general enabler field.

**Q2. Adoption timing.** Proposal: before mid-January, adoption evidence is only *logged as encountered* (one row, citation and a sentence); the real Stream 4 search runs mid-January to end-February so Activity 4 has current extent before the 15 March country workshops. Confirm the timing, and whether Pedro Chilambe's team (Activity 4) co-owns it.

**Q3. The pilot draft date.** Work plan task A3 has pilot recipe drafts at mid-October — the same date the schema freezes. Drafting three recipes against an unfrozen schema means redrafting. Proposal: pilot drafts end October, review gate mid-November as planned. Confirm.

**Q4. Normal-season yield versus average yield as the baseline.** The buffering coefficient in this pack is defined against the control's *normal-season* yield (see `06-…` §6). MapSPAM baseline production is a multi-year average that already contains stress seasons. The algebra in `02-…` §3 makes loss × buffering × baseline exact only if the baseline is normal-season yield. Either the engine rescales MapSPAM to a normal-season equivalent, or the loss fraction is defined against average yield. A schema-freeze decision for Pete and S2; it changes what Namita extracts only in how the loss fraction is labelled.

**Q5. Namita's split between Activities 2 and 3.** The budget gives her 0.489 FTE-years across both. How much of her 50 % goes to this synthesis?

**Q6. Which Crosswalk is authoritative.** The SharePoint copy has 16 practices including direct-seeded rice and SRI; the local copy in `Technical Development/` has 15. This pack uses the 16 (DSR/SRI included as an Alliance addition). Confirm the SharePoint copy is the reference.

**Q7. How the grant's significance threshold is read.** *Recommendation from the carbon-finance review: use the percentage-point reading for anything investor-facing.* "Significant adaptation" is > 5 % reduced yield loss. Read as the share of the hazard loss avoided (the buffering coefficient b > 0.05), most evidenced practices will pass; read as more than 5 percentage points of yield saved in a stress season (L × b > 0.05), few will at moderate severity. The worked example (`06` Step 11) shows the difference. Fix the reading at schema freeze.

**Q8. The scale of the adaptation increment.** The work plan's Equation 1 and the indicator both measure the climate-specific increment in absolute terms (kg/ha). On that scale a practice that raises yield by the same percentage in every season — and buffers nothing — scores a small **negative** adaptation value, because there is less yield in a bad season for the percentage to act on (`02` §3.2; in the worked example the no-buffering reference is −0.10, not 0). Two options: (a) keep the absolute scale, which is consistent with the indicator and additive with the production layer, and report every b against its reference −p; or (b) define adaptation on the relative scale (b_rel = difference in log response ratios), where zero means no change in the proportional effect, and adjust how the engine adds the two layers. The pack records b, b_rel and p for every coefficient so either can be chosen at schema freeze. This is also worth raising with the indicator team.

**Q9. Protocol registration.** The methods review asks for the protocol (estimator, weights, entry conditions, sensitivity analyses, screening rules) to be frozen and publicly timestamped at the schema freeze, with a dated amendment log after it (`07`). Confirm the venue — OSF or CGSpace — and that registering it is acceptable to Lini as project co-lead.

