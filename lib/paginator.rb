class Paginator

  include Processing::Proxy

  def draw_links
    text('<', width - 50, height-50)
    text('>', width - 30, height-50)
  end
end
