#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HASHES_FILE="$SCRIPT_DIR/hashes.json"

current_version=$(jq -r '.version' "$HASHES_FILE")

# Upstream publishes multiple tag tracks (skill-v*, ext-v*, cli-v*), and
# `releases/latest` may point at a non-skill track. List tags and pick the
# highest `skill-v*` semver explicitly.
auth_header=()
if [ -n "${GITHUB_TOKEN:-}" ]; then
  auth_header=(-H "Authorization: Bearer $GITHUB_TOKEN")
fi
latest_version=$(curl -sf "${auth_header[@]}" \
  https://api.github.com/repos/pbakaus/impeccable/tags \
  | jq -r '.[].name | select(startswith("skill-v")) | ltrimstr("skill-v")' \
  | sort -V | tail -1)

if [ -z "$latest_version" ]; then
  echo "ERROR: no skill-v* tags found" >&2
  exit 1
fi

echo "Current: $current_version, Latest: $latest_version"

if [ "$current_version" = "$latest_version" ]; then
  echo "Already up to date"
  exit 0
fi

echo "Updating claude-code-plugin-impeccable from $current_version to $latest_version"

src_url="https://github.com/pbakaus/impeccable/archive/refs/tags/skill-v${latest_version}.tar.gz"
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
