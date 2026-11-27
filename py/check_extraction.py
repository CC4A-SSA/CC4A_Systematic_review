"""Check the full text extractions and gather them into one workbook.

What it does: reads every extraction file (one JSON per paper, written under
docs/synthesis/fulltext_extraction_rules.md), and for every extracted row
checks
  check_quote    the quote is on the page it cites: found, found on another
                 page (page given), or not_found
  check_numbers  every number in the row's values appears in its quote: ok,
                 missing (the numbers that are not), or n/a for figure and
                 table_image rows
  check_cell     a table value is the first number of a quoted cell
  check_fields   (rules 0.2 on) each cost_return column holds an allowed
                 value: outcome name, Yes/No/NA cost items, year codes
A row whose quote is not found is dropped from the clean tables and kept on
the problems sheet. Figure values are listed for a person to check. Where a second reader
(an agent that did not extract the paper) has checked a paper against its
PDF, its findings from qc/<record_id>.json go on the qc sheet: rows it
thinks are wrong (error) or open to judgement (query), and values it thinks
were missed, each with a yellow person_decision column; its verdict goes on
the papers sheet.
Rows whose practices are all out of scope in catalogues/vocab_practices.csv
(e.g. nutrient_mgmt_b, dropped in practice register v0.2) are taken out of
the workbook and written to a second one, <name>_out_of_scope.xlsx, with the
same sheets; the extraction files keep them. So are all the rows of a paper
that is out of scope as a whole (paper_out_of_scope: its confirmed practices
are all out of scope and no row names one in scope), rows coded "other" too.
Rows a person dropped at the
check (a "dropped" field giving the reason) go on the dropped sheet and are
not checked; their second-reader findings are left off. Each data sheet runs
record_id, title, row; where and what (country, product); the practices; the
outcome with its values; costs; page and quote; the checks last.
The batches (--batch) and the PDFs are in the shared folder (py/paths.py,
CC4A_SHARED_DIR); the pilot and fulltext_v02 rounds are in git.
Reads: extractions/<round>/<record_id>.json
       extractions/<round>/qc/<record_id>.json (when there)
       outputs/04_fulltext/pdf/<record_id>.pdf
       outputs/04_fulltext/included_records.csv (titles)
       catalogues/vocab_practices.csv (sub-practices, scope)
Writes: extractions/<round>/checked.xlsx   papers, cost_return, adoption,
          carbon, to_check (figure and picture-table values), qc, problems
        extractions/<round>/checked_out_of_scope.xlsx   cost_return, adoption,
          carbon rows whose practices are all out of scope
Run with:
  uv run python py/check_extraction.py --dir extractions/fulltext_v02
  uv run python py/check_extraction.py --dir extractions/fulltext_v02 --record 6134332
  uv run python py/check_extraction.py --batch 1      batch_001/batch_001.xlsx
"""

import argparse
import csv
import json
import re
import unicodedata
from pathlib import Path

import pymupdf as fitz
import openpyxl
from openpyxl.cell.cell import ILLEGAL_CHARACTERS_RE
from openpyxl.styles import Font, PatternFill

from paths import EXTRACT_BATCHES, EXTRACT_PILOT, INCLUDED, PDF_DIR, ROOT, WORK

DEFAULT_DIR = EXTRACT_PILOT
TABLES = ("cost_return", "adoption", "carbon")
# The value columns whose numbers must appear in the quote, per table.
VALUE_FIELDS = {
    "cost_return": ("value_trt", "value_con", "value_trt_error", "value_con_error"),
    "adoption": ("value",),
    "carbon": ("value",),
}
# A table quote lists row label, column header and cell, separated by this.
PART_SEP = " | "
PAPER_FIELDS = ("record_id", "rules_version", "decision", "exclude_reason",
                "practices_confirmed", "outcomes_found", "study_design", "countries",
                "pages_read", "supplementary", "notes")
PROVENANCE = ("data_type", "extraction_method", "page", "locator", "quote", "computation",
              "note")
CHECKS = ("check_quote", "check_numbers", "check_cell", "check_fields")
# Values a person reads off the page image, never checked against the text.
BY_EYE = ("figure", "table_image")

# Allowed values of the cost_return columns from rules 0.2.0 on.
OUTCOMES = {
    "Gross Return", "Net Return", "Gross Margin", "Total Cost",
    "Total Cost per Unit Product", "Total Cost per Asset", "Total Cost (Unconfirmed)",
    "Fixed Cost", "Fixed Cost per Unit Product", "Fixed Cost per Asset", "Variable Cost",
    "Variable Cost per Unit Product", "Variable Cost per Asset", "Labour Cost",
    "Labour Cost per Unit Product", "Labour Cost per Asset",
    "Benefit Cost Ratio (GRTC)", "Benefit Cost Ratio (GRVC)", "Benefit Cost Ratio (GMVC)",
    "Benefit Cost Ratio (NRVC)", "Benefit Cost Ratio (NRTC)", "Benefit Cost Ratio (GMTC)",
    "Benefit Cost Ratio (Unspecified)", "Cost Benefit Ratio (TCGR)",
    "Cost Benefit Ratio (VCGR)", "Net Present Value", "Payback Period",
    "Return on Investment", "Internal Rate of Return", "Marginal Rate of Return",
    "Return to Labour", "Value Cost Ratio", "Labour Use", "Other (named)"}
PRACTICES = ("awd", "biochar", "rotational_grazing", "ca_bundle", "cover_crops",
             "nutrient_mgmt_b", "trees_in_farmlands", "fodder_banks", "feed_mgmt",
             "silvopasture", "dsr", "sri", "erw", "boundary_plantings", "improved_fallow",
             "riparian_buffers", "shaded_perennials", "crop_livestock_integration",
             "solar_irrigation", "water_harvesting", "improved_varieties")
COST_ITEMS = ("seeds", "nutrient_inputs", "labour", "pest_control_inputs", "land_rent",
              "equipment_costs", "tax", "transport", "irrigation", "feed", "interest",
              "input_production")
ERROR_TYPES = ("SD", "SE", "SEM", "SED", "LSD", "CI95")
VOCAB = ROOT / "catalogues" / "vocab_practices.csv"


def practice_values() -> dict[str, set[str]]:
    """What each practice column may hold: one or more of its sub-practices
    (joined by "; ") or unspecified, or yes for a practice without any."""
    with VOCAB.open(encoding="utf-8") as f:
        subs = {r["practice_code"]: [s for s in r["subpractices"].split(";") if s]
                for r in csv.DictReader(f)}
    return {p: set(subs.get(p) or ["yes"]) | ({"unspecified"} if subs.get(p) else set())
            for p in PRACTICES}


def in_scope_practices() -> set[str]:
    with VOCAB.open(encoding="utf-8") as f:
        return {r["practice_code"] for r in csv.DictReader(f) if r["scope"] == "in_scope"}


def named_practices(row: dict) -> set[str]:
    """The practice codes a row names: the practice columns it marks
    (cost_return) and its practice field, without "other" and "none"."""
    named = {p for p in PRACTICES if row.get(p)} | {str(row.get("practice") or "")}
    return named - {"", "other", "none"}


def out_of_scope(row: dict, in_scope: set[str]) -> bool:
    """A row is out of scope when it names practices and none is in scope.
    "other" and an empty practice are left for a person."""
    named = named_practices(row)
    return bool(named) and not named & in_scope


def paper_out_of_scope(ex: dict, in_scope: set[str]) -> bool:
    """A paper is out of scope when no row names an in-scope practice and
    either every row is out of scope or the practices the agent confirmed are
    all out of scope (then its rows coded "other" go too)."""
    rows = [row for t in TABLES for row in ex.get(t) or [] if not row.get("dropped")]
    if any(named_practices(row) & in_scope for row in rows):
        return False
    confirmed = set(ex.get("practices_confirmed") or []) - {"", "other", "none"}
    if confirmed and not confirmed & in_scope:
        return True
    return bool(rows) and all(out_of_scope(row, in_scope) for row in rows)


ALLOWED = {
    "data_type": {"field_measured", "survey_reported", "project_records", "modelled",
                  "secondary"},
    "extraction_method": {"text", "table", "table_image", "figure"},
    "is_incremental": {"yes", "no"},
    "comparator_matches_vocab": {"yes", "no", "unclear"},
    "budget_type": {"partial", "full", "unstated"},
    "labour_valued": {"yes", "no", "unstated"},
    "costs_unknown": {"Yes", "No", ""},
    "error_type": {"", *ERROR_TYPES, *(f"Grouped {e}" for e in ERROR_TYPES)},
    "feedstock": {"", "crop_residue", "manure", "forest_residue", "wood_unspecified", "other",
                  "unstated"},
    "flag": {"", "paper_inconsistent", "table_image", "paper_inconsistent; table_image"},
} | {c: {"Yes", "No", "NA", ""} for c in COST_ITEMS}
# 2019 · 2019.1 · 2019..2020 · 2019.1..2019.2 · Y3 · Y1..Y20 · empty
YEAR = re.compile(r"(\d{4}(\.\d)?(\.\.\d{4}(\.\d)?)?|Y\d+(\.\.Y\d+)?)?")
# Column order of the cost_return sheet, as in the rules.
# The column order of each data sheet: the paper, where and what, the
# practices, the outcome with its values, the costs, where the value came
# from, then the checks (CHECKS, last).
FRONT = ("record_id", "title", "row")
COST_COLUMNS = ("country", "site", "measurement_year", "product", "product_con",
                "practice", *PRACTICES, "feedstock", "other_practices",
                "comparator_matches_vocab",
                "outcome", "label_in_paper", "outcome_formula", "outcome_unit",
                "is_incremental", "treatment_name", "control_name", "value_trt",
                "value_con", "value_trt_error", "value_con_error", "error_type",
                "replicates", "animals_per_rep", "exchange_rate", "scenario",
                "discount_rate", "discount_period",
                "budget_type", "labour_valued", "costs_unknown", *COST_ITEMS, "other_costs",
                "flag")
TABLE_COLUMNS = {
    "cost_return": COST_COLUMNS,
    "adoption": ("country", "geography", "year", "practice", "kind", "measure",
                 "definition_used", "ever_vs_current", "value", "denominator",
                 "sample_size", "driver", "significant", "context"),
    "carbon": ("country", "year", "practice", "project_name", "measure", "value", "unit",
               "share_basis", "payment_form", "reporter"),
}

def titles(folder: Path) -> dict[str, str]:
    """Each record's title, from the included records and the folder's
    papers.csv or pilot_papers.csv."""
    out = {}
    for path in (INCLUDED, folder / "pilot_papers.csv", folder / "papers.csv"):
        if path.exists():
            with path.open(encoding="utf-8-sig", newline="") as f:
                out |= {r["record_id"]: r.get("title") or "" for r in csv.DictReader(f)}
    return out

# Characters PDF text and copied quotes spell differently.
SWAPS = {"­": "", "‐": "-", "‑": "-", "‒": "-", "–": "-",
         "—": "-", "−": "-", "‘": "'", "’": "'", "“": '"',
         "”": '"', " ": " ", " ": " ", " ": " ", "·": "."}
# A minus sign counts only where it cannot be a range dash ("4-5") or a
# hyphen: at the start, or after a space, bracket or sign.
NUMBER = re.compile(r"(?:(?<![\w.)])-\s?)?(?:\d{1,3}(?:[ ,]\d{3})+(?:\.\d+)?|\d+(?:[.,]\d+)?)")


def normalise(text: str) -> str:
    """One spelling for comparing a quote with page text."""
    text = unicodedata.normalize("NFKC", text)
    # Control characters some PDFs carry inside words count as nothing.
    text = "".join(SWAPS.get(c, c) for c in text
                   if c in "\t\n\r" or unicodedata.category(c) != "Cc")
    # A word broken over a line ("manage-\nment") reads as one word. Only
    # between letters, so a minus sign before a number on the next line stays.
    text = re.sub(r"(?<=[^\W\d_])-[ \t]*\n\s*(?=[^\W\d_])", "", text)
    return re.sub(r"\s+", " ", text).strip().lower()


def squash(text: str) -> str:
    """Without any spaces, for table cells whose spacing the PDF text loses."""
    return re.sub(r"\s+", "", text)


def numbers_in(text: str, readings: bool = False) -> set[float]:
    """Every number written in a text, reading 1,119,298 and 1 119 298 as one.
    With readings, a number also counts in its other possible reading, so a
    value cleaned by the rules ("2.788" meaning 2788, "1,5" meaning 1.5)
    still matches the quote it came from."""
    out = set()
    if readings:
        for m in re.findall(r"-?\d+(?:[.,]\d+)+", unicodedata.normalize("NFKC", text)):
            for raw in (re.sub(r"[.,]", "", m), m.replace(",", ".")):
                if raw.count(".") <= 1:
                    out.add(round(float(raw), 6))
    for m in NUMBER.findall(unicodedata.normalize("NFKC", text).replace("−", "-")):
        raw = re.sub(r"\s", "", m)
        if re.fullmatch(r"-?\d{1,3}(,\d{3})+(\.\d+)?", raw):
            raw = raw.replace(",", "")
        else:
            raw = raw.replace(",", ".")
        try:
            out.add(round(float(raw), 6))
        except ValueError:
            pass
    return out


class Pdf:
    """The normalised text of each page of one PDF, read once."""

    def __init__(self, path: Path):
        with fitz.open(path) as doc:
            self.pages = [normalise(p.get_text()) for p in doc]
        self.squashed = [squash(p) for p in self.pages]

    def has(self, part: str, page: int) -> bool:
        if not 1 <= page <= len(self.pages):
            return False
        p = normalise(part)
        return p in self.pages[page - 1] or squash(p) in self.squashed[page - 1]

    def find_quote(self, quote: str, page: int) -> str:
        parts = [q for q in quote.split(PART_SEP) if q.strip()]
        if not parts:
            return "not_found"
        if all(self.has(q, page) for q in parts):
            return "found"
        for other in range(1, len(self.pages) + 1):
            if other != page and all(self.has(q, other) for q in parts):
                return f"found_other_page:{other}"
        return "not_found"


def check_numbers(row: dict, table: str) -> str:
    if row.get("extraction_method") in BY_EYE:
        return "n/a"
    have = numbers_in(row.get("quote") or "", readings=True)
    missing, sign = [], []
    for field in VALUE_FIELDS[table]:
        value = row.get(field)
        if value in (None, ""):
            continue
        for n in numbers_in(str(value)):
            if n in have:
                continue
            (sign if -n in have else missing).append(f"{field}={value}")
    out = []
    if missing:
        out.append("missing: " + "; ".join(missing))
    if sign:
        out.append("sign_differs: " + "; ".join(sign))
    return "; ".join(out) or "ok"


def check_cell(row: dict, table: str) -> str:
    """For a table value, the value must be the first number in one of the
    quoted cells, so an error printed beside it ("0.302 (0.138)") cannot be
    taken for the value, and a short cell is tied to its value."""
    if row.get("extraction_method") != "table":
        return "n/a"
    value = row.get(VALUE_FIELDS[table][0])
    if value in (None, ""):
        return "n/a"
    parts = [q for q in (row.get("quote") or "").split(PART_SEP) if q.strip()]
    if len(parts) < 2:
        return "no_cell_part"
    want = numbers_in(str(value))
    for part in parts[1:]:
        first = NUMBER.findall(normalise(part))
        if first and numbers_in(first[0], readings=True) & want:
            return "ok"
    return "value_not_first_in_cell"


PRACTICE_VALUES = practice_values()


def check_fields(row: dict, table: str, version: str) -> str:
    """Each cost_return column holds a value the rules allow."""
    if table != "cost_return" or version < "0.2":
        return "n/a"
    bad = []
    if row.get("outcome") not in OUTCOMES:
        bad.append(f"outcome={row.get('outcome')}")
    for col, ok in ALLOWED.items():
        value = row.get(col)
        value = "" if value is None else str(value).strip()
        if value not in ok:
            bad.append(f"{col}={value}")
    for col, ok in PRACTICE_VALUES.items():
        value = str(row.get(col) or "").strip()
        if value and not set(value.split("; ")) <= ok:
            bad.append(f"{col}={value}")
    if not YEAR.fullmatch(str(row.get("measurement_year") or "")):
        bad.append(f"measurement_year={row.get('measurement_year')}")
    if not row.get("control_name"):
        bad.append("control_name empty (write 'no control')")
    items = [row.get(c) for c in COST_ITEMS]
    if row.get("costs_unknown") == "Yes" and any(items):
        bad.append("cost items filled although costs_unknown = Yes")
    if row.get("costs_unknown") != "Yes" and not any(items):
        bad.append("no cost items and costs_unknown not Yes")
    return "; ".join(bad) or "ok"


def cell(value):
    if isinstance(value, (list, dict)):
        value = "; ".join(map(str, value)) if isinstance(value, list) else json.dumps(value)
    if isinstance(value, str):
        # Excel cannot hold control characters.
        value = ILLEGAL_CHARACTERS_RE.sub("", value)
    return value


def write_sheet(wb, name: str, rows: list[dict], first: tuple = (), last: tuple = ()):
    ws = wb.create_sheet(name)
    cols = (list(first) + sorted({k for r in rows for k in r} - set(first) - set(last))
            + list(last))
    ws.append(cols)
    for c in ws[1]:
        c.font = Font(bold=True)
    for r in rows:
        ws.append([cell(r.get(c)) for c in cols])
    ws.freeze_panes = "B2"
    return ws, cols


QC_FIELDS = ("record_id", "title", "kind", "table", "row", "field", "extracted", "should_be",
             "person_decision", "page", "why", "row_quote")


def read_qc(path: Path, ex: dict, out: list, skip: set = frozenset(),
            title: str = "") -> dict:
    """Add a second reader's findings on one paper to out; its verdict.
    Findings on rows in skip ((table, 1-based row), the out-of-scope and
    dropped rows) are left off."""
    if not path.exists():
        return {"qc_verdict": "", "qc_decision_ok": "", "qc_summary": ""}
    q = json.loads(path.read_text(encoding="utf-8"))
    rid = ex["record_id"]
    start = len(out)
    if q.get("decision_ok") is False:
        out.append({"record_id": rid, "kind": "decision", "field": "decision",
                    "extracted": ex.get("decision"), "why": q.get("decision_note")})
    for i in q.get("issues") or []:
        rows = ex.get(i.get("table")) or []
        n = i.get("row")
        if isinstance(n, int) and (i.get("table"), n + 1) in skip:
            continue
        quote = rows[n].get("quote") if isinstance(n, int) and 0 <= n < len(rows) else None
        # The second reader counts rows from 0; the sheets count from 1.
        out.append({"record_id": rid, "kind": i.get("severity"), "table": i.get("table"),
                    "row": n + 1 if isinstance(n, int) else n, "field": i.get("field"),
                    "extracted": i.get("extracted"), "should_be": i.get("should_be"),
                    "page": i.get("page"), "why": i.get("why"), "row_quote": quote})
    for m in q.get("missed") or []:
        out.append({"record_id": rid, "kind": "missed", "table": m.get("table"),
                    "page": m.get("page"), "field": m.get("locator"), "why": m.get("what")})
    for finding in out[start:]:
        finding["title"] = title
    return {"qc_verdict": q.get("verdict"), "qc_decision_ok": q.get("decision_ok"),
            "qc_summary": q.get("summary")}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dir", type=Path, default=DEFAULT_DIR,
                    help="a round's folder; a relative path is looked for in the shared "
                         "folder, then the repo")
    ap.add_argument("--batch", type=int, help="check batch N in the shared folder, "
                                              "written to batch_NNN.xlsx")
    ap.add_argument("--record", help="check one paper only and print its problems")
    ap.add_argument("--out", help="workbook name in --dir (default checked.xlsx), e.g. when "
                                  "checked.xlsx is open in Excel")
    args = ap.parse_args()
    if args.batch:
        args.dir = EXTRACT_BATCHES / f"batch_{args.batch:03d}"
        args.out = args.out or f"batch_{args.batch:03d}.xlsx"
    elif not args.dir.is_absolute():
        args.dir = next((base / args.dir for base in (WORK, ROOT)
                         if (base / args.dir).is_dir()), ROOT / args.dir)

    papers, clean, problems, by_eye, qc = [], {t: [] for t in TABLES}, [], [], []
    scoped_out = {t: [] for t in TABLES}
    dropped = []
    in_scope = in_scope_practices()
    title_of = titles(args.dir)
    paths = sorted(args.dir.glob(f"{args.record or '*'}.json"))
    for path in paths:
        ex = json.loads(path.read_text(encoding="utf-8"))
        rid = ex["record_id"]
        title = title_of.get(rid, "")
        pdf = Pdf(PDF_DIR / f"{rid}.pdf")
        counts = {}
        paper_out = paper_out_of_scope(ex, in_scope)
        skip = set()
        for table in TABLES:
            rows = ex.get(table) or []
            counts[table] = sum(not r.get("dropped") for r in rows)
            for i, row in enumerate(rows, 1):
                row = {"record_id": rid, "title": title, "row": i, **row}
                if row.get("dropped"):
                    dropped.append({"table": table, **row})
                    skip.add((table, i))
                    continue
                if paper_out or out_of_scope(row, in_scope):
                    skip.add((table, i))
                    scoped_out[table].append(row)
                    continue
                row["check_quote"] = pdf.find_quote(row.get("quote") or "",
                                                    int(row.get("page") or 0))
                row["check_numbers"] = check_numbers(row, table)
                row["check_cell"] = check_cell(row, table)
                row["check_fields"] = check_fields(row, table,
                                                   str(ex.get("rules_version") or ""))
                if row["check_quote"] == "not_found":
                    problems.append({"table": table, **row})
                    continue
                clean[table].append(row)
                if any(row[c] not in ("ok", "n/a") for c in CHECKS[1:]):
                    problems.append({"table": table, **row})
                if row.get("extraction_method") in BY_EYE:
                    by_eye.append({"table": table, "person_value": None,
                                   "person_ok": None, **row})
        review = read_qc(args.dir / "qc" / f"{rid}.json", ex, qc, skip, title)
        papers.append({"title": title} | {k: ex.get(k) for k in PAPER_FIELDS} |
                      {f"n_{t}": counts[t] for t in TABLES} | review)

    if args.record:
        for p in problems:
            print(f"{p['table']} row {p['row']}: quote {p['check_quote']}, "
                  f"numbers {p['check_numbers']}, cell {p['check_cell']}, "
                  f"fields {p['check_fields']}")
        print(f"{sum(len(v) for v in clean.values())} rows pass, {len(problems)} problems")
        return

    wb = openpyxl.Workbook()
    wb.remove(wb.active)
    write_sheet(wb, "papers", papers, ("record_id", "title", *PAPER_FIELDS[1:]))
    for table in TABLES:
        write_sheet(wb, table, clean[table], (*FRONT, *TABLE_COLUMNS[table], *PROVENANCE),
                    CHECKS)
    ws, cols = write_sheet(wb, "to_check", by_eye,
                           ("record_id", "title", "table", "row", "person_value",
                            "person_ok", "page", "locator", "quote"), CHECKS)
    yellow = PatternFill("solid", fgColor="FFF2CC")
    for c in ("person_value", "person_ok"):
        for r in range(1, len(by_eye) + 2):
            ws.cell(r, cols.index(c) + 1).fill = yellow
    ws, cols = write_sheet(wb, "qc", qc, QC_FIELDS)
    for r in range(1, len(qc) + 2):
        ws.cell(r, cols.index("person_decision") + 1).fill = yellow
    write_sheet(wb, "problems", problems, ("record_id", "title", "table", "row", *CHECKS,
                                           *PROVENANCE))
    if dropped:
        write_sheet(wb, "dropped", dropped,
                    ("record_id", "title", "table", "row", "dropped", "outcome", "measure",
                     "treatment_name", "control_name", "value_trt", "value_con", "value",
                     "page", "quote"))
    out = args.dir / (args.out or "checked.xlsx")
    wb.save(out)
    n_out = sum(len(v) for v in scoped_out.values())
    if n_out:
        wb = openpyxl.Workbook()
        wb.remove(wb.active)
        for table in TABLES:
            write_sheet(wb, table, scoped_out[table],
                        (*FRONT, *TABLE_COLUMNS[table], *PROVENANCE))
        wb.save(out.with_name(f"{out.stem}_out_of_scope.xlsx"))

    n_rows = sum(len(v) for v in clean.values())
    n_bad = sum(1 for p in problems if p["check_quote"] == "not_found")
    n_num = sum(1 for p in problems if p["check_numbers"] not in ("ok", "n/a"))
    n_cell = sum(1 for p in problems if p["check_cell"] not in ("ok", "n/a"))
    n_field = sum(1 for p in problems if p["check_fields"] not in ("ok", "n/a"))
    print(f"{len(papers)} papers, {sum(p['decision'] == 'include' for p in papers)} included")
    print(f"{n_rows} rows kept; {n_bad} dropped (quote not found); "
          f"{n_num} with a number not in its quote or of the other sign; "
          f"{n_cell} table values not first in their cell; {n_field} with a column value "
          f"the rules do not allow; {len(by_eye)} figure or picture-table values to check")
    if n_out:
        print(f"{n_out} rows out of scope -> {out.stem}_out_of_scope.xlsx")
    if dropped:
        print(f"{len(dropped)} rows dropped at a person's check -> sheet dropped")
    print(f"second reader: {sum(1 for p in papers if p['qc_verdict'])} papers checked, "
          f"{sum(q['kind'] == 'error' for q in qc)} errors, "
          f"{sum(q['kind'] == 'query' for q in qc)} queries, "
          f"{sum(q['kind'] == 'missed' for q in qc)} missed")
    print(f"wrote {out}")


if __name__ == "__main__":
    main()
