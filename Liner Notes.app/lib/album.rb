require 'lib/rovi'
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
        LinerNotes.logger.error "Timed out trying to get all the credits :("
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

    artist_scores.min < 5 ? best : nil
  end

end
