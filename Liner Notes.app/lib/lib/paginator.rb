class Paginator

  include Processing::Proxy

  attr_accessor :items, :num_items,
                :current_page, :num_pages, :per_page

  def initialize(items, opts={})
    @current_page = opts.fetch(:page, 0).to_i
    @per_page     = opts.fetch(:per_page, 25)
    @items        = items
    @num_items    = items.size
    @num_pages    = (num_items / per_page.to_f).ceil
    @offset       = current_page * per_page
  end

  def page
    items[@offset, per_page]
  end

  def draw_links(x, y)
    return unless num_pages > 1

    txt = "#{current_page+1}/#{num_pages}"
    text('<', x, y)
    text(txt, x + 16, y)
    text('>', x + text_width(txt) + 20, y)
  end
end
