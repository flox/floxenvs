#!/usr/bin/env bash
# Scan the latest published image for an env.
# Usage: scripts/run-trivy.sh <kind> <name>
# Output: JSON array of findings on stdout.
# No-op for pkg kind; no-op when trivy is not on PATH;
# tolerates a missing image (returns []).
set -euo pipefail

KIND=${1:?kind (env|pkg) required}
NAME=${2:?name required}

# Only envs publish container images.
if [[ $KIND != env ]]; then
  echo "[]"
  exit 0
fi

if ! command -v trivy >/dev/null 2>&1; then
  echo "[]"
  exit 0
fi

ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || {
  echo "[]" # no-op: not a git repo
  exit 0
}
IMAGE="ghcr.io/flox/floxenvs/${NAME}-latest"

# `trivy image` may fail when the image isn't pushed yet
# (e.g. brand-new env). Treat as "no findings" so the
# audit pipeline keeps moving.
out=$(trivy image --quiet --format json --severity \
        CRITICAL,HIGH,MEDIUM,LOW \
        --no-progress \
        --timeout 5m \
        "$IMAGE" 2>/dev/null) \
  || { echo "[]"; exit 0; }

echo "$out" | "${ROOT}/scripts/lib/trivy-to-findings.sh"
