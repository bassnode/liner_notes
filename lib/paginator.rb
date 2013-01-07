class Paginator

  include Processing::Proxy

  # Keep a map of all the next/prev links so we can act
  # upon the correct Paginator when there is a click.
  @@links = {}

  attr_accessor :items, :num_items,
                :current_page, :num_pages, :per_page

  # @param [Fixnum] number of items to show per page
  def initialize(per_page=nil)
    @per_page = per_page ? per_page : 25
    @offset = 0
  end

  # @return [Array] the collection to page through
  def page
    items[@offset, per_page]
  end

  # @param [Array] the content that will be paged through
  def set_content(content)
    @items = content
    @num_items = items.size
    @num_pages = (num_items / per_page.to_f).ceil
    @current_page ||= 0
  end

  # @param [Fixnum] the x coordinate for the pagination link
  # @param [Fixnum] the y coordinate for the pagination link
  def draw_links(x, y)
    return unless num_pages > 1

    txt = "#{current_page+1}/#{num_pages}"
    next_x = x + text_width(txt).to_i + 20

    text('<', x, y)
    text(txt, x + 16, y)
    text('>', next_x, y)

    self.class.register_link(x, y, :prev_page!, self)
    self.class.register_link(next_x, y, :next_page!, self)
  end

  def rewind!
    loc(0)
  end

  def next_page!
    if current_page == num_pages-1
      rewind!
    else
      loc(current_page+1)
    end
  end

  def prev_page!
    if current_page == 0
      loc(num_pages-1)
    else
      loc(current_page-1)
    end
  end

  def loc(page)
    @current_page = page
    @offset = page * per_page
  end


  # @param [Fixnum] the x coordinate of the link
  # @param [Fixnum] the y coordinate of the link
  # @param [Symbol] the method to call on click
  # @param [Paginator] the paginator to send the click to
  def self.register_link(x, y, method, obj)
    key = [x,y]
    @@links[key] ||= [method, obj]
  end

  # Increments/decrements the current_page if the
  # x/y coords of the click hit a paginator link.
  #
  # @param [Fixnum] the x coordinate of the click
  # @param [Fixnum] the y coordinate of the click
  def self.click(x,y)
    keys = @@links.keys
    pad = 10

    clicked = keys.detect do |x_y|
      xrange = x_y[0]-pad..x_y[0]+pad
      yrange = x_y[1]-pad..x_y[1]+pad

      xrange.include?(x) && yrange.include?(y)
    end

    if clicked
      direction, paginator = @@links[clicked]
      paginator.send(direction)
    end
  end
end
