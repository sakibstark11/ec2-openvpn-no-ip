set -e

sudo su
yum update -y
yum install -y git curl https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
yum install -y noip

systemctl enable noip.service

noip2 -C -u ${noip_username} -p ${noip_password}

systemctl start noip.service

su - ec2-user
curl -O ${openvpn_script}
chmod +x openvpn-install.sh

APPROVE_INSTALL=y ENDPOINT=${noip_domain} CLIENT=portable-network PASS=1 ./openvpn-install.sh
