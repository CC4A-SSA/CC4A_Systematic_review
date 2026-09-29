# Search strategy

Four streams, four searches. They share the screening machinery and the search log; they do not share strings, because they are different evidence questions with different literatures.

Specific datasets and programmes named below are **candidates to check**, not confirmed sources. Verify each exists, is accessible and contains what is claimed before it goes into the register.

---

## 0. Common machinery

**Search log.** One row per search: date, source or database, exact string, filters, hits, export file name, who ran it (and which AI tool). Kept as a sheet beside the extraction template. Anyone should be able to rerun a search from the log.

**Screening.** Two stages: title/abstract, then full text.

1. *Calibration.* The first 100 title/abstract records for the first pilot practice are screened independently by Namita and a second screener (Pete, or an independent AI session given only the criteria). Disagreements are discussed and the criteria tightened in writing **before the protocol freeze**. Report Cohen's kappa; **AI-assisted screening does not go routine until kappa ≥ 0.7.**
2. *Recall test.* Build a known-includes set per pilot practice (the seed PDFs in `Literature/` plus the ERA trials for that practice). The AI screen must retain **≥ 95 %** of them. Report the figure.
3. *Routine.* Two independently prompted AI screens at title/abstract; every include from either, and every disagreement, goes to a human. In addition a human checks a random sample of **150 records excluded by both** for each pilot practice (if none are wrongly excluded, this bounds the false-exclusion rate at about 2 %), and 50 per practice thereafter. Any wrongful exclusion → re-screen that batch by hand.
3. *Full text.* Human decision, with the exclusion reason recorded from the list below.

Record counts at each stage per practice (a PRISMA-style flow), including the not-taken-forward practices screened out, so every exclusion is visible.

**Exclusion reasons (full text).** Not the practice (per `01`); no comparator; comparator unstated; pot or incubation only (mechanism use only); method paper (suitability, yield-response or profitability *method*) with no primary data; duplicate of an ERA record already extracted; outside scope stream; not retrievable.

**The out-of-scope guard.** Papers whose contribution is a method for predicting suitability, yield response or profitability are excluded — that review is a separate strand. If such a paper also reports primary observations (trial means, costs), extract those observations and ignore the method. Do not follow citation trails into the modelling literature.

**Time boxes and stop rule.** Breadth first: every Go practice gets a recipe at some tier before any practice gets a deep one. For each practice × stream the **time box in `07` is the primary stop**. Before stopping, run **citation closure**: backward and forward citation chasing from the included stress-season studies; if it yields nothing new, record "closed", otherwise record what was left. Report both, so a reader knows whether a practice was searched to closure or to a deadline.

**Reproducibility.** Archive every export (RIS or CSV) and every API query URL with its date in the search folder. Google Scholar and AI discovery tools are not rerunnable, so they supplement the database searches and are logged as such, never the only route to an include. Complete a ROSES (or PRISMA) checklist when the synthesis is released.

**Test every string before using it.** Record hit counts at calibration, and check the database string's recall against the known-includes set (§0, step 2): it should retrieve **≥ 90 %** of them; if not, find what the missed papers call the practice and add those terms. Bare acronyms (AWD, DSR, SRI) and common words (hay, supplementation, agroforestry) will return large volumes of noise; combine them with the crop or system term as below, and drop any term that adds hits but no includes. "Direct seeding" in the CA block also retrieves direct-seeded rice papers; screen those to the DSR recipe.

**AI-assisted discovery.** Allowed and expected (OpenAlex or Semantic Scholar APIs, literature-discovery assistants, citation chasing). Rules: log every query; treat AI-returned summaries as pointers, never as sources; every number comes from the document itself with a quote and locator (`04`).

---

## 1. Stream 1 — practice evidence

### 1.1 Order of sources per practice

Work down this list. Each step can end the search for a given field.

1. **Adaptation Insights.** If Andreea Nowak's synthesis already has stress/normal-separated effects for the practice, consume them (with their source list, so tiers can be assigned centrally). See `08`.
2. **ERA.** Query ERA (ERA Agronomy data, https://github.com/ERAgriculture) for the practice's era-aom codes in SSA. ERA already holds treatment and control means, site coordinates and season information for coded studies: this fills `effect` and `site_season` without re-extracting. Record `era_study_code`; verify a sample against the source papers (ERA is a secondary source).
3. **Meta-analyses and systematic reviews.** For mechanism, moderators and — above all — to harvest primary studies that report season-level or site-season-level results. Do not extract pooled meta-analytic effects as buffering coefficients; they are rarely separated by season condition. They can populate the production effect at a lower tier.
4. **Targeted stress-season search** (§1.3). The hard part, and where the effort goes.
4a. **Multi-season search without the stress block.** The stress block favours papers whose authors chose to report stress seasons — often because the result was interesting. So for each practice also retrieve **all multi-season trials** (ERA, the Stream 2 datasets, and a practice × "long-term" / "multi-year" / "seasons" string), and let S5 classify their seasons afterwards. Compare coefficients from the two routes; a difference is reported as possible selection bias.
5. **Grey literature and project evaluations.** Costs, longevity, farmer-managed performance, disadoption. Often the only source of costs.
6. **Citation chasing** (backward and forward) from the best stress-season studies found.

### 1.2 Databases

Peer-reviewed: Scopus or Web of Science (whichever the Alliance licence covers), CAB Abstracts, Google Scholar (first 200 results, sorted by relevance), AGRIS.

Grey and evaluation: CGSpace (CGIAR repository), 3ie Development Evidence Portal (impact evaluations), World Bank Open Knowledge Repository, IFAD and FAO evaluation offices, GEF evaluation office, KALRO, EIAR and Nigerian NARS repositories where online, carbon-standard registries (Verra, Gold Standard, Plan Vivo) — **project design documents and monitoring and verification reports are an explicit source of practice costs, farmer counts, project-level costs and persistence**.

Grey versus peer-reviewed is recorded (`source.doc_type`) and used as a moderator. Where a practice × hazard has 10 or more independent trials, test for small-study effects (a multilevel Egger-type test with precision as a moderator); otherwise state that small-study effects could not be assessed.

### 1.3 String structure

`[practice block] AND [stress block] AND [outcome block] AND [geography block]`

Drop the geography block for mechanism searches and when SSA returns fewer than about 30 hits.

**Stress block** (for the stress-season search):
```
(drought OR "dry spell" OR "water stress" OR "moisture stress" OR "water deficit" OR "low rainfall" OR "dry year" OR "dry season"
 OR "rainfall variability" OR "heat stress" OR "high temperature" OR waterlog* OR flood* OR "yield stability" OR "yield variability"
 OR "stress year" OR "bad year" OR resilien* OR "El Niño" OR "La Niña")
```

**Outcome block:**
```
(yield OR productivity OR "grain yield" OR "biomass" OR "milk yield" OR "milk production" OR "liveweight" OR "live weight" OR "weight gain" OR mortality OR "forage production")
```

**Geography block:**
```
(Africa OR "sub-Saharan" OR Sahel OR Kenya OR Ethiopia OR Nigeria OR Tanzania OR Uganda OR Rwanda OR Malawi OR Zambia OR Zimbabwe OR Mozambique
 OR Ghana OR "Burkina Faso" OR Mali OR Niger OR Senegal OR Benin OR Cameroon OR Madagascar OR "South Africa" OR Sudan OR Somalia)
```

**Practice blocks:**

| Practice | Block |
|---|---|
| AWD | `("alternate wetting and drying" OR AWD OR "intermittent irrigation" OR "controlled irrigation" OR "safe AWD") AND rice` |
| Biochar | `(biochar OR "bio-char" OR "pyrolysed biomass" OR "charcoal amendment")` |
| Rotational grazing | `("rotational grazing" OR "planned grazing" OR "holistic grazing" OR "holistic planned grazing" OR "deferred grazing" OR "grazing management" OR "rotational resting" OR "grazing reserve" OR kalo OR olopololi OR "controlled grazing")` |
| CA bundle | `("conservation agriculture" OR "no-till" OR "zero till*" OR "minimum till*" OR "reduced till*" OR ripping OR "direct seeding" ) AND (mulch OR residue* OR "soil cover")` |
| Cover crops | `("cover crop*" OR "green manure" OR "relay crop*" OR mucuna OR "velvet bean" OR lablab OR canavalia OR crotalaria)` |
| Nutrient mgmt (b) | `("integrated soil fertility" OR ISFM OR "micro-dosing" OR microdosing OR "deep placement" OR "fertilizer use efficiency" OR "fertiliser use efficiency" OR "site-specific nutrient" OR "4R")` |
| Trees in farmlands | `(parkland* OR "scattered trees" OR "on-farm trees" OR "trees on farm*" OR Faidherbia OR "Vitellaria" OR shea OR "alley crop*" OR "hedgerow intercrop*" OR "FMNR" OR "farmer managed natural regeneration" OR "agroforestry")` — screen out multistrata, boundary and fallow at title/abstract |
| Fodder banks | `("fodder bank*" OR "fodder tree*" OR "fodder shrub*" OR Calliandra OR Leucaena OR Gliricidia OR Sesbania OR "tree fodder") AND (dairy OR milk OR cattle OR goat* OR sheep OR livestock)` |
| Feed management | `("feed management" OR "forage conservation" OR silage OR hay OR "urea treatment" OR "crop residue treatment" OR supplementation OR "improved forage*" OR Napier OR Brachiaria) AND (dairy OR milk OR cattle OR goat* OR sheep OR livestock)` — exclude methane-additive studies at screening |
| Silvopasture | `(silvopast* OR "silvo-past*" OR agrosilvopast* OR "shade trees" ) AND (cattle OR dairy OR livestock OR "heat stress" OR THI)` |
| DSR | `("direct seeded rice" OR "direct-seeded rice" OR "dry seeding" OR "wet seeding" OR DSR) AND rice` |
| SRI | `("system of rice intensification" OR SRI) AND rice` |
| ERW | `("rock dust" OR "rock powder" OR basalt OR "silicate rock" OR "enhanced weathering" OR remineral*) AND (yield OR drought OR "water")` |

**Cost and characteristic strings** (run separately, grey literature weighted):
```
[practice block] AND (cost* OR "labour requirement" OR "labor requirement" OR "person-days" OR "establishment cost" OR "gross margin"
 OR "cost-benefit" OR "partial budget" OR profitab* OR lifespan OR "useful life" OR replacement OR "tree survival" OR mortality
 OR persistence OR revers* OR disadopt* OR abandon* OR "monitoring cost" OR "transaction cost" OR "verification cost" OR "cost per farmer")
```
Profitability papers are read **for their cost tables only**.

### 1.4 Inclusion criteria — Stream 1

| Criterion | Include | Exclude |
|---|---|---|
| Practice | Matches `01` definition, including named boundary cases | Not-taken-forward practices; out-of-scope practices |
| Design | Field experiments (on-station, on-farm), RCTs, quasi-experimental, panels, project evaluations with a comparator, observational with a stated comparator | No comparator; pot/incubation (mechanism only) |
| Comparator | Stated, or recoverable from methods | Unstated and unrecoverable |
| Outcome | Crop or livestock productivity; mechanism variables; costs; characteristics | Mitigation-only outcomes |
| Geography | SSA preferred; elsewhere admitted as `extrapolated` for mechanism and where SSA is thin | — |
| Date | No lower limit for long-term trials; 1990 onwards otherwise | — |
| Language | English and French; others logged, not extracted | — |
| Findings | **All directions, including null and negative** | — |

---

## 2. Stream 2 — long-term trials and large datasets

The aim: datasets where the practice ran across years that include hazard years, so avoided loss can be estimated empirically. The key test is whether seasons can be labelled — coordinates plus planting and harvest dates are enough, because S5 classifies seasons against the hazard stack afterwards. A rigorous trial with no season classification is currently unusable; the fix is a desk exercise, which makes it high value per hour.

### 2.1 Where to look

| Source type | Candidates to check |
|---|---|
| ERA's underlying studies | Studies in ERA with ≥3 seasons and coordinates — query ERA for multi-season studies per practice code. Cheapest source of all |
| CGIAR long-term trials | CIMMYT conservation agriculture long-term trials (southern and eastern Africa); ICRAF/CIFOR-ICRAF long-term agroforestry trials (for example *Faidherbia* and *Gliricidia* systems); Alliance/TSBF long-term soil fertility trials in Kenya; IITA long-term trials (Nigeria); ILRI rangeland and livestock records |
| National research stations | KALRO, EIAR, Nigerian research institutes — long-term fertility, tillage and agroforestry experiments |
| Multi-environment and on-farm networks | CIMMYT maize regional trials, including managed-drought and managed-heat trials (also Stream 3); tricot citizen-science trials (seasons with coordinates); Africa RISING; N2Africa; OFRA; Excellence in Agronomy |
| Biochar-specific | Multi-year biochar field trials in Kenya and East Africa — check the `Literature/Biochar` folder first (Namaswa 2026 is Kenyan) |
| Panels and evaluations | LSMS-ISA plot panels with practice modules (practice × weather interaction studies); 3ie-registered impact evaluations with multi-season data |
| Crop model intercomparison | AgMIP and GGCMI outputs — for Stream 3 scoping, not practice effects |
| Insurance and index | Index-based livestock insurance data (NDVI and mortality); crop index insurance loss records — mainly Stream 3 |

### 2.2 What to record

The `dataset` table: custodian, contact, practices, commodities, countries, years, sites, whether it has coordinates, dates and a control, whether seasons are already classified, access, licence, effort to obtain and to use, and what it could yield.

### 2.3 Hand-off to S5

For every dataset with coordinates and years, send S5 the site list and years **before** requesting the data. S5 returns how many stress site-seasons at each severity the dataset would contain. That number, not the dataset's reputation, sets its priority.

### 2.4 Priority score

| Factor | 3 | 2 | 1 |
|---|---|---|---|
| Expected stress site-seasons (from S5) | ≥ 10, several severities | 3–9 | < 3 |
| Practice priority | Pilot practice | Go practice | Enhancement |
| Usability | Coordinates, dates and control all present | Two of three | One |
| Effort (obtain + use) | ≤ 3 days | 4–10 days | > 10 days |

Score = product of the four. High ≥ 36, medium 12–35, low < 12. Adjust by judgement and say why.

Output: a prioritised register, first cut end October, with the top datasets requested by mid-November.

---

## 3. Stream 3 — the loss matrix

Practice-independent: per cent of production lost at moderate, severe and extreme intensity of each hazard, per crop or livestock system. A different literature from the practice search.

**Be deliberately conservative at moderate severity.** Farmers are adapted to their prevailing climate; generic thresholds overstate impact at that level. Real losses appear at severe and extreme. Where the evidence at moderate severity is ambiguous, the bronze value errs low.

### 3.1 Severity is defined by the hazard stack, not by the literature

Severity classes are fixed absolute thresholds on the Adaptation Atlas indices (drought: NDWS; heat: NTx35; livestock heat: THI; flood and waterlogging per the hazard specification, task F3). Extraction records the hazard index and value the source uses (`hazard_index`, `hazard_index_value`); Pete and S5 map it to a class (`severity_mapped`). Losses reported against an index that cannot be mapped are still recorded — they inform bronze judgement.

### 3.2 Order of work

1. **Maize × drought and heat** — due mid-October (work plan A1). Bronze.
2. Other MapSPAM crops in the eligible extents, drought and heat.
3. Waterlogging and flood.
4. Livestock block: THI → milk and liveweight; drought → forage and mortality.

### 3.3 Sources by tier

| Tier | Sources |
|---|---|
| **Bronze** (what the MVP runs on) | Expert parameterisation by E1 and Pete, anchored to: managed-stress trials (stressed vs optimal arms at known stress intensity); statistical yield–weather studies for SSA; crop physiology thresholds; livestock heat-stress relationships (Thornton's THI–milk work, as in decision 4 of the work plan). Every bronze value states its anchor |
| **Silver** (calibration) | Documented drought and flood events with reported production losses, linked to the index for the same season and area: FEWS NET outlooks and reports, FAO GIEWS crop and food security assessment missions, WFP assessments, post-disaster needs assessments, ReliefWeb, EM-DAT, national drought management bulletins (for example Kenya's NDMA). Also the **control arms of Stream 1 and 2 trials** — they give L(h,s) directly (`02` §3) |
| **Gold** | Not searched now. A scoping task (A6) reports on model-based options in December |

National agricultural statistics are ruled out as an empirical route for SSA (series too short and too confounded); do not search them for loss attribution.

### 3.4 Strings

```
(maize OR corn OR sorghum OR millet OR rice OR cassava OR bean* OR wheat OR teff OR groundnut)
AND (drought OR "dry spell" OR "water stress" OR "heat stress" OR "high temperature" OR waterlog* OR flood*)
AND ("yield loss" OR "yield reduction" OR "yield penalty" OR "production loss" OR "crop failure" OR "yield decline")
AND [geography block]
```
```
(cattle OR dairy OR goat* OR sheep OR camel* OR livestock OR pastoral*)
AND (drought OR "heat stress" OR "temperature-humidity index" OR THI)
AND ("milk yield" OR "milk production" OR mortality OR "weight loss" OR "liveweight" OR "forage" OR "biomass")
AND [geography block]
```
Event search (silver): `("crop assessment" OR "harvest assessment" OR "food security assessment") AND drought AND [country] AND [year]` for the drought years S5 identifies in each focal country.

### 3.5 Inclusion — Stream 3

Include any source that reports a production loss attributable to a named hazard, with a stated reference (normal season, long-term mean, trend, non-stressed control) and a location. Exclude losses without a stated reference, and losses where the source attributes most of the loss to something else (conflict, pests, prices). Record `loss_reference` for every row — see open question Q4.

---

## 4. Stream 4 — adoption and current extent

How much of each practice is already happening, where, among whom, and trending which way. Feeds Activity 4 scenario B (current extent) and C (2030 trend), and the enhancement-track adoption layer. Sex-disaggregated figures are sought throughout, because the grant defines scalability in numbers of women and men farmers.

### 4.1 The hard part is definition, not data

Survey "minimum tillage" is rarely our CA bundle; "agroforestry" in a household survey is rarely parklands as defined. Every row records the source's definition and whether it matches ours (`definition_match`). A broader definition gives an **upper bound**, not an estimate.

### 4.2 Where to look

| Source type | Candidates to check |
|---|---|
| Household panels | LSMS-ISA surveys (for example Ethiopia ESS, Nigeria GHS-Panel, Malawi IHS, Tanzania NPS, Uganda UNPS) — plot-level modules on organic fertiliser, tillage, erosion control, trees and intercropping |
| CGIAR adoption tracking | SPIA (Standing Panel on Impact Assessment) adoption studies, including its work with national surveys in Ethiopia and elsewhere |
| National censuses and surveys | Ethiopia agricultural sample surveys; Kenya 2019 census agriculture module and KNBS surveys; Nigeria NBS and NAERLS agricultural performance surveys |
| Project records | IFAD, World Bank, GIZ and NGO project completion reports; carbon-project monitoring reports (farmer counts, hectares enrolled) |
| Remote sensing | On-farm tree cover products (trees in farmlands, parklands); irrigated rice scheme extents (AWD, DSR, SRI denominator) |
| Syntheses | Published adoption reviews for SSA (CA, ISFM, agroforestry) — for pointers to primary sources |

### 4.3 Strings

```
[practice block] AND (adopt* OR uptake OR "use of" OR extent OR "area under" OR prevalence OR diffusion OR disadopt* OR abandon*)
AND [geography block]
```

### 4.4 Inclusion — Stream 4

Every row records `context` (pre-project baseline, within project, non-project, general population) and `reporter` (independent survey vs implementer self-report): baseline adoption bears on additionality, and implementer counts tend to be trainees rather than current users. Include national or subnational figures with a stated reference year, measure and denominator; project figures only with the project area stated (they are not extent estimates, they are lower bounds for the project geography). Exclude adoption *intentions* and willingness-to-adopt studies. Log adoption encountered during Streams 1–3 as a row with `adoption_logged`, then sweep properly in the Stream 4 window (see `07`).
