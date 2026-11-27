"""Choose the papers for the full text extraction pilot.

What it does: picks papers that have a PDF, spread over the outcome folders
and the defined practices, with some modelled studies and some whose values
sit in tables or figures, and short enough to read in one go. Seeded, so the
same run gives the same papers.
Reads: outputs/04_fulltext/included_records.csv
       outputs/04_fulltext/fulltext_index.csv
       outputs/04_fulltext/pdf/<record_id>.pdf
Writes: extractions/fulltext_pilot/pilot_papers.csv
Run with:
  uv run python py/select_pilot.py
"""

import csv
import random
import re

import pymupdf as fitz

from paths import EXTRACT_PILOT, FULLTEXT

OUT = EXTRACT_PILOT / "pilot_papers.csv"
SEED = 20261116
# Papers per outcome folder. Carbon finance has only five PDFs.
PER_FOLDER = {"Adoption": 8, "Costs, returns and incentives": 9, "Multiple outcomes": 9,
              "Carbon finance": 4}
MIN_MODELLED = 4
MAX_PAGES = 40
MODELLED = re.compile(r"\b(model(l)?ed|model(l)?ing|simulat\w*|ex[- ]ante|scenario\w*)\b", re.I)


def main():
    rows = list(csv.DictReader(open(FULLTEXT / "included_records.csv", encoding="utf-8")))
    ok = {r["record_id"] for r in csv.DictReader(open(FULLTEXT / "fulltext_index.csv",
                                                      encoding="utf-8"))
          if r["status"] == "ok"}
    pool = []
    for r in rows:
        if r["record_id"] not in ok or r["outcome_folder"] not in PER_FOLDER:
            continue
        with fitz.open(FULLTEXT / "pdf" / f"{r['record_id']}.pdf") as doc:
            r["pages"] = doc.page_count
            text = " ".join(p.get_text() for p in doc)
        if r["pages"] > MAX_PAGES:
            continue
        r["modelled_hint"] = bool(MODELLED.search(r["abstract"] or ""))
        r["n_tables"] = len(re.findall(r"\bTable\s+\d", text))
        r["n_figures"] = len(re.findall(r"\bFig(?:ure)?\.?\s+\d", text))
        pool.append(r)

    rng = random.Random(SEED)
    rng.shuffle(pool)
    chosen, seen_practices = [], set()
    for folder, n in PER_FOLDER.items():
        cands = [r for r in pool if r["outcome_folder"] == folder]
        # A practice not yet in the sample first, so the sample spreads.
        cands.sort(key=lambda r: all(p in seen_practices for p in r["practices"].split("; ")))
        for r in cands[:n]:
            chosen.append(r)
            seen_practices.update(r["practices"].split("; "))
    # Top up the modelled studies by swapping out the last non-modelled ones.
    extra = [r for r in pool if r["modelled_hint"] and r not in chosen]
    while sum(r["modelled_hint"] for r in chosen) < MIN_MODELLED and extra:
        drop = next(r for r in reversed(chosen) if not r["modelled_hint"]
                    and r["outcome_folder"] != "Carbon finance")
        add = next((r for r in extra if r["outcome_folder"] == drop["outcome_folder"]), None)
        if add is None:
            break
        chosen[chosen.index(drop)] = add
        extra.remove(add)

    OUT.parent.mkdir(parents=True, exist_ok=True)
    cols = ["record_id", "outcome_folder", "practices", "pages", "n_tables", "n_figures",
            "modelled_hint", "publication_year", "doi", "title"]
    with open(OUT, "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, cols, extrasaction="ignore")
        w.writeheader()
        w.writerows(chosen)
    print(f"{len(chosen)} papers, {sum(r['modelled_hint'] for r in chosen)} with a modelling hint,"
          f" {len({p for r in chosen for p in r['practices'].split('; ')})} practices")
    print(f"wrote {OUT}")


if __name__ == "__main__":
    main()
