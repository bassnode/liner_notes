require 'ruby-debug'
require 'jruby/profiler'

def profile(&block)
  profile_data = JRuby::Profiler.profile do
    yield
  end
  profile_printer = JRuby::Profiler::GraphProfilePrinter.new(profile_data)
  profile_printer.printProfile(STDOUT)
end

