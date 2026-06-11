#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HASHES_FILE="$SCRIPT_DIR/hashes.json"

OWNER="agentigy"
REPO="skillcheck"
BRANCH="main"
FAKE_HASH="sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="

current_rev=$(jq -r '.rev' "$HASHES_FILE")

# Upstream ships no tags/releases, so track the latest commit on the
# default branch and read the version from its package.json.
latest_rev=$(curl -sfL \
  "https://api.github.com/repos/${OWNER}/${REPO}/commits/${BRANCH}" \
  | jq -r '.sha')
latest_version=$(curl -sfL \
  "https://raw.githubusercontent.com/${OWNER}/${REPO}/${latest_rev}/package.json" \
  | jq -r '.version')

echo "Current rev: $current_rev"
echo "Latest rev:  $latest_rev (version $latest_version)"

if [ "$current_rev" = "$latest_rev" ]; then
  echo "Already up to date"
  exit 0
fi

echo "Updating ${REPO} to $latest_rev (version $latest_version)"

src_url="https://github.com/${OWNER}/${REPO}/archive/${latest_rev}.tar.gz"
echo "Fetching source from $src_url ..."
src_hash=$(nix-prefetch-url --unpack "$src_url" 2>/dev/null)
src_sri=$(nix hash convert --hash-algo sha256 --to sri "$src_hash")
echo "  srcHash: $src_sri"

# Write with a dummy npmDepsHash so flox build reports the real one.
jq -n \
  --arg v "$latest_version" \
  --arg r "$latest_rev" \
  --arg s "$src_sri" \
  --arg n "$FAKE_HASH" \
  '{version: $v, rev: $r, srcHash: $s, npmDepsHash: $n}' > "$HASHES_FILE"

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
  --arg r "$latest_rev" \
  --arg s "$src_sri" \
  --arg n "$npm_hash" \
  '{version: $v, rev: $r, srcHash: $s, npmDepsHash: $n}' > "$HASHES_FILE"

echo "Updated to $latest_rev (version $latest_version)"
