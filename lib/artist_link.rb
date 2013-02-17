class ArtistLink
  attr_reader :name

  class << self
    attr_accessor :selected

    def reset!
      self.selected = nil
    end
  end

  def initialize(name)
    @name = name
  end

  def show
    self.class.selected = name
  end

end
