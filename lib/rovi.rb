require 'thread'
require 'digest/md5'
require 'open-uri'
require 'json'
require 'socket'

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

  def self.can_connect?
    begin
      Socket.gethostbyname URL.split('//').last
    rescue SocketError
      return false
    end

    true
  end

  def load_json(uri, *cache_keys)

    begin
      if cached = fetch_cached(*cache_keys)
        json = cached
      else
        throttle!
        LinerNotes.logger.debug uri
        json = open(uri).read
        cache! json, *cache_keys
      end

      JSON.load(json)
    rescue OpenURI::HTTPError
      LinerNotes.logger.error $!.inspect
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
        LinerNotes.logger.debug "*** Sleeping to avoid Rovi throttling notifications (#{REQUESTS_PER_SECOND} req/sec)"
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

    return 0 if s == t

    m, n = s.length, t.length

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

    LinerNotes.logger.debug %Q{"#{s}" vs "#{t}" Score: #{d[m-1][n-1]}}
    d[m-1][n-1]
  end

end
