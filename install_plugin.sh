
#! /usr/local/bin/python3


sudo rm logstash-output-azure_loganalytics-0.3.2.gem

gem build logstash-output-azure_loganalytics.gemspec

cwd=$(pwd)

cd /usr/share/logstash

sudo /usr/share/logstash/bin/logstash-plugin remove logstash-output-azure_loganalytics

cd ${cwd}

sudo /usr/share/logstash/bin/logstash-plugin install logstash-output-azure_loganalytics-0.3.2.gem

echo "Done"




