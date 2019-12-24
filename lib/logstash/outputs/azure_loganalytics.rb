# encoding: utf-8

require "logstash/outputs/base"
require "logstash/namespace"
require "stud/buffer"
require "logstash/logAnalyticsClient/logstash_event_buffer"
require "logstash/logAnalyticsClient/logStashAutoResizeBuffer"
require "logstash/logAnalyticsClient/loganalytics_configuration"

class LogStash::Outputs::AzureLogAnalytics < LogStash::Outputs::Base

  config_name "azure_loganalytics"
  
  concurrency :shared

  # Your Operations Management Suite workspace ID
  config :workspace_id, :validate => :string, :required => true

  # The primary or the secondary Connected Sources client authentication key
  config :shared_key, :validate => :string, :required => true

  # The name of the event type that is being submitted to Log Analytics. 
  # This must be only alpha characters.
  config :log_type, :validate => :string, :required => true

  # The service endpoint (Default: ods.opinsights.azure.com)
  config :endpoint, :validate => :string, :default => 'ods.opinsights.azure.com'

  # The name of the time generated field.
  # Be carefule that the value of field should strictly follow the ISO 8601 format (YYYY-MM-DDThh:mm:ssZ)
  config :time_generated_field, :validate => :string, :default => ''

  # The list of key names in in-coming record that you want to submit to Log Analytics
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

  # Max number of items to buffer before flushing. Default 50.
  config :flush_items, :validate => :number, :default => 50
  
  # Max number of seconds to wait between flushes. Default 5
  config :flush_interval_time, :validate => :number, :default => 5

  public
  def register
    ## Configure
    if not @log_type.match(/^[[:alpha:]]+$/)
      raise ArgumentError, 'log_type must be only alpha characters' 
    end

    @key_types.each { |k, v|
      t = v.downcase
      if ( !t.eql?('string') && !t.eql?('double') && !t.eql?('boolean') ) 
        raise ArgumentError, "Key type(#{v}) for key(#{k}) must be either string, boolean, or double"
      end
    }

    @RESIZING_WINDOW = false

    ## Start 
    @logstash_configuration= LogStashConfiguration::new(@workspace_id, @shared_key, @log_type, @endpoint, @time_generated_field, @key_names, @key_types, @flush_items, @flush_interval_time)
    @logstash_event_buffer=LogStashAutoResizeBuffer::new(@logstash_configuration, @logger)
    @buffers = {}

  end # def register


  public 
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
  end

  public
  def multi_receive(events)
    events.each do |event|
      # creating document from event
      document = handle_single_event(event)
      # Skip if document doesn't contain any items
      next if (document.keys).length < 1
      # current_buffer = @buffers[Thread.current] != nil ?  @buffers[Thread.current] : add_buffer(Thread.current)
      # current_buffer.add_event_document2(document)

      @logstash_event_buffer.add_event_document2(document)

    end
  end # def receive


  private
  def convert_value(type, val)
    t = type.downcase
    case t
    when "boolean"
      v = val.downcase
      return (v.to_s == 'true' ) ? true : false
    when "double"
      return Integer(val) rescue Float(val) rescue val
    else
      return val
    end
  end

  private 
  def add_buffer(current_thread)
    thread_logstash_configuration = @logstash_configuration.copy()
    thread_logstashAutoResizeBuffer = LogStashAutoResizeBuffer::new(thread_logstash_configuration, @logger)
    @buffers[current_thread] = thread_logstashAutoResizeBuffer
    return thread_logstashAutoResizeBuffer
  end

end # class LogStash::Outputs::AzureLogAnalytics
