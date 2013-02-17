class Paginator

  include Processing::Proxy

  attr_accessor :items, :num_items,
                :current_page, :num_pages, :per_page

  # @param [Fixnum] number of items to show per page
  def initialize(per_page=nil)
    @per_page = per_page ? per_page : 25
    @offset = 0
  end

  # @return [Array] the collection to page through
  def page
    items[@offset, per_page] || []
  end

  # @param [Array] the content that will be paged through
  # @param [Boolean] (false) whether to reset the current page to 0
  def set_content(content, rewind=false)
    @items = content
    @num_items = items.size
    @num_pages = (num_items / per_page.to_f).ceil
    if rewind
      rewind!
    else
      @current_page ||= 0
    end
  end

  # @param [Fixnum] the x coordinate for the pagination link
  # @param [Fixnum] the y coordinate for the pagination link
  def draw_links(x, y)
    return unless num_pages > 1

    txt = "#{current_page+1}/#{num_pages}"
    next_x = x + text_width(txt).to_i + 20

    text('◄', x, y)
    text(txt, x + 16, y)
    text('►', next_x, y)

    Links.register(x, y, :prev_page!, self)
    Links.register(next_x, y, :next_page!, self)
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

end
