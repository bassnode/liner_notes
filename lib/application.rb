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
      :genre => ITUNES.currentTrack.genre,
      :year => ITUNES.currentTrack.year
    }
  end

  def update_time_display(sender)
    debug "TIMER #{Time.now}"
    @title_label.text = ITUNES.playerPosition
    run if song_changed?
  end

  def song_changed?
    ITUNES.playerPosition.to_i < 1
  end

  def start
    application :name => "Liner Notes" do |app|
      app.delegate = self
      @window = window(:frame => [0, 0, 1000, 1000], :style => [:titled, :closable, :miniaturizable, :resizable], :title => "#{current_track[:artist]} - #{current_track[:title]}") do |win|
        win.contentView.margin  = 0
        # win.view = layout_view(:layout => {:expand => [:width, :height],:padding => 0, :margin => 0}) do |vert|
        @title_label = label  :text => "#{current_track[:artist]} - #{current_track[:title]}",
                              :font => font(:name => "Arial", :size => 22),
                              :text_align => :center,
                              :layout => {:start => false, :align => :center}

        @discog = text_field :frame => [0,0,200,200],
                             :text => "DISCO",
                             :editable => false,
                             :layout => {:expand => :width, :start => true, :align => :center}

        @lyrics = text_field :frame => [0,0,200,200],
                             :text => "lyricoh",
                              :font => font(:name => "Arial", :size => 10),
                             :editable => false,
                             :layout => {:expand => :width, :start => true, :align => :center}

        @cover = image_view(:frame => [0,0,1000,700])
        win << @title_label
        win << @discog
        win << @lyrics
        win << @cover
        # if !ITUNES.currentTrack.artworks.empty?
          # @cover.data = ITUNES.currentTrack.artworks.first.data
        # end

        # vert << layout_view(:layout => {:padding => 0, :margin => 0,:start => false, :expand => [:width, :height]}) do |pic|
          # pic << @cover = web_view(:layout => {:expand =>  [:width, :height]}, :url => "http://photos4.meetupstatic.com/photos/event/a/6/d/3/global_9822707.jpeg")
        # end
        @timer = NSTimer.scheduledTimerWithTimeInterval 1,
                                                         target: self,
                                                         selector: 'update_time_display:',
                                                         userInfo: nil,
                                                         repeats: true

        # end
        ITUNES.run
        run
        win.will_close { exit }
      end
    end
  end

  def run
    debug "RUUUUUUUUN"
    load_song_details
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
    fetch_discog
    fetch_lyrics
  end

  # TODO: Implement their pixel_tracking_url thing so they don't ban me.
  def fetch_lyrics
    url = "http://api.musixmatch.com/ws/1.1/track.search?apikey=3bc1042fde1ac8c1979c400d6f921320&q_artist=#{clean_artist_name(true)}&q_track=#{clean_track_name(true)}&format=xml&page_size=1&f_has_lyrics=1"
    puts url
    DataRequest.new.get(url) do |data|
      hashed = XmlSimple.xml_in(data, 'ForceArray' => false)
      if hashed['header']['status_code'].to_i == 200
        track_id = hashed['body']['track_list']['track']['track_id']

        lyrics_url = "http://api.musixmatch.com/ws/1.1/track.lyrics.get?track_id=#{track_id}&format=xml&apikey=3bc1042fde1ac8c1979c400d6f921320"
        puts lyrics_url
        DataRequest.new.get(lyrics_url) do |data|
          hashed = XmlSimple.xml_in(data, 'ForceArray' => false)
          @lyrics.text = hashed['body']['lyrics']['lyrics_body']
        end

      end
    end
  end

  def fetch_discog
    Future.new do
      begin
        ac = AlbumCredits::Finder.new
        releases = ac.find_releases(current_track[:artist], current_track[:album])#, current_track[:year])
        sorted_releases = releases.inject([]) do |rel_array, release|
          unless (engineers = ac.engineers_for_release(release)).nil?
            rel_array << [release, engineers]
          end
          rel_array
        end.sort_by{|arr| arr.last.size}.reverse

        if sorted_releases.empty?
          debug "No engineering data :/"
          return
        end

        release, engineers = sorted_releases.shift

        str = "#{release.tracklist.size} songs"
        str << release.notes
        str << "\n"
        str << engineers.map{|engineer| "#{engineer.role} #{engineer.name}"}.join("\n")
        @discog.text = str
      rescue Exception => e
        debug "Failed at getting discog info: #{e}"
      end
    end
  end


  def clean_artist_name(use_in_url=false)
    clean_string current_track[:artist], use_in_url
  end

  def clean_track_name(use_in_url=false)
    clean_string current_track[:title], use_in_url
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

  def track_file_location(file, suffix=0)
    case file
    when :cover
      File.join(album_cache_dir, 'artwork', "cover_#{suffix}")
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

    puts artwork_url
    DataRequest.new.get(artwork_url) do |data|
      hashed = XmlSimple.xml_in(data)
      album_id = hashed['results'][0]['data'][0]['id'][0]

      debug "Found albumid #{Rovi.image_lookup_url(album_id)}"
      DataRequest.new.get(Rovi.image_lookup_url(album_id)) do |data|
        hashed = XmlSimple.xml_in(data)
        @all_covers = hashed['images'][0]['front'][0]['Image']


        @cover.url = @all_covers.sort_by{ |img| img['height'][0].to_i }.reverse.first['url'][0]
        # We can add the rotator once we have another image source.
        # Right now, Rovi just sends back 5 of the same pic in diff sizes.
        # rotator = NSTimer.scheduledTimerWithTimeInterval 2,
          # target: self,
          # selector: 'rotate_cover_image:',
          # userInfo: nil,
          # repeats: true

      end
    end
  end

  def rotate_cover_image(sender)
    @all_covers.sort_by{ |img| img['height'][0].to_i }.reverse.each_with_index do |cova, idx|
      if !cova['url'][0].empty?
        @cover.url = cova['url'][0]
        DownloadDelegator.new(track_file_location(:cover, idx)).get(cova['url'][0])
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
