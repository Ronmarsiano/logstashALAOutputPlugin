# encoding: utf-8

require "logstash/logAnalyticsClient/logstash_event_buffer"

class LogStashAutoResizeBuffer
    @MAX_WINDOW_SIZE = 10000

    def initialize(max_items, max_interval, logger,workspace_id, shared_key, endpoint, log_type,time_generated_field,flush_items)
        @log_type = log_type
        @time_generated_field = time_generated_field
        @flush_items = flush_items
        @semaphore = Mutex.new
        @client=LogAnalyticsClient::new(workspace_id, shared_key, endpoint)
        @logger = logger
        @logstash_event_buffer=LogStashEventBuffer::new(@flush_itemsm,@flush_interval_time,@logger,@workspace_id,@shared_key,@endpoint,@log_type,@time_generated_field,@flush_items)
        # buffer_initialize(
        #   :max_items => max_items,
        #   :max_interval => max_interval,
        #   :logger => logger
        # )
    end



    public
    def add_event(event_document)
        print_message("Add event")
        @semaphore.synchronize do
            @logstash_event_buffer.buffer_receive(event_document)    
        end
    end # def receive

    
    public 
    def handle_window_size(amount_of_documents)
        print_message("Start resize")
        @semaphore.synchronize do
            buffer_status = @logstash_event_buffer.get_buffer_status()
            # increase window state + increasing the size is diffrent then old size
            if buffer_status == BufferState.FULL_WINDOW_RESIZE and [2*@logstash_event_buffer.get_buffer_size, @MAX_WINDOW_SIZE].min != @logstash_event_buffer.get_buffer_size
                new_buffer_size = [2*@logstash_event_buffer.get_buffer_size, @MAX_WINDOW_SIZE].min
                @logstash_event_buffer.buffer_flush()
                @logstash_event_buffer=LogStashEventBuffer::new(new_buffer_size,@flush_interval_time,@logger,@workspace_id,@shared_key,@endpoint,@log_type,@time_generated_field,new_buffer_size)
            elsif buffer_status == BufferState.TIME_REACHED_WINDOW_RESIZE and [@logstash_event_buffer.get_buffer_size/2,1].max != @logstash_event_buffer.get_buffer_size
                new_buffer_size = [@logstash_event_buffer.get_buffer_size/2,1].max
                @logstash_event_buffer.buffer_flush()
                @logstash_event_buffer=LogStashEventBuffer::new(new_buffer_size,@flush_interval_time,@logger,@workspace_id,@shared_key,@endpoint,@log_type,@time_generated_field,new_buffer_size)
            else
                print "No action needed"
            end
        end
    end


    public
    def print_message(message)
        print("\n" + message + "[ThreadId= " + Thread.current.object_id.to_s + " , semaphore= " +  @semaphore.locked?.to_s + " ]\n")
    end 

end