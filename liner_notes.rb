require 'rubygems'
require 'ruby-processing'
require 'lib/line'
require 'lib/cache'
require 'lib/itunes'
require 'lib/rovi'
require 'lib/resolver_factory'
require 'lib/echonest'
require 'lib/musix_match'
require 'lib/paginator'
require 'ap'
require 'lib/profiler'

# TODO: How do I remove artwork when the newly-playing
# song doesn't have any, but the previous one did?

# At least while developing
Thread.abort_on_exception = true

class LinerNotes < Processing::App
  import 'java.util.concurrent.Executors'
  include Cache

  X_SPLIT = 600
  X_MARGIN = 20
  Y_SPLIT = 300
  LINES_PER_PAGE = 25

  attr_accessor :resolver

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

    @resolver    = Rovi.new
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
    text "#{@song[:artist]} - #{@song[:album]}", 5, height-15
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
    heading = %Q{"#{@song[:title]}"}
    if @track_credits
      heading += " by " + @track_credits.first(3).join(', ')
    end

    text(heading, 10, 16)
    #line(0, 24, width, 24)
  end

  def draw_artwork
    if @artwork
      tint(@tint_color || 255, 200) # rgb, alpha
      image(@artwork, 0, 0, width/2, height)
      @tint_color = get(width/2, height/2)
      #@tint_color = get(random(0,X_SPLIT), random(0,Y_SPLIT))
    end

    if @extra_artwork
      image(@extra_artwork, X_SPLIT, 0, width/2, height)
    end
  end

  def draw_contributors
    return unless @individual_credits && @individual_credits.any?

    l = Line.new(20)
    @individual_credits.keys.sort.take(LINES_PER_PAGE).each do |contrib|
      text(contrib, 10, l.next!)
    end
  end

  # TODO Refactor and encapsulate pagination in a class/lib
  def draw_credits
    return unless @individual_credits && @individual_credits.any?

    # TODO: User-selected artist
    f = @individual_credits.keys.sort.first
    artist = @individual_credits[f]

    # Sort the credits by role and year
    credits = artist.credits.map { |c| ["#{c['credit']}_#{c['year']}", c] }
    credits = credits.sort{ |x,y| x[0] <=> y[0] }.reverse

    @page ||= 0
    pages = (credits.size / LINES_PER_PAGE.to_f).ceil

    if frame_count > 1 && frame_count % 30 == 1
      @page += 1
    elsif @page == pages
      puts "STARTING PAGES OVER"
      @page = 0
    end

    offset = @page * LINES_PER_PAGE

    text_size 32
    text(artist.name, x(X_SPLIT), 20)
    text_size 14
    l = Line.new(32)

    row_count = 0
    page = credits[offset, credits.size]
    while page and page.size > 0 and row_count < LINES_PER_PAGE do
      credit = page.shift.last
      performer = credit['primaryartists'].first['name']
      role = credit['credit']
      role_line = nil

      # Don't draw this until later so as not to
      # go over the LINES_PER_PAGE limit.
      if @role.nil? or @role.downcase != role.downcase
        row_count += 1
        @role = role
        role_line = lambda { text(role, x(X_SPLIT), l.next!) }
      end

      break if row_count >= LINES_PER_PAGE

      # Handle blank performers
      performer = performer.empty? ? "" : "#{performer} - "
      str = "\t\t#{performer}#{credit['title']} [#{credit['year']}]"
      role_line.call if role_line
      text(str, x(X_SPLIT), l.next!)
      row_count += 1
    end

    paginator = Paginator.new
    paginator.draw_links
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
