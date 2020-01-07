# encoding: utf-8
class LogstashLoganalyticsOutputConfiguration

    def initialize(workspace_id, workspace_key, custom_log_table_name, endpoint='ods.opinsights.azure.com', time_generated_field='', key_names=[], key_types={}, plugin_flush_interval=5, decrease_factor= 100, amount_resizing=true, max_items=2000, proxy, retransmition_time, logger)
        @workspace_id = workspace_id
        @workspace_key = workspace_key
        @custom_log_table_name = custom_log_table_name
        @endpoint = endpoint
        @time_generated_field = time_generated_field
        @key_names = key_names
        @key_types = key_types
        @plugin_flush_interval = plugin_flush_interval
        @MIN_MESSAGE_AMOUNT = 100 
        @max_items = max_items
        @decrease_factor = decrease_factor
        @amount_resizing = amount_resizing
        @proxy = proxy
        @logger = logger
        @retransmition_time = retransmition_time
        # Delay between each resending of a message
        @RETRANSMITION_DELAY = 2
        
        # Maximum of 30 MB per post to Log Analytics Data Collector API. 
        # This is a size limit for a single post. 
        # If the data from a single post that exceeds 30 MB, you should split it.
        @loganalytics_api_data_limit = 30 * 1000 * 1000

        # Taking 4K saftey buffer
        @MAX_SIZE_BYTES = @loganalytics_api_data_limit - 4000
    end

    def validate_configuration()
        @key_types.each { |k, v|
            t = v.downcase
            if ( !t.eql?('string') && !t.eql?('double') && !t.eql?('boolean') ) 
                raise ArgumentError, "Key type(#{v}) for key(#{k}) must be either string, boolean, or double"
            end
        }

        if @retransmition_time < 0
            raise ArgumentError, "Setting retransmition_time which sets the time spent for resending each failed messages must be positive integer. [retransmition_time=#{@retransmition_time}]." 
        
        elsif @max_items < @MIN_MESSAGE_AMOUNT
            raise ArgumentError, "Setting max_items to value must be greater then #{@MIN_MESSAGE_AMOUNT}."

        elsif @workspace_id.empty? or @workspace_key.empty? or @custom_log_table_name.empty? 
            raise ArgumentError, "Malformed configuration , the following arguments can not be null or empty.[workspace_id=#{@workspace_id} , workspace_key=#{@workspace_key} , custom_log_table_name=#{@custom_log_table_name}]"

        elsif not @custom_log_table_name.match(/^[[:alpha:]]+$/)
            raise ArgumentError, 'custom_log_table_name must be only alpha characters.' 

        elsif custom_log_table_name.empty?
            raise ArgumentError, 'custom_log_table_name should not be empty.' 
        elsif @key_names.length > 500
            raise ArgumentError, 'Azure Loganalytics imits the amount of columns to 500 in each table.' 

        end

        @logger.info("Azure Loganalytics configuration was found valid.")
        
        # If all validation pass then configuration is valid 
        return  true
    end

    def MAX_SIZE_BYTES
        @MAX_SIZE_BYTES
    end

    def amount_resizing
        @amount_resizing
    end

    def proxy
        @proxy
    end

    def logger
        @logger
    end

    def decrease_factor
        @decrease_factor
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

    def MIN_MESSAGE_AMOUNT
        @MIN_MESSAGE_AMOUNT
    end
end