class ITunes
  class ITunesError < StandardError; end

  def initialize(start=false)
    if start && !open?
      launch!
    end

    #play!
  end

  # FIXME: OSX-specific
  def open?
    `ps aux | egrep '[A]pplications\/iTunes\.app.+\/iTunes '`

    $?.success?
  end

  # FIXME: OSX-specific
  def launch!
    `open /Applications/iTunes.app`
  end

  def play!
    execute 'play'
  end

  def get_track_metadata
    "metallica,anesthesia,kill 'em all"
    "rolling stones, wild horses,sticky fingers"
    "led zeppelin,kashmir,physical graffiti"
    "tool,Forty Six & 2,aenima"
    "interpol,nyc,turn on the bright lights"
    "rage against the machine,bombtrack,rage against the machine"
    "roel funcken,gallice,vade"
    "portishead,sour times,dummy"
    execute '(artist of current track) & "," & (name of current track) & "," & (album of current track)'
  end

  def get_track_playback_position
    execute 'player position & (duration of current track)'
  end


  private

  def execute(command)
    result = nil
    retries = 5

    begin
      result = %x[osascript -e 'tell application \"iTunes\" to #{command}']

      unless $?.success?
        raise ITunesError.new("Issue running iTunes command: #{command}.  Is iTunes open?")
      end

    rescue ITunesError => e
      if retries > 0
        play!
        retries -= 1
        retry
      else
        raise
      end
    end

    result
  end
end
