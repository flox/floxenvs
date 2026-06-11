#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HASHES_FILE="$SCRIPT_DIR/hashes.json"

# Cursor publishes the current agent CLI version on their install page;
# the lab download URL embeds it after /lab/. The build suffix varies
# (e.g. <date>-<short-sha> or <date>-<hh>-<mm>-<ss>-<short-sha>), so
# match the whole path segment up to the next slash rather than a
# fixed shape.
VERSION_URL="https://cursor.com/install"
VERSION_RE='downloads\.cursor\.com/lab/[0-9]{4}\.[0-9]{2}\.[0-9]{2}-[0-9a-f-]+'

current_version=$(jq -r '.version' "$HASHES_FILE")
latest_version=$(curl -sfL "$VERSION_URL" \
  | grep -oE "$VERSION_RE" | head -1 \
  | sed -E "s|.*/lab/||")

echo "Current: $current_version, Latest: $latest_version"

if [ "$current_version" = "$latest_version" ]; then
  echo "Already up to date"
  exit 0
fi

echo "Updating cursor-agent from $current_version to $latest_version"

declare -A PLATFORMS=(
  ["aarch64-darwin"]="darwin/arm64"
  ["aarch64-linux"]="linux/arm64"
  ["x86_64-darwin"]="darwin/x64"
  ["x86_64-linux"]="linux/x64"
)

hashes_json="{}"
for system in "${!PLATFORMS[@]}"; do
  key="${PLATFORMS[$system]}"
  url="https://downloads.cursor.com/lab/$latest_version/$key/agent-cli-package.tar.gz"
  echo "  fetching $system from $url"
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
