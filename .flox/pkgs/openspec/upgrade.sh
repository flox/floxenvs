#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HASHES_FILE="$SCRIPT_DIR/hashes.json"

force=0
while [ $# -gt 0 ]; do
  case "$1" in
    -f | --force)
      force=1
      ;;
    -h | --help)
      echo "Usage: ${0##*/} [--force]"
      echo
      echo "  --force  Re-fetch the tarball and regenerate package-lock.json"
      echo "           and hashes.json even when already on the latest"
      echo "           version. Use after changing how the lockfile is"
      echo "           generated."
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      echo "Usage: ${0##*/} [--force]" >&2
      exit 2
      ;;
  esac
  shift
done

current_version=$(jq -r '.version' "$HASHES_FILE")
latest_version=$(curl -sfL \
  https://registry.npmjs.org/@fission-ai/openspec \
  | jq -r '."dist-tags".latest')

echo "Current: $current_version, Latest: $latest_version"

if [ "$current_version" = "$latest_version" ] && [ "$force" -eq 0 ]; then
  echo "Already up to date"
  exit 0
fi

if [ "$current_version" = "$latest_version" ]; then
  echo "Forcing regeneration of openspec at $current_version"
else
  echo "Updating openspec from $current_version to $latest_version"
fi

src_url="https://registry.npmjs.org/@fission-ai/openspec/-/openspec-${latest_version}.tgz"
src_hash=$(nix-prefetch-url "$src_url" 2>/dev/null)
src_sri=$(nix hash convert --hash-algo sha256 --to sri "$src_hash")
echo "  sourceHash: $src_sri"

# Regenerate package-lock.json from the published tarball's package.json.
# Upstream stopped shipping package-lock.json (they moved to pnpm), and the
# npm tarball strips it on publish, so we synthesize a consistent lockfile
# from package.json with `npm install --package-lock-only`.
#
# devDependencies are deleted first. `npm install --package-lock-only`
# records the whole graph regardless of --omit=dev (that flag only
# changes what gets installed), so upstream's test tooling would land in
# the committed lockfile and Dependabot would alert on it. dontNpmBuild
# means none of it is ever run. default.nix deletes the same field from
# the source it builds, since `npm ci` refuses to run when package.json
# and package-lock.json disagree.
lock_tmp="$(mktemp -d)"
if curl -sfL "$src_url" -o "$lock_tmp/openspec.tgz" 2>/dev/null &&
  tar -xzf "$lock_tmp/openspec.tgz" -C "$lock_tmp" --strip-components=1 &&
  (cd "$lock_tmp" &&
    jq 'del(.devDependencies)' package.json > package.json.tmp &&
    mv package.json.tmp package.json &&
    npm install --package-lock-only --ignore-scripts >/dev/null 2>&1) &&
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
