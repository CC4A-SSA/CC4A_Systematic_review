# Addendum: what Chun's analysis needs from the synthesis

**Status:** agreed 29 September 2026 (decision D11 in `00`). The fields below
are in `extraction_schema.csv`, `02-extraction-schema.md` and the extraction
template.
**Author:** Namita Joshi, 29 September 2026.

This pack (files `00` to `09`) is the protocol. This addendum adds what
Chun's net economic benefit (NEB) analysis asked for and the pack does not
yet carry. It changes no decision in `00`. The line with Chun in `00` still
holds: we extract, Chun converts, values and decides what enters NEB.

## 1. Chun's original template

Chun's parameter sheet had six columns and three kinds of parameter.

| Column | Meaning |
|---|---|
| `parameter` | Adoption rate, cost (total, installation, variable), share of carbon income |
| `definition` | What is measured, for example "proportion of farmers who adopt the practice" |
| `practice` | Practice name |
| `value` | The figure as reported, for example "25 USD/ha or 1-26 person-days/ha" |
| `literature` | DOI or URL |
| `detail` | Context: sample, wage basis, what the cost includes, horizon, discount rate |

Her worked rows, for agroforestry, show the kinds of evidence she expects:

- an adoption rate from a stratified survey, with the correction from the raw
  respondent share to the sampling frame rate;
- a determinant of adoption (credit group membership raising adoption
  probability by 0.17 percentage points);
- a payment response (a payment of UGX 70,000/ha/year cutting two year tree
  cover loss from 9.1% to 4.2%);
- choice experiments on the payment needed to induce participation;
- a total discounted cost (US$64/ha/year, five years, 30% discount rate) and
  installation and variable costs in USD and person-days;
- the share of carbon income that reaches farmers.

## 2. What the pack already covers

| Chun's need | Where it lands in the pack |
|---|---|
| Installation cost | `cost.cost_class = establishment_fixed` |
| Variable cost | `cost.cost_class = variable_running` |
| Person-days, not priced | `cost.labour_days`, `labour_included`, `family_labour_costed` |
| Currency as reported | `cost.currency`, `price_year`; Chun converts (`00`, D5) |
| What a cost includes | the `*_included` boundary fields and `boundary_quote_id` |
| Adoption rate with its definition | `adoption_obs.definition_used`, `denominator`, `measure`, `value` |
| Literature and detail | `source` and `quote`; every value carries a verbatim quote and locator (`04`) |

## 3. Gaps, and the fix

### 3.1 Share of carbon income to farmers

**Gap.** Mitigation is out of scope (`00`), and `09` finding C8 records that
there is no benefit sharing search. `cost.cost_class = farmer_payment`
records a payment as a cost, not the share of carbon revenue it represents.

**Added.** A new table, `benefit_share`, stream 1 and 4, one row per
project and arrangement.

| Field | Type | Req | Allowed / unit | Description |
|---|---|---|---|---|
| `benefit_share_id` | id | R | BSH-0001 | Unique id |
| `source_id` | id | R |  | Parent source |
| `practice_id` | enum | R | (as study) | Practice |
| `project_name` | string | O |  | Carbon project, where named |
| `country` | string | R | ISO3 |  |
| `share_value` | number | R | fraction | Share of carbon income that reaches farmers |
| `share_basis` | enum | R | gross_credit_revenue \| net_of_project_costs \| per_credit_fixed \| unstated | What the share is a share of |
| `payment_form` | enum | R | cash \| in_kind \| mixed \| unstated | How farmers receive it |
| `reporter` | enum | R | project_developer \| independent_evaluation \| registry \| academic_study | Who reports it. Developer figures are claims, not outturns |
| `year` | integer | R |  | Reference year |
| `quote_id` | id | R |  | Verbatim support, as for every value |

Sources: carbon project documents (PDDs), monitoring and verification
reports, registry documents, and evaluations of carbon projects. These are
already named as cost sources in `02` §6, so no separate search is needed:
extract the share when a document already opened for costs reports it.

### 3.2 Determinants of adoption

**Gap.** `adoption_obs` holds extent (share, area, number of farmers). A
finding such as "credit group membership raised adoption probability by 0.17
percentage points" has no home.

**Added.** A new table, `adoption_driver`, stream 4.

| Field | Type | Req | Allowed / unit | Description |
|---|---|---|---|---|
| `driver_id` | id | R | ADR-0001 | Unique id |
| `source_id` | id | R |  | Parent source |
| `practice_id` | enum | R | (as study) | Practice |
| `country` | string | R | ISO3 |  |
| `driver` | string | R |  | The factor, in the source's terms (credit access, tenure, extension contact, payment level) |
| `driver_class` | enum | R | finance \| tenure \| information_extension \| payment_incentive \| labour \| market \| household \| other | For grouping across studies |
| `effect_value` | number | R |  | As reported |
| `effect_unit` | enum | R | percentage_points \| odds_ratio \| marginal_effect \| elasticity \| payment_level \| other | Unit of the effect |
| `model` | string | R |  | Estimation model (probit, logit, double hurdle, RCT difference) |
| `significant` | enum | R | yes \| no \| unstated | At the level the source reports |
| `sample_size` | integer | O |  |  |
| `quote_id` | id | R |  | Verbatim support |

Null and non-significant drivers are extracted, for the same reason as null
effects in `04` §8.

### 3.3 Payment response and choice experiments

**Gap.** `03` §4.4 excludes adoption intentions and willingness to adopt
studies. Chun's template includes discrete choice experiments on the payment
needed to induce participation, and field experiments on payments. These are
what size a carbon payment.

**Added.** Keep the §4.4 exclusion for plain intention surveys ("would you
adopt?"). Admit two kinds of study, tagged so they never mix with extent:

- **payment experiments** with observed behaviour (a randomised payment and a
  measured outcome, such as the tree cover result in Chun's template) go into
  `adoption_driver` with `driver_class = payment_incentive`;
- **choice experiments and willingness to accept** studies go into
  `adoption_driver` with `effect_unit = payment_level`, the currency and
  basis in the quote, and `stated_preference = yes`.

`stated_preference` (`yes | no`, required) keeps what people say they would
do apart from what they were observed to do. The two are never pooled.

### 3.4 Total and discounted costs

**Gap.** `02` §6 does not extract reported NPVs, BCRs or IRRs, because they
embed someone else's boundary and discount rate. There is no `total` cost
class. Chun's template records a total discounted cost with its horizon and
rate.

**Decision (D12).** Collect totals, and flag them: the more is collected,
the more there is to filter later. The caveat is that a total embeds the
authors' boundary, horizon and discount rate, so it is never used in place of
the itemised figures by default. Keep the exclusion of BCRs, IRRs and NPVs of
benefits. Added:

- `cost_class = total`, for a reported total cost of the practice;
- `cost.discount_rate` (number, fraction, conditional: required when the
  figure is discounted);
- `cost.horizon_years` (number, conditional: required when the figure is
  discounted or annualised);
- `cost.author_computed` (enum `yes | no`, required): `yes` when the figure is
  the authors' own aggregate rather than an itemised cost.

A total is extracted alongside its components where the source gives both,
never instead of them. Chun decides whether a total enters NEB. The boundary
fields apply to it as to any cost.

## 4. What Chun reads

Chun reads the extraction template directly and takes what she needs from
it. No separate export is built. What matters is that every item in her
template is a column in the schema, and after §3 it is:

| Chun's template | Schema |
|---|---|
| Adoption rate | `adoption_obs.value`, `measure`, `definition_used`, `denominator` |
| Determinant of adoption | `adoption_driver` |
| Payment response, choice experiments | `adoption_driver` with `driver_class = payment_incentive` |
| Total cost | `cost` with `cost_class = total`, `author_computed`, `discount_rate`, `horizon_years` |
| Installation cost | `cost` with `cost_class = establishment_fixed` |
| Variable cost | `cost` with `cost_class = variable_running` |
| Share of carbon income to farmers | `benefit_share` |
| Literature | `source.doi_or_url` |
| Detail | the boundary fields, `labour_rate`, `sample_size`, and the verbatim quote and locator |

## 5. Timing

Adoption, adoption drivers and benefit sharing are searched and extracted
together with the rest of the review, from the first searches, with their
literature kept separate (decision D8 in `00`). This replaces the January to
February sweep in `07`.

## 6. Chun's answers

Answered by Namita on Chun's behalf, 29 September 2026.

| Question | Answer |
|---|---|
| Are the additions what is needed; is anything missing? | The additions and Pete's template are thorough. Nothing else is needed |
| Flat export, or read the table directly? | Chun extracts what she needs from the final Excel template. Her requirements must be among its columns (§4) |
| When are adoption and benefit sharing needed? | Together with the rest of the review (§5) |
| Collect reported total costs? | Yes, with the caveats stated. Collect more and filter later (§3.4) |
