#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HASHES_FILE="$SCRIPT_DIR/hashes.json"

current_tag=$(jq -r '.tag // empty' "$HASHES_FILE")
latest_tag=$(curl -sfL \
  "https://api.github.com/repos/NousResearch/hermes-agent/releases/latest" \
  | jq -r '.tag_name')

if [ -z "$latest_tag" ] || [ "$latest_tag" = "null" ]; then
  echo "ERROR: failed to fetch latest hermes-agent tag (rate limited?)" >&2
  exit 1
fi

echo "Current: $current_tag, Latest: $latest_tag"

if [ "$current_tag" = "$latest_tag" ]; then
  echo "Already up to date"
  exit 0
fi

echo "Updating hermes-agent to $latest_tag"

# The package builds via upstream's own nix/python.nix, so an upgrade
# is just the source pin: tag + hash of the unpacked tree. The flake
# prefetch narHash is the same SRI value fetchFromGitHub expects.
src_hash=$(nix --extra-experimental-features 'nix-command flakes' \
  flake prefetch --json "github:NousResearch/hermes-agent/$latest_tag" \
  | jq -r '.hash')

if [ -z "$src_hash" ] || [ "$src_hash" = "null" ]; then
  echo "ERROR: failed to prefetch source hash for $latest_tag" >&2
  exit 1
fi

latest_version="${latest_tag#v}"
jq -n \
  --arg v "$latest_version" \
  --arg t "$latest_tag" \
  --arg h "$src_hash" \
  '{version: $v, tag: $t, srcHash: $h}' > "$HASHES_FILE"

echo "Updated to $latest_tag"
