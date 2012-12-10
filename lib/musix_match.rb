require 'open-uri'
require 'json'

class MusixMatch

  include Cache

  URL = "http://api.musixmatch.com/ws/1.1"

  def initialize(api_key='3bc1042fde1ac8c1979c400d6f921320')
    @api_key = api_key
  end

  def lyrics(artist, track)
    query = "q_artist=#{URI.encode(artist)}&q_track=#{URI.encode(track)}"
    json = get('track.search', query)

    if json['track_list'][0]
      track_id = json['track_list'][0]['track']['track_id']
      json = get('track.lyrics.get', "track_id=#{track_id}")

      # Sometimes the request is successful, but the lyrics are empty
      if json && json['lyrics']['lyrics_body'].to_s.strip.length > 0
        json['lyrics']['lyrics_body']
      end
    else
      puts "No tracks returned from MusixMatch"
    end
  end

  def get(resource, query)
    url = "#{URL}/#{resource}?apikey=#{@api_key}&format=json&#{query}"
    key = "#{resource}-#{query}"

    if cached = fetch_cached(key)
      json = JSON.parse(cached)
      return json['message']['body']
    end

    puts url
    raw = open(url).read
    json = JSON.parse(raw)

    if json['message']['header']['status_code'].to_i == 200
      cache!(raw, key)
      json['message']['body']
    else
      puts "MusixMatch: #{json['message']['header']['status_code']} error for #{query}"
      puts json['message']['body']
    end
  end
end
