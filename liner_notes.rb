require 'rubygems'
require 'ruby-processing'
require 'lib/line'
require 'lib/cache'
require 'lib/itunes'
require 'lib/rovi'
require 'lib/resolver_factory'
require 'lib/echonest'
require 'lib/musix_match'
require 'ap'
require 'lib/profiler'

# TODO: How do I remove artwork when the newly-playing
# song doesn't have any, but the previous one did?

# At least while developing
Thread.abort_on_exception = true

class LinerNotes < Processing::App
  # XXX This requires Processing 2 (or at least a newer version than is included
  # in ruby-processing by default).  Custom gem, or pull request?
  #load_library 'controlP5'
  #import 'controlP5'
  import 'java.util.concurrent.Executors'
  include Cache

  X_SPLIT = 500
  X_MARGIN = 5
  Y_SPLIT = 500
  # how many lines of text can fit in a quadrant?
  LINES_PER_PANEL = 25

  attr_accessor :resolver

  def setup
    frame_rate 10
    size 1000, 900

    # could be a newCachedThreadPool too if saves ram
    @thread_pool = Executors.newFixedThreadPool(5)

    @font = load_font "SansSerif-16.vlw"
    #@font = create_font "monaco", 14
    text_font @font, 12

    Rovi.shared_secret = "7Qbqyxz8TT"
    Rovi.api_key = "cc94xnqu4u5hwfqrdeq4umte"

    @resolver    = Rovi.new
    @echonest    = Echonest.new
    @musix_match = MusixMatch.new
    @itunes      = ITunes.new(true)

    #@cp = ControlP5.new(self)
    #@lyric_area = @cp.addTextarea("lyrics").
                      #setPosition(x, 25).
                      #setSize(X_SPLIT-X_MARGIN, 450).
                      #setLineHeight(14).
                      #setColor(color(255)).
                      #setFont(@font)
                      ##setColorBackground(color(255, 128)).
                      ##setColorForeground(color(255, 100,0))

    #@credits_area = @cp.addTextarea("credits").
                      #setPosition(X_SPLIT-X_MARGIN, Y_SPLIT).
                      #setSize(500, 325).
                      #setLineHeight(14).
                      #setColor(color(255)).
                      #setFont(@font)

    update_track(true)
  end

  def draw
    background 0
    fill 255
    stroke 255
    smooth

    update_track
  end

  def x(coord=X_SPLIT)
    coord + X_MARGIN
  end

  def update_track(force=false)
    @song = current_song

    fetch_album_details if force or song_changed?

    draw_credits
    draw_artwork
    draw_track_info
    draw_lyrics
    draw_footer
  end

  def song_changed?
    return false unless @change

    reset!
    @change = false

    true
  end

  def draw_footer
    pos = current_position

    line 0, height-70, width, height-70
    text "#{@song[:artist]} - #{@song[:album]}", 5, height-50
    text "#{pos[:track_location]}/#{pos[:track_duration]}", width-120, height-50
  end

  def draw_lyrics
    return unless @lyrics

    @displayed_lyrics ||= @lyrics.next
    text(@displayed_lyrics.join, x, 40)

    if frame_count > 1 && frame_count % 60 == 1
      begin
        @displayed_lyrics = @lyrics.next
      rescue StopIteration
        @lyrics.rewind
      end
    end

    #@lyric_area.setText(@lyrics.gsub("\r", "")) if @lyrics
  end

  # Draws track name with credits
  def draw_track_info
    heading = %Q{"#{@song[:title]}"}
    if @track_credits
      heading += " by " + @track_credits.first(3).join(', ')
    end

    text(heading, x, 16)
    line(X_SPLIT, 24, width, 24)
  end

  def draw_artwork
    if @artwork
      tint(255, 255)
      image(@artwork, 0, 0, 500, 500)
    end

    if @extra_artwork
      tint(255, 100)
      image(@extra_artwork, X_SPLIT, 0, 500, 500)
    end
  end

  def draw_credits
    if @album_credits
      l = Line.new(Y_SPLIT)
      @album_credits.each_with_index do |credit, idx|
        text(credit, 5, l.next!)
      end

      if @individual_credits
        f = @individual_credits.keys[3]
        artist = @individual_credits[f]
        l = Line.new(Y_SPLIT)
        credits_by_role = artist.credits.group_by{ |c| c['credit'] }

        text(artist.name, x, l.next!)
        credits_by_role.each do |role, credits|
          text(role, x, l.next!)

          credits.sort_by{ |c| c['year'].to_i }.reverse.each do |credit|
            artist = credit['primaryartists'].first['name']
            # Handle blank artists
            artist = artist.empty? ? "" : "#{artist} - "
            str = "\t\t#{artist}#{credit['title']} [#{credit['year']}]"
            text(str, x, l.next!)
          end
        end
      end
    end
  end

  # @return [Hash]
  def current_song
    song_details = @itunes.get_track_metadata
    artist, title, album = song_details.split(',').map(&:chomp)

    if @song &&
        (@song[:artist] != artist ||
         @song[:title] != title)
      @change = true
    end

    Hash[[:artist, :title, :album].zip([artist, title, album])]
  end

  # @return [Hash]
  def current_position
    position = @itunes.get_track_playback_position
    pieces = position.split(',').map(&:chomp)

    {
     :track_location => formatted_track_location(pieces[0]),
     :track_duration => formatted_track_location(pieces[1])
    }
  end

  def fetch_album_details
    @thread_pool.submit do
      if extra_images = @echonest.images(@song[:artist])
        art = extra_images.shuffle.first
        local_img = download_and_cache(art)
        @extra_artwork = load_image(local_img)
      end
    end

    @thread_pool.submit do
      if album = Album.new(@song[:artist], @song[:album])
        @album_credits = album.credits
        @individual_credits = album.credit_objects
        @track_credits = album.track_credits(@song)
        if image = album.image
          @artwork = load_image(image)
        end
      end
    end

    @thread_pool.submit do
      if lyrics = @musix_match.lyrics(@song[:artist], @song[:title])
        # Create an Enumerator that we'll step through later
        @lyrics = lyrics.lines.each_slice(LINES_PER_PANEL)
      end
    end

  end

  # Sets all cached vars to nil
  # and clears out text areas.
  def reset!
    puts "--- RESETTING ---"
    @track_credits = nil
    @album_credits = nil
    @individual_credits = nil
    @artwork = nil
    @extra_artwork = nil
    @lyrics = nil
    @displayed_lyrics = nil
    #@lyric_area.setText('')
    #@credits_area.setText('')
  end

  def formatted_track_location(pos)
    frac = (pos.to_i)/(60.to_f)
    min  = frac.to_i
    sec  = ((frac - min)*60).ceil
    min = min.to_s
    sec = sec.to_s
    min = ' ' + min if min.size == 1
    sec = '0' + sec if sec.size == 1
    "#{min}:#{sec}"
  end

end

LinerNotes.new :title => "Liner Notes"
