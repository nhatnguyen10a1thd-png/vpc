#!/usr/bin/env bash
# ==============================================================================
# Script: setup-gateway.sh
# Purpose: Automated strongSwan Gateway installation, Kernel Tuning & MSS Clamping
# Course: Cloud - Dot 1 - 2026-2027 | GVHD: Huynh Xuan Phung | Student: Nhat Nguyen
# Usage: sudo ./setup-gateway.sh <LOCAL_EIP> <REMOTE_EIP> <LOCAL_CIDR> <REMOTE_CIDR> <ROLE: onprem|cloud>
# ==============================================================================

set -euo pipefail

if [ "$#" -lt 5 ]; then
    echo "Usage: sudo $0 <LOCAL_EIP> <REMOTE_EIP> <LOCAL_CIDR> <REMOTE_CIDR> <onprem|cloud>"
    echo "Example: sudo $0 54.200.10.10 3.210.20.20 10.10.0.0/16 10.20.0.0/16 onprem"
    exit 1
fi

LOCAL_EIP="$1"
REMOTE_EIP="$2"
LOCAL_CIDR="$3"
REMOTE_CIDR="$4"
ROLE="$5"

echo "=========================================================="
echo " [1/5] Updating packages and installing strongSwan suite..."
echo "=========================================================="
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y strongswan strongswan-pki libcharon-extra-plugins iptables-persistent net-tools tcpdump traceroute iperf3

echo "=========================================================="
echo " [2/5] Configuring Linux Kernel IP Forwarding (sysctl)..."
echo "=========================================================="
cat << 'EOF' > /etc/sysctl.d/99-ipsec.conf
net.ipv4.ip_forward = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.rp_filter = 2
net.ipv4.conf.all.rp_filter = 2
EOF

sysctl -p /etc/sysctl.d/99-ipsec.conf

echo "=========================================================="
echo " [3/5] Configuring TCP MSS Clamping via iptables..."
echo "=========================================================="
iptables -t mangle -C FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu 2>/dev/null || \
iptables -t mangle -A FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu

# Save iptables rules across reboots
netfilter-persistent save || true

echo "=========================================================="
echo " [4/5] Generating /etc/ipsec.conf & /etc/ipsec.secrets..."
echo "=========================================================="
cat << EOF > /etc/ipsec.conf
# strongSwan IPsec configuration ($ROLE)
config setup
    charondebug="ike 2, knl 2, cfg 2, net 2, esp 2"
    uniqueids=yes

conn %default
    ikelifetime=28800s
    keylife=3600s
    rekeymargin=3m
    keyingtries=%forever
    keyexchange=ikev2
    authby=secret
    dpddelay=30s
    dpdtimeout=120s
    dpdaction=restart

conn site-to-site-tunnel
    left=%defaultroute
    leftid=$LOCAL_EIP
    leftsubnet=$LOCAL_CIDR
    leftfirewall=yes

    right=$REMOTE_EIP
    rightid=$REMOTE_EIP
    rightsubnet=$REMOTE_CIDR

    ike=aes256-sha256-modp2048!
    esp=aes256-sha256-modp2048!
    auto=start
EOF

cat << EOF > /etc/ipsec.secrets
$LOCAL_EIP $REMOTE_EIP : PSK "VpcCloudDot1@20262027StrongSwanSecretKey"
EOF

chmod 600 /etc/ipsec.secrets

echo "=========================================================="
echo " [5/5] Restarting strongSwan service..."
echo "=========================================================="
systemctl restart strongswan-starter || systemctl restart strongswan
sleep 2

echo "Checking strongSwan status:"
ipsec statusall || swanctl --list-sas

echo "=========================================================="
echo " Gateway configuration completed successfully for: $ROLE"
echo " Local EIP: $LOCAL_EIP | Remote EIP: $REMOTE_EIP"
echo "=========================================================="
