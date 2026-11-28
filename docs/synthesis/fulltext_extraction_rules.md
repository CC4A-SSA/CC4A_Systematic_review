# Full text screening and extraction rules

Version **0.3.1**, 2026-11-27. Every extracted file records the version it
was made under (`rules_version`). A change to these rules is a new version,
listed at the end, so any extraction can be traced to the rules it used.

One pass per paper: decide whether the paper stays in, and if it does,
extract every value it reports for the review's three outcomes, each with
the exact words it came from.

## 1. What you are given

- The PDF, `outputs/04_fulltext/pdf/<record_id>.pdf`. Read it as page images
  and text, so tables and figures are read as they print.
- The record: title, the practices it was tagged with (`practice:` tags in
  Zotero, `practices` in `included_records.csv`), and its outcome folder.
- The defined practices: `catalogues/vocab_practices.csv` (definition and
  what does not count).

## 2. Full text screening

The paper stays in when all four hold. Otherwise record `exclude` and the
first criterion it fails, and extract nothing.

| Criterion | Exclude reason |
|---|---|
| The study is in Africa (at least one site or survey area) | `not_africa` |
| It studies one of the defined practices as an intervention, as defined in the vocabulary, not one it only mentions | `no_defined_practice` |
| It reports at least one value for an outcome below: costs or returns, adoption, or carbon income | `no_outcome_data` |
| The values are its own (field, survey, project or model results), not only figures quoted from other studies | `only_secondary` |

A paper whose only defined practices are `not_taken_forward` or `out_of_scope`
in the vocabulary (for example only `nutrient_mgmt_b`, dropped in practice
register v0.2) is `exclude`, reason `practice_out_of_scope`.

A review or meta-analysis is `exclude`, reason `review`, unless it reports
its own pooled numbers for Africa; then it stays in and those numbers are
extracted with `data_type = secondary`. Practices that are `not_taken_forward`
or `out_of_scope` in the vocabulary are recorded but do not by themselves keep
a paper in.

## 3. What to extract

One row per value, in one of three tables. Extract every relevant value in
the paper, including each treatment, season, site and year separately. Never
average, pool or pick a "best" one, and never calculate a value the paper
does not print.

Where the same value is printed more than once, take it from a table first,
then a figure, and from the text only when it is in neither (text is where
papers most often misquote their own tables). When they differ, record the
other value in `note`.

### cost_return (the 2022 World Bank template)

One row per economic outcome per treatment against its control, only for
comparisons the paper itself makes. Never build a comparison from two columns
the paper does not compare.

**What the row is about**

| Column | What |
|---|---|
| `outcome` | Exactly one name from the outcome list (section 6), chosen by what was calculated (which costs were subtracted from what), not by the paper's label. Plain names, with the area or animal in the unit: `Variable Cost`, unit `KES/ha` |
| `label_in_paper` | The paper's own name for the measure, as printed ("net benefit", "bénéfice brut") |
| `outcome_formula` | For ratios, `Other (named)` and any outcome whose content is not obvious: the formula as the paper states it ("gross return / total cost"), or `unstated` |
| `outcome_unit` | The paper's unit, currency as an ISO 4217 code (`KES/ha`, `USD/farm`, `XOF/ha`). F CFA is `XOF` in West Africa and `XAF` in Central Africa; Ghana's cedi before 2007 is `GHC`, after is `GHS`; the Tunisian dinar is `TND`. When a value is printed in two currencies, take the USD one |
| `is_incremental` | `yes` when the paper prints only the difference from its control (incremental net benefit, incremental NPV); then `value_con` is empty and `control_name` names the baseline. Otherwise `no` |
| `exchange_rate` | The paper's rate, as printed, with its year if given ("1 USD = 2.402 GHS"). Never convert during extraction |

**The treatment and its control**

| Column | What |
|---|---|
| `practice` | Vocabulary code of the practice the row is about |
| practice columns (`awd`, `biochar`, `rotational_grazing`, `ca_bundle`, `cover_crops`, `nutrient_mgmt_b`, `trees_in_farmlands`, `fodder_banks`, `feed_mgmt`, `silvopasture`, `dsr`, `sri`, `erw`, `boundary_plantings`, `improved_fallow`, `riparian_buffers`, `shaded_perennials`, `crop_livestock_integration`, `solar_irrigation`, `water_harvesting`, `improved_varieties`) | For each vocabulary practice the treatment has **and its control does not**: its sub-practice, from the `subpractices` column of `catalogues/vocab_practices.csv` (`nutrient_mgmt_b = isfm`, `ca_bundle = no_till_residue`), several joined by `; `; `unspecified` when the paper does not say which; `yes` for a practice with no sub-practices. Otherwise empty. A practice in both arms is not part of the contrast and is not marked. Biochar: `with_fertiliser` whenever the treatment's biochar goes on with fertiliser (whether the control gets that fertiliser shows in `other_practices`); `blend` for biochar-compost and biochar-based fertilisers. Feed management (register G1.1): `supplementation` only when the supplement is grown on the farm (fodder legumes, fodder trees); bought-in concentrates as the main lever are `supplementation_bought_in` (extracted, not pooled). Shaded perennials: the crop under the shade trees, `coffee`, `cocoa` or `tea` |
| `feedstock` | Biochar rows only: what the char was made from, one of `crop_residue`, `manure`, `forest_residue` (wood or sawdust from forest or woodland), `wood_unspecified`, `other`, `unstated`. Practice register C2.3 excludes forest-residue feedstock: those rows are still extracted, and `forest_residue` is the flag. Empty for other rows |
| `other_practices` | Anything else the treatment has and the control does not (mineral fertiliser, compost, irrigation, a variety not in the vocabulary), named as in the paper, always, even when it is part of an integrated package such as ISFM (compost + NPK against no fertiliser lists the NPK here). Not listed: inputs that are part of how the practice itself works (herbicide replacing tillage in no-till); their cost goes in the cost columns, as in 2022. More than one entry across the practice columns and `other_practices` means the row is a bundle |
| `comparator_matches_vocab` | `yes` when the control is the vocabulary's comparator for `practice` (`catalogues/vocab_practices.csv`, column `comparator`), `no` when it is not (a no-fertiliser control for `nutrient_mgmt_b`), `unclear` |
| `product`, `product_con` | Crop or animal product of the treatment and of the control (sole maize against a maize-bean intercrop) |
| `treatment_name`, `control_name` | As the paper names them, dose included ("Biochar 10 t/ha + 45 kg N/ha"). No control in the paper: `control_name` is `no control` (so we know it was looked for) |
| `replicates` | Replicates for trials, sample size for surveys, empty for models |
| `animals_per_rep` | Animals per replicate, for livestock |
| `country`, `site` | ISO3 country, site as printed |

Skip a treatment whose only contrast with its control is a practice that is
`not_taken_forward` or `out_of_scope` (a living fence, sole jatropha).

**The values**

| Column | What |
|---|---|
| `value_trt`, `value_con` | The number, cleaned: a dot for decimals and no thousands separators. "2.788" meaning 2,788 is `2788`, and the reading goes in `note` |
| `value_trt_error`, `value_con_error`, `error_type` | Spread and its type: `SD`, `SE`, `SEM`, `SED`, `LSD`, `CI95`. One value printed for a whole column is written on every row, type prefixed `Grouped` (`Grouped LSD`), as in 2022 |
| `measurement_year` | `2019` for a year; `2019.1`, `2019.2` for the first and second season starting in 2019 (season name in `note`); `2019..2020` for a value aggregated (averaged or summed) over 2019 and 2020, saying which in `note`; `2019.1..2019.2` for two seasons aggregated. A season spanning two calendar years takes its start year. A model year with no calendar year is `Y1`, `Y2`… No year in the paper: empty, said in `note`, never the publication year |
| `scenario` | For a grid of scenarios (price, yield or farm size assumptions), the cell, as the paper names it ("price +20%"). Discount rates go in `discount_rate`, not here |
| `discount_rate`, `discount_period` | For NPV, IRR and other discounted outcomes |

Every season and year is a row of its own, including each year of a cash
flow table. An average or a total over years or seasons is taken only when
the paper does not print the values it is built from.

Factorial trials whose economics the paper does not pair: every treatment
against the paper's own control (the zero or unfertilised plot), as in
records 6135671 and 6135863.

Supplementary material: when the paper says values in scope are in
supplementary material that is not in the PDF, record it in the paper's
`supplementary` field: `cited_not_found`, or `cited_found` with its URL if a
free copy exists. Values from it are extracted once a person has saved it as
`outputs/04_fulltext/pdf/<record_id>_supp.pdf`.

**Which costs are included** (2022 columns)

| Column | What |
|---|---|
| `budget_type` | `partial` (only the costs that vary between treatment and control), `full`, `unstated` |
| `labour_valued` | Family labour given a money value: `yes`, `no`, `unstated` |
| `costs_unknown` | `Yes` when the paper does not say which costs it counted; the item columns are then empty |
| `seeds`, `nutrient_inputs`, `labour`, `pest_control_inputs`, `land_rent`, `equipment_costs`, `tax`, `transport`, `irrigation`, `feed`, `interest` | `Yes` counted; `No` the item is used but not counted (or the paper lists its costs and this is not among them); `NA` the item does not apply to this system (irrigation in a rainfed trial) |
| `input_production` | For an input made on or off the farm (biochar, compost, feed blocks): `Yes` the cost of making it is counted, `No` the input is used but making it is not costed, `NA` no made input |
| `other_costs` | Any other counted item, by name (marketing, power, certification, water fees) |

Fill these for returns, margins and ratios as well as costs: they record
what was subtracted.

**Checking**

| Column | What |
|---|---|
| `flag` | For a person to look at: `paper_inconsistent` (the paper's own numbers disagree, such as 18.67 against 186.7; keep the printed value), `table_image` (see section 4) |

Marginal rates of return: extracted only when the paper says which
treatment each rate is against; never work the pairing out from the table.
A treatment the paper marks dominated ("D") gets no value and `dominated` in
`note`; a rate printed for the control itself is skipped. Ranges ("NPV from −17,940 to 0") are not extracted, as in 2022;
mention them in the paper's `notes`.

**Settled at the check of batches 1 and 2 (Namita, 27 Nov 2026)**

- *Animal fattening.* A fattening paper's "gross return" is the selling
  price minus the purchase price of the animal (the value of the weight
  gained). Code it `Gross Return` and write that in `outcome_formula`; when
  the paper does not say whether the purchase price is netted out, write
  `unstated` and what the paper does say. A selling price alone is
  `Other (named)`.
- *Before and after changes.* A change in the same arm from before to after
  the treatment (milk value before and after supplementation) is
  `Other (named)`, with the formula; it is neither a `Gross Return` nor
  `is_incremental` (that is a difference from the control).
- *Valued but not paid.* Values that are not cash to the farmer, such as
  nitrogen in a cover crop priced as urea (fertiliser replacement value) or
  an environmental benefit valued by willingness to pay, are extracted as
  `Other (named)`, with the formula, so they are never pooled with returns.
- *Discounted cash flows.* When a paper prints a yearly cash flow both
  undiscounted and discounted, take the undiscounted years and the totals
  (NPV, IRR, payback); not the discounted years, which are the same numbers
  times a discount factor.
- *Bought-in feed.* A commercial compounded concentrate is
  `supplementation_bought_in`, also when the control is a homemade
  concentrate.
- *A paper whose only money value is not a cost or return of the practice*
  (the replacement cost of nutrients lost to erosion) is `no_outcome_data`.
- *A harvested legume grown in a crop* (vetch under-sown in sorghum and cut
  for hay) is neither `cover_crops` nor `feed_mgmt`: `no_defined_practice`.
- *Carbon values built from borrowed sequestration rates times an assumed
  price*, with no with/without comparison of returns, are not the paper's own
  outcome data: `no_outcome_data`.
- *Unitless indices.* A ratio such as an acceptability index (treatment
  benefit over control benefit) has the unit `ratio`, never a currency.
- *Typeset tables.* A table whose numbers are in the PDF's text layer is
  `table`, even in a scanned-looking thesis; `table_image` only when the
  numbers are not in the text.
- *Biochar production only.* A paper on making biochar (a kiln) that never
  applies it to a field is `no_defined_practice`.
- *Crop residue treatment* (urea-treated straw) stays in `feed_mgmt`
  (`residue_treatment`) until the practice register decides on it.

### adoption

One row per adoption figure or adoption driver.

| Column | What |
|---|---|
| `kind` | `rate` (how many adopt) or `driver` (what changes adoption) or `disadoption` |
| `practice` | Vocabulary code |
| `definition_used` | The paper's definition of adoption, in its words |
| `measure` | rate: `share_households`, `share_area`, `area_ha`, `number_farmers`; driver: `odds_ratio`, `marginal_effect`, `coefficient`, `percentage_points`, `elasticity`, `other` |
| `value`, `denominator` | The number and what it is out of |
| `driver` | Driver only: the variable as named (for example "access to credit") |
| `significant` | Driver only: `yes`, `no`, `unstated`, with the level if given |
| `context` | `within_project`, `non_project`, `pre_project_baseline`, `national_general` |
| `ever_vs_current` | `current`, `ever`, `unstated` |
| `country`, `geography`, `year`, `sample_size` | As stated |

### carbon

One row per carbon income figure.

| Column | What |
|---|---|
| `measure` | `share_to_farmers`, `payment_per_farmer`, `payment_per_ha`, `credit_price`, `credits_issued`, `project_revenue`, `other` |
| `practice` | Vocabulary code |
| `project_name` | Where named |
| `value`, `unit` | As printed |
| `share_basis` | For shares: `gross_credit_revenue`, `net_of_project_costs`, `per_credit_fixed`, `unstated` |
| `payment_form` | `cash`, `in_kind`, `mixed`, `unstated` |
| `reporter` | `project_developer`, `independent_evaluation`, `registry`, `academic_study` |
| `country`, `year` | As stated |

## 4. Provenance, on every row

| Column | What |
|---|---|
| `data_type` | Where the number comes from: `field_measured` (trial or experiment records, with observed prices), `survey_reported` (farmer recall, household survey, including means of survey budgets), `project_records` (budgets, monitoring reports), `modelled` (simulation, ex ante or bio-economic model; budgets built on measured yields but assumed prices; projections built from survey data), `secondary` (cited from another study) |
| `extraction_method` | `text`, `table`, `table_image` (a table that is only a picture in the PDF) or `figure` (read off a chart, including printed data labels) |
| `page` | The PDF page number, counting the first page of the file as 1, not the number printed on the page |
| `locator` | Enough to find it without searching: `Table 3, row "Biochar 10 t/ha", column "2019 LR"`; `Figure 2, bar "CA", 2018`; `Results, paragraph 2` |
| `quote` | The exact words, copied from the page, never retyped or tidied. For a table: the row label, the column header and the cell, as they print, separated by ` | `. For a figure or a `table_image`: the caption, and for a figure the axis label |
| `note` | Judgement calls: unit assumptions, number readings, text against table conflicts, arm naming, season names |
| `dropped` | Never set by the agent. Set only at a person's check: the reason a row is dropped (a decision against it, or its paper excluded). The row stays in the file as a record; the checker lists it on the `dropped` sheet and leaves it out of the data sheets and the counts |

Rules the checks enforce:

- The quote has to be on the page it cites. A quote that cannot be found is
  dropped.
- Every number in a `text` or `table` value has to appear in its quote.
- `figure` and `table_image` values are listed for a person to check. Read
  figures as carefully as you can (data labels, gridlines, axis ticks).
- Never calculate a value. If the paper does not print it, it is not
  extracted.
- Never guess a unit, currency, year or sample size the paper does not state:
  leave it empty and say so in `note`.

## 5. Output

One JSON file per paper, `extractions/<round>/<record_id>.json` (the 30
paper pilot is `fulltext_pilot`, under 0.1.0):

```json
{
  "record_id": "W123",
  "rules_version": "0.3.1",
  "decision": "include",
  "exclude_reason": null,
  "practices_confirmed": ["biochar"],
  "outcomes_found": ["cost_return"],
  "study_design": "experiment_on_farm",
  "countries": ["KEN"],
  "pages_read": 14,
  "supplementary": null,
  "notes": "Judgement calls for the paper as a whole.",
  "cost_return": [ { "...": "..." } ],
  "adoption": [],
  "carbon": []
}
```

Then run the checks: `uv run python py/check_extraction.py --dir extractions/<round>`.

## 6. World Bank outcome list

Gross Return · Net Return · Gross Margin · Total Cost · Total Cost per Unit
Product · Total Cost per Asset · Total Cost (Unconfirmed) · Fixed Cost ·
Fixed Cost per Unit Product · Fixed Cost per Asset · Variable Cost · Variable
Cost per Unit Product · Variable Cost per Asset · Labour Cost · Labour Cost
per Unit Product · Labour Cost per Asset · Benefit Cost Ratio (GRTC) ·
Benefit Cost Ratio (GRVC) · Benefit Cost Ratio (GMVC) · Benefit Cost Ratio
(NRVC) · Benefit Cost Ratio (NRTC) · Benefit Cost Ratio (GMTC) · Benefit Cost
Ratio (Unspecified) · Cost Benefit Ratio (TCGR) · Cost Benefit Ratio (VCGR) ·
Net Present Value · Payback Period · Return on Investment · Internal Rate of
Return · Marginal Rate of Return · Return to Labour

Added in 0.2.0: **Value Cost Ratio** (value of the extra yield over the cost
of the input; record the paper's formula) · **Labour Use** (labour as a
quantity, person-days per ha; when the paper gives both days and money, take
both, the money as `Labour Cost`) · **Other (named)** (an economic return or
cost indicator that fits nothing above, with the paper's name in
`label_in_paper` and its formula in `outcome_formula`; use it sparingly, as
the list is meant to stay narrow).

Definitions: the `Outcomes` sheet of `data/wb_nbs_extraction_2022.xlsx`. A
"benefit cost ratio" whose formula the paper does not give is
`Benefit Cost Ratio (Unspecified)`, even when the numbers suggest which one
it is (say so in `note`). The paper's label never decides the outcome on its
own. Gross Margin is revenue minus variable costs; Net Return is revenue
minus total costs (2022 definitions). So a partial budget "net benefit" or a
"net profit" that subtracts only the costs that vary (fertiliser, biochar,
their labour) is a `Gross Margin` with `budget_type = partial`; it is a
`Net Return` only when fixed costs are subtracted too.

## Versions

| Version | Date | Change |
|---|---|---|
| 0.1.0 | 2026-11-16 | First version, for the 30 paper pilot |
| 0.2.0 | 2026-11-17 | cost_return rewritten from Namita's answers to the 44 gaps: 2022 practice and cost-item columns (practices from our vocabulary), `product_con`, `animals_per_rep`, `label_in_paper`, `outcome_formula`, `is_incremental`, `comparator_matches_vocab`, `scenario`, `exchange_rate`, `budget_type`, `labour_valued`, `input_production`, `feed`, `interest`, `flag`; practice columns hold the sub-practice (vocabulary `subpractices` column); paper field `supplementary`; season and aggregate year codes; no calculated values; table > figure > text; method `table_image`; outcomes Value Cost Ratio, Labour Use, Other (named) |
| 0.3.0 | 2026-11-24 | Practice register v0.2 (issue #23): `nutrient_mgmt_b` not taken forward, exclude reason `practice_out_of_scope`; `multistrata_shade_trees` renamed `shaded_perennials` and in scope (sub-practices coffee, cocoa, tea); `feed_mgmt` sub-practice `supplementation_bought_in`; biochar `feedstock` column |
| 0.3.1 | 2026-11-27 | Namita's answers at the check of batches 1 and 2 (section 3, after cost_return): fattening gross return, before/after changes, values not paid in cash, discounted cash flows, bought-in concentrate, unitless indices, typeset tables, and four exclusion cases; crop residue treatment stays in `feed_mgmt`; the `dropped` field, set only at a person's check |
