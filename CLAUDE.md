# cv — session notes

Operational knowledge for working on this repo. README.md documents the build
targets and source layout; this file is the things that will bite you.

## What this repo is

Section partials → **two** outputs, both written into the website repo's page
bundle at `~/git/website/content/cv/` (`index.md` + `cv.pdf`). Remote is
`github:jleberle/cv.git`, branch `main`.

## This repo owns files in another repo

`make build` writes directly into `$(BUNDLE)` — by default
`~/git/website/content/cv/`. Both files there are **generated**. Editing
`website/content/cv/index.md` by hand looks like it works, survives a commit,
and is silently destroyed by the next `make publish`. Change the section
partials here instead.

Use `make preview` to build into `./preview` when you want to inspect output
without touching the website repo.

## `make publish` pushes two repos, in that order

`publish: update-date build pushweb push` — website first, source last, so the
source commit is the last thing that lands. `.NOTPARALLEL` exists to hold that
order; **never** add `-j` to a publish. A half-published state (source pushed
claiming a CV the website doesn't have) is the failure this ordering prevents.

Both push targets sign with GPG (`git commit -S`). No key available means
`publish` fails at the *end*, after it has already stamped dates and rebuilt.

## Section order is the filename glob — there is no manifest

`SECTIONS := $(sort $(wildcard [0-9][0-9]-*.md))`. To reorder, rename. To add a
section, create `NN-name.md`. `meta.yaml` and `webheader.md` are excluded
precisely because they carry no numeric prefix — don't "fix" that by renaming
them.

`01-header.md` is filtered out of the *web* build (`WEB_SECTIONS`) only; it
still appears in the PDF.

## Publications are generated from Zotero, and not by `build`

```bash
make publications   # rewrites 04-publications.md from ~/Documents/Library
```

Deliberately **not** a prerequisite of `build`: it depends on the Zotero
library, not on files in this repo, so making it a dependency would make the
build non-reproducible and fail on any machine without the library. It
overwrites the file wholesale — review the diff before publishing.

It reads **two** exports and cross-references them by citation key:
`Library.json` (CSL-JSON, everything except tags) and `Library.bib` (BBT, the
only export carrying tags). Tags are the ontology — items are selected by
`CV: Book` / `CV: Book Chapter` / `CV: Article` / `CV: Book Review`. A
publication that silently fails to appear is almost always missing its `CV:`
tag in Zotero, not broken here.

## The PDF is reproducible, and that is load-bearing

`SOURCE_DATE_EPOCH` is pinned to the last commit; `gs` omits dates; `qpdf`
derives the `/ID` from content. An unchanged rebuild is byte-identical, which
is what keeps `make publish` from committing a new `cv.pdf` on every run.

```bash
make verify-reproducible   # builds twice into temp dirs and cmp's the bytes
```

Anything that reintroduces a timestamp (a new pandoc filter, a different PDF
post-processor) breaks this quietly — the build still succeeds, it just starts
producing a fresh binary every time. Run the check after touching the PDF
pipeline.

## Apple make is 3.81

`.SHELLFLAGS` is ignored, which is why `$(BUNDLE)/index.md`'s recipe sets
`set -o pipefail` inline instead. Without it a pandoc failure mid-pipe is
masked by `cat -s`'s exit status and `.DELETE_ON_ERROR` never fires, leaving a
truncated `index.md` that looks current. Don't refactor that to rely on
`.SHELLFLAGS`.

## Small things

- `update-date` is idempotent by design — it rewrites `meta.yaml` /
  `webheader.md` only if the stamp actually changed, so a same-month publish
  doesn't touch mtimes and doesn't force a rebuild.
- `pandoc --strip-comments` is what keeps parked `<!-- -->` entries out of the
  generated page. Removing it publishes every commented-out line.
- The web build needs `+definition_lists`; plain gfm flattens the work and
  education entries into paragraphs and the website loses the date column.
