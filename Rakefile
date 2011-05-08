require 'rubygems'
require 'hotcocoa/application_builder'
require 'hotcocoa/standard_rake_tasks'

task :default => [:run]

desc "Boot that shit up, son"
task :console do
  console_app = File.dirname(__FILE__) + "/console_app.rb"
  exec("irb  -r lib/liner_notes --simple-prompt")
end

