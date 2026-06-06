# CV build: numbered section partials -> two outputs in the website page bundle.
#   * PDF  -> $(BUNDLE)/cv.pdf    web-optimized: font-subset, compressed, linearized
#   * Page -> $(BUNDLE)/index.md  full CV as a Hugo page, with a link to the PDF
#
# Requires: pandoc (+ a LaTeX engine), ghostscript (gs), qpdf, git.
# (Replaces the previous markdown-pp pipeline; pandoc concatenates the files.)

WEBSITE := $(HOME)/git/website
BUNDLE  := $(WEBSITE)/content/cv

# Section order is the numeric filename prefix; the sorted glob is the only
# manifest. To reorder or add a section, just rename/create a numbered file.
SECTIONS := $(sort $(wildcard [0-9][0-9]-*.md))

# Source files committed by `make push` (explicit list avoids picking up scratch files).
SOURCES := $(SECTIONS) meta.yaml template.tex webheader.md Makefile README.md LICENSE .gitignore

# Commit message for `make push`; override with: make push MSG="your message"
MSG ?= Updated CV

# Remove a target if its recipe fails, so partial output never looks current.
.DELETE_ON_ERROR:
# `publish` relies on prerequisite order (update-date -> build -> website -> source),
# so never run recipes in parallel.
.NOTPARALLEL:
.PHONY: build pdf web preview publish push pushweb clean update-date check

# --- Preflight: verify required tools are installed ---
check:
	@command -v pandoc  >/dev/null 2>&1 || { echo "ERROR: pandoc not found"; exit 1; }
	@command -v gs      >/dev/null 2>&1 || { echo "ERROR: ghostscript (gs) not found"; exit 1; }
	@command -v qpdf    >/dev/null 2>&1 || { echo "ERROR: qpdf not found"; exit 1; }
	@command -v git     >/dev/null 2>&1 || { echo "ERROR: git not found"; exit 1; }
	@kpsewhich tgpagella.sty >/dev/null 2>&1 || { echo "ERROR: LaTeX package tgpagella not found (install TeX Live / MacTeX)"; exit 1; }
	@echo "All dependencies found."

# Default: build both outputs (no commit/push). Use `make publish` to ship.
build: pdf web
pdf: $(BUNDLE)/cv.pdf
web: $(BUNDLE)/index.md

# Build both outputs into ./preview instead of the website repo (safe to inspect).
preview:
	$(MAKE) build BUNDLE=$(CURDIR)/preview

# --- PDF: pandoc (LaTeX) -> ghostscript (subset + compress) -> qpdf (linearize) ---
$(BUNDLE)/cv.pdf: cv-opt.pdf | $(BUNDLE)
	qpdf --linearize $< $@

cv-opt.pdf: cv-raw.pdf
	gs -q -sDEVICE=pdfwrite -dCompatibilityLevel=1.5 -dPDFSETTINGS=/ebook \
	   -dNOPAUSE -dBATCH -sOutputFile=$@ $<

cv-raw.pdf: $(SECTIONS) meta.yaml template.tex Makefile
	pandoc --metadata-file=meta.yaml --template=template.tex $(SECTIONS) -o $@

# Auto-deleted once the PDF is built.
.INTERMEDIATE: cv-raw.pdf cv-opt.pdf

# --- Web page: pandoc gfm body with the front matter / PDF link prepended ---
# The awk drops only the .hang wrapper divs (opening line + its matching close),
# so a stray </div> from any future content is left intact. cat -s then collapses
# the blank lines left where the wrappers were.
$(BUNDLE)/index.md: $(SECTIONS) webheader.md Makefile | $(BUNDLE)
	{ cat webheader.md; \
	  pandoc $(SECTIONS) -t gfm \
	    | awk '/^<div class="hang">$$/ {h=1; next} h && /^<\/div>$$/ {h=0; next} {print}'; \
	} | cat -s > $@

$(BUNDLE):
	mkdir -p $@

# --- Stamp today's date into meta.yaml and webheader.md ---
# Uses BSD sed/date (macOS). On GNU/Linux drop the '' after -i and use GNU date.
update-date:
	sed -i '' 's/^date: .*/date: "$(shell date +"%B %Y")"/' meta.yaml
	sed -i '' 's/^date: .*/date: $(shell date +"%Y-%m-%d")/' webheader.md

# --- Publish: stamp the date, rebuild, then push website before source so the
# source commit is the last thing that lands. (.NOTPARALLEL keeps this ordered.) ---
publish: update-date build pushweb push

# Commit and push this source repo. Skip the commit if nothing is staged
# (matches pushweb) so a no-op publish doesn't abort on an empty commit.
push:
	git add $(SOURCES)
	git diff --cached --quiet || git commit -S -m '$(MSG)'
	git push origin master

# Commit the generated outputs in the website repo (no-op if unchanged) and push.
pushweb:
	cd $(WEBSITE) && git add content/cv && \
	  { git diff --cached --quiet || git commit -S -m 'Update CV'; } && \
	  git push origin main

# Remove intermediates and any leftover temp files from the working directory.
clean:
	rm -f cv-raw.pdf cv-opt.pdf
	rm -rf preview
