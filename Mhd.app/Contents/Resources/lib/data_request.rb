class DataRequest
  def get(url, &blk)
    @buf = NSMutableData.new
    @blk = blk
    req = NSURLRequest.requestWithURL(NSURL.URLWithString(url))
    NSURLConnection.alloc.initWithRequest(req, delegate:self)
  end

  def connection(conn, didReceiveResponse:resp)
    @buf.setLength(0)
  end

  def connection(conn, didReceiveData:data)
    @buf.appendData(data)
  end

  def connection(conn, didFailWithError:err)
    NSLog "Request failed"
  end

  def connectionDidFinishLoading(conn)
    @blk.call(NSString.alloc.initWithData @buf, encoding:NSUTF8StringEncoding)
  end
end

