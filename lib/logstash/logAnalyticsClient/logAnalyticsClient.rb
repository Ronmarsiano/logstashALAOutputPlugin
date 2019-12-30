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

  end

  def post_data(custom_log_table_name, json_records, record_timestamp ='')
    print("\n\n\n\nstart posting\n\n\n\n ")
    print_message("Start posting")
    raise ConfigError, 'no custom_log_table_name' if custom_log_table_name.empty?
    raise ConfigError, 'custom_log_table_name must be only alpha characters' if not is_alpha(custom_log_table_name)
    raise ConfigError, 'no json_records' if json_records.empty?

    print_message("Config validated")

    body =  json_records
    uri = sprintf("https://%s.%s/api/logs?api-version=%s",
                  @workspace_id, @endpoint, API_VERSION)
    print_message("URI")
    date = rfc1123date()
    print_message("start sig")
    sig = signature(date, body.bytesize)
    print_message("end sig")

    headers = {
        'Content-Type' => 'application/json',
        'Authorization' => sig,
        'Log-Type' => custom_log_table_name,
        'x-ms-date' => date,
        'time-generated-field' => record_timestamp
    }

    print_message("start post")
    res = RestClient.post( uri, body, headers)
    print_message("End post")
    res
  end

  def set_proxy(proxy='')
    RestClient.proxy = proxy.empty? ? ENV['http_proxy'] : proxy
  end

  private
  def is_alpha(s)
    return (s.match(/^[[:alpha:]]+$/)) ? true : false
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


  public
  def print_message(message)
      print("\n" + message + "\n")
  end 

end # end of class