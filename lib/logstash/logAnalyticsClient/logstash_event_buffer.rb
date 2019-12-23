require "stud/buffer"
require "logstash/logAnalyticsClient/logAnalyticsClient"
require "stud/buffer"
require "logstash/logAnalyticsClient/loganalytics_configuration"

class  BufferState
    NONE=1, 
    FULL_WINDOW_RESIZE=2
    TIME_REACHED_WINDOW_RESIZE =3
end


class LogStashEventBuffer 
    include Stud::Buffer

    def initialize(logstash_configuration, logger)
        @client=LogAnalyticsClient::new(logstash_configuration.workspace_id, logstash_configuration.workspace_key, logstash_configuration.endpoint)
        @logger = logger
        @semaphore = Mutex.new
        @buffer_state = BufferState::NONE
        @logstash_configuration = logstash_configuration
        buffer_initialize(
          :max_items => logstash_configuration.max_items,
          :max_interval => logstash_configuration.max_interval,
          :logger => logger
        )
    end

    public
    def add_event_document(event_document)
        @semaphore.synchronize do
            buffer_receive(event_document)
        end
    end # def receive

    # called from Stud::Buffer#buffer_flush when there are events to flush
    public
    def flush (documents, close=false)
        if @semaphore.owned? == false
            print_message("Flush sem owned before")
            @semaphore.synchronize do
                handle_window_size(amount_of_documents)
            end
        else
            print_message("Flush sem *not* owned before")
            handle_window_size(amount_of_documents)
        end
        # Skip in case there are no candidate documents to deliver
        if documents.length < 1
            @logger.debug("No documents in batch for log type #{@logstash_configuration.log_type}. Skipping")
        return
        end

        begin
        @logger.debug("Posting log batch (log count: #{documents.length}) as log type #{@logstash_configuration.log_type} to DataCollector API. First log: " + (documents[0].to_json).to_s)

        res = @client.post_data(@logstash_configuration.log_type, documents, @logstash_configuration.time_generated_field)
        if is_successfully_posted(res)
            @logger.debug("Successfully posted logs as log type #{@logstash_configuration.log_type} with result code #{res.code} to DataCollector API")
        else
            @logger.error("DataCollector API request failure: error code: #{res.code}, data=>" + (documents.to_json).to_s)
        end
        rescue Exception => ex
            print "\n\nException\n\n"
            print ex
            print "\n\n"
            print "Documents"
            print "\n\n"
            print documents
            print "\n\n"
            @logger.error("Exception occured in posting to DataCollector API: '#{ex}', data=>" + (documents.to_json).to_s)
        end
    end # def flush



    private
    def handle_window_size(amount_of_documents)
        # if window is full and current window!=min(increased size , max size)
        if  amount_of_documents == @logstash_configuration.max_items and  @logstash_configuration.max_items != [2*@logstash_event_buffer.get_buffer_size, @logstash_event_buffer.MAX_WINDOW_SIZE].min
            new_buffer_size = [2*@logstash_event_buffer.get_buffer_size, @logstash_event_buffer.MAX_WINDOW_SIZE].min
            @logstash_event_buffer.change_buffer_size(new_buffer_size)
            print_message("Increasing size " + new_buffer_size.to_s())
            
        elsif amount_of_documents < @logstash_configuration.max_items and  @logstash_configuration.max_items != [@logstash_event_buffer.get_buffer_size/2,@logstash_event_buffer.MIN_WINDOW_SIZEl].max
            new_buffer_size = [@logstash_event_buffer.get_buffer_size/2,1].max
            @logstash_event_buffer.change_buffer_size(new_buffer_size)
            print_message("Decreasing size " + new_buffer_size.to_s())
        else
            print "Error shouldn't get here since messages can't be greater then window size "
        end
    end

    public
    def print_message(message)
        print("\n" + message + "[ThreadId= " + Thread.current.object_id.to_s + " , semaphore= " +  @semaphore.locked?.to_s + " ]\n")
    end 

    private 
    def is_successfully_posted(response)
      return (response.code == 200) ? true : false
    end

    public
    def get_buffer_size()
        return @logstash_configuration.flush_items
    end

    public
    def get_buffer_status()
        return @logstash_configuration.buffer_state
    end 

    public 
    def change_buffer_size(new_size)
        @buffer_config[:max_items] = new_size
    end

end



