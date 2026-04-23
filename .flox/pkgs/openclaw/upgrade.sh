#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HASHES_FILE="$SCRIPT_DIR/hashes.json"

current_version=$(jq -r '.version' "$HASHES_FILE")
latest_version=$(curl -sfL "https://api.github.com/repos/openclaw/openclaw/releases/latest" \
  | jq -r '.tag_name' | sed 's/^v//')

echo "Current: $current_version, Latest: $latest_version"

if [ "$current_version" = "$latest_version" ]; then
  echo "Already up to date"
  exit 0
fi

echo "Updating openclaw from $current_version to $latest_version"

# Prefetch source tarball (matches fetchFromGitHub)
src_url="https://github.com/openclaw/openclaw/archive/refs/tags/v${latest_version}.tar.gz"
echo "Fetching source from $src_url ..."
src_raw=$(nix-prefetch-url --unpack "$src_url" 2>/dev/null)
src_hash=$(nix --extra-experimental-features nix-command \
  hash convert --hash-algo sha256 --to sri "$src_raw")
echo "  hash: $src_hash"

# Save original hashes for rollback on failure
tmp_hashes=$(mktemp)
cp "$HASHES_FILE" "$tmp_hashes"

# Build with a dummy pnpmDepsHash to get the real one
jq -n \
  --arg v "$latest_version" \
  --arg h "$src_hash" \
  --arg p "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=" \
  '{version: $v, hash: $h, pnpmDepsHash: $p}' > "$HASHES_FILE"

echo "Building with dummy pnpmDepsHash to compute real one..."
pnpm_hash=$(flox build openclaw 2>&1 \
  | grep "got:" \
  | head -1 \
  | awk '{print $2}') || true

if [ -z "$pnpm_hash" ]; then
  echo "ERROR: Could not extract pnpmDepsHash from build output"
  cp "$tmp_hashes" "$HASHES_FILE"
  rm -f "$tmp_hashes"
  exit 1
fi
rm -f "$tmp_hashes"

echo "  pnpmDepsHash: $pnpm_hash"

# Write final hashes
jq -n \
  --arg v "$latest_version" \
  --arg h "$src_hash" \
  --arg p "$pnpm_hash" \
  '{version: $v, hash: $h, pnpmDepsHash: $p}' > "$HASHES_FILE"

echo "Updated to $latest_version"
