#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HASHES_FILE="$SCRIPT_DIR/hashes.json"

BASE_URL="https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases"

current_version=$(jq -r '.version' "$HASHES_FILE")
latest_version=$(curl -sfL "$BASE_URL/latest")

echo "Current: $current_version, Latest: $latest_version"

if [ "$current_version" = "$latest_version" ]; then
  echo "Already up to date"
  exit 0
fi

echo "Updating claude-code from $current_version to $latest_version"

manifest=$(curl -sfL "$BASE_URL/$latest_version/manifest.json")

declare -A PLATFORMS=(
  ["aarch64-darwin"]="darwin-arm64"
  ["x86_64-darwin"]="darwin-x64"
  ["aarch64-linux"]="linux-arm64"
  ["x86_64-linux"]="linux-x64"
)

hashes_json="{}"
for system in "${!PLATFORMS[@]}"; do
  key="${PLATFORMS[$system]}"
  checksum=$(echo "$manifest" | jq -r ".platforms[\"$key\"].checksum")
  sri_hash=$(nix --extra-experimental-features nix-command \
    hash convert --hash-algo sha256 --to sri "$checksum")
  echo "  $system: $sri_hash"
  hashes_json=$(echo "$hashes_json" | jq --arg p "$system" --arg h "$sri_hash" '.[$p] = $h')
done

jq -n \
  --arg v "$latest_version" \
  --argjson h "$hashes_json" \
  '{version: $v, hashes: $h}' > "$HASHES_FILE"

echo "Updated to $latest_version"
