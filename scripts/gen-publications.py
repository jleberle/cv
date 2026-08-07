#!/usr/bin/env python3
# Generates 04-publications.md from the Zotero library. Tags are the only
# ontology BBT's CSL-JSON export doesn't carry, so tags come from Library.bib
# and everything else (title, journal, pages, ...) comes from Library.json --
# cross-referenced by citation-key. See cv/README.md.
import json
import re
import subprocess
import sys
import tempfile
from pathlib import Path

HOME = Path.home()
BIB = Path(sys.argv[1]) if len(sys.argv) > 1 else HOME / "Documents/Library/Library.bib"
JSON = Path(sys.argv[2]) if len(sys.argv) > 2 else HOME / "Documents/Library/Library.json"
CSL = Path(sys.argv[3]) if len(sys.argv) > 3 else HOME / "git/dotfiles/writing/pandoc/chicago-notes-bibliography-18th-edition.csl"
OUT = Path(__file__).resolve().parent.parent / "04-publications.md"

# (heading, tag) in the order they should appear in the CV.
CATEGORIES = [
    ("Books", "CV: Book"),
    ("Book Chapters", "CV: Book Chapter"),
    ("Articles", "CV: Article"),
    ("Book Reviews", "CV: Book Review"),
]

ENTRY_RE = re.compile(r"^@(\w+)\{([^,]+),", re.M)
KEYWORDS_RE = re.compile(r"keywords\s*=\s*\{([^}]*)\}")


def load_tags(bib_path):
    text = bib_path.read_text(encoding="utf-8")
    starts = [(m.start(), m.group(2).strip()) for m in ENTRY_RE.finditer(text)]
    tags_by_key = {}
    for i, (start, key) in enumerate(starts):
        end = starts[i + 1][0] if i + 1 < len(starts) else len(text)
        m = KEYWORDS_RE.search(text[start:end])
        if not m:
            continue
        tags = [t.strip().replace("\\&", "&") for t in m.group(1).split(",")]
        tags_by_key[key] = {t for t in tags if t}
    return tags_by_key


def load_items(json_path):
    items = json.load(open(json_path))
    return {i["citation-key"]: i for i in items if i.get("citation-key")}


def sort_key(item):
    try:
        year = int(item["issued"]["date-parts"][0][0])
    except (KeyError, IndexError, TypeError, ValueError):
        year = -1  # undated sorts last
    return -year


def render(item, csl_path):
    with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as f:
        json.dump([item], f)
        bib_tmp = f.name
    try:
        doc = f"---\nnocite: '@{item['citation-key']}'\n---\n"
        result = subprocess.run(
            ["pandoc", "--citeproc", "--bibliography", bib_tmp, "--csl", str(csl_path),
             "-f", "markdown", "-t", "markdown_strict"],
            input=doc, capture_output=True, text=True, check=True,
        )
    finally:
        Path(bib_tmp).unlink()
    return result.stdout.strip()


def main():
    if not BIB.exists():
        sys.exit(f"gen-publications: bibliography not found: {BIB}")
    if not JSON.exists():
        sys.exit(f"gen-publications: CSL-JSON library not found: {JSON}")
    if not CSL.exists():
        sys.exit(f"gen-publications: CSL style not found: {CSL}")

    tags_by_key = load_tags(BIB)
    items_by_key = load_items(JSON)

    sections = ["## Publications\n"]
    for heading, tag in CATEGORIES:
        keys = [k for k, tags in tags_by_key.items() if tag in tags and k in items_by_key]
        if not keys:
            continue
        keys.sort(key=lambda k: sort_key(items_by_key[k]))

        entries = []
        for k in keys:
            rendered = render(items_by_key[k], CSL)
            entries.append(f"\\hangindent=0.5in {rendered}")

        block = "\n\n".join(entries)
        sections.append(f"### {heading}\n\n::: {{.hang}}\n\n{block}\n\n:::\n")

    OUT.write_text("\n".join(sections), encoding="utf-8")
    print(f"Wrote {OUT}")


if __name__ == "__main__":
    main()
