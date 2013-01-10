class Links

  CLICK_PAD = 10
  include Processing::Proxy

  # Keep a map of all the links so we can act
  # upon the correct one when there is a click.
  @@links = {}

  # @param [Fixnum] the x coordinate of the link
  # @param [Fixnum] the y coordinate of the link
  # @param [Symbol] the method to call on click
  # @param [Object] the object to send the method to
  def self.register(x, y, method, obj)
    key = [x,y]
    @@links[key] ||= [method, obj]
  end

  # Sends the stored method to the object if
  # currently hovering.
  #
  # @param [Fixnum] the x coordinate of the click
  # @param [Fixnum] the y coordinate of the click
  def self.click(mouse_x, mouse_y)
    if clicked = hovered_link(mouse_x, mouse_y)
      meth, obj = @@links[clicked]
      obj.send(meth)
    end
  end

  # @param [Fixnum] the x coordinate of the mouse
  # @param [Fixnum] the y coordinate of the mouse
  # @return [Boolean] whether the mouse is over a link
  def self.hovering?(mouse_x, mouse_y)
    !!hovered_link(mouse_x, mouse_y)
  end

  # @param [Fixnum] the x coordinate of the mouse
  # @param [Fixnum] the y coordinate of the mouse
  # @return [Array<Fixnum>] hash key for @@links
  def self.hovered_link(mouse_x, mouse_y)
    @@links.keys.detect do |x, y|
      if mouse_x >= x-CLICK_PAD && mouse_x <= x+CLICK_PAD
        if mouse_y >= y-CLICK_PAD && mouse_y <= y+CLICK_PAD
          true
        end
      else
        false
      end
    end
  end
end
