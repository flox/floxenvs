#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HASHES_FILE="$SCRIPT_DIR/hashes.json"

current_version=$(jq -r '.version' "$HASHES_FILE")
latest_version=$(curl -sfL https://registry.npmjs.org/@github/copilot \
  | jq -r '."dist-tags".latest')

echo "Current: $current_version, Latest: $latest_version"

if [ "$current_version" = "$latest_version" ]; then
  echo "Already up to date"
  exit 0
fi

echo "Updating copilot-cli from $current_version to $latest_version"

src_url="https://registry.npmjs.org/@github/copilot/-/copilot-${latest_version}.tgz"
echo "Fetching source from $src_url ..."
src_hash=$(nix-prefetch-url "$src_url" 2>/dev/null)
src_sri=$(nix hash convert --hash-algo sha256 --to sri "$src_hash")
echo "  srcHash: $src_sri"

jq -n \
  --arg v "$latest_version" \
  --arg s "$src_sri" \
  '{version: $v, srcHash: $s}' > "$HASHES_FILE"

echo "Updated to $latest_version"
