require 'open-uri'
require 'rexml/document'
require 'json'

class MusicBrainz
  URL = "http://www.musicbrainz.org/ws/2"
  ART_URL = "http://coverartarchive.org/release"
  include Cache

  def cover_art(artist, title)
    if mbid = release(artist, title)
      # TODO Cache this JSON response
      if raw = Http.get("#{ART_URL}/#{mbid}")
        parsed = JSON.parse(raw)
        if parsed['images']
          image = parsed['images'].first['image']
          return fetch_cached(image) || download_and_cache(image)
        end
      end
    end
  end

  # @param [String]
  # @param [String]
  # @return [String,NilClass]
  def release(artist, title)
    xml = get("artist:#{artist} AND release:#{title}")
    ids = []
    xml.elements.each('metadata/release-list/release'){ |r| ids << r.attribute('id') }
    ids.first
  end

  def get(query, resource='release')
    final_url = "#{URL}/#{resource}?query=#{URI.encode(query)}"
    LinerNotes.logger.debug final_url
    load_xml(final_url, query, resource)
  end

  def load_xml(url, *cache_keys)
    if cached = fetch_cached(*cache_keys)
      xml = cached
    else
      xml = Http.get(url)
      cache! xml, *cache_keys
    end

    REXML::Document.new(xml)
  end

end
