#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HASHES_FILE="$SCRIPT_DIR/hashes.json"

# This script only bumps the goose-cli source. The librusty_v8 pin is
# updated separately when the v8 crate in goose-cli's lockfile shifts;
# upgrading the source without also refreshing librusty_v8 may still
# build but will skew the v8 ABI from what goose-cli was tested against.

current_version=$(jq -r '.version' "$HASHES_FILE")
latest_tag=$(curl -sfL \
  https://api.github.com/repos/block/goose/releases/latest \
  | jq -r '.tag_name')
latest_version="${latest_tag#v}"

echo "Current: $current_version, Latest: $latest_version"

if [ "$current_version" = "$latest_version" ]; then
  echo "Already up to date"
  exit 0
fi

echo "Updating goose-cli from $current_version to $latest_version"

src_url="https://github.com/block/goose/archive/refs/tags/v${latest_version}.tar.gz"
src_hash=$(nix-prefetch-url --unpack "$src_url" 2>/dev/null)
src_sri=$(nix hash convert --hash-algo sha256 --to sri "$src_hash")
echo "  srcHash: $src_sri"

dummy="sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
jq \
  --arg v "$latest_version" \
  --arg s "$src_sri" \
  --arg d "$dummy" \
  '.version = $v | .srcHash = $s | .cargoHash = $d' \
  "$HASHES_FILE" > "$HASHES_FILE.tmp"
mv "$HASHES_FILE.tmp" "$HASHES_FILE"

echo "Building with dummy cargoHash to compute real one..."
cargo_hash=$(flox build goose-cli 2>&1 \
  | grep -A1 "hash mismatch in fixed-output derivation" \
  | grep "got:" | head -1 | awk '{print $NF}') || true

if [ -z "$cargo_hash" ]; then
  echo "ERROR: could not extract cargoHash from build output" >&2
  exit 1
fi

echo "  cargoHash: $cargo_hash"

jq \
  --arg v "$latest_version" \
  --arg s "$src_sri" \
  --arg c "$cargo_hash" \
  '.version = $v | .srcHash = $s | .cargoHash = $c' \
  "$HASHES_FILE" > "$HASHES_FILE.tmp"
mv "$HASHES_FILE.tmp" "$HASHES_FILE"

echo "Updated to $latest_version"
echo "WARNING: librusty_v8 hashes in hashes.json may also need a refresh" \
  "if upstream's v8 crate version shifted." >&2
