# Ruby's built-in logger doesn't work well
# with Processing/Java(?) so there's this simple thing.
require 'singleton'

class LogFile
  include_class java.io.FileOutputStream
  include_class java.io.PrintStream

  ERROR = 1
  INFO  = 2
  DEBUG = 3

  attr_accessor :level

  include Singleton

  def initialize
    log_path = File.join(ENV['HOME'], 'Library', 'Logs', 'liner_notes.log')
    @log = PrintStream.new(FileOutputStream.new(log_path, true))
    @level = INFO
  end

  def add(msg, level=:info)
    stamp = Time.now.strftime '%Y-%m-%d %H:%M:%S'
    output = "[#{stamp}] #{msg}"
    puts output # TEMP
    @log.write "#{output}\n"
  end

  alias << add

  def error(msg)
    add(msg)
  end

  def info(msg)
    add(msg) if level >= INFO
  end

  def debug(msg)
    add(msg) if level == DEBUG
  end
end
