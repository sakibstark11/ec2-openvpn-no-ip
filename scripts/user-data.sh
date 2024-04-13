#!/bin/bash 

set -e

sudo su
yum update -y
yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
yum install -y noip

systemctl enable noip.service
noip2 -C -u ${noip_username} -p ${noip_password} -U 1
systemctl start noip.service

su - ec2-user
cd /home/ec2-user

curl -O ${openvpn_script}
chmod +x openvpn-install.sh

export APPROVE_INSTALL=y
export ENDPOINT=${noip_domain}
export CLIENT=portable-network
export PASS=1
export APPROVE_IP=n
export IPV6_SUPPORT=n
export PORT_CHOICE=1
export PROTOCOL_CHOICE=1
export DNS=1
export COMPRESSION_ENABLED=n
export CUSTOMIZE_ENC=n

./openvpn-install.sh
