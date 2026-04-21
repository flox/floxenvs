#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HASHES_FILE="$SCRIPT_DIR/hashes.json"

current_version=$(jq -r '.version' "$HASHES_FILE")
latest_version=$(curl -sf https://api.github.com/repos/astral-sh/uv/releases/latest \
  | jq -r '.tag_name')

echo "Current: $current_version, Latest: $latest_version"

if [ "$current_version" = "$latest_version" ]; then
  echo "Already up to date"
  exit 0
fi

echo "Updating uv from $current_version to $latest_version"

# Download and hash the new source tarball
src_url="https://github.com/astral-sh/uv/archive/refs/tags/${latest_version}.tar.gz"
echo "Fetching source from $src_url ..."
src_hash=$(nix-prefetch-url --unpack "$src_url" 2>/dev/null)
src_sri=$(nix hash convert --hash-algo sha256 --to sri "$src_hash")
echo "  srcHash: $src_sri"

# Build with a dummy cargoHash to get the real one
tmp_hashes=$(mktemp)
jq -n \
  --arg v "$latest_version" \
  --arg s "$src_sri" \
  --arg c "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=" \
  '{version: $v, srcHash: $s, cargoHash: $c}' > "$HASHES_FILE"

echo "Building with dummy cargoHash to compute real one..."
cargo_hash=$(flox build uv 2>&1 \
  | grep "got:" \
  | head -1 \
  | awk '{print $2}') || true

if [ -z "$cargo_hash" ]; then
  echo "ERROR: Could not extract cargoHash from build output"
  # Restore original hashes
  cp "$tmp_hashes" "$HASHES_FILE"
  rm -f "$tmp_hashes"
  exit 1
fi
rm -f "$tmp_hashes"

echo "  cargoHash: $cargo_hash"

# Write final hashes
jq -n \
  --arg v "$latest_version" \
  --arg s "$src_sri" \
  --arg c "$cargo_hash" \
  '{version: $v, srcHash: $s, cargoHash: $c}' > "$HASHES_FILE"

echo "Updated to $latest_version"
