class LogAnalyticsClient
  API_VERSION = '2016-04-01'.freeze

  def initialize (workspace_id, shared_key,endpoint ='ods.opinsights.azure.com')
    require 'rest-client'
    require 'json'
    require 'openssl'
    require 'base64'
    require 'time'

    @workspace_id = workspace_id
    @shared_key = shared_key
    @endpoint = endpoint
    @uri = sprintf("https://%s.%s/api/logs?api-version=%s",
      @workspace_id, @endpoint, API_VERSION)

  end

  def 
    post_data(custom_log_table_name, body, record_timestamp ='')
    raise ConfigError, 'no json_records' if body.empty?

    header = get_header(custom_log_table_name, record_timestamp)
    response = RestClient.post(@uri, body, header)

    return response
  end

  def 
    get_header(custom_log_table_name,record_timestamp)
      return {
        'Content-Type' => 'application/json',
        'Authorization' => signature(date, body.bytesize),
        'Log-Type' => custom_log_table_name,
        'x-ms-date' => rfc1123date(),
        'time-generated-field' => record_timestamp
    }
  end

  def set_proxy(proxy='')
    RestClient.proxy = proxy.empty? ? ENV['http_proxy'] : proxy
  end

  def rfc1123date()
    current_time = Time.now
    current_time.httpdate()
  end

  def signature(date, content_length)

    sigs = sprintf("POST\n%d\napplication/json\nx-ms-date:%s\n/api/logs",
                  content_length, date)
    utf8_sigs = sigs.encode('utf-8')
    decoded_shared_key = Base64.decode64(@shared_key)
    hmac_sha256_sigs = OpenSSL::HMAC.digest(OpenSSL::Digest.new('sha256'), decoded_shared_key, utf8_sigs)
    encoded_hash = Base64.encode64(hmac_sha256_sigs)
    authorization = sprintf("SharedKey %s:%s", @workspace_id,encoded_hash)
  end

end # end of class