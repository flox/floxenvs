#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HASHES_FILE="$SCRIPT_DIR/hashes.json"
LOCKFILE="$SCRIPT_DIR/package-lock.json"

NPM_PACKAGE="@mariozechner/pi-coding-agent"
FAKE_HASH="sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="

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

# The published tarball has no package-lock.json (npm strips it on publish),
# so regenerate one from the tarball's package.json.
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

# Compute npmDepsHash with the fake-hash trick: write a known-bad hash,
# build the npmDeps FOD, and parse the "got:" line from the mismatch.
# This matches whatever fetchNpmDeps actually produces for this lockfile
# (more reliable than running prefetch-npm-deps manually, which can
# produce different hashes depending on fetcher internals).
tmp_hashes=$(mktemp)
cp "$HASHES_FILE" "$tmp_hashes"

jq -n \
  --arg v "$latest_version" \
  --arg s "$src_sri" \
  --arg nh "$FAKE_HASH" \
  '{version: $v, sourceHash: $s, npmDepsHash: $nh}' > "$HASHES_FILE"

echo "Computing npmDepsHash..."
prefetch_log=$(mktemp)
nix build --impure --no-link \
  --expr '((import <nixpkgs> {}).callPackage ./.flox/pkgs/pi {}).npmDeps' \
  > "$prefetch_log" 2>&1 || true

npm_deps_hash=$(awk '/hash mismatch in fixed-output derivation/,0 {
  if (/got:/) { print $NF; exit }
}' "$prefetch_log")

if [ -z "$npm_deps_hash" ]; then
  echo "ERROR: Could not extract npmDepsHash. Build output:" >&2
  tail -20 "$prefetch_log" >&2
  cp "$tmp_hashes" "$HASHES_FILE"
  rm -f "$tmp_hashes" "$prefetch_log"
  exit 1
fi
rm -f "$tmp_hashes" "$prefetch_log"

echo "  npmDepsHash: $npm_deps_hash"

jq -n \
  --arg v "$latest_version" \
  --arg s "$src_sri" \
  --arg nh "$npm_deps_hash" \
  '{version: $v, sourceHash: $s, npmDepsHash: $nh}' > "$HASHES_FILE"

echo "Updated to $latest_version"
