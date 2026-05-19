#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HASHES_FILE="$SCRIPT_DIR/hashes.json"

current_version=$(jq -r '.version' "$HASHES_FILE")
latest_tag=$(curl -sf \
  https://api.github.com/repos/rohitg00/agentmemory/releases/latest \
  | jq -r '.tag_name')
latest_version="${latest_tag#v}"

echo "Current: $current_version, Latest: $latest_version"

if [ "$current_version" = "$latest_version" ]; then
  echo "Already up to date"
  exit 0
fi

echo "Updating claude-code-plugin-agentmemory from $current_version to $latest_version"

src_url="https://github.com/rohitg00/agentmemory/archive/refs/tags/v${latest_version}.tar.gz"
echo "Fetching source from $src_url ..."
src_hash=$(nix-prefetch-url --unpack "$src_url" 2>/dev/null)
src_sri=$(nix --extra-experimental-features nix-command \
  hash convert --hash-algo sha256 --to sri "$src_hash")
echo "  srcHash: $src_sri"

jq -n \
  --arg v "$latest_version" \
  --arg s "$src_sri" \
  '{version: $v, srcHash: $s}' > "$HASHES_FILE"

# Keep AGENTMEMORY_VERSION in the agentmemory env in sync with
# the plugin tag. The npm package shipped under the same tag is
# what the plugin hooks talk to, so the two must move together.
env_manifest="$SCRIPT_DIR/../../../agentmemory/.flox/env/manifest.toml"
if [ -f "$env_manifest" ]; then
  sed -i.bak \
    -E "s/^AGENTMEMORY_VERSION = \"[^\"]*\"$/AGENTMEMORY_VERSION = \"$latest_version\"/" \
    "$env_manifest"
  rm -f "$env_manifest.bak"
  echo "Synced AGENTMEMORY_VERSION in $env_manifest"
fi

echo "Updated to $latest_version"
