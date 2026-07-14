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

# Regenerate package-lock.json from the published tarball's package.json.
# Upstream stopped shipping package-lock.json (they moved to pnpm), and the
# npm tarball strips it on publish, so we synthesize a consistent lockfile
# from package.json with `npm install --package-lock-only`.
lock_tmp="$(mktemp -d)"
if curl -sfL "$src_url" -o "$lock_tmp/openspec.tgz" 2>/dev/null &&
  tar -xzf "$lock_tmp/openspec.tgz" -C "$lock_tmp" --strip-components=1 &&
  (cd "$lock_tmp" && npm install --package-lock-only --ignore-scripts >/dev/null 2>&1) &&
  [ -f "$lock_tmp/package-lock.json" ]; then
  mv "$lock_tmp/package-lock.json" "$SCRIPT_DIR/package-lock.json"
  echo "  regenerated package-lock.json from published tarball"
else
  echo "  WARNING: could not regenerate package-lock.json" >&2
fi
rm -rf "$lock_tmp"

dummy="sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
jq -n \
  --arg v "$latest_version" \
  --arg s "$src_sri" \
  --arg n "$dummy" \
  '{version: $v, sourceHash: $s, npmDepsHash: $n}' > "$HASHES_FILE"

echo "Building with dummy npmDepsHash to compute real one..."
npm_hash=$(flox build openspec 2>&1 \
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
  '{version: $v, sourceHash: $s, npmDepsHash: $n}' > "$HASHES_FILE"

echo "Updated to $latest_version"
