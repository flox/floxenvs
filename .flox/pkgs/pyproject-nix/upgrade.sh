#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HASHES_FILE="$SCRIPT_DIR/hashes.json"

current_rev=$(jq -r '.rev // empty' "$HASHES_FILE")
latest_rev=$(curl -sfL "https://api.github.com/repos/pyproject-nix/pyproject.nix/commits/HEAD" \
  | jq -r '.sha')

if [ -z "$latest_rev" ] || [ "$latest_rev" = "null" ]; then
  echo "ERROR: failed to fetch latest commit SHA (rate limited?)" >&2
  exit 1
fi

echo "Current: $current_rev, Latest: $latest_rev"

if [ "$current_rev" = "$latest_rev" ]; then
  echo "Already up to date"
  exit 0
fi

echo "Updating pyproject-nix to $latest_rev"

src_url="https://github.com/pyproject-nix/pyproject.nix/archive/${latest_rev}.tar.gz"
echo "Fetching source from $src_url ..."
src_raw=$(nix-prefetch-url --unpack "$src_url" 2>/dev/null)
src_hash=$(nix --extra-experimental-features nix-command \
  hash convert --hash-algo sha256 --to sri "$src_raw")
echo "  hash: $src_hash"

jq -n \
  --arg r "$latest_rev" \
  --arg h "$src_hash" \
  '{rev: $r, hash: $h}' > "$HASHES_FILE"

echo "Updated to $latest_rev"
