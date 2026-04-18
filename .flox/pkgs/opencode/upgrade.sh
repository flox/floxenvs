#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HASHES_FILE="$SCRIPT_DIR/hashes.json"

current_version=$(jq -r '.version' "$HASHES_FILE")
latest_version=$(curl -sfL "https://api.github.com/repos/anomalyco/opencode/releases/latest" | jq -r '.tag_name' | sed 's/^v//')

echo "Current: $current_version, Latest: $latest_version"

if [ "$current_version" = "$latest_version" ]; then
  echo "Already up to date"
  exit 0
fi

echo "Updating opencode from $current_version to $latest_version"

declare -A ASSETS=(
  ["aarch64-darwin"]="opencode-darwin-arm64.zip"
  ["x86_64-darwin"]="opencode-darwin-x64.zip"
  ["x86_64-linux"]="opencode-linux-x64.tar.gz"
  ["aarch64-linux"]="opencode-linux-arm64.tar.gz"
)

hashes_json="{}"
for platform in "${!ASSETS[@]}"; do
  asset="${ASSETS[$platform]}"
  url="https://github.com/anomalyco/opencode/releases/download/v${latest_version}/${asset}"
  echo "Fetching hash for $platform from $url ..."
  raw_hash=$(nix-prefetch-url --type sha256 "$url" 2>/dev/null)
  sri_hash=$(nix hash convert --hash-algo sha256 --to sri "$raw_hash")
  echo "  $platform: $sri_hash"
  hashes_json=$(echo "$hashes_json" | jq --arg p "$platform" --arg h "$sri_hash" '.[$p] = $h')
done

jq -n \
  --arg v "$latest_version" \
  --argjson h "$hashes_json" \
  '{version: $v, hashes: $h}' > "$HASHES_FILE"

echo "Updated to $latest_version"
