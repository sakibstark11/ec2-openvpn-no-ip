#!/bin/bash

set -e

apt update
apt install -y gcc wget curl tar

wget https://dmej8g5cpdyqd.cloudfront.net/downloads/noip-duc_3.0.0.tar.gz
tar xf noip-duc_3.0.0.tar.gz
dpkg -i noip-duc_3.0.0/binaries/noip-duc_3.0.0_amd64.deb

# Configure noip-duc
sudo tee /etc/default/noip-duc >/dev/null << EOF
NOIP_USERNAME=${noip_username}
NOIP_PASSWORD=${noip_password}
NOIP_HOSTNAMES=all.ddnskey.com
EOF

# Setup noip-duc service
systemctl daemon-reload
systemctl enable noip-duc
systemctl start noip-duc

su admin
cd /home/admin

# Fetch openvpn-install.sh script
curl -O ${openvpn_script}
chmod +x openvpn-install.sh

# Setup openvpn-install.sh
su - admin -c "sudo APPROVE_INSTALL=y ENDPOINT=${noip_domain} CLIENT=portable-network APPROVE_IP=n IPV6_SUPPORT=n DNS=1 CUSTOMIZE_ENC=n COMPRESSION_ENABLED=n PORT_CHOICE=1 PROTOCOL_CHOICE=1 PASS=1 ./openvpn-install.sh"
