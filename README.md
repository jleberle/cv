# CV

Source for Jared L. Eberle's curriculum vitae. One set of section partials
builds **two** outputs from a single source:

- **`cv.pdf`** — a web-optimized PDF (font-subset, compressed, linearized for
  Fast Web View).
- **A Hugo page** — the full CV rendered as a web page, with a link to the PDF.

Both outputs are written into the [website repo](https://codeberg.org/jleberle/website)
as a Hugo [page bundle](https://gohugo.io/content-management/page-bundles/) at
`content/cv/` (`index.md` + `cv.pdf`).

## Dependencies

| Tool | Role |
|------|------|
| [pandoc](https://pandoc.org/) (with a LaTeX engine, e.g. TeX Live / MacTeX) | Markdown → PDF and Markdown → GitHub-flavored Markdown |
| [Ghostscript](https://www.ghostscript.com/) (`gs`) | Subset fonts + compress the PDF |
| [qpdf](https://qpdf.sourceforge.io/) | Linearize the PDF (Fast Web View) |
| `make` (GNU Make) | Task runner |

On macOS: `brew install pandoc ghostscript qpdf` (plus a LaTeX distribution).

`make push` and `make pushweb` sign commits with GPG (`git commit -S`). A configured, available GPG key is required; without one those targets will fail.

> **Note:** this replaces the previous `markdown-pp` + `pandoc` pipeline.
> `markdown-pp` is no longer used — pandoc concatenates the section files directly.

## Source layout

```
01-header.md        Contact info (no heading; the title block lives in meta.yaml)
02-work.md          ## Academic Employment
03-education.md     ## Education
04-publications.md  ## Publications        (wrapped in ::: {.hang} for web indents)
05-conferences.md   ## Conference Papers   (wrapped in ::: {.hang} for web indents)
06-media.md         ## Media Appearances
07-teaching.md      ## Courses Taught
08-awards.md        ## Awards
09-service.md       ## Service
10-orgs.md          ## Professional Organizations
11-references.md    ## References
meta.yaml           PDF title/subtitle/author/date metadata
webheader.md        Hugo front matter + "Download the PDF" link (prepended to the web page)
Makefile            Build + publish targets
```

**Section order is determined by the numeric filename prefix.** The Makefile
builds from `$(sort $(wildcard [0-9][0-9]-*.md))`, so the filenames are the
single source of truth for ordering — there is no separate manifest to keep in
sync. Each numbered partial (except the header) opens with its own `##` heading.

`meta.yaml` and `webheader.md` have no numeric prefix, so they are deliberately
excluded from the section glob.

## Building

```sh
make check    # verify all dependencies are installed before building
make          # build both the PDF and the web page (default; no commit/push)
make pdf      # build only the PDF
make web      # build only the web page
make preview  # build both into ./preview instead of the website repo
make publish  # stamp the date, build, then commit & push BOTH repos
```

> A plain `make` writes its outputs straight into the website repo's
> `content/cv/` (uncommitted). Use `make preview` to build into a throwaway
> `./preview/` directory when you just want to inspect the result.

`make` tracks file modification times, so it only rebuilds an output when one of
its sources changes (run again with nothing changed → "Nothing to be done").
Force a full rebuild with `make -B`.

### How the build works

- **PDF (`make pdf`)**
  1. `pandoc --metadata-file=meta.yaml <sections> -o cv-raw.pdf` (via LaTeX).
  2. `gs -dPDFSETTINGS=/ebook …` subsets fonts and compresses streams (~75% smaller).
  3. `qpdf --linearize …` reorganizes for Fast Web View → `content/cv/cv.pdf`.
  - The `cv-raw.pdf`/`cv-opt.pdf` intermediates are auto-deleted; `.DELETE_ON_ERROR`
    removes a partial output if any step fails.

- **Web page (`make web`)**
  1. `pandoc <sections> -t gfm` renders the body as GitHub-flavored Markdown.
  2. `webheader.md` (front matter + PDF link) is prepended → `content/cv/index.md`.

## Adding or reordering a section

1. Create a `NN-name.md` file with a `## Heading`, numbered for its position.
2. Renumber neighbors if needed (any gap/order is fine — the glob sorts them).
3. `make` and review the outputs.

## Publishing

- `make push` commits and pushes this source repo (`master`). It skips the
  commit if nothing changed, so it won't abort on an empty commit.
- `make pushweb` commits the generated `content/cv/` outputs in the website repo
  and pushes (`main`), which triggers the website's CI to rebuild and deploy.
- `make publish` runs `update-date`, builds, and does both pushes in one step.

## Notes

- **Hanging indents:** publication and conference entries use `\hangindent` for
  the PDF. On the web both the raw LaTeX and the surrounding `::: {.hang}`
  wrapper are dropped (the web recipe strips the `<div class="hang">` … `</div>`
  lines), so those entries render as plain paragraphs with no hanging indent.
- **Reproducibility:** builds are byte-stable. `SOURCE_DATE_EPOCH` (pinned to
  the last source commit) fixes the LaTeX timestamps, Ghostscript omits its
  info dates, and qpdf writes a content-derived `/ID` — so rebuilding without
  content changes (even `make -B`) reproduces `cv.pdf` exactly, and a no-op
  `make publish` creates no website commit.
