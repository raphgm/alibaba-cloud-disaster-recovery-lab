#!/usr/bin/env bash
# Wraps any of the numbered experiment scripts and appends its measured
# RTO to a results CSV, so repeated runs build up a real dataset instead
# of a one-off number.
#
# Usage: ./measure-rto.sh <scenario-name> <experiment-script> [args...]
# Example:
#   ./measure-rto.sh "ECS/node failure (before fix)" ./02-ecs-instance-failure.sh i-xxxxx node-1
set -euo pipefail

SCENARIO="${1:?Usage: $0 <scenario-name> <experiment-script> [args...]}"
shift
SCRIPT="${1:?Missing experiment script}"
shift

RESULTS_FILE="../results/rto-results-$(date +%F).csv"
mkdir -p "$(dirname "$RESULTS_FILE")"
[ -f "$RESULTS_FILE" ] || echo "timestamp,scenario,rto_seconds" > "$RESULTS_FILE"

OUTPUT=$("$SCRIPT" "$@")
echo "$OUTPUT"

RTO=$(echo "$OUTPUT" | grep -oE 'RTO: [0-9]+' | grep -oE '[0-9]+' | tail -1)
echo "$(date -u +%FT%TZ),${SCENARIO},${RTO}" >> "$RESULTS_FILE"

echo "Recorded to $RESULTS_FILE"
