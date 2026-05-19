#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HASHES_FILE="$SCRIPT_DIR/hashes.json"

current_version=$(jq -r '.version' "$HASHES_FILE")

latest_version=$(
  curl -sfL \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/repos/ogulcancelik/herdr/releases/latest" \
  | jq -r '.tag_name' \
  | sed 's/^v//'
)

echo "Current: $current_version, Latest: $latest_version"

if [ "$current_version" = "$latest_version" ]; then
  echo "Already up to date"
  exit 0
fi

echo "Updating herdr from $current_version to $latest_version"

declare -A PLATFORMS=(
  ["aarch64-darwin"]="macos-aarch64"
  ["x86_64-darwin"]="macos-x86_64"
  ["aarch64-linux"]="linux-aarch64"
  ["x86_64-linux"]="linux-x86_64"
)

base_url="https://github.com/ogulcancelik/herdr/releases/download/v${latest_version}"

hashes_json="{}"
for system in "${!PLATFORMS[@]}"; do
  suffix="${PLATFORMS[$system]}"
  url="${base_url}/herdr-${suffix}"
  raw=$(nix-prefetch-url "$url" 2>/dev/null)
  sri=$(nix --extra-experimental-features nix-command \
    hash convert --hash-algo sha256 --to sri "$raw")
  echo "  $system: $sri"
  hashes_json=$(echo "$hashes_json" \
    | jq --arg p "$system" --arg h "$sri" '.[$p] = $h')
done

jq -n \
  --arg v "$latest_version" \
  --argjson h "$hashes_json" \
  '{version: $v, hashes: ($h | to_entries | sort_by(.key) | from_entries)}' \
  > "$HASHES_FILE"

echo "Updated to $latest_version"
