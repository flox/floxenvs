#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HASHES_FILE="$SCRIPT_DIR/hashes.json"

current_version=$(jq -r '.version' "$HASHES_FILE")
latest_tag=$(curl -sfL \
  https://api.github.com/repos/tailcallhq/forgecode/releases/latest \
  | jq -r '.tag_name')
latest_version="${latest_tag#v}"

echo "Current: $current_version, Latest: $latest_version"

if [ "$current_version" = "$latest_version" ]; then
  echo "Already up to date"
  exit 0
fi

echo "Updating forgecode from $current_version to $latest_version"

declare -A PLATFORMS=(
  ["aarch64-darwin"]="aarch64-apple-darwin"
  ["aarch64-linux"]="aarch64-unknown-linux-gnu"
  ["x86_64-darwin"]="x86_64-apple-darwin"
  ["x86_64-linux"]="x86_64-unknown-linux-gnu"
)

hashes_json="{}"
for system in "${!PLATFORMS[@]}"; do
  triple="${PLATFORMS[$system]}"
  url="https://github.com/tailcallhq/forgecode/releases/download/v$latest_version/forge-$triple"
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
