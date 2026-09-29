---
name: add-practice
description: Add a climate adaptation practice to the CC4A controlled vocabulary and the search keyword list, and rerun the steps that depend on it.
---

# Adding a practice

A practice lives in four places. The protocol defines it; the three files
the scripts read follow the protocol. Change one without the others and the
search finds records the vocabulary cannot code, the template has no option
for it, or the protocol and the code disagree.

| Where | What |
|---|---|
| `docs/synthesis/01-practice-definitions.md` | The definition. Written first |
| `catalogues/vocab_practices.csv` | The practice as a row the scripts read |
| `docs/synthesis/extraction_schema.csv` | The code in the `practice_id` list |
| `catalogues/keyword_list.R` and `docs/synthesis/03-search-strategy.md` §1.3 | The search string |

Adding a practice changes scope. Log it as an amendment in
`docs/protocol.md`, and after the 16 October 2026 freeze agree it with the
team first.

## 1. The definition

Add a section to `01-practice-definitions.md` in the same shape as the
others: Crosswalk row, era-aom codes (or `none` plus the nearest code; never
invent an era code), system, includes, excludes, boundary cases, comparator,
dose, outcomes. The boundary cases are where the coding goes wrong, so name
the neighbouring practice a borderline paper goes to.

## 2. The vocabulary

Add one row to `catalogues/vocab_practices.csv`.

| Column | What goes in it |
|---|---|
| `practice_code` | snake_case, lower case, no spaces. The same code as `practice_id` in the schema |
| `label` | Sentence case, how a person would say it |
| `scope` | `in_scope`, `not_taken_forward` or `out_of_scope`. The last two are listed so screening can name them and count them out |
| `pilot` | `yes` for the three pilots only |
| `crosswalk` | The Crosswalk row and its status |
| `era_codes` | Semicolon separated era-aom leaf codes, as in `01` |
| `system` | The farming system it applies to |
| `definition` | One sentence. What the practice is, not why it matters |
| `comparator` | What its effect is measured against |
| `synonyms` | Semicolon separated, every spelling the literature uses, including hyphenated and abbreviated forms. Step 6 matches on these |
| `notes` | The boundary. Say what it is not, and which neighbouring code a borderline paper goes to |

Write the boundary note even when it feels obvious. Cover crops and
conservation agriculture overlap, and the note is the only place in the
catalogue where that overlap is settled.

## 3. The schema and template

Add the code to the `allowed_values_or_unit` list of `study.practice_id` in
`docs/synthesis/extraction_schema.csv` (the other tables point at it with
`(as study)`). Then rebuild the template:

```
Rscript R/00_shared/build_template.R
```

Never edit `extraction_template.xlsx` by hand; the script overwrites it.

## 4. The keyword list

Add an entry to `KW_PRACTICE` in `catalogues/keyword_list.R`, named for the
practice code, with `terms` and, where the bare terms are noisy (acronyms,
common words), an `and_any` block such as a crop or livestock term. Put the
same string in `03` §1.3. Terms have to be specific enough that the records
returned carry evidence.

Test the string before using it: record the hit count, and check it finds at
least 90% of the practice's known includes set (`03` section 0). A term that
adds hits but no includes is dropped.

```
Rscript R/01_search/openalex_search.R --dry
```

The dry run prints the expected count per query. A query returning tens of
thousands of records is too broad; narrow it before running it for real.

## 5. Rerun what depends on it

| Step | Rerun | Why |
|---|---|---|
| 1 search | yes | The new terms have never been queried |
| 2 dedup | yes | New records join the pool |
| 3 screen | new records only | The screener is resumable, judged records are skipped |
| 4 fetch | new in scope records only | Also resumable |
| 5 extract | new records only | Also resumable |
| 6 harmonise | yes, whole run | The option list changed, so the options hash changed, and decisions taken under the old list retire on their own |
| 7 publish | yes | The tables are rebuilt from the harmonised run |

Nothing already extracted is read again. That is the point of keeping the
vocabulary out of the extraction prompt.

## 6. Check it landed

- The code is the same in all four places. A quick check: every
  `in_scope` code in `vocab_practices.csv` has an entry in `KW_PRACTICE` and
  appears in `study.practice_id`.
- The practice has a drop-down option in the rebuilt template.
- The practice appears in the option list `harmonize.R` prints on a dry run.
- `outputs/review/proposed_vocab_terms.csv` no longer lists the terms that
  prompted the addition.
- No row in the published tables is coded `other` for a paper that is
  plainly about the new practice.
