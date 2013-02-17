require 'thread'
require 'open-uri'

class Http
  @@mutex = Mutex.new
  @@busy = false


  class << self
    include Processing::Proxy

    def mutex
      @@mutex
    end

    def get(uri)
      mutex.synchronize{ @@busy = true }
      response = open(uri).read
      mutex.synchronize{ @@busy = false }

      response
    end


    def busy?
      @@busy
    end
  end
end


