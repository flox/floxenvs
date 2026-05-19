#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HASHES_FILE="$SCRIPT_DIR/hashes.json"

# This script only bumps the main mistral-vibe version + srcHash.
# Python dep overrides in default.nix (textual, pydantic-settings,
# mistralai, agent-client-protocol, otel) are pinned to versions that
# match the API contract upstream pins. If a new mistral-vibe release
# requires different dep versions, those hashes must be updated by
# hand alongside this script's output.

current_version=$(jq -r '.version' "$HASHES_FILE")
latest_tag=$(curl -sfL \
  https://api.github.com/repos/mistralai/mistral-vibe/releases/latest \
  | jq -r '.tag_name')
latest_version="${latest_tag#v}"

echo "Current: $current_version, Latest: $latest_version"

if [ "$current_version" = "$latest_version" ]; then
  echo "Already up to date"
  exit 0
fi

echo "Updating mistral-vibe from $current_version to $latest_version"

src_url="https://github.com/mistralai/mistral-vibe/archive/refs/tags/v${latest_version}.tar.gz"
echo "Fetching source from $src_url ..."
src_hash=$(nix-prefetch-url --unpack "$src_url" 2>/dev/null)
src_sri=$(nix hash convert --hash-algo sha256 --to sri "$src_hash")
echo "  srcHash: $src_sri"

jq -n \
  --arg v "$latest_version" \
  --arg s "$src_sri" \
  '{version: $v, srcHash: $s}' > "$HASHES_FILE"

echo "Updated to $latest_version"
echo "WARNING: Python dep overrides in default.nix may need" \
  "hand-updating to match new upstream constraints." >&2
