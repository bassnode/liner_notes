require 'rubygems'
require 'ruby-processing'
require 'lib/ext/string'
require 'lib/line'
require 'lib/cache'
require 'lib/itunes'
require 'lib/rovi'
require 'lib/echonest'
require 'lib/musix_match'
require 'lib/paginator'
require 'ap'
# uncomment and install ruby-debug if needed
# require 'lib/profiler'

# At least while developing
Thread.abort_on_exception = true

class LinerNotes < Processing::App
  import 'java.util.concurrent.Executors'
  include Cache

  X_SPLIT = 600
  X_MARGIN = 20
  Y_SPLIT = 300

  def setup
    size 1200, 600

    load_pixels

    # could be a newCachedThreadPool too if saves ram
    @thread_pool = Executors.newFixedThreadPool(5)

    text_align LEFT, CENTER
    @font = load_font "SansSerif-16.vlw"
    @big_font = load_font "Serif-32.vlw"
    #@font = create_font "monaco", 14
    text_font @font, 14

    Rovi.shared_secret = "7Qbqyxz8TT"
    Rovi.api_key = "cc94xnqu4u5hwfqrdeq4umte"

    @echonest    = Echonest.new
    @musix_match = MusixMatch.new
    @itunes      = ITunes.new(true)

    update_track(true)
  end

  def draw
    background 0
    fill 255
    stroke 255
    smooth

    update_track
  end

  def x(coord=0)
    coord + X_MARGIN
  end

  def update_track(force=false)
    @song = current_song

    fetch_album_details if force or song_changed?

    draw_artwork
    draw_contributors
    draw_credits
    #draw_lyrics
    draw_track_info
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

    line 0, height-30, width, height-30
    text "#{@song[:artist].titleize} - #{@song[:album].titleize}", 5, height-15
    text "#{pos[:track_location]}/#{pos[:track_duration]}", width-120, height-15
  end

  def draw_lyrics
    return unless @lyrics

    @displayed_lyrics ||= @lyrics.next
    text(@displayed_lyrics.join, X_SPLIT, Y_SPLIT)

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
    heading = @song[:title].titleize
    if @track_credits
      heading += " by " + @track_credits.first(3).join(', ')
    end

    text(heading, 10, 16)
  end

  def draw_artwork
    if @artwork
      tint(255, 128)
      image(@artwork, 0, 0, width/2, height)
      @tint_color = get(width/2, height/2)
      # Don't black out the photo
      @tint_color = 100 if @tint_color <= -16777216
      #@tint_color = get(random(0,X_SPLIT), random(0,Y_SPLIT))
    end

    if @extra_artwork
      tint(@tint_color || 255, 128) # rgb, alpha
      image(@extra_artwork, X_SPLIT, 0, width/2, height)
    end
  end

  def draw_contributors
    return unless @album_credits

    paginator = Paginator.new(@album_credits, :page => @contrib_page)

    l = Line.new(20)
    paginator.page.each do |contrib|
      text(contrib.first, 10, l.next!)
      text(contrib.last, 200, l.curr)
    end

    paginator.draw_links(X_SPLIT - 75, height-50)
  end

  # TODO Encapsulate credits in a class
  def draw_credits
    return unless @individual_credits && @individual_credits.any?

    # TODO: User-selected artist
    f = @individual_credits.keys.sort.first
    artist = @individual_credits[f]

    text_size 32
    text(artist.name, x(X_SPLIT), 20)
    text_size 14
    l = Line.new(32)

    paginator = Paginator.new(artist.formatted_credits, :page => @credit_page)

    paginator.page.each do |credit|
      if credit.is_a? String
        str = credit
      else
        performer = credit['primaryartists'].first['name']
        # Handle blank performers
        performer = performer.empty? ? "" : "#{performer} - "
        str = "\t\t#{performer}#{credit['title']} [#{credit['year']}]"
      end

      text(str, x(X_SPLIT), l.next!)
    end

    paginator.draw_links(width - 70, height-50)
  end

  def mouse_pressed
    #return unless mouse_y >= y_of_pagination
    # do something if clicked < or >
    puts mouse_x
    puts mouse_y
    puts "*"*20
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
