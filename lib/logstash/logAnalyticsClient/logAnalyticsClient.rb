# encoding: utf-8
require "logstash/logAnalyticsClient/logstashLoganalyticsConfiguration"
require 'rest-client'
require 'json'
require 'openssl'
require 'base64'
require 'time'

class LogAnalyticsClient
  API_VERSION = '2016-04-01'.freeze

  def initialize (logstashLoganalyticsConfiguration)
    @logstashLoganalyticsConfiguration = logstashLoganalyticsConfiguration
    set_proxy(@logstashLoganalyticsConfiguration.proxy)
    @uri = sprintf("https://%s.%s/api/logs?api-version=%s", @logstashLoganalyticsConfiguration.workspace_id, @logstashLoganalyticsConfiguration.endpoint, API_VERSION)
  end

  def 
    post_data(custom_log_table_name, body, record_timestamp ='')
    raise ConfigError, 'no json_records' if body.empty?

    header = get_header(custom_log_table_name, record_timestamp, body.bytesize)
    response = RestClient.post(@uri, body, header)

    return response
  end

  def 
    get_header(custom_log_table_name,record_timestamp, body_bytesize_length)
      date = rfc1123date()

      return {
        'Content-Type' => 'application/json',
        'Authorization' => signature(date, body_bytesize_length),
        'Log-Type' => custom_log_table_name,
        'x-ms-date' => date,
        'time-generated-field' => record_timestamp,
        'x-ms-AzureResourceId' => '/subscriptions/78ffdd91-611e-402f-8a7e-7ab0b209b7c6/resourcegroups/cef/providers/microsoft.compute/virtualmachines/syslog-1'
      }
  end

  # Setting proxy for the REST client.
  # This option is not used in the output plugin and will be used 
  #  
  def set_proxy(proxy='')
    RestClient.proxy = proxy.empty? ? ENV['http_proxy'] : proxy
  end

  def rfc1123date()
    current_time = Time.now
    current_time.httpdate()
  end

  def signature(date, body_bytesize_length)
    sigs = sprintf("POST\n%d\napplication/json\nx-ms-date:%s\n/api/logs", body_bytesize_length, date)
    utf8_sigs = sigs.encode('utf-8')
    decoded_shared_key = Base64.decode64(@logstashLoganalyticsConfiguration.workspace_key)
    hmac_sha256_sigs = OpenSSL::HMAC.digest(OpenSSL::Digest.new('sha256'), decoded_shared_key, utf8_sigs)
    encoded_hash = Base64.encode64(hmac_sha256_sigs)
    authorization = sprintf("SharedKey %s:%s", @logstashLoganalyticsConfiguration.workspace_id, encoded_hash)
  end

end # end of class