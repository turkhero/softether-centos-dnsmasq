#!/bin/bash
# Softether VPN Bridge with dnsmasq for Centos
# References:
# - https://gist.github.com/abegodong/15948f26c8683ab1f5be
SERVER_IP=""
SERVER_PASSWORD=""
SHARED_KEY=""
USER=""

echo -n "Enter Server IP: "
read SERVER_IP
echo -n "Set VPN Username to create: "
read USER
read -s -p "Set VPN Password: " SERVER_PASSWORD
echo ""
read -s -p "Set IPSec Shared Keys: " SHARED_KEY
echo ""
echo "+++ Now sit back and wait until the installation finished +++"
HUB="VPN"
HUB_PASSWORD=${SERVER_PASSWORD}
USER_PASSWORD=${SERVER_PASSWORD}
TARGET="/usr/local/"

yum update -y && yum groupinstall "Development Tools" -y && yum install kernel-devel -y
yum -y install wget dnsmasq expect gcc zlib-devel openssl-devel readline-devel ncurses-devel net-tools nano
sleep 2
wget https://www.softether-download.com/files/softether/v4.34-9745-rtm-2020.04.05-tree/Linux/SoftEther_VPN_Server/64bit_-_Intel_x64_or_AMD64/softether-vpnserver-v4.34-9745-rtm-2020.04.05-linux-x64-64bit.tar.gz
tar xzvf softether-vpnserver-v4.34-9745-rtm-2020.04.05-linux-x64-64bit.tar.gz -C $TARGET
rm -rf softether-vpnserver-v4.34-9745-rtm-2020.04.05-linux-x64-64bit.tar.gz
cd ${TARGET}vpnserver
expect -c 'spawn make; expect number:; send 1\r; expect number:; send 1\r; expect number:; send 1\r; interact'
find ${TARGET}vpnserver -type f -print0 | xargs -0 chmod 600
chmod 700 ${TARGET}vpnserver/vpnserver ${TARGET}vpnserver/vpncmd
mkdir -p /var/lock/subsys
echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.d/ipv4_forwarding.conf
sysctl --system
wget -P /etc/init.d https://raw.githubusercontent.com/turkhero/softether-installer/master/vpnserver
sed -i "s/\[SERVER_IP\]/${SERVER_IP}/g" /etc/init.d/vpnserver
chmod 755 /etc/init.d/vpnserver && /etc/init.d/vpnserver start
systemctl enable vpnserver
systemctl enable dnsmasq
${TARGET}vpnserver/vpncmd localhost /SERVER /CMD ServerPasswordSet ${SERVER_PASSWORD}
${TARGET}vpnserver/vpncmd localhost /SERVER /PASSWORD:${SERVER_PASSWORD} /CMD HubCreate ${HUB} /PASSWORD:${HUB_PASSWORD}
${TARGET}vpnserver/vpncmd localhost /SERVER /PASSWORD:${SERVER_PASSWORD} /HUB:${HUB} /CMD UserCreate ${USER} /GROUP:none /REALNAME:none /NOTE:none
${TARGET}vpnserver/vpncmd localhost /SERVER /PASSWORD:${SERVER_PASSWORD} /HUB:${HUB} /CMD UserPasswordSet ${USER} /PASSWORD:${USER_PASSWORD}
${TARGET}vpnserver/vpncmd localhost /SERVER /PASSWORD:${SERVER_PASSWORD} /CMD IPsecEnable /L2TP:yes /L2TPRAW:yes /ETHERIP:no /PSK:${SHARED_KEY} /DEFAULTHUB:${HUB}
${TARGET}vpnserver/vpncmd localhost /SERVER /PASSWORD:${SERVER_PASSWORD} /CMD BridgeCreate ${HUB} /DEVICE:soft /TAP:yes
#${TARGET}vpnserver/vpncmd localhost /SERVER /PASSWORD:${SERVER_PASSWORD} /HUB:${HUB} /CMD SecureNATEnable
#${TARGET}vpnserver/vpncmd localhost /SERVER /PASSWORD:${SERVER_PASSWORD} /HUB:${HUB} /CMD SecureNatHostSet /MAC:none /IP:10.0.13.1 /MASK:255.255.255.0
#${TARGET}vpnserver/vpncmd localhost /SERVER /PASSWORD:${SERVER_PASSWORD} /HUB:${HUB} /CMD DhcpSet /START:10.0.13.10 /END:10.0.13.254 /MASK:255.255.255.0 /EXPIRE:7200 /GW:10.0.13.1 /DNS:8.8.4.4 /DNS2:8.8.8.8 /DOMAIN:none /LOG:no
cat <<EOF >> /etc/dnsmasq.conf
interface=tap_soft
dhcp-range=tap_soft,10.0.13.10,10.0.13.254,12h
dhcp-option=tap_soft,3,10.0.13.1
EOF
service dnsmasq restart
service vpnserver restart
echo "+++ Installation finished +++"
