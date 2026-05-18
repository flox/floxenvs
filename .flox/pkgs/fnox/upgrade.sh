#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HASHES_FILE="$SCRIPT_DIR/hashes.json"

# Authenticated API calls use Actions' 5000/hr quota. The
# unauthenticated 60/hr is shared per egress IP and gets exhausted
# by parallel runners, surfacing as `curl exit 22`.
auth_header=()
[ -n "${GITHUB_TOKEN:-}" ] \
  && auth_header=(-H "Authorization: Bearer $GITHUB_TOKEN")

current_version=$(jq -r '.version' "$HASHES_FILE")
latest_version=$(curl -sfL --retry 3 --retry-delay 5 \
  -H "Accept: application/vnd.github+json" \
  "${auth_header[@]}" \
  "https://api.github.com/repos/jdx/fnox/releases/latest" \
  | jq -r '.tag_name' | sed 's/^v//')

echo "Current: $current_version, Latest: $latest_version"

if [ "$current_version" = "$latest_version" ]; then
  echo "Already up to date"
  exit 0
fi

echo "Updating fnox from $current_version to $latest_version"

declare -A PLATFORM_MAP=(
  ["aarch64-darwin"]="aarch64-apple-darwin"
  ["x86_64-darwin"]="x86_64-apple-darwin"
  ["aarch64-linux"]="aarch64-unknown-linux-musl"
  ["x86_64-linux"]="x86_64-unknown-linux-musl"
)

binaries_json="{}"
for platform in "${!PLATFORM_MAP[@]}"; do
  target="${PLATFORM_MAP[$platform]}"
  url="https://github.com/jdx/fnox/releases/download/v${latest_version}/fnox-${target}.tar.gz"
  echo "Fetching $platform ($target) ..."
  hex=$(nix-prefetch-url "$url" 2>/dev/null)
  if [ -z "$hex" ]; then
    echo "ERROR: failed to prefetch $url" >&2
    exit 1
  fi
  sri=$(nix --extra-experimental-features nix-command \
    hash convert --hash-algo sha256 --to sri "$hex")
  echo "  $platform: $sri"
  binaries_json=$(echo "$binaries_json" \
    | jq --arg p "$platform" --arg h "$sri" '.[$p] = $h')
done

jq -n \
  --arg v "$latest_version" \
  --argjson b "$binaries_json" \
  '{version: $v, binaries: $b}' > "$HASHES_FILE"

echo "Updated to $latest_version"
