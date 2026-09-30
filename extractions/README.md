# Extractions

The extracted evidence, one CSV per sheet of the extraction template
(`docs/synthesis/extraction_template.xlsx`), with the same columns. The
columns are defined in `docs/synthesis/extraction_schema.csv`; rows link to
each other by id (`source_id`, `study_id`, `site_season_id`, `quote_id`).

| File | One row per |
|---|---|
| `source.csv` | Paper or document |
| `study.csv` | Contrast studied (a practice against its comparator) |
| `site_season.csv` | Site and season, with coordinates and dates |
| `effect.csv` | Treatment and control result for one outcome |
| `cost.csv` | Cost item for one arm |
| `quote.csv` | Verbatim quote and locator supporting one or more values |
| `verification.csv` | Check of one quote (written by the verifier, never the extractor) |
| `gap.csv` | Where evidence is too thin to give a number |
| `notes/<StudyID>.md` | The extractor's judgement calls for each paper |

## Pilot: five papers, 30 September 2026

Five African papers from the 2022 World Bank NbS extraction, re-extracted
against the new template (core fields, all sheets) to test it.

| StudyID | Paper | Practice | Effects | Costs | Quotes |
|---|---|---|---|---|---|
| 6134332 | MacCarthy et al. 2020, Ghana, irrigated rice | biochar | 32 | 15 | 35 |
| 6135863 | Tufa et al. 2022, Ethiopia, maize | biochar | 16 | 15 | 31 |
| 6134030 | Fatumah et al. 2021, Uganda, beans | ca_bundle | 42 | 3 | 31 |
| 6135671 | Ejigu et al. 2021, Ethiopia, maize | nutrient_mgmt_b | 18 | 20 | 26 |
| 6137948 | Obiri et al. 2007, Ghana, maize after legumes | cover_crops | 10 | 65 | 38 |

**How it was done.** Each paper was extracted by a separate AI session that
saw only its paper and the protocol, and not the 2022 numbers. A different
session then verified the output.

**Check A (does the quote exist where it says?).** Done by script for all
161 quotes: all found exactly on the cited page. 342 numbers appear inside
their quotes; 24 more are conversions or figure readings with the
calculation recorded (coordinates converted to decimals, and the Uganda
yields read from Figure 6).

**Check B (does the quote support the claim?).** Done by reading 19 quotes
across the five papers: 18 support their claim, one partially (rainfed
recorded by inference). The Uganda figure readings were checked by eye
against the figure. The other 142 quotes are still to be checked; their
`check_b_supports` is empty.

**Comparison with the 2022 extraction.**
- Costs agree exactly for 6135863 (15 of 15), 6134030 (3 of 3) and 6135671
  (8 comparable values).
- 6137948: the 2022 rows have errors. Lablab labour cost is 119 298 where the
  paper prints 1 119 298; the currency is recorded as GHS (new cedi) where
  the 2001 to 2002 prices are in old cedi (GHC), a factor of 10 000; and some
  rows carry the wrong table or outcome label.
- 6134332: not comparable. The 2022 team used the paper's supplementary
  Table S2 (costs per treatment), which is not in the PDF we hold; we took
  the itemised costs from Table 1. The supplement is needed.

**What the pilot showed about the template.**
- The range columns were needed (Ghana legumes reports labour as ranges).
- The cost sheet has no arm column, so the arm goes at the start of `item`.
  An `arm` field would make cost rows easier to join to effects.
- One site season per study repeats the same site when one trial feeds
  several studies (6135671). Allowing a site season to be shared across
  studies would avoid it.
- Papers are often internally inconsistent (text against table, LSD against
  CV). The extractors took printed table values and logged the
  inconsistency; that rule should be written into the protocol.
- Judgement calls to confirm: whether herbaceous legume fallows are
  cover crops or excluded improved fallows (6137948); whether imported mulch
  counts as the CA bundle's retained residue (6134030); whether compost added
  on top of full fertiliser fits nutrient management scenario (b) (6135671).
