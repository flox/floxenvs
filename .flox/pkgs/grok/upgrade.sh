#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HASHES_FILE="$SCRIPT_DIR/hashes.json"

BASE_URL="https://storage.googleapis.com/grok-build-public-artifacts/cli"

current_version=$(jq -r '.version' "$HASHES_FILE")
latest_version=$(curl -sfL "$BASE_URL/stable" | tr -d '[:space:]')

echo "Current: $current_version, Latest: $latest_version"

if [ "$current_version" = "$latest_version" ]; then
  echo "Already up to date"
  exit 0
fi

echo "Updating grok from $current_version to $latest_version"

declare -A PLATFORMS=(
  ["aarch64-darwin"]="macos-aarch64"
  ["aarch64-linux"]="linux-aarch64"
  ["x86_64-linux"]="linux-x86_64"
)

hashes_json="{}"
for system in "${!PLATFORMS[@]}"; do
  suffix="${PLATFORMS[$system]}"
  url="$BASE_URL/grok-$latest_version-$suffix"
  echo "  fetching $system"
  hash=$(nix-prefetch-url "$url" 2>/dev/null)
  sri=$(nix hash convert --hash-algo sha256 --to sri "$hash")
  echo "    $system: $sri"
  hashes_json=$(echo "$hashes_json" \
    | jq --arg p "$system" --arg h "$sri" '.[$p] = $h')
done

jq -n \
  --arg v "$latest_version" \
  --argjson h "$hashes_json" \
  '{version: $v, hashes: ($h | to_entries | sort_by(.key) | from_entries)}' \
  > "$HASHES_FILE"

echo "Updated to $latest_version"
