class LogStashConfiguration

    def initialize(workspace_id, workspace_key, log_type, endpoint='ods.opinsights.azure.com', time_generated_field='', key_names=[], key_types={}, max_items=50, max_interval=5)
        @workspace_id = workspace_id
        @workspace_key = workspace_key
        @log_type = log_type
        @endpoint = endpoint
        @time_generated_field = time_generated_field
        @key_names = key_names
        @key_types = key_types
        @max_items = max_items
        @max_interval = max_interval
        @MAX_WINDOW_SIZE = 60000
        @MIN_WINDOW_SIZE = 1        
    end

    def copy()
        return logstash_configuration= LogStashConfiguration::new(@workspace_id, @workspace_key, @log_type, @endpoint, @time_generated_field, @key_names, @key_types, @max_items, @max_interval)
    end

    def workspace_id
        @workspace_id
    end

    def workspace_key
        @workspace_key
    end

    def log_type
        @log_type
    end

    def endpoint
        @endpoint
    end

    def time_generated_field
        @time_generated_field
    end

    def key_names
        @key_names
    end

    def key_types
        @key_types
    end

    def max_items
        @max_items
    end

    def max_items=(new_max_items)
        @max_items = new_max_items
    end


    def max_interval
        @max_interval
    end

    def MAX_WINDOW_SIZE
        @MAX_WINDOW_SIZE
    end

    def MIN_WINDOW_SIZE
        @MIN_WINDOW_SIZE
    end
end