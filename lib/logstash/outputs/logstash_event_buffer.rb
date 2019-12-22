require "stud/buffer"


class LogStash::Outputs::LogStashEventBuffer  
    include Stud::Buffer
    def initialize(max_items, max_interval, logger)
        print "CCCCCCCCCCCCCCCCCCCCCRRRRRRRRRRRRRRRRRREEEEEEEEEEEAAAAAAAAAAAAAAATTTTTTTTTTTTTT"
        buffer_initialize(
            :max_items => @flush_items,
            :max_interval => @flush_interval_time,
            :logger => @logger
          )
    end
end
