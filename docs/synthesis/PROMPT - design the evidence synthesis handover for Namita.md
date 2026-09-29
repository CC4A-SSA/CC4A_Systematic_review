# Session prompt — design the evidence synthesis and write the handover for Namita

*Paste the block below into a new session. It is written to stand alone.*

---

Design the evidence synthesis that feeds the geospatial work on INV-089367 Activity 2 (Carbon Crediting for Adaptation, Alliance of Bioversity International and CIAT), and write it up as a handover pack that Namita Joshi can pick up and run.

**Produce the plan, not the synthesis.** Do not start extracting evidence. The output of this session is the protocol, the schemas, the search strategy, the verification design and a worked example — everything Namita needs to begin, and enough that a second person could audit what she produces.

## Read first

Work in the connected OneDrive folder `Gates Carbon Credits for Adaptation`.

- `Workplans/alliance geospatial team/` — the work plan v0.2 docx, and `workplans_claude/` which holds README.md, 01-decisions.md, 02-method.md and 03-source-documents.md. **02-method.md is the important one**: it defines the four areas, the four spatialisation routes, the loss matrix tiers, and the interoperability rules with the CGIAR adaptation indicator.
- `Technical Development/Adaptation & Production/2026-07-08 ClimateImpactAreaIndicator-Adaptation-v3.0.docx` — the CGIAR adaptation indicator. Its data-requirements section, its evidence-tier thinking, its measurement-window and observation-count conditions, and its living reference database specification are all directly reusable. Do not reinvent them.
- `Technical Development/2020.08 - Shared Data Documentation for Joint Review and Collaboration/NCS activities data for Gates.xlsx` — the Crosswalk tab defines which practices are in scope: sixteen practices, of which seven are Go, one Go-caveated, five enhancement or Alliance additions, three not taken forward.

Everything you produce goes in `Technical Development/Adaptation & Production/Synthesis/`.

## The design constraint that governs everything

The synthesis is not a literature review that ends in a report. **Its output is the input to a pipeline.** Every practice ends up as a machine-readable recipe that the geospatial engine reads, and the loss matrix ends up as a table the engine multiplies. If an extraction field does not eventually land in one of those two objects, or in the confidence metadata that travels with them, it should not be in the extraction schema.

Read the recipe schema in Annex B of the work plan and in 02-method.md before designing anything. Work backwards from it.

## Three streams

### Stream 1 — Practice evidence

For every practice in scope, establish:

**Adaptation.** The causal mechanism by which the practice reduces loss when a hazard occurs, stated explicitly — a practice without a defensible mechanism does not get an adaptation layer however good its carbon case. Then the buffering effect: how much loss is avoided, **per hazard and per severity class** (moderate, severe, extreme), not as a single pooled figure. The severity resolution matters because a practice can buffer a moderate dry spell and fail entirely under an extreme one.

**Risk reduction, separately from avoided loss.** Does the practice reduce perceived risk enough that farmers invest in things they would otherwise avoid — more fertiliser, more credit, higher-value crops, more area committed? The test is whether the gain would exist in a climate with no shocks: if yes it is agronomic and belongs with production, if no it is risk management and belongs here. Expect the answer to be no for almost every agronomic practice; the indicator itself places this channel with insurance, weather-indexed credit and advisory services. Record the null finding with its reasoning rather than omitting the question.

**Production in a normal year.** Effect size on yield or output, with the moderators that make it larger or smaller.

**Costs.** Establishment or fixed costs and variable running costs, separately, **with an exact statement of what each figure includes** — labour at what rate, whether family labour is costed, inputs, transport, equipment, training, certification. Cost figures whose boundary is unstated are worse than no figure, because they get used.

**Practice characteristics.** Longevity and any replacement cycle for assets that wear out (irrigation equipment, fencing, tree mortality and replanting). Time to benefit, separately for production and adaptation, since they can differ — a shade tree's production effect and its microclimate buffering do not arrive at the same time. Persistence and any reversal risk.

All of it conditioned on context, because none of these numbers travel unconditionally.

### Stream 2 — Long-term trials and large datasets

Find long-term trials, multi-environment trial networks, panel evaluations and other large datasets where the practice was running across years that include hazard years, and where avoided loss could therefore be estimated empirically rather than assumed. CGIAR centre archives, national research station records, breeding trial networks, ERA's underlying studies, AgMIP and crop-model intercomparison outputs, insurance and index datasets.

The trick that makes these usable: a trial only serves this purpose if its seasons can be labelled stress or normal. Coordinates plus planting and harvest dates are enough for us to classify them against the hazard stack afterwards. A rigorous trial with no season classification is currently unusable, and the fix is a desk exercise rather than new fieldwork — which makes it high value per hour.

Output of this stream is a prioritised register of candidate datasets with what each could yield, what it would cost to obtain and use, and who to ask.

### Stream 3 — The loss matrix

*(Proposed addition — see the note at the end.)*

Separately from any practice: how much production is lost at moderate, severe and extreme intensity of each hazard, for each crop or livestock system. This is the term the buffering coefficient is applied to, and it is a different evidence question with a different literature — crop–hazard–yield studies, documented drought and flood events with reported losses, crop model output — so it needs its own search strategy rather than being folded into the practice search.

Be deliberately conservative at moderate severity. Farmers are already adapted to their prevailing climate, and generic thresholds overstate impact at that level; real losses appear at severe and extreme.

## Explicitly out of scope

- **Methodologies for predicting spatial suitability, yield response or profitability.** Reviewing the literature for those methods is a separate strand of work. Do not include it here, and do not let the search drift into it.
- **Net economic benefit analysis.** Chun Song owns it. This synthesis supplies cost and benefit parameters to him; it does not compute NEB. Make the boundary explicit in the handover so there is one cost parameter set rather than two.
- **Adoption rates and current extent.** Activity 4. Confirm this with Pete rather than assuming.

## What the handover pack must contain

1. **Practice definitions** precise enough to drive both discovery and screening — what counts as this practice and what does not, with the boundary cases named. Anchor them to the ERA controlled vocabulary (the era-aom repository: twelve themes, sixty-six practices, one hundred and ninety-six leaf practices) and to the Crosswalk rows, so the recipes are interoperable rather than bespoke. Where a practice is a bundle, say how the bundle is defined and how a study reporting only part of it is treated.
2. **The extraction schema** — every field, its type, whether it is required, and which recipe field it eventually populates.
3. **The search strategy** per stream: sources, search terms, inclusion and exclusion criteria, screening steps. Grey literature and project evaluations are in scope and will carry much of the practical detail, especially on costs.
4. **The verification protocol** (see below).
5. **The evidence tier rubric**, taken from the CGIAR adaptation indicator rather than invented, with the measurement-window and minimum-observation conditions.
6. **A worked example** — one practice taken end to end, from definition through search to populated recipe, so Namita has a template rather than a description of one. Pick one of the three pilot practices: alternate wetting and drying rice, biochar, or rotational grazing.
7. **Sequencing and effort**, tied to the geospatial plan's dates: recipe schema frozen mid-October, maize loss matrix mid-October, the three pilot recipes through review by mid-November, all Go-practice recipes by mid-January.
8. **What to request from Adaptation Insights** before starting, so we consume Andreea Nowak's synthesis where it already covers a practice rather than repeating the review.

## Traceability and adversarial verification

This is the part that has to be right, because AI-assisted extraction fails in a specific and quiet way.

Every extracted number carries a **verbatim quotation and a locator** — page, table or section — sufficient for someone else to find it in the source. A second, independent pass re-opens the source and confirms two separate things: that the quoted text exists as quoted, and that it actually supports the claim attached to it. Those are different failure modes. A fabricated quotation is the obvious one; a real quotation that does not say what the extraction claims is the more common one and the harder to catch, so design the check to test both, and log mismatches rather than silently correcting them.

Record for every study: design (experimental, survey, modelled, project evaluation, observational), spatial replication (sites, and site-seasons rather than years), temporal replication and which seasons were hazard seasons, plot or study area, the comparator the effect was measured against, and the dose or intensity of the practice as implemented. An effect size without a stated comparator and dose does not transfer to another context.

Capture negative and null findings. A practice that performs worse under stress than the baseline it replaces is a finding this work exists to surface, and dropping those biases every default built from the evidence base.

## Before you finalise, ask Pete

Put a small number of real questions — the ones where getting it wrong would waste Namita's time. Likely candidates: whether adoption is confirmed out of scope; whether livestock outcome metrics are in scope for stream 1 and at what granularity; how much of the cost work is ours versus Chun's; and whether the loss matrix belongs in this synthesis or is run separately.

## Additions beyond the original brief

The brief for this session named streams 1 and 2, costs, practice characteristics, practice definitions, traceability and adversarial verification. The following were added because the geospatial method needs them, and each should be confirmed or struck rather than assumed: the loss matrix as stream 3; capturing coordinates and dates so seasons can be classified; separating stress-season from normal-season effect sizes; the comparator and dose requirements; explicit capture of null and negative findings; mappable enablers and constraints; livestock outcome metrics; and anchoring practice definitions to the era-aom vocabulary.
