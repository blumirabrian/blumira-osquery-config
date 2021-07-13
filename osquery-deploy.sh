#!/bin/bash

SENSOR_IP=""

DIST=$(. /etc/os-release && echo "$ID"| tr '[:upper:]' '[:lower:]')

have_git(){
	if [ $(which git| wc -m) -gt 0 ]; then
		echo "git found"
	else
		echo -e "\nError \n\nGit required to complete automated installation.\n\nPlease install Git and try again.\n"
		exit 0
	fi
}

dist_test_u(){
if [ $(echo $DIST | grep ubuntu| wc -m) -gt 0 ]; then
	echo "Ubuntu Distribution Found"
	apt update
	export OSQUERY_KEY=1484120AC4E9F8A1A577AEEE97A80C63C9D8B80B
	sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys $OSQUERY_KEY
	sudo add-apt-repository 'deb [arch=amd64] https://pkg.osquery.io/deb deb main'
	sudo apt-get update
	sudo apt-get install osquery
	if [ $(systemctl status auditd | grep running | wc -m) -gt 0 ]; then
		echo "Warning Auditd is running, you will need to disable for Osquery to be able to track Process Events."
	else
		echo
	fi

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
	if [ $(systemctl status auditd | grep running | wc -m) -gt 0 ]; then
		echo "Warning Auditd is running, you will need to disable for Osquery to be able to track Process Events."
	else
		echo
	fi
else
	echo "Not Red Hat"
fi
}

dist_test_c(){
if [ $(echo $DIST | grep centos| wc -m) -gt 0 ]; then
	echo "CentOS Distribution Found"
	curl -L https://pkg.osquery.io/rpm/GPG | sudo tee /etc/pki/rpm-gpg/RPM-GPG-KEY-osquery
	sudo yum-config-manager --add-repo https://pkg.osquery.io/rpm/osquery-s3-rpm.repo
	sudo yum-config-manager --enable osquery-s3-rpm-repo
	sudo yum -y install osquery
	if [ $(systemctl status auditd | grep running | wc -m) -gt 0 ]; then
		echo "Warning Auditd is running, you will need to disable for Osquery to be able to track Process Events."
	else
		echo
	fi

else
	echo "Not CentOS"
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

help_menu(){
echo -e "\n===== Blumira Osquery Deployment Utility =====\n"
echo -e "   -h --help see this help menu\n"
echo -e "   -d --distro provide the linux distro to deploy osquery on (supported options: ubuntu|rhel|centos)\n"
echo -e "   -s --server provide the server IP of the Blumira sensor to send syslog forwarding to\n"
echo -e "\n"
}

### Main ###

## Auto Deploy Niceness

TEMP=`getopt -o s:d:h:: --long server:,distro:,help:: -- "$@"`

while true; do
  case "$1" in
	-s|--server)
		SENSOR_IP=$2; shift 2;;
	-d|--distro)
		DIST=$2; shift 2
		if [ $(echo $DIST | grep ubuntu| wc -m) -gt 0 ]; then
			have_git
			dist_test_u
			## Osquery
			config_osquery
			## Syslog
			syslog_config
			blumira_syslog_check
			exit 0
		elif [ $(echo $DIST | grep rhel| wc -m) -gt 0 ]; then
				have_git
				dist_test_r
				## Osquery
				config_osquery
				## Syslog
				syslog_config
				blumira_syslog_check
				exit 0
		elif [ $(echo $DIST | grep centos| wc -m) -gt 0 ]; then
				have_git
				dist_test_c
				## Osquery
				config_osquery
				## Syslog
				syslog_config
				blumira_syslog_check
				exit 0
		else
				echo "No Supported Distro's Found"
		fi

		exit 0;;


	-h|--help)
		help_menu
	exit 0;;
	*)
	exit 0;;
esac
done

## Find Dist
have_git

dist_test_u

dist_test_r

dist_test_c

## Osquery

config_osquery

## Syslog

syslog_config

blumira_syslog_check

