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
the problems sheet. Figure values are listed for a person to check.
Reads: extractions/<round>/<record_id>.json
       outputs/04_fulltext/pdf/<record_id>.pdf
Writes: extractions/<round>/checked.xlsx   papers, cost_return, adoption,
          carbon, to_check (figure and picture-table values), problems
Run with:
  uv run python py/check_extraction.py --dir extractions/fulltext_v02
  uv run python py/check_extraction.py --dir extractions/fulltext_v02 --record 6134332
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

ROOT = Path(__file__).resolve().parents[1]
PDF_DIR = ROOT / "outputs" / "04_fulltext" / "pdf"
DEFAULT_DIR = ROOT / "extractions" / "fulltext_pilot"
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
             "riparian_buffers", "multistrata_shade_trees", "crop_livestock_integration",
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
    "flag": {"", "paper_inconsistent", "table_image", "paper_inconsistent; table_image"},
} | {c: {"Yes", "No", "NA", ""} for c in COST_ITEMS}
# 2019 · 2019.1 · 2019..2020 · 2019.1..2019.2 · Y3 · Y1..Y20 · empty
YEAR = re.compile(r"(\d{4}(\.\d)?(\.\.\d{4}(\.\d)?)?|Y\d+(\.\.Y\d+)?)?")
# Column order of the cost_return sheet, as in the rules.
COST_COLUMNS = ("outcome", "label_in_paper", "outcome_formula", "outcome_unit",
                "is_incremental", "exchange_rate", "practice", *PRACTICES, "other_practices",
                "comparator_matches_vocab", "product", "product_con", "treatment_name",
                "control_name", "replicates", "animals_per_rep", "country", "site",
                "value_trt", "value_con", "value_trt_error", "value_con_error", "error_type",
                "measurement_year", "scenario", "discount_rate", "discount_period",
                "budget_type", "labour_valued", "costs_unknown", *COST_ITEMS, "other_costs",
                "flag")

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


def write_sheet(wb, name: str, rows: list[dict], first: tuple = ()):
    ws = wb.create_sheet(name)
    cols = list(first) + sorted({k for r in rows for k in r} - set(first))
    ws.append(cols)
    for c in ws[1]:
        c.font = Font(bold=True)
    for r in rows:
        ws.append([cell(r.get(c)) for c in cols])
    ws.freeze_panes = "B2"
    return ws, cols


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dir", type=Path, default=DEFAULT_DIR)
    ap.add_argument("--record", help="check one paper only and print its problems")
    ap.add_argument("--out", help="workbook name in --dir (default checked.xlsx), e.g. when "
                                  "checked.xlsx is open in Excel")
    args = ap.parse_args()

    papers, clean, problems, by_eye = [], {t: [] for t in TABLES}, [], []
    paths = sorted(args.dir.glob(f"{args.record or '*'}.json"))
    for path in paths:
        ex = json.loads(path.read_text(encoding="utf-8"))
        rid = ex["record_id"]
        pdf = Pdf(PDF_DIR / f"{rid}.pdf")
        counts = {}
        for table in TABLES:
            rows = ex.get(table) or []
            counts[table] = len(rows)
            for i, row in enumerate(rows, 1):
                row = {"record_id": rid, "row": i, **row}
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
        papers.append({k: ex.get(k) for k in PAPER_FIELDS} |
                      {f"n_{t}": counts[t] for t in TABLES})

    if args.record:
        for p in problems:
            print(f"{p['table']} row {p['row']}: quote {p['check_quote']}, "
                  f"numbers {p['check_numbers']}, cell {p['check_cell']}, "
                  f"fields {p['check_fields']}")
        print(f"{sum(len(v) for v in clean.values())} rows pass, {len(problems)} problems")
        return

    wb = openpyxl.Workbook()
    wb.remove(wb.active)
    write_sheet(wb, "papers", papers, PAPER_FIELDS)
    for table in TABLES:
        first = ("record_id", "row", *CHECKS, *PROVENANCE)
        if table == "cost_return":
            first += COST_COLUMNS
        write_sheet(wb, table, clean[table], first)
    ws, cols = write_sheet(wb, "to_check", by_eye,
                           ("record_id", "table", "row", "person_value", "person_ok",
                            "page", "locator", "quote"))
    yellow = PatternFill("solid", fgColor="FFF2CC")
    for c in ("person_value", "person_ok"):
        for r in range(1, len(by_eye) + 2):
            ws.cell(r, cols.index(c) + 1).fill = yellow
    write_sheet(wb, "problems", problems, ("record_id", "table", "row", *CHECKS,
                                           *PROVENANCE))
    out = args.dir / (args.out or "checked.xlsx")
    wb.save(out)

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
    print(f"wrote {out}")


if __name__ == "__main__":
    main()
