# Each way to draw multiline text.
#
# line = Line.new(20)
# line.next! # => 40
# line.next! # => 60
# line.prev! # => 40
# line.curr  # => 40

class Line
  LINE_HEIGHT = 20
  attr_accessor :curr

  def initialize(starting_px=0)
    @curr = starting_px
  end

  def next!
    @curr += LINE_HEIGHT
  end

  def prev!
    @curr -= LINE_HEIGHT
  end
end

