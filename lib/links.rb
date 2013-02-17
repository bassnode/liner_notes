require 'set'

class Links

  CLICK_PAD_X = 10
  CLICK_PAD_Y = 10
  include Processing::Proxy

  # Not sure why plain ole' Set isn't working here, but
  # let's just get it done.
  class LinkSet < Set
    def initialize
      @hash_lookup = {}
      super()
    end

    def add(o)
      return if @hash_lookup.has_key?(o.hash)
      @hash_lookup[o.hash] = true
      super
    end
    alias << add
  end

  class Link
    attr_reader :x, :y, :object, :method, :options

    # @param [Fixnum] the x coordinate of the link
    # @param [Fixnum] the y coordinate of the link
    # @param [Symbol] the method to call on click
    # @param [Object] the object to send the method to
    # @param [Hash] options
    def initialize(x, y, method, object, options={})
      @x = x
      @y = y
      @method = method
      @object = object
      @options = options
    end

    # @param [String] a unique identifier for the Link
    def hash
      "#{x}#{y}"
    end

    def click!
      object.send(method)
    end

    # @param [Boolean] is the mouse over a link?
    def hovering?(mouse_x, mouse_y)
      if mouse_x >= x && mouse_x <= padded_x
        if mouse_y >= y && mouse_y <= padded_y
          true
        end
      else
        false
      end
    end

    # @return [Fixnum]
    def padded_x
      x + options.fetch(:x_padding, CLICK_PAD_X)
    end

    # @return [Fixnum]
    def padded_y
      y + options.fetch(:y_padding, CLICK_PAD_Y)
    end

  end

  # set to hold all the links
  @@links = LinkSet.new

  def self.reset!
    @@links = LinkSet.new
  end

  # @param [Fixnum] the x coordinate of the link
  # @param [Fixnum] the y coordinate of the link
  # @param [Symbol] the method to call on click
  # @param [Object] the object to send the method to
  # @param [Hash] options
  def self.register(x, y, method, obj, opts={})
    @@links << Link.new(x, y, method, obj, opts)
  end

  # Sends the stored method to the object if
  # currently hovering.
  #
  # @param [Fixnum] the x coordinate of the click
  # @param [Fixnum] the y coordinate of the click
  def self.click(mouse_x, mouse_y)
    if link = hovered_link(mouse_x, mouse_y)
      link.click!
    end
  end

  # @param [Fixnum] the x coordinate of the mouse
  # @param [Fixnum] the y coordinate of the mouse
  # @return [Boolean,NilClass] whether the mouse is over a link
  def self.hovering?(mouse_x, mouse_y)
    !!hovered_link(mouse_x, mouse_y)
  end

  # @param [Fixnum] the x coordinate of the mouse
  # @param [Fixnum] the y coordinate of the mouse
  # @return [Link] object that's being hovered over
  def self.hovered_link(mouse_x, mouse_y)
    @@links.detect do |link|
      link.hovering?(mouse_x, mouse_y)
    end
  end
end
