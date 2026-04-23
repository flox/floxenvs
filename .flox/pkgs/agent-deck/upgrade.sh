#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HASHES_FILE="$SCRIPT_DIR/hashes.json"

current_version=$(jq -r '.version' "$HASHES_FILE")
latest_tag=$(curl -sf \
  https://api.github.com/repos/asheshgoplani/agent-deck/releases/latest \
  | jq -r '.tag_name')
latest_version="${latest_tag#v}"

echo "Current: $current_version, Latest: $latest_version"

if [ "$current_version" = "$latest_version" ]; then
  echo "Already up to date"
  exit 0
fi

echo "Updating agent-deck from $current_version to $latest_version"

# Download and hash the new source tarball
src_url="https://github.com/asheshgoplani/agent-deck/archive/refs/tags/v${latest_version}.tar.gz"
echo "Fetching source from $src_url ..."
src_hash=$(nix-prefetch-url --unpack "$src_url" 2>/dev/null)
src_sri=$(nix hash convert --hash-algo sha256 --to sri "$src_hash")
echo "  srcHash: $src_sri"

# Write with dummy vendorHash so flox build can compute the real one
dummy_hash="sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
jq -n \
  --arg v "$latest_version" \
  --arg s "$src_sri" \
  --arg h "$dummy_hash" \
  '{version: $v, srcHash: $s, vendorHash: $h}' > "$HASHES_FILE"

echo "Building with dummy vendorHash to compute real one..."
vendor_hash=$(flox build agent-deck 2>&1 \
  | grep "got:" \
  | head -1 \
  | awk '{print $2}') || true

if [ -z "$vendor_hash" ]; then
  echo "ERROR: Could not extract vendorHash from build output"
  exit 1
fi

echo "  vendorHash: $vendor_hash"

# Write final hashes
jq -n \
  --arg v "$latest_version" \
  --arg s "$src_sri" \
  --arg h "$vendor_hash" \
  '{version: $v, srcHash: $s, vendorHash: $h}' > "$HASHES_FILE"

echo "Updated to $latest_version"
