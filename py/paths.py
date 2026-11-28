"""Where the Python scripts find the files that are not in git.

What it does: the run output (search, screening, the PDFs) and the
extraction batches live in the team's shared OneDrive folder, "Cost,
Adoption & Credit systematic review". Each person sets that folder's local
path as CC4A_SHARED_DIR in .Renviron, which R/00_shared/paths.R reads too.
Python does not load .Renviron, so this reads the setting from the
environment first, then from .Renviron. Unset, everything stays inside the
clone, as before.
Reads: .Renviron (CC4A_SHARED_DIR)
Writes: nothing. Imported, not run.
"""

import os
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def _setting(name: str) -> str:
    if os.environ.get(name):
        return os.environ[name]
    renviron = ROOT / ".Renviron"
    if renviron.exists():
        for line in renviron.read_text(encoding="utf-8").splitlines():
            key, sep, value = line.partition("=")
            if sep and key.strip() == name:
                return value.strip().strip("\"'")
    return ""


_shared = _setting("CC4A_SHARED_DIR")
if _shared and not Path(_shared).is_dir():
    raise SystemExit(f"CC4A_SHARED_DIR is set but the folder is not there: {_shared}. "
                     "Is OneDrive syncing it?")
WORK = Path(_shared) if _shared else ROOT

OUTPUTS = WORK / "outputs"
FULLTEXT = OUTPUTS / "04_fulltext"
PDF_DIR = FULLTEXT / "pdf"
INCLUDED = FULLTEXT / "included_records.csv"
FETCH_INDEX = FULLTEXT / "fulltext_index.csv"
# The extraction batches (py/batch.py), not in git.
EXTRACT_BATCHES = WORK / "extractions" / "fulltext"
# The pilot and the five 2022 papers stay in git.
EXTRACT_PILOT = ROOT / "extractions" / "fulltext_pilot"
EXTRACT_V02 = ROOT / "extractions" / "fulltext_v02"
