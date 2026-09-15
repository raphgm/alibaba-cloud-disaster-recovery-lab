#!/usr/bin/env bash
# Experiment 2 — ECS/node instance failure.
# Force-stops the ECS instance backing an ACK node and times until the
# autoscaler reschedules the evicted pods onto a healthy node.
#
# This is the experiment most likely to miss its RTO target on a
# default node pool config — see src/terraform/standby-buffer.tf for
# the fix that gets it from ~6m40s down to under a minute.
#
# Usage: ./02-ecs-instance-failure.sh <instance-id> <node-name>
set -euo pipefail

INSTANCE_ID="${1:?Usage: $0 <instance-id> <node-name>}"
NODE_NAME="${2:?Usage: $0 <instance-id> <node-name>}"

echo "=== Experiment 2: ECS/Node Instance Failure ==="
echo "Target: $INSTANCE_ID (node: $NODE_NAME)"

PODS_BEFORE=$(kubectl get pods --field-selector spec.nodeName="$NODE_NAME" -o name)
echo "Pods currently on this node:"
echo "$PODS_BEFORE"

START=$(date +%s)
echo "[$(date -u +%H:%M:%S)] Force-stopping instance..."
aliyun ecs StopInstance --InstanceId "$INSTANCE_ID" --ForceStop true

echo "Waiting for evicted pods to reschedule and reach Running elsewhere..."
while true; do
  ALL_RUNNING=true
  for pod in $PODS_BEFORE; do
    name="${pod#pod/}"
    NEW_NODE=$(kubectl get pod "$name" -o jsonpath='{.spec.nodeName}' 2>/dev/null || echo "")
    PHASE=$(kubectl get pod "$name" -o jsonpath='{.status.phase}' 2>/dev/null || echo "")
    if [ "$NEW_NODE" == "$NODE_NAME" ] || [ "$PHASE" != "Running" ]; then
      ALL_RUNNING=false
    fi
  done
  [ "$ALL_RUNNING" == "true" ] && break
  sleep 5
done
END=$(date +%s)

echo "[$(date -u +%H:%M:%S)] All pods rescheduled and Running."
echo "RTO: $((END - START)) seconds"
