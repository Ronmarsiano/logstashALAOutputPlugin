require "stud/buffer"
require "logstash/logAnalyticsClient/logAnalyticsClient"
require "stud/buffer"
require "logstash/logAnalyticsClient/loganalytics_configuration"


class LogStashAutoResizeBuffer
    include Stud::Buffer

    def initialize(logstash_configuration, logger)
        @client=LogAnalyticsClient::new(logstash_configuration.workspace_id, logstash_configuration.workspace_key, logstash_configuration.endpoint)
        @logger = logger
        @semaphore = Mutex.new
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
                handle_window_size(documents.length)
            end
        else
            print_message("------>>>>>>>>Flush sem *not* owned before")
            handle_window_size(documents.length)
        end
        # Skip in case there are no candidate documents to deliver
        if documents.length < 1
            @logger.debug("No documents in batch for log type #{@logstash_configuration.custom_log_table_name}. Skipping")
        return
        end

        begin
        @logger.debug("Posting log batch (log count: #{documents.length}) as log type #{@logstash_configuration.custom_log_table_name} to DataCollector API. First log: " + (documents[0].to_json).to_s)

        res = @client.post_data(@logstash_configuration.custom_log_table_name, documents, @logstash_configuration.time_generated_field)
        if is_successfully_posted(res)
            @logger.debug("Successfully posted logs as log type #{@logstash_configuration.custom_log_table_name} with result code #{res.code} to DataCollector API")
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
        print_message("Handiling amount of messages in window - "+ amount_of_documents.to_s())
        # if window is full and current window!=min(increased size , max size)
        if  amount_of_documents == @logstash_configuration.max_items and  @logstash_configuration.max_items != [2*@logstash_configuration.max_items, @logstash_configuration.MAX_WINDOW_SIZE].min
            print_message("Increase: Taking min between " + @logstash_configuration.max_items.to_s() + "*2="+ (@logstash_configuration.max_items*2).to_s()+" and "+@logstash_configuration.MAX_WINDOW_SIZE.to_s() )
            new_buffer_size = [2*@logstash_configuration.max_items, @logstash_configuration.MAX_WINDOW_SIZE].min
            print_message("Increase: new buffer size is "+ new_buffer_size.to_s())
            change_buffer_size(new_buffer_size)
        # TODO change 1 to min winowd size 
        elsif amount_of_documents < @logstash_configuration.max_items and  @logstash_configuration.max_items != [@logstash_configuration.max_items/2,@logstash_configuration.MIN_WINDOW_SIZE].max
            print_message("Decrease: Taking min between " + @logstash_configuration.max_items.to_s() + "/2="+ (@logstash_configuration.max_items/2).to_s()+" and 1")
            new_buffer_size = [@logstash_configuration.max_items/2,@logstash_configuration.MIN_WINDOW_SIZE].max
            print_message("Decrease: new buffer size is "+ new_buffer_size.to_s())
            change_buffer_size(new_buffer_size)
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
        print_message("Changing buffer size from " + @buffer_config[:max_items].to_s + " to " + new_size.to_s)
        @buffer_config[:max_items] = new_size
        @logstash_configuration.max_items = new_size
    end

end