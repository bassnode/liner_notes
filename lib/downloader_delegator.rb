framework 'Cocoa'

class DownloadDelegator

  def initialize(save_to_path)
    @save_to = save_to_path
  end

  def get(url_string)
    url        = NSURL.URLWithString(url_string)
    req        = NSURLRequest.requestWithURL(url)
    NSURLDownload.alloc.initWithRequest(req, delegate:self)
  end

  def downloadDidBegin(dl_process)
    puts "downloading..."
  end

  def download(dl_process, decideDestinationWithSuggestedFilename:filename)
    dl_process.setDestination(@save_to, allowOverwrite:true)
  end

  def download(dl_process, didFailWithError:error)
    error_description = error.localizedDescription
    more_details      = error.userInfo[NSErrorFailingURLStringKey]
    puts "Download failed. #{error_description} - #{more_details}"
  end

  def downloadDidFinish(dl_process)
    puts "Download finished!"
  end

end

