require "stud/buffer"


class LogStashEventBuffer 
    include Stud::Buffer

    def initialize(max_items, max_interval, logger)
        @semaphore = Mutex.new
        buffer_initialize(
          :max_items => max_items,
          :max_interval => max_interval,
          :logger => logger
        )

        print "CCCCCCCCCCCCCCCCCCCCCRRRRRRRRRRRRRRRRRREEEEEEEEEEEAAAAAAAAAAAAAAATTTTTTTTTTTTTT"
    end


  # called from Stud::Buffer#buffer_flush when there are events to flush
  public
  def flush (documents, close=false)
    handle_window_size(documents.length)
    # Skip in case there are no candidate documents to deliver
    if documents.length < 1
      @logger.debug("No documents in batch for log type #{@log_type}. Skipping")
      return
    end

    begin
      @logger.debug("Posting log batch (log count: #{documents.length}) as log type #{@log_type} to DataCollector API. First log: " + (documents[0].to_json).to_s)
      res = @client.post_data(@log_type, documents, @time_generated_field)
      if is_successfully_posted(res)
        @logger.debug("Successfully posted logs as log type #{@log_type} with result code #{res.code} to DataCollector API")
      else
        @logger.error("DataCollector API request failure: error code: #{res.code}, data=>" + (documents.to_json).to_s)
      end
    rescue Exception => ex
      @logger.error("Exception occured in posting to DataCollector API: '#{ex}', data=>" + (documents.to_json).to_s)
    end
  end # def flush

  public 
  def handle_window_size(amount_of_documents)
    # Reduce widow size
    if amount_of_documents < @flush_items
      print "\n\XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX\n\n"
      print @semaphore
      print "\n\YYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYY\n\n"
      @semaphore.synchronize do
        buffer_initialize(
          :max_items => @flush_items / 2,
          :max_interval => @flush_interval_time,
          :logger => @logger
        )
      end
    elsif @flush_items < @MAX_WINDOW_SIZE
      print "\n\XXXXXXXXdddddddXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX\n\n"
      print @semaphore
      print "\n\YYYYYYYYYYdddddddYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYY\n\n"
      @semaphore.synchronize do
        buffer_initialize(
          :max_items => @flush_items * 2 > @MAX_WINDOW_SIZE ? @MAX_WINDOW_SIZE : @flush_items * 2,
          :max_interval => @flush_interval_time,
          :logger => @logger
        )
      end
    end
  end

end



