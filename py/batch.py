"""Batches for the full text extraction: pick them, log them, merge them.

What it does: the corpus is extracted 30 papers at a time, each batch in its
own folder with its own workbook, so a person can check one batch at a time.
  new      picks the next batch from the included records that have a PDF and
           are not in any batch yet, the outcome folders in FOLDER_ORDER
           (Costs first), shuffled within a folder with a fixed seed so a
           batch mixes practices. Writes batch_NNN/papers.csv and logs the
           papers in status.csv as "assigned". --pilot makes a batch of the
           30 pilot papers instead (they are left out of the normal batches
           until then), --size sets the batch size. It first runs
           py/check_register.py and stops if the practice codes have drifted
           from the practice register.
  update   reads a batch's extraction files into status.csv: decision,
           exclude reason, outcomes and practices found, rows per table. An
           included paper that is out of scope as a whole
           (py/check_extraction.py paper_out_of_scope) is logged as excluded,
           reason practice_out_of_scope.
           A paper whose decision changes is set to sync to Zotero again.
  qc       marks a batch as checked by a person (--by initials). Papers a
           person still has to deal with (a supplementary table to find, a
           value to settle) get a short reason in status.csv's needs_person
           column; R/04_fetch/zotero_status.R tags them "needs a person".
  scope    lists the included records not in any batch whose tagged practices
           are all out of scope in catalogues/vocab_practices.csv (scope other
           than in_scope; "none" and "other" tags do not count either way), with
           or without a PDF, in scope_excluded.csv. They are not extracted; new
           skips them and R/04_fetch/zotero_status.R moves them to the outcome
           folder's "2. Rejected". Rerun after any scope change; records that
           are back in scope drop off the list.
  merge    stacks the sheets of the checked batches' workbooks
           (batch_NNN.xlsx, as the person left them) into one workbook, with
           a batch column. --all takes unchecked batches too.
The batches, status.csv and the run output are in the shared folder
(py/paths.py, CC4A_SHARED_DIR), not in git; the pilot list is in git.
Reads: outputs/04_fulltext/included_records.csv
       outputs/04_fulltext/fulltext_index.csv
       extractions/fulltext_pilot/pilot_papers.csv
       extractions/fulltext/batch_NNN/*.json and batch_NNN.xlsx
       catalogues/vocab_practices.csv (scope)
Writes: extractions/fulltext/status.csv
        extractions/fulltext/scope_excluded.csv (scope)
        extractions/fulltext/batch_NNN/papers.csv
        extractions/fulltext/merged.xlsx (merge)
Run with:
  uv run python py/batch.py new
  uv run python py/batch.py update 1
  uv run python py/batch.py qc 1 --by NJ
  uv run python py/batch.py scope
  uv run python py/batch.py merge
"""

import argparse
import csv
import json
import random
import sys
from datetime import date

import openpyxl

from check_extraction import in_scope_practices, paper_out_of_scope
from check_register import check as check_register

from paths import EXTRACT_BATCHES, EXTRACT_PILOT, FETCH_INDEX, INCLUDED, ROOT

PILOT = EXTRACT_PILOT / "pilot_papers.csv"
DIR = EXTRACT_BATCHES
STATUS = DIR / "status.csv"
SCOPE_EXCLUDED = DIR / "scope_excluded.csv"
VOCAB = ROOT / "catalogues" / "vocab_practices.csv"

BATCH_SIZE = 30
SEED = 2026
FOLDER_ORDER = ("Costs, returns and incentives", "Multiple outcomes", "Adoption",
                "Carbon finance", "Outcome unclear")
PAPER_COLUMNS = ("record_id", "outcome_folder", "practices", "publication_year", "doi",
                 "title")
STATUS_COLUMNS = ("record_id", "batch", "outcome_folder", "status", "assigned_on",
                  "decision", "exclude_reason", "outcomes_found", "practices_confirmed",
                  "n_cost_return", "n_adoption", "n_carbon", "needs_person", "qc_by",
                  "qc_on", "zotero_synced")
SCOPE_COLUMNS = ("record_id", "outcome_folder", "practices", "has_pdf", "excluded_on",
                 "zotero_synced")
NOT_A_PRACTICE = {"none", "other", ""}


def read_csv(path):
    if not path.exists():
        return []
    with path.open(encoding="utf-8", newline="") as f:
        return list(csv.DictReader(f))


def write_csv(path, rows, columns):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, columns, extrasaction="ignore")
        w.writeheader()
        w.writerows(rows)


def batch_name(n):
    return f"batch_{int(n):03d}"


def cmd_new(args):
    problems = check_register()
    if problems:
        sys.exit("Practice codes out of step with the register "
                 "(py/check_register.py):\n  " + "\n  ".join(problems))
    status = read_csv(STATUS)
    taken = {r["record_id"] for r in status} | {r["record_id"] for r in read_csv(SCOPE_EXCLUDED)}
    pilot = {r["record_id"] for r in read_csv(PILOT)}
    with_pdf = {r["record_id"] for r in read_csv(FETCH_INDEX) if r["status"] == "ok"}
    records = [r for r in read_csv(INCLUDED)
               if r["record_id"] in with_pdf and r["record_id"] not in taken]
    if args.pilot:
        chosen = [r for r in records if r["record_id"] in pilot]
    else:
        records = [r for r in records if r["record_id"] not in pilot]
        rng = random.Random(SEED)
        chosen = []
        for folder in FOLDER_ORDER:
            group = sorted((r for r in records if r["outcome_folder"] == folder),
                           key=lambda r: r["record_id"])
            rng.shuffle(group)
            chosen += group
        chosen = chosen[:args.size]
    if not chosen:
        sys.exit("No papers left to assign.")

    n = max((int(r["batch"]) for r in status), default=0) + 1
    out = DIR / batch_name(n)
    write_csv(out / "papers.csv", chosen, PAPER_COLUMNS)
    today = date.today().isoformat()
    status += [{"record_id": r["record_id"], "batch": n, "outcome_folder": r["outcome_folder"],
                "status": "assigned", "assigned_on": today} for r in chosen]
    write_csv(STATUS, status, STATUS_COLUMNS)
    left = len(records) - len(chosen) if not args.pilot else None
    print(f"{batch_name(n)}: {len(chosen)} papers -> {out / 'papers.csv'}")
    for r in chosen:
        print(f"  {r['record_id']}  {r['outcome_folder'][:20]:20}  {r['title'][:70]}")
    if left is not None:
        print(f"{left} papers with a PDF still unassigned (pilot papers not counted)")


def cmd_update(args):
    status = read_csv(STATUS)
    folder = DIR / batch_name(args.batch)
    in_scope = in_scope_practices()
    done = 0
    for r in status:
        if int(r["batch"]) != args.batch:
            continue
        path = folder / f"{r['record_id']}.json"
        if not path.exists():
            continue
        ex = json.loads(path.read_text(encoding="utf-8"))
        before = (r.get("decision") or "", r.get("exclude_reason") or "")
        if ex.get("decision") == "include" and paper_out_of_scope(ex, in_scope):
            ex["decision"], ex["exclude_reason"] = "exclude", "practice_out_of_scope"
        r.update({
            "status": r["status"] if r["status"] == "qc_done" else "extracted",
            "decision": ex.get("decision") or "",
            "exclude_reason": ex.get("exclude_reason") or "",
            "outcomes_found": "; ".join(ex.get("outcomes_found") or []),
            "practices_confirmed": "; ".join(ex.get("practices_confirmed") or []),
            # Rows a person dropped at the check are not counted.
            **{f"n_{t}": sum(not row.get("dropped") for row in ex.get(t) or [])
               for t in ("cost_return", "adoption", "carbon")},
        })
        if before != (r["decision"], r["exclude_reason"]) and before[0]:
            r["zotero_synced"] = ""
        done += 1
    write_csv(STATUS, status, STATUS_COLUMNS)
    total = sum(int(r["batch"]) == args.batch for r in status)
    print(f"{batch_name(args.batch)}: {done} of {total} papers extracted")


def cmd_qc(args):
    status = read_csv(STATUS)
    today = date.today().isoformat()
    n = 0
    for r in status:
        if int(r["batch"]) == args.batch and r["status"] == "extracted":
            r.update(status="qc_done", qc_by=args.by, qc_on=today)
            n += 1
    write_csv(STATUS, status, STATUS_COLUMNS)
    print(f"{batch_name(args.batch)}: {n} papers marked as checked by {args.by}")


def cmd_scope(args):
    in_scope = {r["practice_code"] for r in read_csv(VOCAB) if r["scope"] == "in_scope"}
    in_batch = {r["record_id"] for r in read_csv(STATUS)}
    with_pdf = {r["record_id"] for r in read_csv(FETCH_INDEX) if r["status"] == "ok"}
    before = {r["record_id"]: r for r in read_csv(SCOPE_EXCLUDED)}
    today = date.today().isoformat()
    out = []
    for r in read_csv(INCLUDED):
        tags = {p.strip() for p in r["practices"].split(";")} - NOT_A_PRACTICE
        if r["record_id"] in in_batch or not tags or tags & in_scope:
            continue
        old = before.get(r["record_id"], {})
        out.append({"record_id": r["record_id"], "outcome_folder": r["outcome_folder"],
                    "practices": r["practices"],
                    "has_pdf": "yes" if r["record_id"] in with_pdf else "no",
                    "excluded_on": old.get("excluded_on") or today,
                    "zotero_synced": old.get("zotero_synced", "")})
    back = sorted(set(before) - {r["record_id"] for r in out})
    write_csv(SCOPE_EXCLUDED, out, SCOPE_COLUMNS)
    n_pdf = sum(r["has_pdf"] == "yes" for r in out)
    print(f"{len(out)} records out of scope ({n_pdf} with a PDF) -> {SCOPE_EXCLUDED}")
    if back:
        print(f"{len(back)} back in scope since the last run: {', '.join(back)}")


def cmd_merge(args):
    status = read_csv(STATUS)
    batches = sorted({int(r["batch"]) for r in status
                      if args.all or r["status"] == "qc_done"})
    merged = openpyxl.Workbook()
    merged.remove(merged.active)
    for n in batches:
        path = DIR / batch_name(n) / f"{batch_name(n)}.xlsx"
        if not path.exists():
            print(f"skipped {batch_name(n)}: no workbook")
            continue
        wb = openpyxl.load_workbook(path)
        for ws in wb.worksheets:
            rows = list(ws.iter_rows(values_only=True))
            if not rows:
                continue
            if ws.title not in merged.sheetnames:
                out = merged.create_sheet(ws.title)
                out.append(("batch", *rows[0]))
                out.freeze_panes = "B2"
            out = merged[ws.title]
            header = [c.value for c in out[1]][1:]
            if list(rows[0]) != header:
                sys.exit(f"{path.name} sheet {ws.title}: columns differ from earlier batches")
            for row in rows[1:]:
                out.append((batch_name(n), *row))
    target = DIR / "merged.xlsx"
    merged.save(target)
    print(f"merged {len(batches)} batches -> {target}")


def main():
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    p = sub.add_parser("new")
    p.add_argument("--size", type=int, default=BATCH_SIZE)
    p.add_argument("--pilot", action="store_true")
    p = sub.add_parser("update")
    p.add_argument("batch", type=int)
    p = sub.add_parser("qc")
    p.add_argument("batch", type=int)
    p.add_argument("--by", required=True)
    sub.add_parser("scope")
    p = sub.add_parser("merge")
    p.add_argument("--all", action="store_true")
    args = ap.parse_args()
    {"new": cmd_new, "update": cmd_update, "qc": cmd_qc, "scope": cmd_scope,
     "merge": cmd_merge}[args.cmd](args)


if __name__ == "__main__":
    main()
