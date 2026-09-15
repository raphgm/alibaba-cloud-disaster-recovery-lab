#!/usr/bin/env bash
# Experiment 3 — Data loss (OSS).
# Deletes a versioned OSS object, then restores it from the previous
# version and times the recovery. Requires bucket versioning to already
# be enabled (see src/terraform/main.tf).
#
# Usage: ./03-data-loss-oss.sh oss://bucket-name/path/to/object.json
set -euo pipefail

OBJECT_URI="${1:?Usage: $0 oss://bucket-name/path/to/object.json}"

echo "=== Experiment 3: Data Loss (OSS) ==="
echo "Target: $OBJECT_URI"

echo "Current versions before deletion:"
ossutil api list-object-versions --bucket "$(echo "$OBJECT_URI" | sed -E 's#oss://([^/]+)/.*#\1#')" \
  --prefix "$(echo "$OBJECT_URI" | sed -E 's#oss://[^/]+/(.*)#\1#')" || true

START=$(date +%s)
echo "[$(date -u +%H:%M:%S)] Deleting object..."
ossutil rm "$OBJECT_URI"

echo "Object deleted. Fetching previous version ID to restore from..."
BUCKET=$(echo "$OBJECT_URI" | sed -E 's#oss://([^/]+)/.*#\1#')
KEY=$(echo "$OBJECT_URI" | sed -E 's#oss://[^/]+/(.*)#\1#')

PREVIOUS_VERSION=$(ossutil api list-object-versions --bucket "$BUCKET" --prefix "$KEY" \
  --query "Versions[?IsLatest==\`false\`] | [0].VersionId" -o tsv 2>/dev/null || echo "")

if [ -z "$PREVIOUS_VERSION" ]; then
  echo "No previous version found — was versioning enabled before this object was created?"
  exit 1
fi

echo "[$(date -u +%H:%M:%S)] Restoring version $PREVIOUS_VERSION..."
ossutil cp "oss://${BUCKET}/${KEY}?versionId=${PREVIOUS_VERSION}" "$OBJECT_URI"

END=$(date +%s)
echo "[$(date -u +%H:%M:%S)] Object restored."
echo "RTO: $((END - START)) seconds"
