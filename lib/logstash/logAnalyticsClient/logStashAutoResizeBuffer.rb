require "stud/buffer"
require "logstash/logAnalyticsClient/logAnalyticsClient"
require "stud/buffer"
require "logstash/logAnalyticsClient/logstashLoganalyticsConfiguration"


class LogStashAutoResizeBuffer
    include Stud::Buffer

    def initialize(logstashLoganalyticsConfiguration, logger)
        @client=LogAnalyticsClient::new(logstashLoganalyticsConfiguration.workspace_id, logstashLoganalyticsConfiguration.workspace_key, logstashLoganalyticsConfiguration.endpoint)
        @logger = logger
        @logstashLoganalyticsConfiguration = logstashLoganalyticsConfiguration
        buffer_initialize(
          :max_items => logstashLoganalyticsConfiguration.max_items,
          :max_interval => logstashLoganalyticsConfiguration.plugin_flush_interval,
          :logger => logger
        )
    end


    public
    def add_event_document(event_document)
        buffer_receive(event_document)
    end # def add_event_document


    # called from Stud::Buffer#buffer_flush when there are events to flush
    public
    def flush (documents, close=false)
        # Skip in case there are no candidate documents to deliver
        if documents.length < 1
            @logger.warn("No documents in batch for log type #{@logstashLoganalyticsConfiguration.custom_log_table_name}. Skipping")
            return
        end

        # We send Json in the REST request 
        documents_json = documents.to_json

        # 
        if @logstashLoganalyticsConfiguration.amount_resizing == true
            # Resizing the amount of messages according to size of message recived and amount of messages
            change_max_size(documents.length, documents_json.bytesize)
        end

        send_message_to_loganalytics(documents_json, documents.length)

    end # def flush

    private 
    def send_message_to_loganalytics(documents_json, amount_of_documents)
        begin
            @logger.debug("Posting log batch (log count: #{amount_of_documents}) as log type #{@logstashLoganalyticsConfiguration.custom_log_table_name} to DataCollector API.")
            response = @client.post_data(@logstashLoganalyticsConfiguration.custom_log_table_name, documents_json, @logstashLoganalyticsConfiguration.time_generated_field)
            if is_successfully_posted(response)
                @logger.debug("Successfully posted logs as log type #{@logstashLoganalyticsConfiguration.custom_log_table_name} with result code #{response.code} to DataCollector API")
            else
                @logger.error("DataCollector API request failure: error code: #{response.code}, data=>" + (documents.to_json).to_s)
            end
            rescue Exception => ex
                @logger.error("Exception in posting data to Azure Loganalytics.\n[Exception: '#{ex}'")
                @logger.error("Documents failed to be sent.[documents= '#{documents_json}']")
            end
    end # end send_message_to_loganalytics

    private
    def change_max_size(amount_of_documents, documents_byte_size)
        average_document_size = documents_byte_size / amount_of_documents

        # If window is full we need to increase it 
        # "amount_of_documents" can be greater since buffer is not synchronized meaning 
        # that flush can occure after limit was reached.
        if  amount_of_documents >= @logstashLoganalyticsConfiguration.max_items
            if ((2 * @logstashLoganalyticsConfiguration.max_items) * average_document_size) < @logstashLoganalyticsConfiguration.MAX_SIZE_BYTES
                new_buffer_size = 2 * @logstashLoganalyticsConfiguration.max_items
                change_buffer_size(new_buffer_size)
            else
                new_buffer_size = @logstashLoganalyticsConfiguration.MAX_SIZE_BYTES / average_document_size
                change_buffer_size(new_buffer_size)
            end

        # We would like to decrease the window but not more then the MIN_MESSAGE_AMOUNT
        # We are trying to decrease it slowly to be able to send as much messages as we can in one window 
        elsif amount_of_documents < @logstashLoganalyticsConfiguration.max_items and  @logstashLoganalyticsConfiguration.max_items != [(@logstashLoganalyticsConfiguration.max_items - @logstashLoganalyticsConfiguration.decrease_factor) ,@logstashLoganalyticsConfiguration.MIN_MESSAGE_AMOUNT].max
            new_buffer_size = [(@logstashLoganalyticsConfiguration.max_items - @logstashLoganalyticsConfiguration.decrease_factor) ,@logstashLoganalyticsConfiguration.MIN_MESSAGE_AMOUNT].max
            change_buffer_size(new_buffer_size)

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
    def change_buffer_size(new_size)
        print_message("Changing buffer size from " + @buffer_config[:max_items].to_s + " to " + new_size.to_s)
        @buffer_config[:max_items] = new_size
        @logstashLoganalyticsConfiguration.max_items = new_size
    end

end