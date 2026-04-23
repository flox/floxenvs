#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HASHES_FILE="$SCRIPT_DIR/hashes.json"
LOCKFILE="$SCRIPT_DIR/package-lock.json"

NPM_PACKAGE="@mariozechner/pi-coding-agent"

current_version=$(jq -r '.version' "$HASHES_FILE")
latest_version=$(curl -sfL "https://registry.npmjs.org/${NPM_PACKAGE}/latest" \
  | jq -r '.version')

echo "Current: $current_version, Latest: $latest_version"

if [ "$current_version" = "$latest_version" ]; then
  echo "Already up to date"
  exit 0
fi

echo "Updating pi from $current_version to $latest_version"

# Fetch and hash the published npm tarball
src_url="https://registry.npmjs.org/${NPM_PACKAGE}/-/pi-coding-agent-${latest_version}.tgz"
echo "Fetching source from $src_url ..."
src_hash=$(nix-prefetch-url "$src_url" 2>/dev/null)
src_sri=$(nix hash convert --hash-algo sha256 --to sri "$src_hash")
echo "  sourceHash: $src_sri"

# The published tarball has no package-lock.json, so regenerate one from
# the tarball's package.json using a temporary workspace.
echo "Regenerating package-lock.json..."
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

tarball="$tmpdir/pi.tgz"
curl -sfL "$src_url" -o "$tarball"
mkdir -p "$tmpdir/extract"
tar -xzf "$tarball" -C "$tmpdir/extract" --strip-components=1

(
  cd "$tmpdir/extract"
  npm install --package-lock-only --ignore-scripts >/dev/null 2>&1
)

cp "$tmpdir/extract/package-lock.json" "$LOCKFILE"

# Compute npmDepsHash using nixpkgs' prefetch-npm-deps helper
echo "Computing npmDepsHash..."
npm_deps_hash=$(nix run --impure \
  --expr '(import <nixpkgs> {}).prefetch-npm-deps' \
  -- "$LOCKFILE" 2>/dev/null \
  | tail -n1)
npm_deps_sri=$(nix hash convert --hash-algo sha256 --to sri "$npm_deps_hash" \
  2>/dev/null || echo "$npm_deps_hash")
echo "  npmDepsHash: $npm_deps_sri"

jq -n \
  --arg v "$latest_version" \
  --arg s "$src_sri" \
  --arg nh "$npm_deps_sri" \
  '{version: $v, sourceHash: $s, npmDepsHash: $nh}' > "$HASHES_FILE"

echo "Updated to $latest_version"
