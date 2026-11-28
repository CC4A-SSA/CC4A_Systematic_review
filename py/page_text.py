"""Print the text of PDF pages, so quotes are copied from it, never retyped.

Pages count from 1 at the first page of the file, as the extraction rules do.
Run with:
  uv run python py/page_text.py W123 5        one page
  uv run python py/page_text.py W123 5-7      a range
  uv run python py/page_text.py W123 all      every page
Reads: outputs/04_fulltext/pdf/<record_id>.pdf, in the shared folder when
       CC4A_SHARED_DIR is set (py/paths.py)
"""

import sys
import pymupdf

from paths import PDF_DIR


def main():
    record_id, which = sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else "all"
    sys.stdout.reconfigure(encoding="utf-8")
    with pymupdf.open(PDF_DIR / f"{record_id}.pdf") as doc:
        if which == "all":
            pages = range(1, doc.page_count + 1)
        elif "-" in which:
            a, b = map(int, which.split("-"))
            pages = range(a, b + 1)
        else:
            pages = [int(which)]
        for p in pages:
            print(f"\n===== page {p} of {doc.page_count} =====\n")
            print(doc[p - 1].get_text())


if __name__ == "__main__":
    main()
