#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HASHES_FILE="$SCRIPT_DIR/hashes.json"

current_version=$(jq -r '.version' "$HASHES_FILE")
latest_version=$(npm view @anthropic-ai/claude-code version)

echo "Current: $current_version, Latest: $latest_version"

if [ "$current_version" = "$latest_version" ]; then
  echo "Already up to date"
  exit 0
fi

echo "Updating claude-code from $current_version to $latest_version"

# Download and hash the new source tarball
src_url="https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-${latest_version}.tgz"
echo "Fetching source from $src_url ..."
src_hash=$(nix-prefetch-url --unpack "$src_url" 2>/dev/null)
src_sri="sha256-$(nix --extra-experimental-features nix-command \
  hash convert --hash-algo sha256 --to sri "$src_hash" \
  | sed 's/sha256-//')"
echo "  srcHash: $src_sri"

# Download source, extract package-lock.json, compute npmDepsHash
workdir=$(mktemp -d)
trap 'rm -rf "$workdir"' EXIT

curl -sfL "$src_url" | tar xz -C "$workdir" --strip-components=1

# Generate package-lock.json from package.json (tarball ships bun.lock only)
(cd "$workdir" && npm install --package-lock-only --ignore-scripts 2>/dev/null)
chmod -f +w "$SCRIPT_DIR/package-lock.json" 2>/dev/null || true
cp "$workdir/package-lock.json" "$SCRIPT_DIR/package-lock.json"

npm_deps_hash=$(prefetch-npm-deps "$SCRIPT_DIR/package-lock.json" 2>/dev/null)
echo "  npmDepsHash: $npm_deps_hash"

# Write updated hashes
jq -n \
  --arg v "$latest_version" \
  --arg s "$src_sri" \
  --arg n "$npm_deps_hash" \
  '{version: $v, srcHash: $s, npmDepsHash: $n}' > "$HASHES_FILE"

echo "Updated to $latest_version"
