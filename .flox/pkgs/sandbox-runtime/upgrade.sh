#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HASHES_FILE="$SCRIPT_DIR/hashes.json"

# This bumps the sandbox-runtime tarball + npmDepsHash. The bundled
# package-lock.json is fetched separately from the upstream package's
# repository, since the tarball npm publishes does not contain one.

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
  https://registry.npmjs.org/@anthropic-ai/sandbox-runtime \
  | jq -r '."dist-tags".latest')

echo "Current: $current_version, Latest: $latest_version"

if [ "$current_version" = "$latest_version" ] && [ "$force" -eq 0 ]; then
  echo "Already up to date"
  exit 0
fi

if [ "$current_version" = "$latest_version" ]; then
  echo "Forcing regeneration of sandbox-runtime at $current_version"
else
  echo "Updating sandbox-runtime from $current_version to $latest_version"
fi

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
  rm -f "$SCRIPT_DIR/package-lock.json.tmp"
  echo "  WARNING: could not fetch upstream package-lock.json;" \
    "leaving the existing one in place" >&2
fi

# Upstream's lockfile is their *repo* lockfile, so the overwhelming
# majority of its entries exist only to lint, typecheck and test the
# source (at 0.0.76: 329 of 334). This package sets dontNpmBuild — the
# npm tarball already ships a prebuilt dist/ — so none of that tooling
# is ever run, and nixpkgs' npmInstallHook prunes it from the output
# anyway. Dependabot still scans it while it sits in the committed
# lockfile, so drop the dev-only entries here. A package reachable from
# a runtime dependency is never marked "dev": true, and "devOptional"
# entries are deliberately kept, so this cannot remove anything the
# build needs. default.nix deletes devDependencies from the package.json
# it builds to match, because `npm ci` refuses to run when package.json
# and package-lock.json disagree.
#
# Whichever lockfile is now in place — freshly fetched or the previous
# one — gets pruned, so re-running with --force fixes a stale file. The
# legacy "dependencies" tree is only present in lockfileVersion 2.
jq '(.packages |= with_entries(select(.value.dev != true)))
  | (.packages[""] |= del(.devDependencies))
  | (if has("dependencies")
     then .dependencies |= with_entries(select(.value.dev != true))
     else . end)' \
  "$SCRIPT_DIR/package-lock.json" > "$SCRIPT_DIR/package-lock.json.tmp"
mv "$SCRIPT_DIR/package-lock.json.tmp" "$SCRIPT_DIR/package-lock.json"
echo "  pruned dev-only entries from package-lock.json" \
  "($(jq '.packages | length' "$SCRIPT_DIR/package-lock.json") remain)"

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
