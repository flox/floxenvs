#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HASHES_FILE="$SCRIPT_DIR/hashes.json"

# This bumps the sandbox-runtime tarball + npmDepsHash. The bundled
# package-lock.json is fetched separately from the upstream package's
# repository, since the tarball npm publishes does not contain one.

current_version=$(jq -r '.version' "$HASHES_FILE")
latest_version=$(curl -sfL \
  https://registry.npmjs.org/@anthropic-ai/sandbox-runtime \
  | jq -r '."dist-tags".latest')

echo "Current: $current_version, Latest: $latest_version"

if [ "$current_version" = "$latest_version" ]; then
  echo "Already up to date"
  exit 0
fi

echo "Updating sandbox-runtime from $current_version to $latest_version"

src_url="https://registry.npmjs.org/@anthropic-ai/sandbox-runtime/-/sandbox-runtime-${latest_version}.tgz"
src_hash=$(nix-prefetch-url --unpack "$src_url" 2>/dev/null)
src_sri=$(nix hash convert --hash-algo sha256 --to sri "$src_hash")
echo "  hash: $src_sri"

# Refresh the vendored package-lock.json from upstream's repo at the
# matching version tag (best-effort — falls back to npm registry shasum
# if the tag isn't present).
lock_url="https://raw.githubusercontent.com/anthropic-experimental/sandbox-runtime/v${latest_version}/package-lock.json"
if curl -sfL "$lock_url" -o "$SCRIPT_DIR/package-lock.json.tmp" 2>/dev/null; then
  mv "$SCRIPT_DIR/package-lock.json.tmp" "$SCRIPT_DIR/package-lock.json"
  echo "  refreshed package-lock.json from upstream"
else
  echo "  WARNING: could not fetch upstream package-lock.json;" \
    "leaving the existing one in place" >&2
fi

dummy="sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
jq -n \
  --arg v "$latest_version" \
  --arg s "$src_sri" \
  --arg n "$dummy" \
  '{version: $v, hash: $s, npmDepsHash: $n}' > "$HASHES_FILE"

echo "Building with dummy npmDepsHash to compute real one..."
npm_hash=$(flox build sandbox-runtime 2>&1 \
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
  '{version: $v, hash: $s, npmDepsHash: $n}' > "$HASHES_FILE"

echo "Updated to $latest_version"
