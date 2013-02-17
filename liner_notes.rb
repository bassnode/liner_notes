require 'rubygems'
require 'ruby-processing'
require 'lib/log_file'
require 'lib/ext/string'
require 'lib/http'
require 'lib/line'
require 'lib/links'
require 'lib/cache'
require 'lib/itunes'
require 'lib/rovi'
require 'lib/album'
require 'lib/music_credits'
require 'lib/artist_link'
require 'lib/echonest'
require 'lib/musix_match'
require 'lib/paginator'
require 'ap'
# Uncomment if needing debugger
#require 'lib/profiler'

class LinerNotes < Processing::App
  include_class java.util.concurrent.Executors
  include Cache

  X_SPLIT = 600
  X_MARGIN = 20
  Y_SPLIT = 300

  class << self
    attr_accessor :logger
  end

  def setup
    size 1200, 600

    frame_rate 3

    load_pixels

    setup_logging

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

    @credits_paginator = Paginator.new
    @contributors_paginator = Paginator.new

    Thread.new do
      loop do
        if Http.busy?
          #fill(0)
          #background(255)
          #stroke(195, 35, 35)
          stroke_weight(1)
          msg = "Loading..."
          x = width - text_width(msg) - 8
          rect(x-7, 7, text_width(msg)+10, 20, 3, 3, 3, 3)
          text(msg, x, 16)
          sleep 0.2
        end
      end
    end

    update_track(true)
  end

  def draw
    background 0
    fill 255
    stroke 255
    smooth

    update_track

    cursor Links.hovering?(mouse_x, mouse_y) ? HAND : ARROW
  end

  def x(coord=0)
    coord + X_MARGIN
  end

  def setup_logging
    LinerNotes.logger = LogFile.instance
    LinerNotes.logger.level = LogFile::DEBUG # TODO Switch when in dev vs. app
  end

  def have_internet?
    if @connected.nil? ||                               # initial check
       @connected == false && frame_count % 30 == 0 ||  # check for recovery
       @connected && frame_count % 120 == 0             # ensure connection
      @connected = Rovi.can_connect?
    end

    @connected
  end

  def show_connection_error
    text "Cannot connect to the internet. \n Please check your connection.", X_SPLIT-100, Y_SPLIT
  end

  def update_track(force=false)

    # TODO: Don't show this if we don't currently need the
    # internet, i.e. all threads are done and we're not resetting
    #
    # FIXME: After recovering from an initial missing net conn,
    # the track doesn't update. Likely because it's missing force?
    unless have_internet? # || all_threads_done?
      show_connection_error
      return
    end

    @song = current_song

    fetch_album_details if force or song_changed?

    draw_artwork
    draw_contributors
    draw_credits
    draw_lyrics
    draw_track_info
    draw_footer
  end

  def song_changed?
    return false unless @change

    reset!
    @change = false

    true
  end

  # Draws the track position and progress bar
  def draw_footer
    pos = current_position

    complete_pixels = (width * pos[:percent_complete]).floor
    stroke_weight(5)
    line 0, height-5, complete_pixels, height-5
    text pos[:track_location], complete_pixels+10, height-10
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

    @contributors_paginator.set_content(@album_credits)

    l = Line.new(20)
    @contributors_paginator.page.each do |contrib|
      text(contrib.first, 10, l.next!)
      # Make sure the text doesn't flow over
      parts       = contrib.last.split(',')
      second_part = parts.shift
      x_start     = 200
      max_width   = X_SPLIT - x_start -2
      parts.each do |role|
        if text_width(second_part) + text_width(role) <= max_width-2
          second_part << ", #{role}"
        end
      end

      text(second_part, x_start, l.curr)

      Links.register(10, l.curr, :show, ArtistLink.new(contrib.first), :x_padding => X_SPLIT)
    end

    @contributors_paginator.draw_links(X_SPLIT - 80, height-50)
  end

  def draw_credits
    return unless @individual_credits && @individual_credits.any?

    if ArtistLink.selected
      artist = @individual_credits[ArtistLink.selected]
    else
      f = @individual_credits.keys.sort.first
      artist = @individual_credits[f]
    end

    # In the case where the HTTP requests to Rovi timeout
    # and we get incomplete data:
    if !artist
      puts "CHOSEN: #{ArtistLink.selected}"
      puts @individual_credits.keys
    end
    return unless artist

    reset_paginator = artist != @previous_artist
    @previous_artist = artist

    text_size 32
    text(artist.name, x(X_SPLIT), 20)
    text_size 14
    l = Line.new(32)

    # Try to show the artist's contribution to the current album first
    if @album_credits and credit = @album_credits.detect{ |d| d[0] =~ /#{artist.name}/i }
      album_credit = credit.last
    else
      album_credit = nil
    end

    @credits_paginator.set_content(artist.formatted_credits(album_credit), reset_paginator)

    @credits_paginator.page.each do |credit|
      if credit.is_a? String # credit name separator/heading
        str = credit
      else
        performer = credit['primaryartists'].first['name']
        # Handle blank performers
        performer = performer.empty? ? "" : "#{performer} - "
        year = credit['year'].empty? ? "" : "[#{credit['year']}]"
        str = "\t\t#{performer}#{credit['title']} #{year}"
      end

      text(str, x(X_SPLIT), l.next!)
    end

    @credits_paginator.draw_links(width - 80, height-20)
  end

  def mouse_pressed
    # handle any link clicks
    Links.click(mouse_x, mouse_y)
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
     :track_duration => formatted_track_location(pieces[1]),
     :percent_complete => pieces[0].to_f / pieces[1].to_f
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

    #@thread_pool.submit do
      #if lyrics = @musix_match.lyrics(@song[:artist], @song[:title])
        ## Create an Enumerator that we'll step through later
        #@lyrics = lyrics.lines.each_slice(LINES_PER_PANEL)
      #end
    #end
  end

  # Sets all cached vars to nil
  def reset!
    LinerNotes.logger.debug "--- RESETTING ---"
    @track_credits = nil
    @album_credits = nil
    @individual_credits = nil
    @artwork = nil
    @extra_artwork = nil
    @lyrics = nil
    @displayed_lyrics = nil
    Links.reset!
    ArtistLink.reset!
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
