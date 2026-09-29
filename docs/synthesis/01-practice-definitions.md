# Practice definitions

These definitions drive both discovery (what to search for) and screening (what to keep). Each is anchored to two things so the recipes stay interoperable rather than bespoke:

- **era-aom** — the ERA controlled vocabulary (https://github.com/ERAgriculture/era-aom, `data/pilot/`). The crop practice scheme has 12 themes, 66 practices and 196 leaf practices. Codes below are leaf-practice notations (for example `b28` = Biochar); the full identifier is `era:practice:<code>`. Control practices carry `h` codes and define comparators.
- **The Crosswalk** — the TNC–Alliance practice crosswalk (SharePoint copy of `NCS activities data for Gates.xlsx`), and the matching row of the Alliance adaptation tab.

Where era-aom has no leaf for a practice, that is said, and the nearest codes are given. Do not invent era codes; in `study.era_codes` write `none` followed by the nearest code (for example `none; nearest b14.2`).

---

## 1. Rules that apply to every practice

**1.1 A study qualifies when its treatment–control contrast isolates the practice.** The treatment has the practice; the comparator is the same system without it; everything else is held constant or reported. That is an *isolated* contrast.

**1.2 Bundles.** Many studies test a bundle (practice + fertiliser + improved variety versus farmer practice). Three cases:

| Case | Treatment | Handling |
|---|---|---|
| Isolated | Practice only differs | Full use. `contrast_type = isolated` |
| Defined bundle | The contrast matches a bundle this pack defines (conservation agriculture, ISFM, SRI) | Full use *for the bundle recipe*. `contrast_type = defined_bundle` |
| Partial / confounded | The practice plus other things not in a defined bundle, or only part of a defined bundle | Extract, record every component in `bundle_components`, set `contrast_type = confounded` or `partial_bundle`. **Never pooled with isolated contrasts.** Eligible only at a lower tier (see `05-…`). |

ERA codes several practices per treatment; the ERA practice combination is the component list.

**1.3 Comparator and dose are mandatory.** An effect size without a stated comparator and a stated dose does not transfer and is not extracted as an effect (it can still be logged as a finding). Each practice below names its standard comparator and its dose descriptors.

**1.4 Out-of-SSA evidence.** Admitted for mechanism, and for effect sizes where SSA evidence is absent or thin, with `analogue_domain = extrapolated`. SSA evidence is preferred, East Africa and Nigeria first for the country profiles.

**1.5 One observation, one practice.** A study feeding tree fodder is a fodder-bank study, not a feed-management study. The boundary cases below say which recipe wins, so nothing is counted twice.

---

## 2. Practices in scope

Status as on the Crosswalk: **Go** (7 TNC practices, consolidated into 6 Alliance rows), **Go – caveated** (1), **enhancement or Alliance addition** (5, counting DSR and SRI as one row). Three are not taken forward (§3).

### 2.1 Alternate wetting and drying (AWD) — pilot

| | |
|---|---|
| Crosswalk | Rice Cultivation (AWD) — Go – caveated. Alliance row 5, *Moderate AWD in irrigated rice* |
| era-aom | `b13` Alternate Wetting & Drying. Related, **not** AWD: `b14.1` midseason drainage, `b14.2` other reduced water use, `b15` SRI |
| System | Irrigated lowland rice with controllable water |
| Includes | Repeated drain–re-flood cycles managed against a field water-table or soil-moisture threshold. "Safe" or moderate AWD (re-flood at about 15 cm below surface) is the Crosswalk practice |
| Excludes | Rainfed rice; single midseason drainage only (`b14.1`); schemes without water control; upland rice |
| Boundary cases | *Severe AWD* (deeper thresholds, longer dry periods): extract, but keep separate by recording the threshold as dose — it has a different yield response. AWD inside an SRI package: SRI recipe, unless the contrast isolates AWD |
| Comparator | Continuous flooding — `h48` conventional rice management. Where the scheme already imposes unplanned drying (common in SSA schemes that set water rotations), the farmers' actual water regime is the comparator — record it as such |
| Dose | Re-flooding threshold (cm below surface or soil water potential), number of drying cycles, timing (vegetative only or whole season). Record `water_control_level` (field, block, scheme): where the scheme sets the rotation, farmer-level AWD may not be implementable |
| Outcomes | Grain yield (t/ha), irrigation water applied (mm), water productivity |
| Adaptation note | **Different method.** The hazard is irrigation water scarcity, not rainfed drought (Alliance tab row 5). The buffering question is: when water supply falls between the AWD and continuous-flooding demand, how much production is protected? Extract water-saving and yield response per regime; severity is expressed as a water-supply deficit class, not an Atlas drought class. AWD does not protect against heat sterility or submergence — record that as the null it is |

### 2.2 Biochar — pilot

| | |
|---|---|
| Crosswalk | Biochar — Go. Alliance row 9 |
| era-aom | `b28` Biochar |
| System | Rainfed and irrigated cropland; responsive soils (acidic, degraded, low SOC, coarse-textured) |
| Includes | Field application of pyrolysed biomass, alone or co-applied with fertiliser where the control receives the same fertiliser |
| Excludes | Pot and incubation studies (mechanism only, never effect sizes); ash (`b74`); biochar used as feed additive. **Charcoal fines and pit- or Kon-Tiki-kiln char are included** where the source says what they are made from — they are what smallholders actually use |
| Boundary cases | *Biochar–compost blends and biochar-based fertilisers*: `partial_bundle` unless the contrast isolates the char. *Historical char / kiln-site and forest-conversion chronosequences*: observational design, extract with `design = observational`. *Biochar in paddy rice*: biochar recipe; record water regime as a moderator |
| Comparator | Same field and fertiliser regime, no biochar |
| Dose | Rate (t/ha), feedstock, production method (pit, drum, Kon-Tiki, retort, industrial), pyrolysis temperature, particle size, application year(s) and years since application. **Record `dose_farm_feasible`:** at roughly 25–35 % char yield, 10 t/ha needs 30–40 t of feedstock, far more than a maize field's stover (much of which is fed to livestock). Farm-feasible rates are typically low single-digit t/ha, or banded application |
| Outcomes | Crop yield; soil moisture or plant-available water (mechanism evidence); pH (moderator) |
| Worked example | See `06-worked-example-biochar.md` |

### 2.3 Sustainable rangeland management — rotational / planned grazing — pilot

| | |
|---|---|
| Crosswalk | Livestock sustainable rangeland mgmt (TBD) — Go – enhancement. Alliance row 19; Alliance proposes rotational or planned grazing as the definition |
| era-aom | `d16` Rotational Grazing; `d19` Controlled Grazing |
| System | Rangeland and extensive grazing, pastoral and agro-pastoral |
| Includes | Rotation among paddocks or grazing units at intervals; planned or holistic grazing with deliberate rest; **deferred grazing, seasonal grazing reserves and by-law enclosures on communal land** (for example community dry-season reserves; Ethiopian community enclosures that are grazed or cut on a schedule) — tag `subtype = deferred`. On communal land this, not paddock rotation, is the common form |
| Excludes | Cut-and-carry / zero grazing (`d20` → feed management or fodder banks); permanent exclosures with no grazing or cutting; bush clearing or reseeding alone |
| Boundary cases | *Exclosure then grazed rotation*: include, record both phases. *Improved pasture sowing* (`d11`, `d12`) with rotation: `partial_bundle` |
| Comparator | Continuous or open grazing — `h11`. On communal land, **uncontrolled communal grazing with its usual mobility** — not a fenced continuous paddock. Record `herd_mobility`, `enforcement_note` and `stocking_rate_equal`; the unit of observation is the grazing unit or community |
| Dose | Stocking rate (TLU/ha), number of units, rest period (days), grazing period, season of rest |
| Outcomes | **Livestock**: liveweight gain, mortality, milk, offtake. **Forage**: standing biomass (kg DM/ha), ground cover. Forage is an intermediate; livestock outcome is preferred where reported (see `02-…` §5) |
| Note | ERA does not cover this practice (Alliance tab). Expect grey literature, rangeland journals, carbon-project documents (Verra VM0026, VM0032, VM0042 projects) and pastoral development evaluations to carry the evidence |

### 2.4 Conservation agriculture bundle: reduced tillage and residue management

| | |
|---|---|
| Crosswalk | Reduced Tillage — Go, "estimated at CA-bundle level". Alliance row 10, *Reduced tillage and residue management* |
| era-aom | `b38` no or zero tillage; `b39` reduced or minimum tillage; residue retained as mulch `b27`, `b27.1–b27.3`; residue incorporation `b41` is **not** CA |
| System | Rainfed cropland |
| Defined bundle | **Minimum soil disturbance (`b38` or `b39`) plus retained residue cover (`b27` family).** Rotation is optional and recorded |
| Excludes | Tillage change with residues removed or burnt, as a stand-alone recipe estimate (`partial_bundle`, extract but do not pool); plastic mulch `b26` |
| Comparator | Conventional tillage `h6` with residues removed (`h35`), burnt (`h36`) or grazed (`h39`) — record which |
| Dose | Tillage type, residue cover **measured at planting** (`residue_cover_at_planting` — post-harvest grazing on communal land often removes residues farmers intended to keep, so most farmer-managed 'CA' fails the residue test), weed control method (herbicide vs hand), years since conversion |
| Outcomes | Yield; soil moisture and infiltration as mechanism evidence |
| Note | Years since conversion is a first-order moderator — CA yield effects are often negative in early years. Extract it for every observation |

### 2.5 Cover crops

| | |
|---|---|
| Crosswalk | Cover Crops — Go, "bundle-aware with reduced tillage". Alliance row 8 |
| era-aom | No "cover crop" leaf. Nearest: green manure in time `b11.1`, `b12.1`; in space `b11.2`, `b12.2`, `b13.2`; relay green manure `b11.3`, `b12.3`, `b13.3` |
| Includes | Non-harvested plants grown in rotation or relay with the main crop to cover the soil |
| Excludes | Harvested legumes in rotation or intercrop (`b3.x`, `b25`, `b50.x` — these are crop diversification, not in scope) |
| Boundary cases | *Cover crop within CA*: the cover-crop recipe takes **only** contrasts where tillage and residue are held constant and the cover crop is the difference; CA-vs-conventional contrasts go to 2.4. This is what "counted once" means |
| Comparator | Same system with bare fallow between seasons |
| Dose | Species, biomass produced (t DM/ha), termination method and timing |

### 2.6 Nutrient management — scenario (b)

| | |
|---|---|
| Crosswalk | Nutrient Management — Go – enhancement. Alliance row 6, scenario (b): improved fertiliser-use efficiency / ISFM at lower emissions intensity than the business-as-usual intensification pathway |
| era-aom | `b17`, `b21`, `b16`, `b23` (inorganic inputs), `b29` compost, `b30` manure, `b73` other organic; `b17.1` etc. (reductions); control `h10`, `h10.1`, `h10.2` |
| Includes | Efficiency practices at equal or lower nutrient input than farmer practice: combined organic + inorganic (ISFM), micro-dosing, deep placement, split application, site-specific rates |
| Excludes | **Plain rate increases versus zero or low fertiliser** — that is the business-as-usual intensification the scenario is defined against |
| Boundary cases | *ISFM with improved variety*: `partial_bundle`. *Liming* (`b32`): out unless TNC adds it |
| Comparator | Farmer or recommended fertiliser practice (`h10`, `h10.2`), **not** `h10.1` no fertiliser |
| Dose | N, P, K kg/ha by source; organic input t/ha and type; placement and timing |
| Open | The scenario (b) definition is a joint decision with TNC not yet closed. Screen to this definition; flag borderline contrasts rather than excluding them |

### 2.7 Trees in farmlands (parklands and alley cropping)

| | |
|---|---|
| Crosswalk | Parklands and Intercropping (alley cropping) — both Go, consolidated into Alliance row 12, *Trees in farmlands*, with the TNC sub-pathway tag retained |
| era-aom | Parklands `a8`, scattered trees `a8.1`, FMNR `a1` (as a route to parklands); alley cropping `a3`, `a4`, `a4.1`, `a14` |
| Includes | Crops grown under scattered or regularly spaced trees; crops in alleys between tree rows |
| Excludes | Multistrata / shade tree crops (`a12` — dropped by TNC; open joint item); boundary plantings (`a9`, `a10`); agroforestry fallows (`a19.x`); prunings as a stand-alone amendment (`a15–a18`) |
| Boundary cases | *Under-canopy vs outside-canopy designs*: common for parklands; `design = observational`, record distance from trunk. *Alley cropping with prunings applied*: this is the practice; record pruning fate |
| Tag | `subtype = parkland` or `alley` on every record |
| Comparator | Same crop in open field, beyond tree influence |
| Dose | Tree species, density (trees/ha) or alley width, tree age, canopy cover |
| Temporal | Production and microclimate effects arrive on different timescales from tree age — record tree age for every observation |

### 2.8 Fodder banks

| | |
|---|---|
| Crosswalk | Fodder banks — Go. Alliance row 16 |
| era-aom | Agroforestry fodders added `d17.3` or substituted `d18.3`; crop and non-crop fodders `d17.1`, `d17.2` where from a reserved plot; with `d20` cut and carry |
| Definition | **Defined by function:** a plot planted and reserved to supply feed in the dry season or feed gap, whether woody or herbaceous |
| Includes | Planted fodder trees or shrubs (for example *Calliandra*, *Leucaena*, *Gliricidia*, *Sesbania*) cut and fed; **reserved herbaceous legume or grass banks** (the original West African fodder banks were fenced *Stylosanthes* plots) grazed or cut in the dry season |
| Excludes | Browse from natural vegetation; planted forages fed year-round with no reserve function (→ feed management) |
| Boundary cases | *Tree fodder fed with concentrate*: fodder banks if the contrast isolates the tree fodder. The feed-management recipe never takes fodder-bank contrasts. Dry-season feeding in a **normal** year is production; only the additional gain in a failed season is adaptation (`02` §5) |
| Comparator | Basal or conventional diet — `h60`, `h61` |
| Dose | kg DM/head/day of tree fodder, share of diet, season fed |
| Outcomes | Milk yield, liveweight gain, dry-season body condition; fodder yield (t DM/ha/yr) for the production side |

### 2.9 Feed management (intensive and mixed systems)

| | |
|---|---|
| Crosswalk | Feed Management (renamed from "Feed Management and Additives" on the SharePoint copy) — Go – enhancement. Alliance row 18 |
| era-aom | Crop and non-crop fodders added `d17.1`, `d17.2` or substituted `d18.1`, `d18.2`; feed processing `d22.1`, `d22.2`; concentrates `d22.3`; improved planted forages `d11`, `d12` in mixed systems |
| Includes | Forage quality improvement, conserved forage (hay, silage), crop-residue treatment, balanced supplementation, planted forages fed year-round in mixed and intensive systems |
| Excludes | **Methane-reducing feed additives** (3-NOP, seaweed, oils for methane) — redefined out; reserved fodder plots of any kind (→ fodder banks) |
| Comparator | Basal or conventional diet — `h60`, `h61` |
| Dose | Feed type, kg DM/head/day, diet share, season |
| Outcomes | Milk, liveweight gain, dry-season feed deficit, mortality |

### 2.10 Silvopasture

| | |
|---|---|
| Crosswalk | Silvopasture — Go. Alliance row 21. BCG caution: not relevant for pastoralists — **mixed and dairy systems, heat-stress mechanism** |
| era-aom | `a11` Silvopasture; `a22` agrosilvopastoral |
| Includes | Deliberate combination of trees or shrubs with pasture and livestock |
| Excludes | Open rangeland with natural tree cover and no management of trees for the system |
| Comparator | Pasture without trees |
| Dose | Tree species, density, canopy cover, age |
| Outcomes | Milk, liveweight gain, animal heat-load indicators (THI under canopy, respiration rate, body temperature — mechanism evidence), forage biomass |

### 2.11 Direct-seeded rice (DSR) and System of Rice Intensification (SRI)

| | |
|---|---|
| Crosswalk | Alliance addition on the SharePoint copy (not in the local copy). Shares the AWD eligible area and water-control screen |
| era-aom | **SRI** `b15` — era-aom advises unpacking SRI into its components where possible. **DSR has no leaf**; nearest `b14.2` (other reduced water use), with `h3` transplanting as the control |
| Recipes | Two recipes, one per practice |
| DSR | Dry or wet direct seeding in place of transplanting into puddled fields. Comparator: puddled transplanted flooded rice (`h3` + `h48`) |
| SRI | Defined bundle: young seedlings, wide spacing, intermittent irrigation, organic matter, weeding. Record which components were applied; missing components → `partial_bundle` |
| Adaptation note | Same irrigation-water-scarcity method as AWD |

### 2.12 Enhanced rock weathering (ERW) — bounded layer

| | |
|---|---|
| Crosswalk | Alliance addition. Alliance row 23. CIMMYT (subgrant) supplies CDR, agronomic and profitability surfaces |
| era-aom | No leaf. Nearest analogue for mechanism: `b32` liming |
| Scope here | **Adaptation evidence only.** Production evidence comes from CIMMYT's module — consume it, do not re-review it. Search only for stress-season or water-relation evidence of silicate rock dust |
| Comparator | Same field, no rock dust (same fertiliser) |
| Dose | Rock type, rate (t/ha), particle size, years since application |
| Expected | Thin. A lower-confidence bounded layer or route D is the likely outcome; record it plainly |

---

## 3. Not taken forward

Screened **out** at title/abstract. Count them in the screening log so the exclusion is visible; do not extract.

| Practice | era-aom | Why |
|---|---|---|
| Boundary plantings (hedgerows, windbreaks, living fences, boma) | `a9`, `a10` | Caveated: blocked on the absence of an operational SSA field-boundary product. Data decision, not a judgement on the practice |
| Improved fallow | `b60.x`, `a19.x` | Rotational clearing makes above-ground carbon transient |
| Riparian buffers | none | Hydrologic, sub-kilometre mechanism; cannot be produced at 5 arcmin |

Also not in scope though they will turn up: multistrata / shade tree crops (`a12`), crop–livestock integration as a named practice, solar-powered irrigation, water harvesting (`b33`, `b70` etc.), improved varieties (`b4`, `b5`).

---

## 4. Hazards per practice — what to look for

Mechanisms are hypotheses to test, not assumptions. If the evidence does not support one, the practice gets no adaptation layer for that hazard.

| Practice | Drought | Heat | Waterlogging | Flood | Candidate mechanism to test |
|---|---|---|---|---|---|
| AWD, DSR, SRI | Irrigation water scarcity | — | — | — | Lower water demand under binding supply |
| Biochar | ✓ | — | ✓ (drainage, if evidenced) | — | Plant-available water, rooting |
| CA bundle | ✓ | ✓ (soil temperature) | ✓ | — | Infiltration, evaporation reduction |
| Cover crops | ✓ | — | — | — | Soil cover, infiltration; *can compete for water* — watch for negatives |
| Nutrient mgmt (b) | ✓ | — | — | — | Root growth, water-use efficiency; *fertiliser can raise drought losses* — watch for negatives |
| Trees in farmlands | ✓ | ✓ | — | — | Microclimate, hydraulic lift; *tree–crop competition in dry years* — watch for negatives |
| Fodder banks | ✓ (dry-season feed) | — | — | — | Feed security in the forage gap |
| Feed management | ✓ (dry-season feed) | ✓ (heat increment of diet) | — | — | Feed security, diet quality |
| Silvopasture | ✓ (forage) | ✓ (THI) | — | — | Shade, forage buffering |
| Rotational grazing | ✓ (forage) | — | — | — | Forage reserve, ground cover, recovery |
| ERW | ? | — | — | — | Unclear; likely none evidenced |

Flood is new work in the hazard stack; few practice studies will classify flood seasons. Record any that do.

For livestock, the normal dry season is not a hazard: only a failed or poor season, as S5 classifies it, is. See `02` §5.

---

## 5. Carbon methodology alignment

The outputs will be read by carbon-finance users, so an effect measured on a practice that a crediting methodology would not recognise is mispriced. Every study records `meets_methodology_definition`, and every adoption row `methodology_match`, against the reference below. **The methodology names and conditions here are pointers to confirm against the current published versions before the schema freeze** — they are not verified for this pack.

| Practice | Methodology family to check | Conditions likely to matter for screening |
|---|---|---|
| AWD, DSR, SRI | Verra rice methane methodology and VM0042 (improved agricultural land management); Gold Standard rice methods | Baseline continuous flooding; monitored water levels or drainage events; irrigated with water control |
| Biochar | Verra biochar methodology (VM0044) and Puro.earth biochar standard — not VM0042 | Controlled pyrolysis with feedstock and quality specifications (H/C ratio, contaminants); open-pit char may not qualify |
| CA bundle, cover crops, nutrient management (b) | VM0042; Gold Standard soil organic carbon framework | Practice change from a stated baseline; minimum duration; no reversal to tillage |
| Trees in farmlands, fodder banks, silvopasture | VM0042 and agroforestry methods; Plan Vivo; Gold Standard agriculture/forestry | Tree density and survival monitoring; baseline tree cover |
| Rotational / planned grazing | VM0032 (adjustment of grazing), VM0026 (sustainable grassland management), VM0042 | Grazing plan, stocking rate records, baseline grazing regime, community agreements |
| Feed management | Methane-intensity methods for enteric emissions, where any apply | Usually intensity-based; additives excluded here |
| ERW | Emerging (for example Isometric, Puro) | Rock characterisation, application monitoring |

A study that does not meet the methodology definition is still extracted; `meets_methodology_definition` is a stratum and a flag, not an exclusion.

