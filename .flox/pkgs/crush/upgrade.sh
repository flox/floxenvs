#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HASHES_FILE="$SCRIPT_DIR/hashes.json"

current_version=$(jq -r '.version' "$HASHES_FILE")
latest_version=$(curl -sf https://api.github.com/repos/charmbracelet/crush/releases/latest \
  | jq -r '.tag_name' | sed 's/^v//')

echo "Current: $current_version, Latest: $latest_version"

if [ "$current_version" = "$latest_version" ]; then
  echo "Already up to date"
  exit 0
fi

echo "Updating crush from $current_version to $latest_version"

# Download and hash the new source tarball
src_url="https://github.com/charmbracelet/crush/archive/refs/tags/v${latest_version}.tar.gz"
echo "Fetching source from $src_url ..."
src_hash=$(nix-prefetch-url --unpack "$src_url" 2>/dev/null)
src_sri=$(nix hash convert --hash-algo sha256 --to sri "$src_hash")
echo "  srcHash: $src_sri"

# Build with a dummy vendorHash to get the real one. The goModules
# fixed-output derivation is built before compilation, so the hash
# mismatch surfaces immediately.
tmp_hashes=$(mktemp)
cp "$HASHES_FILE" "$tmp_hashes"

jq -n \
  --arg v "$latest_version" \
  --arg s "$src_sri" \
  --arg vh "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=" \
  '{version: $v, srcHash: $s, vendorHash: $vh}' > "$HASHES_FILE"

echo "Building with dummy vendorHash to compute real one..."
prefetch_log=$(mktemp)
flox build crush > "$prefetch_log" 2>&1 || true

vendor_hash=$(awk '/hash mismatch in fixed-output derivation/,0 {
  if (/got:/) { print $NF; exit }
}' "$prefetch_log")

if [ -z "$vendor_hash" ]; then
  # A transitive dep may pin a `go` directive newer than the toolchain
  # we ship. postPatch only rewrites crush's own go.mod, not vendored
  # ones, so `go mod download` still aborts. Skip the upgrade with a
  # soft success so the workflow doesn't fail until nixpkgs catches up.
  if grep -qE "requires go >= [0-9.]+ \(running go [0-9.]+; GOTOOLCHAIN=local\)" \
       "$prefetch_log"; then
    required=$(grep -oE "requires go >= [0-9.]+" "$prefetch_log" \
      | head -1 | awk '{print $NF}')
    running=$(grep -oE "running go [0-9.]+" "$prefetch_log" \
      | head -1 | awk '{print $NF}')
    echo "SKIP: crush $latest_version needs Go >= $required" \
      "(have $running). Will retry once nixpkgs ships a newer Go." >&2
    cp "$tmp_hashes" "$HASHES_FILE"
    rm -f "$tmp_hashes" "$prefetch_log"
    exit 0
  fi

  echo "ERROR: Could not extract vendorHash. Build output:" >&2
  tail -20 "$prefetch_log" >&2
  cp "$tmp_hashes" "$HASHES_FILE"
  rm -f "$tmp_hashes" "$prefetch_log"
  exit 1
fi
rm -f "$tmp_hashes" "$prefetch_log"

echo "  vendorHash: $vendor_hash"

# Write final hashes
jq -n \
  --arg v "$latest_version" \
  --arg s "$src_sri" \
  --arg vh "$vendor_hash" \
  '{version: $v, srcHash: $s, vendorHash: $vh}' > "$HASHES_FILE"

echo "Updated to $latest_version"
