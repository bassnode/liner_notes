# TODO
#  * Need to do more pruning of song/album/title names before searching
#    remote APIs or else you get shite results :/
#  * Handle inconsistent network/remote services
#  *
#
require 'lib/liner_notes'

CACHE_DIR = NSHomeDirectory().stringByAppendingPathComponent(".liner_notes")
ITUNES = SBApplication.applicationWithBundleIdentifier("com.apple.itunes")
load_bridge_support_file File.expand_path(File.join(File.dirname(__FILE__), '..', 'ext', 'iTunes.bridgesupport'))
# time_left = itunes.currentTrack.duration - itunes.playerPosition

class LinerNotes

  include HotCocoa
  include Graphics

  attr_accessor :cover

  def current_track
    {
      :title  => ITUNES.currentTrack.name,
      :artist => ITUNES.currentTrack.artist,
      :album  => ITUNES.currentTrack.album,
      :genre  => ITUNES.currentTrack.genre,
      :year   => ITUNES.currentTrack.year
    }
  end

  def update_time_display(sender)
    debug "TIMER #{Time.now}"
    # @title_label.text = ITUNES.playerPosition
    run if song_changed?
  end

  def song_changed?
    ITUNES.playerPosition.to_i < 1
    # if ITUNES.playerPosition.to_i < 1 && !@song_changed
      # @song_changed = Time.now.to_i
    # end
  end

  def start
    application :name => "Liner Notes" do |app|
      app.delegate = self
      @window = window(:frame => [0, 0, 1000, 1000], :style => [:titled, :closable, :miniaturizable, :resizable], :title => "#{current_track[:artist]} - #{current_track[:title]}") do |win|
        win.contentView.margin  = 0

        # @title_label = label  :text => "#{current_track[:artist]} - #{current_track[:title]}",
                              # :font => font(:name => "Arial", :size => 22),
                              # :text_align => :center,
                              # :layout => {:start => false, :align => :center}

        @discog = text_field :frame => [0,0,200,200],
                             :text => "DISCO",
                             :editable => false,
                             :layout => {:expand => :width, :start => true, :align => :center}

          @lyrics = text_field( :frame => [0,0,200,200],
                               :text => "lyricoh",
                               # :font => font(:name => "Arial", :size => 10),
                               :editable => false,
                               :layout => {:expand => :width, :start => true, :align => :center})


        @cover = image_view(:frame => [0,0,1000,700])
        # win << @title_label
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
        ITUNES.run unless ITUNES.running?
        run
        win.will_close { exit }
      end
    end
  end

  def run
    debug "WINNNNINNNGG!"
    load_song_details if playing?
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
    fetch_lyrics
    # fetch_discog
  end

  # TODO: Implement their pixel_tracking_url thing so they don't ban me.
  def fetch_lyrics
    @lyrics.text = ''
    url = "http://api.musixmatch.com/ws/1.1/track.search?apikey=3bc1042fde1ac8c1979c400d6f921320&q_artist=#{clean_artist_name(true)}&q_track=#{clean_track_name(true)}&format=json&page_size=1&f_has_lyrics=1"
    puts url
    DataRequest.new.get(url) do |data|
      hashed = JSON.parse(data)
      if hashed['message']['header']['status_code'].to_i == 200 &&
         hashed['message']['body']['track_list'][0]
        track_id = hashed['message']['body']['track_list'][0]['track']['track_id']

        lyrics_url = "http://api.musixmatch.com/ws/1.1/track.lyrics.get?track_id=#{track_id}&format=json&apikey=3bc1042fde1ac8c1979c400d6f921320"
        puts lyrics_url
        DataRequest.new.get(lyrics_url) do |data|
          hashed = JSON.parse(data)
          @lyrics.text = hashed['message']['body']['lyrics']['lyrics_body']
        end

      end
    end
  end

  # XXX This is slow and for now has been replaced by fetch_artwork (Ruvi)
  def fetch_discog
    begin
      ac = AlbumCredits::Finder.new
      releases = ac.find_releases(current_track[:artist], current_track[:album])#, current_track[:year])
      sorted_releases = releases.inject([]) do |rel_array, release|
        engineers = ac.engineers_for_release(release) || []
        rel_array << [release, engineers]
        rel_array
      end.sort_by{|arr| arr.last.size}.reverse

      if sorted_releases.empty?
        debug "No release data"
      else
        release, engineers = sorted_releases.shift
        # debug releases
        # puts "-------------------------------------------"
        # debug engineers

        str = ''#release.inspect
        str << engineers.map{|engineer| "#{engineer.role} #{engineer.name}"}.join("\n")
        str << "\n"
        str << release.notes unless release.notes.nil?
        @discog.text = str
      end
    rescue Exception => e
      debug "Failed at getting discog info: #{e}"
      puts e.backtrace.join("\n")
    end
  end

  # This is ridiculous.
  # I'm making 3 calls to Rovi because either their responses are formatted
  # weirdly or both JSON and XmlSimple flatten out collections in MacRuby..???
  def fetch_artwork
    @discog.text = ''

    @cover.file = File.expand_path(File.join(File.dirname(__FILE__), "..", "resources", "loading.gif"))
    # NOOP ATM - not saving imgs
    if already_have_cover?
      @cover.file = track_file_location(:cover)
      debug "HAVE COVER _ SKIPPING"
      return
    end

    artwork_url = Rovi.album_lookup_url(current_track[:artist], clean_album_name)

    puts artwork_url
    DataRequest.new.get(artwork_url) do |data|
      hashed = JSON.parse(data)
      if hashed['searchResponse']['controlSet']['code'].to_i == 200
        album_id = hashed['searchResponse']['results'][0]['id']
        credits_url = Rovi.prepare_url(hashed['searchResponse']['results'][0]['album']['creditsUri'])
        @cover.url = hashed['searchResponse']['results'][0]['album']['images'][0]['front']['Image']['url']

        # puts credits_url
        DataRequest.new.get(credits_url) do |data|
          hashed = JSON.parse(data)
          creds = hashed['credits'].inject([]) do |creds, c|
            creds << "#{c['name']} - #{c['credit']}"
          end
          @discog.text = creds.join("\n")
        end
      end
    end
  end

  def clean_artist_name(use_in_url=false)
    clean_string current_track[:artist], use_in_url
  end

  def clean_track_name(use_in_url=false)
    clean_string current_track[:title].gsub(/\(.+\)/, ''), use_in_url
  end

  def clean_album_name(use_in_url=false)
    clean_string current_track[:album].gsub(/(\sLP|EP|CD\d*\s*)$/,''), use_in_url
  end

  def clean_string(string, use_in_url=false)
    cleaned = string.gsub(/[^\w\s]/, '')

    if use_in_url
      URI.escape(cleaned)
    else
      cleaned
    end
  end

  def playing?
    ITUNES.running? && !current_track[:title].nil?
  end

  def album_cache_dir
    File.join(CACHE_DIR, clean_artist_name.gsub(/\s/, '_').downcase, clean_album_name.gsub(/\s/, '_').downcase)
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

LinerNotes.new.start
