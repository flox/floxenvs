#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HASHES_FILE="$SCRIPT_DIR/hashes.json"

current_version=$(jq -r '.version' "$HASHES_FILE")

latest_version=$(curl -sfL 'https://go.dev/dl/?mode=json' \
  | jq -r '[.[0].version][0]' \
  | sed 's/^go//')

echo "Current: $current_version, Latest: $latest_version"

if [ "$current_version" = "$latest_version" ]; then
  echo "Already up to date"
  exit 0
fi

echo "Updating go from $current_version to $latest_version"

declare -A PLATFORMS=(
  ["aarch64-darwin"]="darwin-arm64"
  ["aarch64-linux"]="linux-arm64"
  ["x86_64-linux"]="linux-amd64"
)

hashes_json="{}"
for system in "${!PLATFORMS[@]}"; do
  suffix="${PLATFORMS[$system]}"
  sha256=$(curl -sfL 'https://go.dev/dl/?mode=json' \
    | jq -r --arg fn "go${latest_version}.${suffix}.tar.gz" \
      '[.[0].files[] | select(.filename == $fn)][0].sha256')
  sri_hash=$(nix hash convert --hash-algo sha256 --to sri "$sha256")
  echo "  $system: $sri_hash"
  hashes_json=$(echo "$hashes_json" | jq --arg p "$system" --arg h "$sri_hash" '.[$p] = $h')
done

jq -n \
  --arg v "$latest_version" \
  --argjson h "$hashes_json" \
  '{version: $v, hashes: ($h | to_entries | sort_by(.key) | from_entries)}' \
  > "$HASHES_FILE"

echo "Updated to $latest_version"
