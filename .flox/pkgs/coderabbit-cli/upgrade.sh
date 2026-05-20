#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HASHES_FILE="$SCRIPT_DIR/hashes.json"

# CodeRabbit publishes the current CLI version at a stable endpoint.
# The official install.sh fetches this same VERSION file to detect latest.
VERSION_URL="https://cli.coderabbit.ai/releases/latest/VERSION"

current_version=$(jq -r '.version' "$HASHES_FILE")
latest_version=$(curl -sfL "$VERSION_URL" | tr -d '[:space:]')

echo "Current: $current_version, Latest: $latest_version"

if [ -z "$latest_version" ] || [ "$current_version" = "$latest_version" ]; then
  echo "Already up to date or could not detect latest"
  exit 0
fi

echo "Updating coderabbit-cli from $current_version to $latest_version"

declare -A PLATFORMS=(
  ["aarch64-darwin"]="darwin-arm64"
  ["aarch64-linux"]="linux-arm64"
  ["x86_64-darwin"]="darwin-x64"
  ["x86_64-linux"]="linux-x64"
)

hashes_json="{}"
for system in "${!PLATFORMS[@]}"; do
  suffix="${PLATFORMS[$system]}"
  url="https://cli.coderabbit.ai/releases/$latest_version/coderabbit-$suffix.zip"
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
