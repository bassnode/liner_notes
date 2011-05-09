require 'rubygems'
require 'hotcocoa'
require 'hotcocoa/graphics'

framework 'Foundation'
framework 'ScriptingBridge'
framework 'WebKit'

require 'lib/future'
require 'lib/data_request'
require 'lib/downloader_delegator'
require 'lib/rovi'
require 'uri'
require 'json'
require 'pp'
require 'xmlsimple'
require 'fileutils'
require 'album_credits'

class SBElementArray
  def [](value)
    self.objectWithName(value)
  end
end
