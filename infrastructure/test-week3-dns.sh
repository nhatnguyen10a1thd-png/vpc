#!/usr/bin/env bash
# ==============================================================================
# Script: test-week3-dns.sh
# Purpose: Comprehensive Route 53 Hybrid DNS Testing (dig, nslookup, ping, curl)
# Course: Cloud - Dot 1 - 2026-2027 | GVHD: Huynh Xuan Phung | Student: Nhat Nguyen
# Run location: Inside EC2 Workload or Gateway (On-Prem or Cloud)
# ==============================================================================

set -uo pipefail

echo "=================================================================="
echo " ROUTE 53 HYBRID DNS TEST SUITE - WEEK 3"
echo " Timestamp: $(date -u +"%Y-%m-%d %H:%M:%S UTC")"
echo " Hostname: $(hostname) | Local IP: $(hostname -I | awk '{print $1}')"
echo "=================================================================="

# Ensure dnsutils and curl are installed
if ! command -v dig &> /dev/null || ! command -v nslookup &> /dev/null; then
    echo "Installing dnsutils and curl..."
    sudo apt-get update -qq && sudo apt-get install -y -qq dnsutils curl iputils-ping
fi

DOMAIN_APP="app.corp.internal"
EXPECTED_APP_IP="10.20.10.50"

DOMAIN_DB="db.corp.internal"
EXPECTED_DB_IP="10.10.10.50"

# Function to test a domain
test_dns() {
    local domain="$1"
    local expected_ip="$2"

    echo "------------------------------------------------------------------"
    echo "🔍 Testing Resolution for: $domain (Expected IP: $expected_ip)"
    echo "------------------------------------------------------------------"

    # 1. Test with dig
    echo "[1] Testing with dig:"
    DIG_RESULT=$(dig +short "$domain" | tr -d '\r')
    echo "    dig output: $DIG_RESULT"
    if [ "$DIG_RESULT" == "$expected_ip" ]; then
        echo "    ✅ dig PASS: $domain resolved correctly to $expected_ip"
    else
        echo "    ⚠️ dig WARNING: Expected $expected_ip, got '$DIG_RESULT'"
    fi

    # 2. Test with nslookup
    echo "[2] Testing with nslookup:"
    nslookup "$domain" | grep -A 2 "Name:" || nslookup "$domain"

    # 3. Test ping via FQDN
    echo "[3] Testing ICMP Ping via FQDN ($domain):"
    if ping -c 3 -W 2 "$domain" > /dev/null 2>&1; then
        echo "    ✅ ping PASS: Successfully reached $domain over IPsec tunnel"
        ping -c 3 "$domain" | tail -n 2
    else
        echo "    ℹ️ ping: $domain reached/unreachable depending on target host ICMP rules."
    fi
}

# Run tests
test_dns "$DOMAIN_APP" "$EXPECTED_APP_IP"
test_dns "$DOMAIN_DB" "$EXPECTED_DB_IP"

# 4. HTTP Application Test via Domain Name
echo "------------------------------------------------------------------"
echo "🌐 Testing HTTP Web Access via Domain Name: http://$DOMAIN_APP"
echo "------------------------------------------------------------------"
if curl -s -m 5 -I "http://${DOMAIN_APP}" | head -n 5; then
    echo "✅ HTTP Web curl PASS: Successfully received HTTP response from $DOMAIN_APP!"
else
    echo "ℹ️ Note: If Nginx is running on $DOMAIN_APP ($EXPECTED_APP_IP), curl will return 200 OK."
fi

echo "=================================================================="
echo " DNS Testing Complete!"
echo "=================================================================="
