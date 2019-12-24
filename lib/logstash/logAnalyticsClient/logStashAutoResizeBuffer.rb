# encoding: utf-8
require "logstash/logAnalyticsClient/logstash_event_buffer"
require "logstash/outputs/base"
require "logstash/namespace"
require "stud/buffer"
require "logstash/logAnalyticsClient/loganalytics_configuration"


class LogStashAutoResizeBuffer

    def initialize(logstash_configuration, logger)
        @logstash_configuration=logstash_configuration
        @logstash_event_buffer=LogStashEventBuffer::new(logstash_configuration,logger)

    end



    public
    def add_event_document2(event_document)
        @logstash_event_buffer.add_event_document(event_document)   
        # handle_window_size() 
        # end
    end # def receive

    

    public
    def print_message(message)
        print("\n" + message + "[ThreadId= " + Thread.current.object_id.to_s + " , semaphore= " +  @semaphore.locked?.to_s + " ]\n")
    end 



end