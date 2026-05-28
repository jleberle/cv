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
| `rake` | Task runner |

On macOS: `brew install pandoc ghostscript qpdf` (plus a LaTeX distribution).

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
meta.yaml           PDF title/author/date metadata
webheader.md        Hugo front matter + "Download the PDF" link (prepended to the web page)
Rakefile            Build + publish tasks
```

**Section order is determined by the numeric filename prefix.** The Rakefile
builds from `Dir.glob("[0-9][0-9]-*.md").sort`, so the filenames are the single
source of truth for ordering — there is no separate manifest to keep in sync.
Each numbered partial (except the header) opens with its own `##` heading.

`meta.yaml` and `webheader.md` have no numeric prefix, so they are deliberately
excluded from the section glob.

## Building

```sh
rake build    # build both the PDF and the web page (no commit/push)
rake pdf      # build only the PDF
rake web      # build only the web page
rake          # build, then commit & push BOTH repos (default task)
```

### How the build works

- **PDF (`rake pdf`)**
  1. `pandoc --metadata-file=meta.yaml <sections> -o cv-raw.pdf` (via LaTeX).
  2. `gs -dPDFSETTINGS=/ebook …` subsets fonts and compresses streams (~75% smaller).
  3. `qpdf --linearize …` reorganizes for Fast Web View → `content/cv/cv.pdf`.
  - Intermediate files are removed even if a step fails.

- **Web page (`rake web`)**
  1. `pandoc <sections> -t gfm` renders the body as GitHub-flavored Markdown.
  2. `webheader.md` (front matter + PDF link) is prepended → `content/cv/index.md`.

## Adding or reordering a section

1. Create a `NN-name.md` file with a `## Heading`, numbered for its position.
2. Renumber neighbors if needed (any gap/order is fine — the glob sorts them).
3. `rake build` and review the outputs.

## Publishing

- `rake push` commits and pushes this source repo (`master`).
- `rake pushweb` commits the generated `content/cv/` outputs in the website repo
  and pushes (`main`), which triggers the website's CI to rebuild and deploy.
- `rake` (default) does build + both pushes in one step.

## Notes

- **Hanging indents:** publication and conference entries use `\hangindent` for
  the PDF. On the web that raw LaTeX is dropped; instead those sections are
  wrapped in a `::: {.hang}` div and styled by `assets/css/extended/cv.css` in
  the website repo (which is why the site enables `markup.goldmark.renderer.unsafe`).
- **Reproducibility:** LaTeX embeds a build timestamp, so each `rake build`
  produces a byte-different `cv.pdf` even with no content change. `rake pushweb`
  handles this fine (it commits whatever changed).
