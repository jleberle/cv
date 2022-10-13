desc "Build html and pdf"
task :default => [:makepdf, :push] 

desc "Build PDF version only"
task :makepdf do
  sh "markdown-pp cvpdf.mdpp -o cv.md"
  sh "pandoc cv.md -o ~/Git/website/static/cv.pdf"
end

desc "Push to Git Repo"
task :push do
  sh "git add ."
  sh "git commit -S -m 'Updated CV'"
  sh "git push origin master"
end
