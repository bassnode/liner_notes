class ArtistLink
  class << self
    attr_accessor :selected
  end

  def initialize(name)
    @name = name
  end

  def show
    self.class.selected = @name
  end

end
