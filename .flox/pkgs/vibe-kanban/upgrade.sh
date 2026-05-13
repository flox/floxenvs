#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HASHES_FILE="$SCRIPT_DIR/hashes.json"

current_version=$(jq -r '.version' "$HASHES_FILE")
current_tag=$(jq -r '.binaryTag' "$HASHES_FILE")

latest_version=$(curl -sfL \
  "https://npm-cdn.vibekanban.com/binaries/manifest.json" \
  | jq -r '.latest')

echo "Current: $current_version ($current_tag)"
echo "Latest: $latest_version"

# Find the binary tag for the latest version. Tags look like
# v<version>-<timestamp>, e.g. v0.1.44-20260424091429. Iterate
# recent releases (newest first) and pick the first one matching
# the latest version.
latest_tag=$(curl -sfL \
  "https://api.github.com/repos/BloopAI/vibe-kanban/releases?per_page=50" \
  | jq -r --arg v "$latest_version" \
      '[.[] | select(.tag_name | startswith("v" + $v + "-"))][0].tag_name')

if [ -z "$latest_tag" ] || [ "$latest_tag" = "null" ]; then
  echo "Could not find release tag for version $latest_version"
  exit 1
fi

if [ "$current_tag" = "$latest_tag" ]; then
  echo "Already up to date"
  exit 0
fi

echo "Updating vibe-kanban from $current_tag to $latest_tag"

manifest=$(curl -sfL \
  "https://npm-cdn.vibekanban.com/binaries/${latest_tag}/manifest.json")

declare -A PLATFORM_MAP=(
  ["aarch64-darwin"]="macos-arm64"
  ["x86_64-darwin"]="macos-x64"
  ["aarch64-linux"]="linux-arm64"
  ["x86_64-linux"]="linux-x64"
)

binaries_json="{}"
for bin in vibe-kanban vibe-kanban-mcp vibe-kanban-review; do
  bin_hashes="{}"
  for platform in "${!PLATFORM_MAP[@]}"; do
    upstream_platform="${PLATFORM_MAP[$platform]}"
    hex=$(echo "$manifest" \
      | jq -r --arg p "$upstream_platform" --arg b "$bin" \
          '.platforms[$p][$b].sha256')
    if [ -z "$hex" ] || [ "$hex" = "null" ]; then
      echo "Missing sha256 for $bin on $upstream_platform"
      exit 1
    fi
    sri=$(nix --extra-experimental-features nix-command \
      hash convert --hash-algo sha256 --to sri "$hex")
    echo "  $bin / $platform: $sri"
    bin_hashes=$(echo "$bin_hashes" \
      | jq --arg p "$platform" --arg h "$sri" '.[$p] = $h')
  done
  binaries_json=$(echo "$binaries_json" \
    | jq --arg b "$bin" --argjson h "$bin_hashes" '.[$b] = $h')
done

jq -n \
  --arg v "$latest_version" \
  --arg t "$latest_tag" \
  --argjson b "$binaries_json" \
  '{version: $v, binaryTag: $t, binaries: $b}' > "$HASHES_FILE"

echo "Updated to $latest_version ($latest_tag)"
