# encoding: utf-8
require "logstash/outputs/base"
require "logstash/namespace"
require "stud/buffer"
require "logstash/logAnalyticsClient/logStashAutoResizeBuffer"
require "logstash/logAnalyticsClient/logstashLoganalyticsConfiguration"

class LogStash::Outputs::AzureLogAnalytics < LogStash::Outputs::Base

  config_name "logstash-output-azure-loganalytics"
  
  # Stating that the output plugin will run in concurrent mode
  concurrency :shared

  # Your Operations Management Suite workspace ID
  config :workspace_id, :validate => :string, :required => true

  # The primary or the secondary key used for authentication, required by Azure Loganalytics REST API
  config :workspace_key, :validate => :string, :required => true

  # The name of the event type that is being submitted to Log Analytics. 
  # This must be only alpha characters.
  # Table name under custom logs in which the data will be inserted
  config :custom_log_table_name, :validate => :string, :required => true

  # The service endpoint (Default: ods.opinsights.azure.com)
  config :endpoint, :validate => :string, :default => 'ods.opinsights.azure.com'

  # The name of the time generated field.
  # Be carefule that the value of field should strictly follow the ISO 8601 format (YYYY-MM-DDThh:mm:ssZ)
  config :time_generated_field, :validate => :string, :default => ''

  # The list of key names in in-coming record that you want to submit to Log Analytics leaving the keys empty will
  # send all the data into Log analtyics 
  config :key_names, :validate => :array, :default => []

  
  # The list of data types for each column as which you want to store in Log Analytics (`string`, `boolean`, or `double`)
  # - The key names in `key_types` param must be included in `key_names` param. The column data whose key isn't included in  `key_names` is treated as `string` data type.
  # - Multiple key value entries are separated by `spaces` rather than commas 
  #   See also https://www.elastic.co/guide/en/logstash/current/configuration-file-structure.html#hash
  # - If you want to store a column as datetime or guid data format, set `string` for the column ( the value of the column should be `YYYY-MM-DDThh:mm:ssZ format` if it's `datetime`, and `GUID format` if it's `guid`).
  # - In case that `key_types` param are not specified, all columns that you want to submit ( you choose with `key_names` param ) are stored as `string` data type in Log Analytics.
  # Example:
  #   key_names => ['key1','key2','key3','key4',...]
  #   key_types => {'key1'=>'string' 'key2'=>'string' 'key3'=>'boolean' 'key4'=>'double' ...}
  config :key_types, :validate => :hash, :default => {}

  # # Max number of items to buffer before flushing. Default 50.
  # config :flush_items, :validate => :number, :default => 50
  
  # Max number of seconds to wait between flushes. Default 5
  config :plugin_flush_interval, :validate => :number, :default => 5

  # Factor for adding to the amount of messages sent
  config :decrease_factor, :validate => :number, :default => 100

  # This will trigger message amount resizing in a REST request to LA
  config :amount_resizing, :validate => :boolean, :default => true

  # Setting the default amount of messages sent
  # it this is set with amount_resizing=false --> each message will have max_items
  config :max_items, :validate => :number, :default => 2000

  # Setting proxy to be used for the Azure Loganalytics REST client
  config :proxy, :validate => :string, :default => ''

  # This will set the amount of time given for retransmiting messages once sending is failed
  config :retransmition_time, :validate => :number, :default => 10

  # Optional to overide the resorce ID field on the workspace table
  config :azure_resource_id, :validate => :string, :default => ''

  public
  def register
    @logstash_configuration= LogstashLoganalyticsOutputConfiguration::new(@workspace_id, @workspace_key, @custom_log_table_name, @endpoint, @time_generated_field, @key_names, @key_types, @plugin_flush_interval, @decrease_factor, @amount_resizing, @max_items, @azure_resource_id, @proxy, @retransmition_time, @logger)
    
    
    # Validate configuration correcness 
    @logstash_configuration.validate_configuration()
    @logger.info("Logstash Azure Loganalytics output plugin configuration was found valid")

    # Initialize the logstash resizable buffer
    # This buffer will increase and decrease size according to the amount of messages inserted.
    # If the buffer reached the max amount of messages the amount will be increased untill the limit
    @logstash_resizable_event_buffer=LogStashAutoResizeBuffer::new(@logstash_configuration)

  end # def register


  public
  def multi_receive(events)
    events.each do |event|
      # creating document from event
      document = handle_single_event(event)
      # Skip if document doesn't contain any items  
      next if (document.keys).length < 1
      
      @logger.trace("Adding event document - " + event.to_s)
      @logstash_resizable_event_buffer.add_event_document(document)

    end
  end # def multi_receive

  private 
  def handle_single_event(event)
    document = {}
    event_hash = event.to_hash()
    if @key_names.length > 0
      # Get the intersection of key_names and keys of event_hash
      keys_intersection = @key_names & event_hash.keys
      keys_intersection.each do |key|
        if @key_types.include?(key)
          document[key] = convert_value(@key_types[key], event_hash[key])
        else
          document[key] = event_hash[key]
        end
      end
    else
      document = event_hash
    end

    return document
  end # def handle_single_event


  private
  def convert_value(type, value)
    type_downcase = type.downcase
    case type_downcase
    when "boolean"
      value_downcase = value.downcase
      return (value_downcase.to_s == 'true' ) ? true : false
    when "double"
      return Integer(value) rescue Float(value) rescue value
    else
      return value
    end
  end

end # class LogStash::Outputs::AzureLogAnalytics
