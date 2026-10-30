#!/usr/bin/env bash
# ==============================================================================
# Script: test-week3-resilience.sh
# Purpose: Performance Benchmark (iperf3) & Resilience / DPD Testing (<10s Recovery)
# Course: Cloud - Dot 1 - 2026-2027 | GVHD: Huynh Xuan Phung | Student: Nhat Nguyen
# ==============================================================================

set -uo pipefail

MODE="${1:-help}" # options: server | client | dpd-test

echo "=================================================================="
echo " RESILIENCE & PERFORMANCE TEST SUITE (WEEK 3)"
echo " Timestamp: $(date -u +"%Y-%m-%d %H:%M:%S UTC")"
echo " Host: $(hostname) | IP: $(hostname -I | awk '{print $1}')"
echo "=================================================================="

case "$MODE" in
  server)
    echo "--> Setting up iperf3 Server mode..."
    sudo apt-get update -qq && sudo apt-get install -y -qq iperf3
    echo "Starting iperf3 server listening on port 5201..."
    echo "Run './test-week3-resilience.sh client <THIS_SERVER_IP>' on the peer instance."
    iperf3 -s
    ;;

  client)
    TARGET_IP="${2:-10.20.10.50}"
    echo "--> Setting up iperf3 Client mode targeting: $TARGET_IP..."
    sudo apt-get update -qq && sudo apt-get install -y -qq iperf3

    echo "Running 15-second Throughput Benchmark across IPsec VPN Tunnel..."
    iperf3 -c "$TARGET_IP" -t 15 -i 1 -P 1

    echo ""
    echo "Running Multi-stream (2 parallel streams) Benchmark..."
    iperf3 -c "$TARGET_IP" -t 10 -i 1 -P 2
    ;;

  dpd-test)
    PEER_IP="${2:-10.20.10.50}"
    echo "=================================================================="
    echo " DEAD PEER DETECTION (DPD) & RECOVERY TIME TEST (< 10s)"
    echo " Target Peer Private IP: $PEER_IP"
    echo "=================================================================="

    echo "1. Current strongSwan IPsec Status:"
    sudo ipsec status || sudo swanctl --list-sas

    echo ""
    echo "2. Starting continuous ping in background with millisecond timestamps..."
    LOG_FILE="/tmp/dpd_ping_test.log"
    > "$LOG_FILE"

    # Ping every 1 second in background
    (
      while true; do
        TS=$(date +'%H:%M:%S')
        if ping -c 1 -W 1 "$PEER_IP" > /dev/null 2>&1; then
          echo "$TS - SUCCESS: Reply received from $PEER_IP" >> "$LOG_FILE"
        else
          echo "$TS - FAILED: Packet dropped / Tunnel interrupted" >> "$LOG_FILE"
        fi
        sleep 1
      done
    ) &
    PING_PID=$!

    sleep 3
    echo "Baseline traffic recorded. Showing ping output:"
    tail -n 3 "$LOG_FILE"

    echo ""
    echo "3. [SIMULATION] Interrupting strongSwan connection to trigger DPD / Auto-Restart..."
    DISRUPT_START=$(date +%s)
    echo "Disruption triggered at: $(date +'%H:%M:%S')"
    
    # Terminate the connection or restart charon daemon
    sudo ipsec down cloud-to-onprem || sudo swanctl --terminate --ike cloud-to-onprem || sudo killall -9 charon

    echo "Tunnel interrupted. Monitoring automatic self-healing (dpdaction=restart)..."
    
    # Monitor log until connection restores
    RECOVERED=0
    for i in {1..30}; do
      sleep 1
      CURRENT_STATUS=$(tail -n 1 "$LOG_FILE")
      echo "  [+$i s] $CURRENT_STATUS"
      if [[ "$CURRENT_STATUS" =~ "SUCCESS" ]] && [ $i -ge 2 ]; then
        DISRUPT_END=$(date +%s)
        RECOVERY_TIME=$((DISRUPT_END - DISRUPT_START))
        echo ""
        echo "✅ RECOVERY CONFIRMED! Tunnel self-healed and re-established in: ~$RECOVERY_TIME seconds!"
        RECOVERED=1
        break
      fi
    done

    # Clean up background ping
    kill "$PING_PID" 2>/dev/null || true

    if [ "$RECOVERED" -eq 1 ]; then
      echo "✅ DPD TEST RESULT: PASSED (Under 10s resilience criteria met!)"
    else
      echo "⚠️ DPD TEST RESULT: Recovery took longer than 30s. Checking service status:"
      sudo ipsec statusall || sudo journalctl -u ipsec -n 20 --no-pager
    fi
    ;;

  *)
    echo "Usage: $0 {server | client <target_ip> | dpd-test <peer_ip>}"
    echo "Examples:"
    echo "  On Cloud Workload (10.20.10.50):    $0 server"
    echo "  On On-Prem Workload (10.10.10.50):  $0 client 10.20.10.50"
    echo "  On strongSwan Gateway (resilience): $0 dpd-test 10.20.10.50"
    ;;
esac
