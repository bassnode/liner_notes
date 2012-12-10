class ITunes

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
    "interpol,nyc,turn on the bright lights"
    "tool,Forty Six & 2,aenima"
    "pantera, walk, vulgar display of power"
    "rage against the machine, bombtrack, rage against the machine"
    "metallica, anesthesia, kill 'em all"
    execute '(artist of current track) & "," & (name of current track) & "," & (album of current track)'
  end

  def get_track_playback_position
    execute 'player position & (duration of current track)'
  end


  private

  # TODO: Look at being more defensive here, including starting
  # iTunes if not running, surfacing actual system error message, etc.
  def execute(command)
    result = %x[osascript -e 'tell application \"iTunes\" to #{command}']

    unless $?.success?
      raise "Issue running iTunes command: #{command}.  Is iTunes open?"
    end

    result
  end
end
