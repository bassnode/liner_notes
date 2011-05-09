require 'digest/md5'
require 'uri'

# We don't actually make the HTTP calls here, just a collection of that
# prepares URL strings for the Rovi API.

module Rovi
  @shared_secret = "7Qbqyxz8TT"
  @api_key       = "cc94xnqu4u5hwfqrdeq4umte"
  @base_url      = "http://api.rovicorp.com"
  @format        = 'json'

  def self.md5
    Digest::MD5.hexdigest(@api_key + @shared_secret + Time.now.to_i.to_s)
  end

  def self.default_opts
    {
      :apikey => @api_key,
      :sig    => md5,
      :format => @format
    }
  end

  def self.album_lookup_url(artist, album)
    all_opts = { :query => "#{artist} #{album}".gsub(/\(.*\)/,'').strip,
                 :facet => 'type',
                 :size => '1',
                 :include => 'album:all',
                 :entitytype => 'album'}.merge(default_opts)

    opts_string = parameterize_hash(all_opts)
    "#{@base_url}/search/v1/search?#{opts_string}"
  end


  def self.image_lookup_url(albumid)
    opts = { :albumid => albumid }.merge(default_opts)

    opts_string = parameterize_hash(opts)
    "#{@base_url}/data/v1/album/images?#{opts_string}"
  end

  # Takes a url and adds/changes what's necessary to make it valid.
  def self.prepare_url(url)
    url.gsub!('format=xml',"format=#{@format}")
    url += "&sig=#{md5}"      unless url.match(/&sig=/)
    url += "&api=#{@api_key}" unless url.match(/&api=/)
    url
  end

  def self.parameterize_hash(opts)
    opts.map{ |k,v| "#{k}=#{URI.escape(v)}"}.join('&')
  end
end
