
#! /usr/local/bin/python3

echo Install Java

sudo apt-get update

sudo apt install openjdk-11-jre-headless

echo Download and install the Public Signing Key

wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add -

echo Save the repository definition to /etc/apt/sources.list.d/elastic-7.x.list

echo "deb https://artifacts.elastic.co/packages/7.x/apt stable main" | sudo tee -a /etc/apt/sources.list.d/elastic-7.x.list

echo "update"

sudo apt-get update

echo "install logstash"

sudo apt-get install logstash

echo "Try to update\\install ruby"

sudo apt  install ruby

echo "Starting logstash service in 3 seconds"

sleep 3

sudo systemctl start logstash.service

echo "Remove old gem file"

sudo rm logstash-output-azure-loganalytics-1.0.0.gem

echo "Pulling data from github"

git pull 

echo "Building new logstash plugin"

gem build logstash-output-azure-loganalytics.gemspec

cwd=$(pwd)

cd /usr/share/logstash

echo "Remove old plugin"

sudo /usr/share/logstash/bin/logstash-plugin remove logstash-output-azure-loganalytics

cd ${cwd}

echo "Install new plugin"

sudo /usr/share/logstash/bin/logstash-plugin install logstash-output-azure-loganalytics-1.0.0.gem

echo "Done"

sudo /usr/share/logstash/bin/logstash -f  /etc/logstash/logstash-syslog.conf --path.settings /etc/logstash/




