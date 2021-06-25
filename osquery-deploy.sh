#!/bin/bash

SENSOR_IP=""

DIST=$(. /etc/os-release && echo "$ID"| tr '[:upper:]' '[:lower:]')

dist_test_u(){
if [ $(echo $DIST | grep ubuntu| wc -m) -gt 0 ]; then
	echo "Ubuntu Distribution Found"
	apt update
	export OSQUERY_KEY=1484120AC4E9F8A1A577AEEE97A80C63C9D8B80B
	sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys $OSQUERY_KEY
	sudo add-apt-repository 'deb [arch=amd64] https://pkg.osquery.io/deb deb main'
	sudo apt-get update
	sudo apt-get install osquery
else
	echo "Not Ubuntu"
fi
}

dist_test_r(){
if [ $(echo $DIST | grep rhel| wc -m) -gt 0 ]; then
	echo "Red Hat Distribution Found"
	curl -L https://pkg.osquery.io/rpm/GPG | sudo tee /etc/pki/rpm-gpg/RPM-GPG-KEY-osquery
	sudo yum-config-manager --add-repo https://pkg.osquery.io/rpm/osquery-s3-rpm.repo
	sudo yum-config-manager --enable osquery-s3-rpm-repo
	sudo yum -y install osquery
else
	echo "Not Red Hat"
fi
}

config_osquery(){
git clone https://github.com/palantir/osquery-configuration.git
sudo cp -av osquery-configuration/Classic/Servers/Linux/* /etc/osquery/
sudo chown -R root. /etc/osquery/

sudo systemctl enable osqueryd.service
sudo systemctl start osqueryd.service
}

blumira_content(){
cat <<EOF
# Setup Disk Queues
\$WorkDirectory /var/spool/rsyslog # where to place spool files
\$ActionQueueFileName blumiraRule1 # unique name prefix for spool files
\$ActionQueueMaxDiskSpace 1g       # 1gb space limit (use as much as possible)
\$ActionQueueSaveOnShutdown on     # save messages to disk on shutdown
\$ActionQueueType LinkedList       # run asynchronously
\$ActionResumeRetryCount -1        # infinite retries if host is down

# Define BluFormat for parsing
\$template BluFormat,"<%pri%> BLUNIX %timestamp:::date-rfc3339% %HOSTNAME% %app-name% %procid% %msgid%%msg:::sp-if-no-1st-sp%%msg:::drop-last-lf%\n"

# Send messages to Blumira Sensor
# Be sure to change <sensor_ip> to your Sensor's IP
*.* @@$SENSOR_IP:514;BluFormat

# Run the following if wanting to use local output:
# sudo touch /var/log/blumira.log && sudo chmod 640 /var/log/blumira.log && sudo chown syslog:adm /var/log/blumira.log
# *.* /var/log/blumira.log;BluFormat # Local Debugging
EOF


}

blumira_syslog_check(){

if [ -f /etc/rsyslog.d/23-blumira.conf ];then
	echo "Blumira Sensor Configuration Found"
	sudo systemctl restart rsyslog.service
else
	blumira_content > /etc/rsyslog.d/23-blumira.conf
	if [ $(sudo ls /var/log/rsyslog | grep "No such file or directory" | wc -m) -gt 0 ];then
	sudo systemctl restart rsyslog.service
		else
		sudo mkdir -v /var/spool/rsyslog
		if [ "$(lsb_release -ds | grep Ubuntu)" != "" ]; then
   		sudo chown -R syslog:adm /var/spool/rsyslog
			fi
		sudo systemctl restart rsyslog.service
	fi
fi


}

syslog_content(){
cat <<EOF
# Prep
\$ModLoad imfile
\$InputFilePollInterval 10
\$PrivDropToGroup adm
\$WorkDirectory /var/spool/rsyslog

# Osquery Log File:
\$InputFileName /var/log/osquery/osqueryd.results.log
\$InputFileTag osqueryd:
\$InputFileStateFile stat-osquery
\$InputFileSeverity info
\$InputFilePersistStateInterval 20000
\$InputRunFileMonitor

# Tag, Forward to BLUNIX System Logger then Stop
if \$programname == 'osqueryd' then stop
EOF
}

syslog_config(){
   
syslog_content > /etc/rsyslog.d/osquery.conf

sudo chown syslog. /var/log/osquery/osqueryd.results.log
sudo systemctl restart rsyslog.service

}

### Main ###

## Find Dist

dist_test_u

dist_test_r

config_osquery

syslog_config

blumira_syslog_check

