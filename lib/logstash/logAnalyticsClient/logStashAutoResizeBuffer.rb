# encoding: utf-8
require "stud/buffer"
require "logstash/logAnalyticsClient/logAnalyticsClient"
require "stud/buffer"
require "logstash/logAnalyticsClient/logstashLoganalyticsConfiguration"


class LogStashAutoResizeBuffer
    include Stud::Buffer

    def initialize(logstashLoganalyticsConfiguration)
        @logstashLoganalyticsConfiguration = logstashLoganalyticsConfiguration
        @logger = @logstashLoganalyticsConfiguration.logger
        @client=LogAnalyticsClient::new(logstashLoganalyticsConfiguration)
        buffer_initialize(
          :max_items => logstashLoganalyticsConfiguration.max_items,
          :max_interval => logstashLoganalyticsConfiguration.plugin_flush_interval,
          :logger => @logstashLoganalyticsConfiguration.logger
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
        # Setting reisizng to true will cause chanigng the max size
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
                @logger.info("Successfully posted #{amount_of_documents} logs into cutom log analytics table[#{@logstashLoganalyticsConfiguration.custom_log_table_name}].")
            else
                @logger.error("DataCollector API request failure: error code: #{response.code}, data=>" + (documents.to_json).to_s)
                resend_message(documents_json, amount_of_documents)
            end
            rescue Exception => ex
                @logger.error("Exception in posting data to Azure Loganalytics.\n[Exception: '#{ex}'\nDocuments(#{amount_of_documents}) failed to be sent.[documents= '#{documents_json}']")
                resend_message(documents_json, amount_of_documents)
            end
    end # end send_message_to_loganalytics

    private 
    def resend_message(documents_json, amount_of_documents)
        @logger.info("Resending #{amount_of_documents} documents as log type #{@logstashLoganalyticsConfiguration.custom_log_table_name} to DataCollector API in 2 seconds.")
        sleep 2
        response = @client.post_data(@logstashLoganalyticsConfiguration.custom_log_table_name, documents_json, @logstashLoganalyticsConfiguration.time_generated_field)
        if is_successfully_posted(response)
            @logger.info("Successfully sent #{amount_of_documents} logs into cutom log analytics table[#{@logstashLoganalyticsConfiguration.custom_log_table_name}] after resending.")
        else
            resend_message(documents_json, amount_of_documents)
        end
    end

    private
    def change_max_size(amount_of_documents, documents_byte_size)
        new_buffer_size = @logstashLoganalyticsConfiguration.max_items
        average_document_size = documents_byte_size / amount_of_documents
        # If window is full we need to increase it 
        # "amount_of_documents" can be greater since buffer is not synchronized meaning 
        # that flush can occure after limit was reached.
        if  amount_of_documents >= @logstashLoganalyticsConfiguration.max_items
            # if doubling the size wouldn't exceed the API limit
            if ((2 * @logstashLoganalyticsConfiguration.max_items) * average_document_size) < @logstashLoganalyticsConfiguration.MAX_SIZE_BYTES
                new_buffer_size = 2 * @logstashLoganalyticsConfiguration.max_items
            else
                new_buffer_size = @logstashLoganalyticsConfiguration.MAX_SIZE_BYTES / average_document_size
            end

        # We would like to decrease the window but not more then the MIN_MESSAGE_AMOUNT
        # We are trying to decrease it slowly to be able to send as much messages as we can in one window 
        elsif amount_of_documents < @logstashLoganalyticsConfiguration.max_items and  @logstashLoganalyticsConfiguration.max_items != [(@logstashLoganalyticsConfiguration.max_items - @logstashLoganalyticsConfiguration.decrease_factor) ,@logstashLoganalyticsConfiguration.MIN_MESSAGE_AMOUNT].max
            new_buffer_size = [(@logstashLoganalyticsConfiguration.max_items - @logstashLoganalyticsConfiguration.decrease_factor) ,@logstashLoganalyticsConfiguration.MIN_MESSAGE_AMOUNT].max
        end

        change_buffer_size(new_buffer_size)
    end

    private 
    def is_successfully_posted(response)
      return (response.code == 200) ? true : false
    end

    public 
    def change_buffer_size(new_size)
        # Change buffer size only if it's needed
        if @buffer_config[:max_items] != new_size
            old_buffer_size = @buffer_config[:max_items]
            @buffer_config[:max_items] = new_size
            @logstashLoganalyticsConfiguration.max_items = new_size
            @logger.info("Changing buffer size.[configuration='#{old_buffer_size}' , new_size='#{new_size}']")
        else
            @logger.info("Buffer size wasn't changed.[configuration='#{old_buffer_size}' , new_size='#{new_size}']")
        end
    end

end