# blumira-osquery-config
Script to ease osquery deplyment with Blumira

Requirements:

git installed

auditd disabled

```
./osquery-deploy.sh -h

===== Blumira Osquery Deployment Utility =====

   -h --help see this help menu

   -d --distro provide the linux distro to deploy osquery on (supported options: ubuntu|rhel|centos)

   -s --server provide the server IP of the Blumira sensor to send syslog forwarding to
```

Example:
```
sudo osquery-deploy.sh -d ubuntu -s 172.16.1.100
```
