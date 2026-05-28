# CV build: one source (per-section partials) -> two outputs
#   * PDF  -> Hugo page bundle resource   (content/cv/cv.pdf)
#   * Page -> Hugo page bundle markdown    (content/cv/index.md, links to the PDF)
#
# Requires: pandoc (with a LaTeX engine for PDF). markdown-pp is no longer used.

# Section partials are numbered (NN-name.md) in output order; the prefix is the
# single source of truth for ordering. This replaces the old cvpdf.mdpp master.
# To reorder or add a section, just rename/create a numbered file.
SECTIONS = Dir.glob("[0-9][0-9]-*.md").sort.join(" ")

WEBSITE = File.expand_path("~/git/website")
BUNDLE  = File.join(WEBSITE, "content", "cv")   # Hugo page bundle for the CV

desc "Build PDF + web page, push the CV source and the website outputs"
task :default => [:build, :push, :pushweb]

desc "Build both the PDF and the Hugo page"
task :build => [:pdf, :web]

desc "Build the web-optimized PDF into the Hugo page bundle"
task :pdf do
  mkdir_p BUNDLE
  raw = "cv-raw.pdf"
  opt = "cv-opt.pdf"
  begin
    sh "pandoc --metadata-file=meta.yaml #{SECTIONS} -o #{raw}"
    # Optimize for the web in two passes:
    #   1. Ghostscript subsets fonts + compresses streams (~75% smaller here).
    #   2. qpdf linearizes for Fast Web View (progressive load over HTTP).
    sh "gs -q -sDEVICE=pdfwrite -dCompatibilityLevel=1.5 -dPDFSETTINGS=/ebook " \
       "-dNOPAUSE -dBATCH -sOutputFile=#{opt} #{raw}"
    sh "qpdf --linearize #{opt} #{BUNDLE}/cv.pdf"
  ensure
    rm_f raw
    rm_f opt
  end
end

desc "Build the Hugo CV page (markdown) with a link to the PDF"
task :web do
  mkdir_p BUNDLE
  body = "cvbody.md"
  begin
    sh "pandoc #{SECTIONS} -t gfm -o #{body}"
    sh "cat webheader.md #{body} > #{BUNDLE}/index.md"
  ensure
    rm_f body
  end
end

desc "Commit and push the CV source repo"
task :push do
  sh "git add ."
  sh "git commit -S -m 'Updated CV'"
  sh "git push origin master"
end

desc "Commit and push the generated CV outputs in the website repo"
task :pushweb do
  Dir.chdir(WEBSITE) do
    sh "git add content/cv"
    # Commit only if the build produced changes; then push (no-op if up to date).
    sh "git diff --cached --quiet || git commit -S -m 'Update CV'"
    sh "git push origin main"
  end
end
