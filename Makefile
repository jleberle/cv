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

# Remove a target if its recipe fails, so partial output never looks current.
.DELETE_ON_ERROR:
.PHONY: build pdf web publish push pushweb

# Default: build both outputs (no commit/push). Use `make publish` to ship.
build: pdf web
pdf: $(BUNDLE)/cv.pdf
web: $(BUNDLE)/index.md

# --- PDF: pandoc (LaTeX) -> ghostscript (subset + compress) -> qpdf (linearize) ---
$(BUNDLE)/cv.pdf: cv-opt.pdf | $(BUNDLE)
	qpdf --linearize $< $@

cv-opt.pdf: cv-raw.pdf
	gs -q -sDEVICE=pdfwrite -dCompatibilityLevel=1.5 -dPDFSETTINGS=/ebook \
	   -dNOPAUSE -dBATCH -sOutputFile=$@ $<

cv-raw.pdf: $(SECTIONS) meta.yaml
	pandoc --metadata-file=meta.yaml $(SECTIONS) -o $@

# Auto-deleted once the PDF is built.
.INTERMEDIATE: cv-raw.pdf cv-opt.pdf

# --- Web page: pandoc gfm body with the front matter / PDF link prepended ---
$(BUNDLE)/index.md: $(SECTIONS) webheader.md | $(BUNDLE)
	pandoc $(SECTIONS) -t gfm -o cvbody.md
	cat webheader.md cvbody.md > $@
	rm -f cvbody.md

$(BUNDLE):
	mkdir -p $@

# --- Publish ---
publish: build push pushweb

# Commit and push this source repo.
push:
	git add .
	git commit -S -m 'Updated CV'
	git push origin master

# Commit the generated outputs in the website repo (no-op if unchanged) and push.
pushweb:
	cd $(WEBSITE) && git add content/cv && \
	  { git diff --cached --quiet || git commit -S -m 'Update CV'; } && \
	  git push origin main
