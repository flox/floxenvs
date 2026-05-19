#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HASHES_FILE="$SCRIPT_DIR/hashes.json"

current_version=$(jq -r '.version' "$HASHES_FILE")

latest_tag=$(curl -sfL \
  "https://api.github.com/repos/max-sixty/worktrunk/releases/latest" \
  | jq -r '.tag_name')
latest_version="${latest_tag#v}"

echo "Current: $current_version"
echo "Latest:  $latest_version"

if [ "$current_version" = "$latest_version" ]; then
  echo "Already up to date"
  exit 0
fi

echo "Updating worktrunk from $current_version to $latest_version"

# All four binary tarball checksums live in a single sha256.sum
# file in the release assets, one line per file.
sha256_sum=$(curl -sfL \
  "https://github.com/max-sixty/worktrunk/releases/download/v${latest_version}/sha256.sum")

declare -A PLATFORM_MAP=(
  ["aarch64-darwin"]="aarch64-apple-darwin"
  ["x86_64-darwin"]="x86_64-apple-darwin"
  ["aarch64-linux"]="aarch64-unknown-linux-musl"
  ["x86_64-linux"]="x86_64-unknown-linux-musl"
)

hashes_json="{}"
for platform in "${!PLATFORM_MAP[@]}"; do
  triple="${PLATFORM_MAP[$platform]}"
  file="worktrunk-${triple}.tar.xz"
  hex=$(echo "$sha256_sum" \
    | awk -v f="$file" '$2 == "*" f { print $1 }')
  if [ -z "$hex" ]; then
    echo "Missing sha256 for $file"
    exit 1
  fi
  sri=$(nix --extra-experimental-features nix-command \
    hash convert --hash-algo sha256 --to sri "$hex")
  echo "  $platform: $sri"
  hashes_json=$(echo "$hashes_json" \
    | jq --arg p "$platform" --arg h "$sri" '.[$p] = $h')
done

jq -n \
  --arg v "$latest_version" \
  --argjson h "$hashes_json" \
  '{version: $v, hashes: $h}' > "$HASHES_FILE"

echo "Updated to $latest_version"
