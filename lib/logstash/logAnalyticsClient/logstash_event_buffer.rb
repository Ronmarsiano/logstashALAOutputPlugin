require "stud/buffer"
require "logstash/logAnalyticsClient/logAnalyticsClient"

class LogStashEventBuffer 
    include Stud::Buffer

    def initialize(max_items, max_interval, logger,workspace_id, shared_key, endpoint, log_type,time_generated_field,flush_items)
        @log_type = log_type
        @time_generated_field = time_generated_field
        @flush_items = flush_items
        @semaphore = Mutex.new
        @client=LogAnalyticsClient::new(workspace_id, shared_key, endpoint)
        @logger = logger
        buffer_initialize(
          :max_items => max_items,
          :max_interval => max_interval,
          :logger => logger
        )
    end

    public
    def add_event(event_document)
        print("\nStart add event" + Thread.current.object_id.to_s + " locked= "+ @semaphore.locked?)
        @semaphore.synchronize do
            print("\nMutex took"+ Thread.current.object_id.to_s + " locked= "+ @semaphore.locked?)
            buffer_receive(event_document)
            print "\nend buffer recive"+ Thread.current.object_id.to_s + " locked= "+ @semaphore.locked?
        end
        print("\nMutex release"+ Thread.current.object_id.to_s + " locked= "+ @semaphore.locked?)
        print("\nEnd add event"+ Thread.current.object_id.to_s + " locked= "+ @semaphore.locked?)
    end # def receive

    # called from Stud::Buffer#buffer_flush when there are events to flush
    public
    def flush (documents, close=false)
        print "\nStarting FLus\n"+ Thread.current.object_id.to_s + " locked= "+ @semaphore.locked?
        # Skip in case there are no candidate documents to deliver
        if documents.length < 1
        @logger.debug("No documents in batch for log type #{@log_type}. Skipping")
        return
        end

        begin
        @logger.debug("Posting log batch (log count: #{documents.length}) as log type #{@log_type} to DataCollector API. First log: " + (documents[0].to_json).to_s)
        res = @client.post_data(@log_type, documents, @time_generated_field)
        if is_successfully_posted(res)
            print "\nMessage sent\n"+ Thread.current.object_id.to_s + " locked= "+ @semaphore.locked?
            @logger.debug("Successfully posted logs as log type #{@log_type} with result code #{res.code} to DataCollector API")
        else
            @logger.error("DataCollector API request failure: error code: #{res.code}, data=>" + (documents.to_json).to_s)
        end
        rescue Exception => ex
        @logger.error("Exception occured in posting to DataCollector API: '#{ex}', data=>" + (documents.to_json).to_s)
        end

        handle_window_size(documents.length)
        print("\nend flushing\n"+ Thread.current.object_id.to_s + " locked= "+ @semaphore.locked?)

    end # def flush

    private 
    def is_successfully_posted(response)
      return (response.code == 200) ? true : false
    end

    public 
    def handle_window_size(amount_of_documents)
        print("\nStart resize"+ Thread.current.object_id.to_s + " locked= "+ @semaphore.locked?)
        # Reduce widow size
        if amount_of_documents < @flush_items
            buffer_initialize(
            :max_items => @flush_items / 2,
            :max_interval => @flush_interval_time,
            :logger => @logger
            )
        elsif @flush_items < @MAX_WINDOW_SIZE
            buffer_initialize(
            :max_items => @flush_items * 2 > @MAX_WINDOW_SIZE ? @MAX_WINDOW_SIZE : @flush_items * 2,
            :max_interval => @flush_interval_time,
            :logger => @logger
            )
        end
        print("\nEnd resize\n"+ Thread.current.object_id.to_s + " locked= "+ @semaphore.locked?)
    end

end



