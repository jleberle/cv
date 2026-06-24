# CV build: numbered section partials -> two outputs in the website page bundle.
#   * PDF  -> $(BUNDLE)/cv.pdf    web-optimized: font-subset, compressed, linearized
#   * Page -> $(BUNDLE)/index.md  full CV as a Hugo page, with a link to the PDF
#
# Requires: pandoc, tectonic (LaTeX engine), ghostscript (gs), qpdf, git.
# (Replaces the previous markdown-pp pipeline; pandoc concatenates the files.)

WEBSITE := $(HOME)/git/website
BUNDLE  := $(WEBSITE)/content/cv

# Section order is the numeric filename prefix; the sorted glob is the only
# manifest. To reorder or add a section, just rename/create a numbered file.
SECTIONS := $(sort $(wildcard [0-9][0-9]-*.md))
WEB_SECTIONS := $(filter-out 01-header.md,$(SECTIONS))

# Source files committed by `make push` (explicit list avoids picking up scratch files).
SOURCES := $(SECTIONS) meta.yaml template.tex webheader.md web-letterhead.md Makefile README.md LICENSE .gitignore

# Commit message for `make push`; override with: make push MSG="your message"
# Exported so the recipe reads it from the environment ($$MSG), which keeps
# quotes and apostrophes in the message intact.
MSG ?= Updated CV
export MSG

# Reproducible PDFs: tectonic stamps its timestamps from SOURCE_DATE_EPOCH
# (pinned to the last commit), gs omits its CreationDate/ModDate, and qpdf
# derives the /ID from content — so an unchanged rebuild is byte-identical.
export SOURCE_DATE_EPOCH := $(shell git log -1 --format=%ct 2>/dev/null || date +%s)

# Current season (Northern Hemisphere) from the month, for the web description.
SEASON := $(shell case $$(date +%m) in (12|01|02) echo Winter;; (03|04|05) echo Spring;; (06|07|08) echo Summer;; (09|10|11) echo Fall;; esac)

# Remove a target if its recipe fails, so partial output never looks current.
.DELETE_ON_ERROR:
# `publish` relies on prerequisite order (update-date -> build -> website -> source),
# so never run recipes in parallel.
.NOTPARALLEL:
.PHONY: build pdf web preview publish push pushweb clean update-date check

# --- Preflight: verify required tools are installed ---
check:
	@command -v pandoc   >/dev/null 2>&1 || { echo "ERROR: pandoc not found"; exit 1; }
	@command -v gs       >/dev/null 2>&1 || { echo "ERROR: ghostscript (gs) not found"; exit 1; }
	@command -v qpdf     >/dev/null 2>&1 || { echo "ERROR: qpdf not found"; exit 1; }
	@command -v git      >/dev/null 2>&1 || { echo "ERROR: git not found"; exit 1; }
	@command -v tectonic >/dev/null 2>&1 || { echo "ERROR: tectonic not found (brew install tectonic)"; exit 1; }
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
	qpdf --linearize --deterministic-id $< $@

cv-opt.pdf: cv-raw.pdf
	gs -q -sDEVICE=pdfwrite -dCompatibilityLevel=1.5 -dPDFSETTINGS=/ebook \
	   -dOmitInfoDate=true -dOmitXMP=true -dOmitID=true \
	   -dNOPAUSE -dBATCH -sOutputFile=$@ $<

cv-raw.pdf: $(SECTIONS) meta.yaml template.tex Makefile
	pandoc --strip-comments --metadata-file=meta.yaml --template=template.tex --pdf-engine=tectonic $(SECTIONS) -o $@

# Auto-deleted once the PDF is built.
.INTERMEDIATE: cv-raw.pdf cv-opt.pdf

# --- Web page: pandoc gfm body with the front matter / PDF link prepended ---
# --strip-comments keeps parked <!-- --> entries out of the generated index.md.
# The awk drops only the .hang wrapper divs (opening line + its matching close),
# so a stray </div> from any future content is left intact. cat -s then collapses
# the blank lines left where the wrappers were.
# set -o pipefail: a pandoc failure mid-pipe must fail the recipe (so
# .DELETE_ON_ERROR removes the truncated index.md) instead of being masked
# by the exit status of `cat -s`. Inline because Apple's make 3.81 ignores
# .SHELLFLAGS, the usual way to set this.
$(BUNDLE)/index.md: $(WEB_SECTIONS) webheader.md web-letterhead.md Makefile | $(BUNDLE)
	set -o pipefail; \
	{ cat webheader.md; \
	  printf '\n'; \
	  cat web-letterhead.md; \
	  printf '\n'; \
	  pandoc --strip-comments $(WEB_SECTIONS) -t gfm \
	    | awk '/^<div class="hang">$$/ {h=1; next} h && /^<\/div>$$/ {h=0; next} {print}' \
	    | sed 's|https://jaredeberle.org|[jaredeberle.org](/)|g'; \
	} | cat -s > $@

$(BUNDLE):
	mkdir -p $@

# --- Stamp today's date into meta.yaml and webheader.md ---
# Idempotent: each file is replaced only if the stamp actually changed, so a
# same-month publish doesn't touch mtimes (and thus doesn't force a rebuild).
update-date:
	sed 's/^date: .*/date: "$(shell date +"%B %Y")"/' meta.yaml > meta.yaml.tmp
	cmp -s meta.yaml.tmp meta.yaml && rm meta.yaml.tmp || mv meta.yaml.tmp meta.yaml
	sed -e 's/^date: .*/date: $(shell date +"%Y-%m-%d")/' \
	    -e 's/^description: .*/description: "$(SEASON) $(shell date +"%Y")"/' \
	    webheader.md > webheader.md.tmp
	cmp -s webheader.md.tmp webheader.md && rm webheader.md.tmp || mv webheader.md.tmp webheader.md

# --- Publish: stamp the date, rebuild, then push website before source so the
# source commit is the last thing that lands. (.NOTPARALLEL keeps this ordered.) ---
publish: update-date build pushweb push

# Commit and push this source repo. Skip the commit if nothing is staged
# (matches pushweb) so a no-op publish doesn't abort on an empty commit.
push:
	git add $(SOURCES)
	git diff --cached --quiet || git commit -S -m "$$MSG"
	git push origin main

# Commit the generated outputs in the website repo (no-op if unchanged) and push.
pushweb:
	cd $(WEBSITE) && git add content/cv && \
	  { git diff --cached --quiet || git commit -S -m 'Update CV'; } && \
	  git push origin main

# Remove intermediates and any leftover temp files from the working directory.
clean:
	rm -f cv-raw.pdf cv-opt.pdf meta.yaml.tmp webheader.md.tmp
	rm -rf preview
