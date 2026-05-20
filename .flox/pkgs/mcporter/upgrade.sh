#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HASHES_FILE="$SCRIPT_DIR/hashes.json"

current_version=$(jq -r '.version' "$HASHES_FILE")
latest_tag=$(curl -sfL \
  https://api.github.com/repos/steipete/mcporter/releases/latest \
  | jq -r '.tag_name')
latest_version="${latest_tag#v}"

echo "Current: $current_version, Latest: $latest_version"

if [ "$current_version" = "$latest_version" ]; then
  echo "Already up to date"
  exit 0
fi

echo "Updating mcporter from $current_version to $latest_version"

src_url="https://github.com/steipete/mcporter/archive/refs/tags/v${latest_version}.tar.gz"
src_hash=$(nix-prefetch-url --unpack "$src_url" 2>/dev/null)
src_sri=$(nix hash convert --hash-algo sha256 --to sri "$src_hash")
echo "  srcHash: $src_sri"

dummy="sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
jq -n \
  --arg v "$latest_version" \
  --arg s "$src_sri" \
  --arg p "$dummy" \
  '{version: $v, srcHash: $s, pnpmDepsHash: $p}' > "$HASHES_FILE"

echo "Building with dummy pnpmDepsHash to compute real one..."
pnpm_hash=$(flox build mcporter 2>&1 \
  | grep -A2 "hash mismatch in fixed-output derivation" \
  | grep "got:" | head -1 | awk '{print $NF}') || true

if [ -z "$pnpm_hash" ]; then
  echo "ERROR: could not extract pnpmDepsHash from build output" >&2
  exit 1
fi

echo "  pnpmDepsHash: $pnpm_hash"

jq -n \
  --arg v "$latest_version" \
  --arg s "$src_sri" \
  --arg p "$pnpm_hash" \
  '{version: $v, srcHash: $s, pnpmDepsHash: $p}' > "$HASHES_FILE"

echo "Updated to $latest_version"
