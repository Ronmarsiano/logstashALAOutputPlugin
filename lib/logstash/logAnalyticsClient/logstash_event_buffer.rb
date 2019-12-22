# encoding: utf-8
require "stud/buffer"
require "logstash/logAnalyticsClient/logAnalyticsClient"
require "logstash/logAnalyticsClient/logStashAutoResizeBuffer"

class  BufferState
    NONE=1, 
    FULL_WINDOW_RESIZE=2
    TIME_REACHED_WINDOW_RESIZE =3
end


class LogStashEventBuffer 
    include Stud::Buffer

    @MAX_WINDOW_SIZE = 10000

    def initialize(max_items, max_interval, logger,workspace_id, shared_key, endpoint, log_type,time_generated_field,flush_items)
        @log_type = log_type
        @time_generated_field = time_generated_field
        @flush_items = flush_items
        @semaphore = Mutex.new
        @client=LogAnalyticsClient::new(workspace_id, shared_key, endpoint)
        @logger = logger
        @buffer_state = BufferState::NONE
        buffer_initialize(
          :max_items => max_items,
          :max_interval => max_interval,
          :logger => logger
        )
    end

    public
    def get_buffer_size()
        return @flush_items
    end


    public
    def get_buffer_status()
        return @buffer_state
    end 

    # called from Stud::Buffer#buffer_flush when there are events to flush
    public
    def flush (documents, close=false)
        # Skip in case there are no candidate documents to deliver
        if documents.length < 1
        @logger.debug("No documents in batch for log type #{@log_type}. Skipping")
        return
        end

        begin
        @logger.debug("Posting log batch (log count: #{documents.length}) as log type #{@log_type} to DataCollector API. First log: " + (documents[0].to_json).to_s)
        res = @client.post_data(@log_type, documents, @time_generated_field)
        if is_successfully_posted(res)
            print_message("Message sent")
            @logger.debug("Successfully posted logs as log type #{@log_type} with result code #{res.code} to DataCollector API")
        else
            @logger.error("DataCollector API request failure: error code: #{res.code}, data=>" + (documents.to_json).to_s)
        end
        rescue Exception => ex
        @logger.error("Exception occured in posting to DataCollector API: '#{ex}', data=>" + (documents.to_json).to_s)
        end
        update_window_state(documents.length)
    end # def flush

    private 
    def is_successfully_posted(response)
      return (response.code == 200) ? true : false
    end



    public 
    def update_window_state(amount_of_documents)
        # Reduce widow size
        if amount_of_documents < @flush_items
            @buffer_state = BufferState::TIME_REACHED_WINDOW_RESIZE
        elsif @flush_items < @MAX_WINDOW_SIZE
            @buffer_state = BufferState::FULL_WINDOW_RESIZE
        else
            @buffer_state = BufferState::NONE
        end
    end

end



