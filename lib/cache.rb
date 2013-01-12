module Cache

  CACHE_DIR = 'data/cache'

  # @param [String] the data or resource to cache
  # @param [Array<String>] the splatted array to use as cache keys
  # @return [String] either the file path to the resource (image)
  #                  or the data itself (JSON)
  def cache!(data, *keys)
    key = cache_key(*keys)
    local_cache = File.join(CACHE_DIR, key)

    File.open(local_cache, 'w+') do |f|
      f.write(data)
    end

    image_key?(key) ? local_cache : data
  end

  def image_key?(key)
    key =~ /\w+\.\w+/
  end

  def cached?(*keys)
    key = cache_key(*keys)
    local_cache = File.join(CACHE_DIR, key)

    File.exist?(local_cache)
  end

  # @param [Array<String>] the splatted array to use as cache keys
  # @return [NilClass, String] either the cached item, i.e.
  #                            file path to the resource (image) data (JSON)
  #                            or nil if it's not cached.
  def fetch_cached(*keys)
    key = cache_key(*keys)
    local_cache = File.join(CACHE_DIR, key)

    if cached?(*keys)
      LinerNotes.logger.debug "Cache hit for #{key}"
      if image_key? key
        # image file
        local_cache
      else
        # JSON, etc.
        File.read(local_cache)
      end
    else
      nil
    end
  end

  # Downloads the uri local, treating it like a file
  # instead of a JSON response.
  #
  # @param [String] URI of resource (image, xml, etc.)
  # @return [String] file path to resource @see #fetch_cached and #cache!
  def download_and_cache(uri)
    uri = add_protocol(uri)
    key = cache_key(uri)

    if data = fetch_cached(uri)
      data
    else
      LinerNotes.logger.debug "Downloading and caching #{uri} KEY: #{key}"
      cache!(open(uri).read, uri)
    end
  end


  # Returns either the file path (in the case of images) or
  # the a MD5 of the cache keys (everything else).
  #
  # @param [Array<String>] the splatted array to use as cache keys
  # @return [String] the cache key identifier
  def cache_key(*keys)
    if keys.size == 1 and keys.first =~ /^http/
      url_pieces = keys.first.split('/')
      keys = [url_pieces[2], *url_pieces.last(2)]
      keys.join('-')
    else
      Digest::MD5.hexdigest(keys.sort.join)
    end
  end

  # Prefixs uri with http:// if missing.
  #
  # @param [String]
  # @return [String]
  def add_protocol(uri)
    unless uri =~ /^[http]/i
      cleaned = uri.gsub('//', '')
      uri = "http://#{cleaned}"
    end

    uri
  end

end
