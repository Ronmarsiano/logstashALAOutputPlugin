
#! /usr/local/bin/python3

echo "Remove old gem file"

sudo rm logstash-output-azure_loganalytics-0.3.2.gem

echo "Pulling data from github"

git pull 

echo "Building new logstash plugin"

gem build logstash-output-azure_loganalytics.gemspec

cwd=$(pwd)

cd /usr/share/logstash

echo "Remove old plugin"

sudo /usr/share/logstash/bin/logstash-plugin remove logstash-output-azure_loganalytics

cd ${cwd}

echo "Install new plugin"

sudo /usr/share/logstash/bin/logstash-plugin install logstash-output-azure_loganalytics-0.3.2.gem

echo "Done"




