require 'thread'
require 'digest/md5'
require 'open-uri'
require 'json'

class Rovi
  include Cache
  import java.util.concurrent.Executors
  import java.util.concurrent.TimeUnit

  URL = "http://api.rovicorp.com"
  VERSION = 'v1'
  SEARCH_VERSION = 'v2.1'
  REQUESTS_PER_SECOND = 5

  class << self
    attr_accessor :shared_secret, :api_key, :last_request
  end

  def initialize
    @mutex = Mutex.new
  end

  def md5
    Digest::MD5.hexdigest(Rovi.api_key + Rovi.shared_secret + Time.now.to_i.to_s)
  end

  def default_opts
    {
      :apikey => Rovi.api_key,
      :sig    => md5,
      :format => 'json'
    }
  end

  def parameterize_hash(opts)
    opts.map{ |k,v| "#{k}=#{URI.escape(v)}"}.join('&')
  end

  def load_json(uri, *cache_keys)

    begin
      if cached = fetch_cached(*cache_keys)
        json = cached
      else
        throttle!
        puts uri
        json = open(uri).read
        cache! json, *cache_keys
      end

      JSON.load(json)
    rescue OpenURI::HTTPError
      puts $!.inspect
    end
  end

  # @param [String] URL resource/API endpoint
  # @param [Hash] URL parameters
  # @param [Array] cache keys
  # @return [Hash, NilClass] the parsed JSON or nil if nothing/error
  def get(resource, params, *cache_keys)
    all_opts    = params.merge(default_opts)
    opts_string = parameterize_hash(all_opts)
    json        = load_json("#{URL}/#{resource}?#{opts_string}", *cache_keys)
    update_last_request

    # Hacky due to Rovi API being inconsistent in its responses
    # http://developer.rovicorp.com/forum/read/116702
    successful = false
    begin
      if json['searchResponse']['controlSet']['code'].to_i == 200 &&
        json['searchResponse']['totalResultCounts'].to_i > 0
        successful = true
      end
    rescue
      # Other API response type
      successful = true if json && json['code'].to_i == 200
    end

    successful ? json : nil
  end

  # Rovi only allows 5 requests/sec. so ensure API
  # requests are thottled.
  def throttle!
    next_request = 1.0 / REQUESTS_PER_SECOND

    @mutex.synchronize do
      if Rovi.last_request && Time.now.to_f - Rovi.last_request.to_f < next_request
        puts "*** Sleeping to avoid Rovi throttling notifications (#{REQUESTS_PER_SECOND} req/sec)"
        sleep 0.5
      end
    end

  end

  def update_last_request
    @mutex.synchronize { Rovi.last_request = Time.now }
  end

  # The distance between 2 strings.
  # Thanks jRuby.
  #
  # @param [String]
  # @param [String]
  # @param [Fixnum] the score. lower is closer.
  def levenshtein(s, t)
    s = s.strip.downcase
    t = t.strip.downcase

    m, n = s.length, t.length

    return 0 if m == n

    d = Array.new(m) { Array.new(n) { 0 } }

    0.upto(m-1) do |i|
      d[i][0] = i
    end

    0.upto(n-1) do |j|
      d[0][j] = j
    end

    1.upto(n-1) do |j|
      1.upto(m-1) do |i|
        d[i][j] = if s[i] == t[j]
          d[i-1][j-1]
        else
          [d[i-1][j]   + 1,     # deletion
           d[i][j-1]   + 1,     # insertion
           d[i-1][j-1] + 1].min # substitution
        end
      end
    end

    puts %Q{"#{s}" vs "#{t}" Score: #{d[m-1][n-1]}}
    d[m-1][n-1]
  end

end


class MusicCredits < Rovi

  attr_accessor :credits
  attr_reader :id, :name


  # @param [String] Rovi database ID of contributor
  # @param [String] Contributor name
  def initialize(id, name)
    super()
    @id = id
    @name = name

    if result = get("data/#{VERSION}/name/musiccredits", {:nameid => @id},  @id)
      @credits = result['credits']
    end
  end

  # Add the credit role as a member of the returned array
  # for easier display, sorted by role and year.
  #
  # @param [String,NilClass] the credit to favor/place at beginning
  # @return [Array<Hash,String>] the credits
  def formatted_credits(preferred_role=nil)
    # They can come comma-separated, so take the first
    # value if possible.
    preferred_role = preferred_role.split(',').first.strip unless preferred_role.nil?

    # If there is a preferred_role, then stick all
    # of those values (up till the role changes) in a
    # separate array which will later be placed at the
    # front of the returned dataset.
    role = nil
    preferred = false
    preferred_array = []

    credits = sorted_credits.map(&:last).inject([]) do |arr, c|
      curr_role = c['credit']
      # When it changes, insert the role title as a marker.
      if role.nil? or curr_role.downcase != role.downcase
        role = curr_role
        preferred = !preferred_role.nil? && role =~ /^#{preferred_role}/i ? true : false

        if preferred
          preferred_array << curr_role
        else
          arr << curr_role
        end
      end

      if preferred
        preferred_array << c
      else
        arr << c
      end

      arr
    end

    preferred_array + credits
  end


  private

  # Sort credits by role & year.
  #
  # @return [<Array(String,Hash)>] the sort value and credit details
  def sorted_credits
    formatted = credits.map do |c|
      ["#{c['credit']}_#{c['year']}", c]
    end

    formatted.sort{ |x,y| x[0] <=> y[0] }.reverse
  end
end

class Album < Rovi

  attr_accessor :album
  attr_reader :original_artist, :original_album

  # @param [String] artist name
  # @param [String] album name
  def initialize(artist, album)
    super()
    @original_artist = artist
    @original_album = album

    params = { :query => "#{original_artist} #{original_album}".gsub(/[\(,\[].*[\),\]]/,'').strip,
               :facet => 'type',
               :size => '10',
               :include => 'album:all',
               :entitytype => 'album' }

    if json = get("search/#{SEARCH_VERSION}/music/search", params, original_artist, original_album)
      if matching_album = best_result(json['searchResponse']['results'])
        @album = matching_album
      end
    end
  end

  # Attempts to logically group the album's contributors by
  # type of contributions.
  # TODO: Make smarter.
  #
  # @return [Array<String>, NilClass] in format "Name - Contribution"
  def credits
    return unless album['credits']

    groups = {
      :artistic => /guitar|drums|vocals|bass|composer|primary artist/i,
      :technical => /engineer|producer|mixing|mastering|tracking/i
    }

    creds = album['credits'].map do |c|
      [c['name'], c['credit']]
    end.uniq

    grouped = creds.group_by do |artist, credit|
      groups.values.detect{ |regex| regex.match credit }
    end

    # artists, then engineers, then everyone else
    grouped[groups[:artistic]].to_a + grouped[groups[:technical]].to_a + grouped[nil].to_a
  end

  # @return [Hash{String => MusicCredits}, NilClass] credits keyed by contributor name
  def credit_objects
    if album['credits']
      results = {}

      album['credits'].each do |credit|
        thread_pool.submit do
          results[credit['name']] = MusicCredits.new(credit['id'], credit['name'])
        end
      end

      thread_pool.shutdown
      unless thread_pool.await_termination(1, TimeUnit::MINUTES)
        puts "Timed out trying to get all the credits :("
      end

      results
    end

  end

  # @return [Array<String>, NilClass] list of contributors for a song
  def track_credits(track)
    return unless album['tracks']

    track = album['tracks'].detect do |t|
      t['title'].downcase == track[:title].downcase
    end

    if track
      credits = []

      if track['performers']
        credits.concat track['performers'].map{ |p| p['name'] }
      end

      if track['composers']
        credits.concat track['composers'].map{ |p| p['name'] }
      end

      credits.uniq
    else
      nil
    end

  end


  # @return [String, NilClass] the 2nd largest image
  def image
    if album['images'] && album['images'].length > 0 && album['images'][0]['front']
      images = album['images'][0]['front'].sort_by{ |cover| cover['width'].to_i }
      image = images.last['url'].split('?').first

      return fetch_cached(image) || download_and_cache(image)
    end

    nil
  end

  def release_info
    if album['releases']
      album['releases'].detect{ |a| a['isMain'] }
    end
  end

  private

  def thread_pool
    @thread_pool ||= Executors.newFixedThreadPool(3)
  end

  # @param [Hash] the results from a Rovi API search
  # @return [Hash,NilClass] the album which most closely matches
  #               the original_album and original_artist name.
  def best_result(results)
    scores = []
    results.each do |result|
      score = levenshtein(original_album, result['album']['title'])
      scores << [result['album'], score]
      break if score == 0 # THE BEST!
    end

    best = scores.sort_by(&:last).first.first

    # Check artist
    artist_scores = best['primaryArtists'].map do |artist|
      levenshtein(original_artist, artist['name'])
    end

    artist_scores.min < 10 ? best : nil
  end

end
