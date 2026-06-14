#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HASHES_FILE="$SCRIPT_DIR/hashes.json"

current_version=$(jq -r '.version' "$HASHES_FILE")

# Upstream tags releases as bare `X.Y.Z` (no `v` prefix).
latest_version=$(curl -sf \
  https://api.github.com/repos/addyosmani/agent-skills/releases/latest \
  | jq -r '.tag_name')

echo "Current: $current_version, Latest: $latest_version"

if [ "$current_version" = "$latest_version" ]; then
  echo "Already up to date"
  exit 0
fi

echo "Updating claude-code-plugin-agent-skills from $current_version to $latest_version"

src_url="https://github.com/addyosmani/agent-skills/archive/refs/tags/${latest_version}.tar.gz"
echo "Fetching source from $src_url ..."
src_hash=$(nix-prefetch-url --unpack "$src_url" 2>/dev/null)
src_sri=$(nix --extra-experimental-features nix-command \
  hash convert --hash-algo sha256 --to sri "$src_hash")
echo "  srcHash: $src_sri"

jq -n \
  --arg v "$latest_version" \
  --arg s "$src_sri" \
  '{version: $v, srcHash: $s}' > "$HASHES_FILE"

echo "Updated to $latest_version"
