class DataRequest

  def get(url, &blk)
    @buf = NSMutableData.new
    @blk = blk
    req = NSURLRequest.requestWithURL(NSURL.URLWithString(url))
    NSURLConnection.alloc.initWithRequest(req, delegate:self)
  end

  # Called when we receive a response from the server.
  # This can be called multiple times if there are any server redirects in place.
  # We reset the length of our data buffer each time this callback is called.
  def connection(conn, didReceiveResponse:resp)
    @buf.setLength(0)
  end

  # Called each time data is received from the server.
  # This can be called multiple times and we just append the data to our buffer each time.
  def connection(conn, didReceiveData:data)
    @buf.appendData(data)
  end

  # Called if there is an error retrieving the data.
  # We, basically, just ignore the error. You’d probably want to do something sane in your application.
  def connection(conn, didFailWithError:err)
    NSLog "Request failed"
  end

  def connectionDidFinishLoading(conn)
    @blk.call(NSString.alloc.initWithData @buf, encoding:NSUTF8StringEncoding)
  end
end

# vamp-plugins.org
