class LogStashConfiguration

    def initialize(workspace_id, workspace_key, custom_log_table_name, endpoint='ods.opinsights.azure.com', time_generated_field='', key_names=[], key_types={}, plugin_flush_interval=5, increase_factor= 100, logger)
        @workspace_id = workspace_id
        @workspace_key = workspace_key
        @custom_log_table_name = custom_log_table_name
        @endpoint = endpoint
        @time_generated_field = time_generated_field
        @key_names = key_names
        @key_types = key_types
        @plugin_flush_interval = plugin_flush_interval
        @MAX_WINDOW_SIZE = 60000
        @MIN_WINDOW_SIZE = 1    
        @max_items = 50
        @increase_factor =increase_factor
        @logger = logger    
    end

    def validate_configuration()
        if not @custom_log_table_name.match(/^[[:alpha:]]+$/)
            raise ArgumentError, 'custom_log_table_name must be only alpha characters' 
        end
    
        @key_types.each { |k, v|
            t = v.downcase
            if ( !t.eql?('string') && !t.eql?('double') && !t.eql?('boolean') ) 
                raise ArgumentError, "Key type(#{v}) for key(#{k}) must be either string, boolean, or double"
            end
        }

        if @workspace_id.empty? or @workspace_key.empty? or @custom_log_table_name.empty? 
            raise ArgumentError, "Malformed configuration , the following arguments can not be null or empty.[workspace_id=#{@workspace_id} , workspace_key=#{@workspace_key} , custom_log_table_name=#{@custom_log_table_name}]"
        end

        # If all validation pass then configuration is valid 
        return  true
    end

    def copy()
        return logstash_configuration= LogStashConfiguration::new(@workspace_id, @workspace_key, @custom_log_table_name, @endpoint, @time_generated_field, @key_names, @key_types, @max_items, @plugin_flush_interval)
    end

    def increase_factor
        @increase_factor
    end

    def workspace_id
        @workspace_id
    end

    def workspace_key
        @workspace_key
    end

    def custom_log_table_name
        @custom_log_table_name
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


    def plugin_flush_interval
        @plugin_flush_interval
    end

    def MAX_WINDOW_SIZE
        @MAX_WINDOW_SIZE
    end

    def MIN_WINDOW_SIZE
        @MIN_WINDOW_SIZE
    end
end