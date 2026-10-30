#!/usr/bin/env bash
# ==============================================================================
# Script: setup-workload.sh
# Purpose: Setup Workload Host (Nginx Web Server, iperf3, Diagnostic Utilities)
# Course: Cloud - Dot 1 - 2026-2027 | GVHD: Huynh Xuan Phung | Student: Nhat Nguyen
# Usage: sudo ./setup-workload.sh <ROLE: onprem-workload|cloud-workload>
# ==============================================================================

set -euo pipefail

ROLE="${1:-cloud-workload}"
PRIVATE_IP=$(hostname -I | awk '{print $1}')
HOSTNAME=$(hostname)

echo "=========================================================="
echo " [1/3] Updating packages & installing test applications..."
echo "=========================================================="
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y nginx iperf3 curl net-tools iputils-ping dnsutils traceroute

echo "=========================================================="
echo " [2/3] Configuring Sample Nginx Web Service..."
echo "=========================================================="
systemctl enable nginx
systemctl start nginx

cat << EOF > /var/www/html/index.html
<!DOCTYPE html>
<html lang="vi">
<head>
    <meta charset="UTF-8">
    <title>Hybrid Cloud VPN Workload - $ROLE</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: #0f172a; color: #f8fafc; padding: 40px; }
        .card { background: #1e293b; border-radius: 12px; padding: 30px; max-width: 700px; margin: auto; box-shadow: 0 10px 25px rgba(0,0,0,0.5); border: 1px solid #334155; }
        h1 { color: #38bdf8; margin-top: 0; font-size: 24px; }
        .badge { background: #0284c7; color: white; padding: 4px 10px; border-radius: 6px; font-weight: bold; font-size: 13px; }
        .info { background: #0f172a; padding: 15px; border-radius: 8px; margin-top: 20px; font-family: monospace; font-size: 14px; line-height: 1.6; border-left: 4px solid #38bdf8; }
        .status { color: #4ade80; font-weight: bold; }
    </style>
</head>
<body>
    <div class="card">
        <h1>🌐 Mạng Lai Hybrid Cloud - Workload Server</h1>
        <p><span class="badge">$ROLE</span> &nbsp; Trạng thái kết nối VPN: <span class="status">HOẠT ĐỘNG TỐT (ACTIVE)</span></p>
        <div class="info">
            <strong>Server Hostname:</strong> $HOSTNAME<br>
            <strong>Private IP Address:</strong> $PRIVATE_IP<br>
            <strong>Protocol:</strong> IPsec IKEv2 / ESP (AES-256-GCM)<br>
            <strong>Đề tài:</strong> Mô phỏng trung tâm dữ liệu On-Premises bằng strongSwan kết nối Cloud<br>
            <strong>GVHD:</strong> Huỳnh Xuân Phụng | <strong>Sinh viên:</strong> Nhat Nguyen
        </div>
    </div>
</body>
</html>
EOF

echo "=========================================================="
echo " [3/3] Starting iperf3 background listener daemon..."
echo "=========================================================="
killall iperf3 2>/dev/null || true
iperf3 -s -D

echo "=========================================================="
echo " Workload Setup Completed for: $ROLE"
echo " Private IP: $PRIVATE_IP"
echo " HTTP Server: Listening on port 80"
echo " iperf3 Server: Listening in background on port 5201"
echo "=========================================================="
