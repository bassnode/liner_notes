require 'rubygems'
require 'hotcocoa'
framework 'Foundation'
framework 'ScriptingBridge'
require 'lib/future'
require 'lib/data_request'
require 'uri'

ITUNES = SBApplication.applicationWithBundleIdentifier("com.apple.itunes")
load_bridge_support_file 'iTunes.bridgesupport'
# itunes.run

# time_left = itunes.currentTrack.duration - itunes.playerPosition
class SBElementArray
  def [](value)
    self.objectWithName(value)
  end
end


# Replace the following code with your own hotcocoa code

class Application

  include HotCocoa

  def current_track
    {
      :title => ITUNES.currentTrack.name,
      :artist => ITUNES.currentTrack.artist,
      :genre => ITUNES.currentTrack.genre
    }
  end

  def start
    application :name => "Mhd" do |app|
      app.delegate = self
      window :frame => [100, 100, 500, 500], :title => "#{current_track[:artist]} - #{current_track[:title]}" do |win|
        @label = label(:text => current_track[:title], :layout => {:start => false})
        win << @label
        fetch_artwork
        win.will_close { exit }
      end
    end
  end

  def fetch_artwork
    clean_artist = URI.escape(current_track[:artist])
    artwork_url = "http://ws.audioscrobbler.com/2.0/?method=artist.getimages&artist=#{clean_artist}&api_key=b25b959554ed76058ac220b7b2e0a026"
DataRequest.new("http://google.ca") do |data|
  NSLog "Data: #{data}"
end
    
    # DataRequest.new(artwork_url) do |data|
      # NSLog "Data: #{data}"
    # end
    
  end


  # Request helper setting up a connection and a delegate
  # used to monitor the transfer
  # def initiate_request(url_string, delegator)
    # url         = NSURL.URLWithString(url_string)
    # request     = NSURLRequest.requestWithURL(url)
    # NSLog("doin #{request.inspect}")
    # @connection = NSURLConnection.connectionWithRequest(request, delegate:delegator)
  # end


  # file/open
  def on_open(menu)
  end

  # file/new
  def on_new(menu)
  end

  # help menu item
  def on_help(menu)
  end

  # This is commented out, so the minimize menu item is disabled
  #def on_minimize(menu)
  #end

  # window/zoom
  def on_zoom(menu)
  end

  # window/bring_all_to_front
  def on_bring_all_to_front(menu)
  end
end

Application.new.start
