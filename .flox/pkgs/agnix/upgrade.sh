#!/usr/bin/env bash

set -euo pipefail

OWNER="agent-sh"
REPO="agnix"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HASHES_FILE="$SCRIPT_DIR/hashes.json"

current_version=$(jq -r '.version' "$HASHES_FILE")

# Get latest stable release tag from GitHub (strip leading v).
latest_version=$(
  curl -sfL \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/repos/${OWNER}/${REPO}/releases/latest" \
  | jq -r '.tag_name' \
  | sed 's/^v//'
)

echo "Current: $current_version, Latest: $latest_version"

if [ "$current_version" = "$latest_version" ]; then
  echo "Already up to date"
  exit 0
fi

echo "Updating $REPO from $current_version to $latest_version"

# Prefetch source from GitHub. Matches what `fetchFromGitHub` produces:
# GitHub's archive tarball, unpacked and hashed.
src_url="https://github.com/${OWNER}/${REPO}/archive/refs/tags/v${latest_version}.tar.gz"
src_raw=$(nix-prefetch-url --unpack "$src_url" 2>/dev/null)
src_hash=$(nix --extra-experimental-features nix-command \
  hash convert --hash-algo sha256 --to sri "$src_raw")
echo "  hash: $src_hash"

tmp_hashes=$(mktemp)
cp "$HASHES_FILE" "$tmp_hashes"
trap 'cp "$tmp_hashes" "$HASHES_FILE"; rm -f "$tmp_hashes"' EXIT

write_hashes() {
  local cargo_hash="$1"
  jq -n \
    --arg v "$latest_version" \
    --arg h "$src_hash" \
    --arg c "$cargo_hash" \
    '{
      version: $v,
      hash: $h,
      cargoHash: $c
    }' > "$HASHES_FILE"
}

# Write the real src hash with a fake cargoHash, then build to learn
# the real cargoHash from the fixed-output derivation mismatch error.
write_hashes "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="

echo "Building with dummy cargoHash to compute real one..."
prefetch_log=$(mktemp)
flox build agnix > "$prefetch_log" 2>&1 || true

cargo_hash=$(awk '/hash mismatch in fixed-output derivation/,0 {
  if (/got:/) { print $NF; exit }
}' "$prefetch_log")

if [[ "$cargo_hash" != sha256-* ]]; then
  echo "ERROR: Could not extract cargoHash. Build output:" >&2
  tail -30 "$prefetch_log" >&2
  rm -f "$prefetch_log"
  exit 1
fi
rm -f "$prefetch_log"
echo "  cargoHash: $cargo_hash"

write_hashes "$cargo_hash"

# Hashes are good; clear the rollback trap.
rm -f "$tmp_hashes"
trap - EXIT

echo "Updated to $latest_version"
