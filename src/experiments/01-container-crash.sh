#!/usr/bin/env bash
# Experiment 1 — Container crash.
# Kills PID 1 in the target pod and times recovery to Running.
#
# Usage: ./01-container-crash.sh <pod-name> [namespace]
set -euo pipefail

POD="${1:?Usage: $0 <pod-name> [namespace]}"
NAMESPACE="${2:-default}"

echo "=== Experiment 1: Container Crash ==="
echo "Target: pod/$POD (namespace: $NAMESPACE)"

START=$(date +%s)
echo "[$(date -u +%H:%M:%S)] Killing PID 1 in $POD..."
kubectl exec -it "$POD" -n "$NAMESPACE" -- kill 1 || true

echo "Waiting for pod to report Running again..."
while true; do
  STATUS=$(kubectl get pod "$POD" -n "$NAMESPACE" -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
  if [ "$STATUS" == "Running" ]; then
    READY=$(kubectl get pod "$POD" -n "$NAMESPACE" -o jsonpath='{.status.containerStatuses[0].ready}' 2>/dev/null || echo "false")
    if [ "$READY" == "true" ]; then
      break
    fi
  fi
  sleep 1
done
END=$(date +%s)

echo "[$(date -u +%H:%M:%S)] Pod is Running and Ready."
echo "RTO: $((END - START)) seconds"
