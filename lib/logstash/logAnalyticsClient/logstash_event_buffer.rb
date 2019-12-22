require "stud/buffer"


class LogStashEventBuffer 
    include Stud::Buffer

    def initialize(max_items, max_interval, logger)
        buffer_initialize(
          :max_items => max_items,
          :max_interval => max_interval,
          :logger => logger
        )
        
        print "CCCCCCCCCCCCCCCCCCCCCRRRRRRRRRRRRRRRRRREEEEEEEEEEEAAAAAAAAAAAAAAATTTTTTTTTTTTTT"
    end
end
