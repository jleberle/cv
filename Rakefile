# CV build: one source (per-section partials) -> two outputs
#   * PDF  -> Hugo page bundle resource   (content/cv/cv.pdf)
#   * Page -> Hugo page bundle markdown    (content/cv/index.md, links to the PDF)
#
# Requires: pandoc (with a LaTeX engine for PDF). markdown-pp is no longer used.

# Ordered list of section partials. This replaces the old cvpdf.mdpp master.
SECTIONS = %w[
  header.md
  work.md
  education.md
  publications.md
  conferences.md
  media.md
  teaching.md
  awards.md
  service.md
  orgs.md
  references.md
].join(" ")

WEBSITE = File.expand_path("~/git/website")
BUNDLE  = File.join(WEBSITE, "content", "cv")   # Hugo page bundle for the CV

desc "Build PDF + web page, push the CV source and the website outputs"
task :default => [:build, :push, :pushweb]

desc "Build both the PDF and the Hugo page"
task :build => [:pdf, :web]

desc "Build the PDF into the Hugo page bundle"
task :pdf do
  mkdir_p BUNDLE
  sh "pandoc --metadata-file=meta.yaml #{SECTIONS} -o #{BUNDLE}/cv.pdf"
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
