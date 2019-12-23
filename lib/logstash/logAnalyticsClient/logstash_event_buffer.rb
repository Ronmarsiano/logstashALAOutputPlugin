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

    def initialize(logstash_configuration)
        @log_type = logstash_configuration.log_type
        @time_generated_field = logstash_configuration.time_generated_field
        @flush_items = logstash_configuration.flush_items
        @client=LogAnalyticsClient::new(logstash_configuration.workspace_id, logstash_configuration.shared_key, logstash_configuration.endpoint)
        @logger = logger
        @buffer_state = BufferState::NONE

        buffer_initialize(
          :max_items => logstash_configuration.max_items,
          :max_interval => logstash_configuration.max_interval,
          :logger => logstash_configuration.logger
        )
    end

    public
    def add_event_document(event_document)
        print "\n\n what i got \n\n"
        print event_document
        print ("\n\n*************************\n\n")
        buffer_receive(event_document)
    end # def receive

    # called from Stud::Buffer#buffer_flush when there are events to flush
    public
    def flush (documents, close=false)
        print("\nfllusshhhiinggg\n")
        # Skip in case there are no candidate documents to deliver
        if documents.length < 1
        @logger.debug("No documents in batch for log type #{logstash_configuration.log_type}. Skipping")
        return
        end

        begin
        @logger.debug("Posting log batch (log count: #{documents.length}) as log type #{logstash_configuration.log_type} to DataCollector API. First log: " + (documents[0].to_json).to_s)

        res = @client.post_data(logstash_configuration.log_type, documents, logstash_configuration.time_generated_field)
        print "\n\n ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n\n"
        if is_successfully_posted(res)
            print "\nMessage sent\n"+ Thread.current.object_id.to_s
            @logger.debug("Successfully posted logs as log type #{logstash_configuration.log_type} with result code #{res.code} to DataCollector API")
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
    def is_successfully_posted(response)
      return (response.code == 200) ? true : false
    end

    public
    def get_buffer_size()
        return logstash_configuration.flush_items
    end

    public
    def get_buffer_status()
        return logstash_configuration.buffer_state
    end 

end



