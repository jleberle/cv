require 'rake/clean'

CLEAN.include("*.md","*.html")

desc "Build html and pdf"
task :default => [:makepdf, :makehtml, :clean, :push] 

desc "Build PDF version only"
task :makepdf do
  sh "markdown-pp cvpdf.mdpp -o cv.md"
  sh "pandoc cv.md -o ~/Website/static/uploads/cv.pdf"
end

desc "Build HTML only"
task :makehtml do
  sh "markdown-pp cvhtml.mdpp -o cv.md"
  sh "cp cv.md ~/Website/content/cv/index.md"
  sh "cd ~/Website && make deploy"
end

desc "Push to Git Repo"
task :push do
  sh "git add ."
  sh "git commit -S -m 'Updated CV'"
  sh "git push origin master"
end
