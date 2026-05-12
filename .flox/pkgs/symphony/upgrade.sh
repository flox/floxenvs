#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" \
  && pwd)"
HASHES_FILE="$SCRIPT_DIR/hashes.json"

current_rev=$(jq -r '.rev' "$HASHES_FILE")
latest_rev=$(
  curl -sfL \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/repos/openai/symphony/commits/main" \
  | jq -r '.sha'
)

echo "Current: $current_rev"
echo "Latest:  $latest_rev"

if [ "$current_rev" = "$latest_rev" ]; then
  echo "Already up to date"
  exit 0
fi

short=${latest_rev:0:7}
echo "Updating symphony to $short ($latest_rev)"

# 1) Source hash: prefetch the GitHub archive tarball.
src_url="https://github.com/openai/symphony/archive/${latest_rev}.tar.gz"
src_raw=$(nix-prefetch-url --unpack "$src_url" 2>/dev/null)
src_hash=$(
  nix --extra-experimental-features nix-command \
    hash convert --hash-algo sha256 --to sri "$src_raw"
)
echo "  srcHash:    $src_hash"

# 2) mixFodDeps hash: stage updated hashes.json with
# the real srcHash and a fake mixFodHash, build to
# trigger the hash mismatch, parse "got: sha256-..."
fake_hash="sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="

jq -n \
  --arg v "$short" \
  --arg rev "$latest_rev" \
  --arg src "$src_hash" \
  --arg fod "$fake_hash" \
  '{version: $v, rev: $rev, srcHash: $src, mixFodHash: $fod}' \
  > "$HASHES_FILE"

mix_err=$(
  nix --extra-experimental-features "nix-command flakes" \
    build "$SCRIPT_DIR/../../..#symphony" \
    --no-link 2>&1 || true
)
mix_hash=$(
  echo "$mix_err" \
  | grep -E '^\s*got:\s+sha256-' \
  | head -1 \
  | sed -E 's/^\s*got:\s+//'
)

if [ -z "$mix_hash" ]; then
  echo "ERROR: could not capture mixFodHash" >&2
  echo "$mix_err" | tail -40 >&2
  exit 1
fi
echo "  mixFodHash: $mix_hash"

jq -n \
  --arg v "$short" \
  --arg rev "$latest_rev" \
  --arg src "$src_hash" \
  --arg fod "$mix_hash" \
  '{version: $v, rev: $rev, srcHash: $src, mixFodHash: $fod}' \
  > "$HASHES_FILE"

echo "Updated symphony to $short"
