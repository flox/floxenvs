#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HASHES_FILE="$SCRIPT_DIR/hashes.json"

STORAGE_BASE="https://static.ampcode.com/cli"

current_version=$(jq -r '.version' "$HASHES_FILE")
latest_version=$(curl -sfL "$STORAGE_BASE/cli-version.txt" | tr -d '[:space:]')

echo "Current: $current_version, Latest: $latest_version"

if [ "$current_version" = "$latest_version" ]; then
  echo "Already up to date"
  exit 0
fi

echo "Updating amp from $current_version to $latest_version"

declare -A PLATFORMS=(
  ["aarch64-darwin"]="darwin-arm64"
  ["aarch64-linux"]="linux-arm64"
  ["x86_64-darwin"]="darwin-x64"
  ["x86_64-linux"]="linux-x64"
)

hashes_json="{}"
for system in "${!PLATFORMS[@]}"; do
  amp_plat="${PLATFORMS[$system]}"
  hex=$(curl -sfL "$STORAGE_BASE/$latest_version/$amp_plat-amp.sha256" \
    | awk '{print $1}')
  sri=$(nix hash convert --hash-algo sha256 --to sri "$hex")
  echo "  $system: $sri"
  hashes_json=$(echo "$hashes_json" \
    | jq --arg p "$system" --arg h "$sri" '.[$p] = $h')
done

jq -n \
  --arg v "$latest_version" \
  --argjson h "$hashes_json" \
  '{version: $v, binaryHashes: ($h | to_entries | sort_by(.key) | from_entries)}' \
  > "$HASHES_FILE"

echo "Updated to $latest_version"
