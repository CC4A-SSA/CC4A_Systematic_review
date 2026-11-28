"""Check the review's practice codes against the practice register.

What it does: the practice register (TNC and the Alliance,
CC4A-SSA/cc4adapt) is the agreed list of practices, with IDs such as C1.1
and G1.1. catalogues/crosswalk_register.csv says which register row each of
the review's practice codes (catalogues/vocab_practices.csv) belongs to. This
fails when the two drift apart:
  - an in-scope code has no crosswalk row with a register ID
  - a crosswalk row names a code the vocabulary does not have
  - a code is in scope but its register rows are all dropped or not taken
    forward, or the other way round
  and, unless --offline, against the published register:
  - the register has a newer version than the crosswalk's register_version
  - a register practice that is agreed or proposed has no crosswalk row
  - a crosswalk row's register_status differs from the register's status
Run it before every search and every extraction batch; py/batch.py new runs
it and stops on a failure. When the register cannot be reached the online
checks are skipped with a warning.
Reads: catalogues/vocab_practices.csv
       catalogues/crosswalk_register.csv
       the register CSV and version page (REGISTER_CSV, REGISTER_PAGE)
Writes: nothing
Run with:
  uv run python py/check_register.py
  uv run python py/check_register.py --offline
"""

import argparse
import csv
import io
import re
import sys
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
VOCAB = ROOT / "catalogues" / "vocab_practices.csv"
CROSSWALK = ROOT / "catalogues" / "crosswalk_register.csv"
REGISTER_CSV = ("https://raw.githubusercontent.com/CC4A-SSA/cc4adapt/main/docs/"
                "practice_definitions/practice_definitions.csv")
REGISTER_PAGE = "https://cc4a-ssa.github.io/cc4adapt/practice_definitions/"
LIVE = ("agreed", "proposed")
GONE = ("dropped", "not taken forward")


def read(path: Path) -> list[dict]:
    with path.open(encoding="utf-8-sig", newline="") as f:
        return list(csv.DictReader(f))


def fetch(url: str) -> str:
    with urllib.request.urlopen(url, timeout=30) as r:
        return r.read().decode("utf-8-sig")


def local_problems(vocab: list[dict], cw: list[dict]) -> list[str]:
    out = []
    scope = {r["practice_code"]: r["scope"] for r in vocab}
    for code in sorted(set(r["practice_code"] for r in cw) - set(scope)):
        out.append(f"crosswalk names {code}, which is not in vocab_practices.csv")
    for code, s in scope.items():
        rows = [r for r in cw if r["practice_code"] == code]
        ids = [r for r in rows if r["register_id"]]
        if s == "in_scope" and not ids:
            out.append(f"{code} is in scope but has no register_id in the crosswalk")
        if not ids:
            continue
        live = any(r["register_status"].lower().startswith(LIVE) for r in ids)
        if s == "in_scope" and not live:
            out.append(f"{code} is in scope but its register rows are dropped or "
                       "not taken forward")
        if s != "in_scope" and live:
            out.append(f"{code} is {s} but the register has it as agreed or proposed")
    return out


def online_problems(cw: list[dict]) -> list[str]:
    out = []
    page = fetch(REGISTER_PAGE)
    latest = re.search(r'"latest":\s*"(v[\d.]+)"', page)
    versions = {r["register_version"] for r in cw}
    if latest and versions != {latest.group(1)}:
        out.append(f"register is at {latest.group(1)}; crosswalk rows are at "
                   f"{', '.join(sorted(versions))}")
    reg = list(csv.DictReader(io.StringIO(fetch(REGISTER_CSV))))
    status = {r["ID"]: r["Status"] for r in reg if "." in r["ID"]}
    mapped = {r["register_id"] for r in cw if r["register_id"]}
    for rid, s in status.items():
        if s.lower().startswith(LIVE) and rid not in mapped:
            out.append(f"register {rid} ({s}) has no review code in the crosswalk")
    for r in cw:
        rid = r["register_id"]
        if not rid:
            continue
        if rid not in status:
            # A dropped row may be taken out of the register altogether.
            if not r["register_status"].lower().startswith(GONE):
                out.append(f"{r['practice_code']}: {rid} is not in the register")
        elif status[rid] != r["register_status"]:
            out.append(f"{r['practice_code']}: crosswalk has {rid} as "
                       f"'{r['register_status']}', the register as '{status[rid]}'")
    return out


def check(offline: bool = False) -> list[str]:
    vocab, cw = read(VOCAB), read(CROSSWALK)
    problems = local_problems(vocab, cw)
    if not offline:
        try:
            problems += online_problems(cw)
        except OSError as e:
            print(f"warning: register not reached ({e}); online checks skipped",
                  file=sys.stderr)
    return problems


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--offline", action="store_true", help="skip the published register")
    args = ap.parse_args()
    problems = check(args.offline)
    for p in problems:
        print(f"FAIL: {p}")
    if problems:
        sys.exit(1)
    print("practice codes match the register")


if __name__ == "__main__":
    main()
