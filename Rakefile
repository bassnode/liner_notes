require 'rubygems'

task :default => :build

desc "Clear cache and build OSX execuatable"
task :build do
  sh "rm -Rf data/cache/*"
  sh "rp5 app --jruby"
end
