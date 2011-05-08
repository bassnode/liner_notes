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
require 'pp'
require 'xmlsimple'
require 'fileutils'

CACHE_DIR = NSHomeDirectory().stringByAppendingPathComponent(".liner_notes")
ITUNES = SBApplication.applicationWithBundleIdentifier("com.apple.itunes")
load_bridge_support_file File.expand_path(File.join(File.dirname(__FILE__), '..', 'ext', 'iTunes.bridgesupport'))

# time_left = itunes.currentTrack.duration - itunes.playerPosition
class SBElementArray
  def [](value)
    self.objectWithName(value)
  end
end


# Replace the following code with your own hotcocoa code

class Application

  include HotCocoa
  include Graphics

  def current_track
    {
      :title => ITUNES.currentTrack.name,
      :artist => ITUNES.currentTrack.artist,
      :album => ITUNES.currentTrack.album,
      :genre => ITUNES.currentTrack.genre
    }
  end

  def start
    application :name => "Liner Notes" do |app|
      app.delegate = self
      window :frame => [0, 0, 1000, 800], :view => :nolayout, :title => "#{current_track[:artist]} - #{current_track[:title]}" do |win|
        # @label = label(:text => current_track[:title], :layout => {:start => false})
        # win << @label

        win.view = layout_view(:layout => {:expand => [:width, :height],:padding => 0, :margin => 0}) do |vert|
          vert << layout_view(:frame => [0, 0, 0, 40], :mode => :horizontal,:layout => {:padding => 0, :margin => 0,:start => false, :expand => [:width]}) do |horiz|
            horiz << label(:text => "Feed", :layout => {:align => :center})
            # img = Image.new('/Users/ed/.liner_notes/au/verbs/artwork/cover.jpg')
            # canvas = Canvas.for_rendering(:size => [400,400])
            # canvas.draw(img,0,0)
            # horiz << canvas
          end

          vert << layout_view(:frame => [0, 0, 0, 0], :layout => {:expand => [:width, :height]}, :margin => 0, :spacing => 0) do |view|
            web_view = web_view(:layout => {:expand =>  [:width, :height]}, :url => "http://photos4.meetupstatic.com/photos/event/a/6/d/3/global_9822707.jpeg")
            view << web_view
          end
        end


        ITUNES.run
        load_song_details
        display_liner_notes
        win.will_close { exit }
      end
    end
  end

  def debug(obj)
    if obj.is_a?(String)
      NSLog(obj)
    else
      NSLog(obj.inspect)
    end
  end

  def load_song_details
    create_album_dir
    fetch_artwork
  end

  def display_liner_notes

  end

  def clean_artist_name(use_in_url=false)
    clean_string current_track[:artist], use_in_url
  end

  def clean_album_name(use_in_url=false)
    clean_string current_track[:album], use_in_url
  end

  def clean_string(string, use_in_url=false)
    cleaned = string.gsub(/[^\w\s]/, '')

    if use_in_url
      URI.escape(cleaned)
    else
      cleaned.gsub(/\s/, '_').downcase
    end
  end

  def album_cache_dir
    File.join(CACHE_DIR, clean_artist_name, clean_album_name)
  end

  def create_album_dir
    FileUtils.mkdir_p(File.join(album_cache_dir, 'artwork'))
    FileUtils.mkdir_p(File.join(album_cache_dir, 'lyrics'))
    FileUtils.mkdir_p(File.join(album_cache_dir, 'discographies'))
  end

  def track_file_location(file)
    case file
    when :cover
      File.join(album_cache_dir, 'artwork', 'cover')
    end
  end

  def already_have_cover?
    File.exists?(track_file_location(:cover))
  end

  def fetch_artwork
    # artwork_url = "http://ws.audioscrobbler.com/2.0/?method=album.getinfo&api_key=b25b959554ed76058ac220b7b2e0a026&autocorrect=1&artist=#{clean_artist_name(true)}&album=#{clean_album_name(true)}"
    # cover_url = hashed['album'][0]['image'].last['content']

    return if already_have_cover?

    artwork_url = Rovi.album_lookup_url(current_track[:artist], current_track[:album])
    DataRequest.new.get(artwork_url) do |data|
      hashed = XmlSimple.xml_in(data)
      if hashed['error']
        debug "LastFM artwork Fail: #{hashed}"
      else
        album_id = hashed['results'][0]['data'][0]['id'][0]
        DataRequest.new.get(Rovi.image_lookup_url(album_id)) do |data|
          hashed = XmlSimple.xml_in(data)
          cover_url = hashed['images'][0]['front'][0]['Image'].sort_by{ |img| img['height'][0].to_i }.last['url'][0]
          DownloadDelegator.new(track_file_location(:cover)).get(cover_url) unless cover_url.empty?
        end

      end
    end
  end

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
