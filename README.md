# Azure Log Analytics output plugin for Logstash 

Azure Sentinel provides a new output plugin for Logstash. Using this output plugin, you will be able to send any log you want using Logstash to the Azure Sentinel/Log Analytics workspace
Today you will be able to send messages to custom logs table that you will define in the output plugin. 
Getting started with Logstash 

Azure Sentinel output plugin uses the rest API integration to Log Analytics, in order to ingest the logs into custom logs tables [What are custom logs tables] 

Plugin version: v1.0.0 
Released on: 2020-04-30 

## Installation

Azure Sentinel provides Logstash output plugin to Log analytics workspace. 
Install the logstash-output-azure-loganalytics, use Logstash Working with plugins document. 
For offline setup follow Logstash Offline Plugin Management instruction. 

## Configuration

in your Logstash configuration file, add the Azure Sentinel output plugin to the configuration with following values: 
- workspace_id – your workspace ID guid 
- workspace_key – your workspace primary key guid 
- custom_log_table_name – table name, in which the logs will be ingested, limited to one table, the log table will be presented in the logs blade under the custom logs label, with a _CL suffix. 
- endpoint – Optional field by default set as log analytics endpoint.  
- time_generated_field – Optional field, this property is used to override the default TimeGenerated field in Log Analytics. Populate this property with the name of the sent data time field. 
- key_names – list of Log analytics output schema fields. 
- plugin_flash_interval – Optional filed, define the maximal time difference (in seconds) between sending two messages to Log Analytics. 
- Max_items – Optional field, 2000 by default. this parameter will control the maximum batch size. This value will be changed if the user didn’t specify “amount_resizing = false” in the configuration. 

Note: View the GitHub to learn more about the sent message’s configuration, performance settings and mechanism 

## Tests

Here is an example configuration who parse Syslog incoming data into a custom table named "logstashCustomTableName".

### Example Configuration
<u>Configuration</u>
```
input {
  tcp {
    port => 514
    type => syslog
  }
}

filter {
    grok {
      match => { "message" => "<%{NUMBER:PRI}>1 (?<TIME_TAG>[0-9]{4}-[0-9]{1,2}-[0-9]{1,2}T[0-9]{1,2}:[0-9]{1,2}:[0-9]{1,2})[^ ]* (?<HOSTNAME>[^ ]*) %{GREEDYDATA:MSG}" }
    }
}

output {
        logstash-output-azure-loganalytics {
                workspace_id => "<WS_ID>"
                workspace_key => "${WS_KEY}"
                custom_log_table_name => "logstashCustomTableName"
                key_names => ['PRI','TIME_TAG','HOSTNAME','MSG']
                plugin_flush_interval => 5
        }
}
```

### Run the plugin with the example configuration

Now you run logstash with the the example configuration like this:
```
# Test your logstash configuration before actually running the logstash
bin/logstash -f logstash-apache2-to-loganalytics.conf --configtest
# run
bin/logstash -f logstash-apache2-to-loganalytics.conf
```

Here is an expected output for sample input (Apache2 access log):

<u>Apache2 access log</u>
```
106.143.121.169 - - [29/Dec/2016:01:38:16 +0000] "GET /test.html HTTP/1.1" 304 179 "-" "Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/55.0.2883.87 Safari/537.36"
```

<u>Output (rubydebug)</u>
```
{
        "message" => "106.143.121.169 - - [29/Dec/2016:01:38:16 +0000] \"GET /test.html HTTP/1.1\" 304 179 \"-\" \"Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/55.0.2883.87 Safari/537.36\"",
       "@version" => "1",
     "@timestamp" => "2016-12-29T01:38:16.000Z",
           "path" => "/var/log/apache2/access.log",
           "host" => "host_name",
           "type" => "apache_access",
       "clientip" => "106.143.121.169",
          "ident" => "-",
           "auth" => "-",
      "timestamp" => "29/Dec/2016:01:38:16 +0000",
           "verb" => "GET",
        "request" => "/test.html",
    "httpversion" => "1.1",
       "response" => "304",
          "bytes" => "179",
       "referrer" => "\"-\"",
          "agent" => "\"Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/55.0.2883.87 Safari/537.36\""
}
```