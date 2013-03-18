require 'thread'
require 'open-uri'

class Http
  @@mutex = Mutex.new
  @@busy = false


  class << self

    def mutex
      @@mutex
    end

    def get(uri)
      mutex.synchronize{ @@busy = true }
      response = nil
      begin
        response = open(uri).read
      rescue => e
        LinerNotes.logger.error "Couldn't get #{uri}: #{e}"
      end

      mutex.synchronize{ @@busy = false }

      response
    end


    def busy?
      @@busy
    end
  end
end


