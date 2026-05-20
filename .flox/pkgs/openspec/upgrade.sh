#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HASHES_FILE="$SCRIPT_DIR/hashes.json"

current_version=$(jq -r '.version' "$HASHES_FILE")
latest_version=$(curl -sfL \
  https://registry.npmjs.org/@fission-ai/openspec \
  | jq -r '."dist-tags".latest')

echo "Current: $current_version, Latest: $latest_version"

if [ "$current_version" = "$latest_version" ]; then
  echo "Already up to date"
  exit 0
fi

echo "Updating openspec from $current_version to $latest_version"

src_url="https://registry.npmjs.org/@fission-ai/openspec/-/openspec-${latest_version}.tgz"
src_hash=$(nix-prefetch-url "$src_url" 2>/dev/null)
src_sri=$(nix hash convert --hash-algo sha256 --to sri "$src_hash")
echo "  sourceHash: $src_sri"

# Refresh package-lock.json from upstream's repo at this version tag.
lock_url="https://raw.githubusercontent.com/Fission-AI/OpenSpec/v${latest_version}/package-lock.json"
if curl -sfL "$lock_url" -o "$SCRIPT_DIR/package-lock.json.tmp" 2>/dev/null; then
  mv "$SCRIPT_DIR/package-lock.json.tmp" "$SCRIPT_DIR/package-lock.json"
  echo "  refreshed package-lock.json from upstream"
else
  echo "  WARNING: could not refresh upstream package-lock.json" >&2
fi

dummy="sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
jq -n \
  --arg v "$latest_version" \
  --arg s "$src_sri" \
  --arg n "$dummy" \
  '{version: $v, sourceHash: $s, npmDepsHash: $n}' > "$HASHES_FILE"

echo "Building with dummy npmDepsHash to compute real one..."
npm_hash=$(flox build openspec 2>&1 \
  | grep -A1 "hash mismatch in fixed-output derivation" \
  | grep "got:" | head -1 | awk '{print $NF}') || true

if [ -z "$npm_hash" ]; then
  echo "ERROR: could not extract npmDepsHash from build output" >&2
  exit 1
fi

echo "  npmDepsHash: $npm_hash"

jq -n \
  --arg v "$latest_version" \
  --arg s "$src_sri" \
  --arg n "$npm_hash" \
  '{version: $v, sourceHash: $s, npmDepsHash: $n}' > "$HASHES_FILE"

echo "Updated to $latest_version"
