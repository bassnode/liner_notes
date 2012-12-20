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

    puts "#{s} vs #{t} Score: #{d[m-1][n-1]}"
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
      @album = best_result(json['searchResponse']['results'])
    end
  end

  # @return [Array<String>, NilClass] in format "Name - Contribution"
  def credits
    album['credits'].map do |c|
      "#{c['name']} - #{c['credit']}"
    end if album['credits']
  end

  # @return [Hash{String => MusicCredits}, NilClass] credits keyed by contributor name
  def credit_objects
    if album['credits']
      thread_pool = Executors.newFixedThreadPool(3)
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

  # @param [Hash] the results from a Rovi API search
  # @return [Hash] the result which most closely matches the
  #                original_album name.
  def best_result(results)
    scores = []
    results.each do |result|
      score = levenshtein(original_album, result['album']['title'])
      scores << [result['album'], score]
      break if score == 0 # THE BEST!
    end

    scores.sort_by(&:last).first.first
  end

end
