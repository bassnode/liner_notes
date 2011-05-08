require 'lib/liner_notes'

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

  attr_accessor :cover

  def current_track
    {
      :title => ITUNES.currentTrack.name,
      :artist => ITUNES.currentTrack.artist,
      :album => ITUNES.currentTrack.album,
      :genre => ITUNES.currentTrack.genre
    }
  end

  def update_time_display(sender)
    debug "TIMER #{Time.now}"
    @title_label.text = ITUNES.currentTrack.duration - ITUNES.playerPosition
    run if song_changed?
  end

  def song_changed?
    ITUNES.playerPosition.to_i < 1
  end

  def start
    application :name => "Liner Notes" do |app|
      app.delegate = self
      window :frame => [0, 0, 1000, 1000], :style => [:titled, :closable, :miniaturizable, :resizable], :view => :nolayout, :title => "#{current_track[:artist]} - #{current_track[:title]}" do |win|

        @cover = image_view(:frame => [0,0,1000,1000])
        # win << @cover
        win.view = layout_view(:layout => {:expand => [:width, :height],:padding => 0, :margin => 0}) do |vert|
          vert << layout_view(:frame => [0, 0, 0, 40], :mode => :horizontal,:layout => {:padding => 0, :margin => 0,:start => false, :expand => [:width]}) do |horiz|
            @title_label = label(:text => "#{current_track[:artist]} - #{current_track[:title]}", :layout => {:start => false, :align => :center})
            horiz << @title_label
          end
          vert << @cover

          # vert << layout_view(:layout => {:padding => 0, :margin => 0,:start => false, :expand => [:width, :height]}) do |pic|
            # pic << @cover = web_view(:layout => {:expand =>  [:width, :height]}, :url => "http://photos4.meetupstatic.com/photos/event/a/6/d/3/global_9822707.jpeg")
          # end
          @timer = NSTimer.scheduledTimerWithTimeInterval 1,
                                                           target: self,
                                                           selector: 'update_time_display:',
                                                           userInfo: nil,
                                                           repeats: true

        end
        ITUNES.run
        run
        win.will_close { exit }
      end
    end
  end

  def run
    debug "RUUUUUUUUN"
    load_song_details
    display_liner_notes
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

    if already_have_cover?
      @cover.file = track_file_location(:cover)
      debug "HAVE COVER _ SKIPPING"
      return
    end

    artwork_url = Rovi.album_lookup_url(current_track[:artist], current_track[:album])

    DataRequest.new.get(artwork_url) do |data|
      hashed = XmlSimple.xml_in(data)
      album_id = hashed['results'][0]['data'][0]['id'][0]

      DataRequest.new.get(Rovi.image_lookup_url(album_id)) do |data|
        hashed = XmlSimple.xml_in(data)
        cover = hashed['images'][0]['front'][0]['Image'].sort_by{ |img| img['height'][0].to_i }.last

        if cover['url'][0].empty?
          debug "No cover art :("
        else
          @cover.url = cover['url'][0]
          DownloadDelegator.new(track_file_location(:cover)).get(cover['url'][0])
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
