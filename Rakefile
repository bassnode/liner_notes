require 'rubygems'

task :default => :build

desc "Clear cache and build OSX execuatable"
task :build => :clear_cache do
  sh "rp5 app"
end

task :clear_cache do
  sh "rm -Rf data/cache/*"
end

task :credits do
  # Otherwise code will whine:
  class LinerNotes
    def self.logger
      LogFile.instance
    end
  end

  require 'lib/cache'
  require 'lib/http'
  require 'lib/log_file'
  require 'lib/rovi'
  require 'lib/album'

  album = Album.new(ENV['ARTIST'], ENV['ALBUM'])
  if album.success?
    album.credits.each do |artist, role|
      puts "%-40s %20s" % [role[0..39], artist]
    end
  end
end
