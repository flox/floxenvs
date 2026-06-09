#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HASHES_FILE="$SCRIPT_DIR/hashes.json"

OWNER="carlrannaberg"
REPO="cclint"
NPM_NAME="@carlrannaberg/cclint"
FAKE_HASH="sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="

current_version=$(jq -r '.version' "$HASHES_FILE")
latest_version=$(curl -sfL \
  "https://registry.npmjs.org/${NPM_NAME}/latest" \
  | jq -r '.version')

echo "Current: $current_version, Latest: $latest_version"

if [ "$current_version" = "$latest_version" ]; then
  echo "Already up to date"
  exit 0
fi

echo "Updating ${REPO} from $current_version to $latest_version"

src_url="https://github.com/${OWNER}/${REPO}/archive/refs/tags/v${latest_version}.tar.gz"
echo "Fetching source from $src_url ..."
src_hash=$(nix-prefetch-url --unpack "$src_url" 2>/dev/null)
src_sri=$(nix hash convert --hash-algo sha256 --to sri "$src_hash")
echo "  srcHash: $src_sri"

# Write with a dummy npmDepsHash so flox build reports the real one.
jq -n \
  --arg v "$latest_version" \
  --arg s "$src_sri" \
  --arg n "$FAKE_HASH" \
  '{version: $v, srcHash: $s, npmDepsHash: $n}' > "$HASHES_FILE"

echo "Building with dummy npmDepsHash to compute real one..."
npm_hash=$(flox build "$REPO" 2>&1 \
  | grep -A2 "hash mismatch in fixed-output derivation" \
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
  '{version: $v, srcHash: $s, npmDepsHash: $n}' > "$HASHES_FILE"

echo "Updated to $latest_version"
