#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HASHES_FILE="$SCRIPT_DIR/hashes.json"

current_version=$(jq -r '.version' "$HASHES_FILE")

# Resolve the latest stable GitHub release. We require
# a tagged release because the src is fetched by tag.
latest_tag=$(curl -sf \
  https://api.github.com/repos/microsoft/playwright-cli/releases/latest \
  | jq -r '.tag_name // empty')

if [ -z "$latest_tag" ]; then
  echo "ERROR: microsoft/playwright-cli has no GitHub release." >&2
  echo "       upgrade.sh requires a tagged release (resolves source from a v\${version} tag)." >&2
  echo "       Re-run after upstream cuts a release." >&2
  exit 1
fi

latest_version="${latest_tag#v}"

echo "Current: $current_version, Latest: $latest_version"

if [ "$current_version" = "$latest_version" ]; then
  echo "Already up to date"
  exit 0
fi

echo "Updating playwright-cli to $latest_version"

src_url="https://github.com/microsoft/playwright-cli/archive/refs/tags/v${latest_version}.tar.gz"
src_hash=$(nix-prefetch-url --unpack "$src_url" 2>/dev/null)
src_sri=$(nix hash convert --hash-algo sha256 --to sri "$src_hash")

dummy="sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
jq -n \
  --arg v "$latest_version" \
  --arg s "$src_sri" \
  --arg n "$dummy" \
  '{version: $v, srcHash: $s, npmDepsHash: $n}' \
  > "$HASHES_FILE"

echo "Building with dummy npmDepsHash..."
npm_hash=$(flox build playwright-cli 2>&1 \
  | grep "got:" | head -1 | awk '{print $2}') || true

if [ -z "$npm_hash" ]; then
  echo "ERROR: could not extract npmDepsHash" >&2
  exit 1
fi

jq -n \
  --arg v "$latest_version" \
  --arg s "$src_sri" \
  --arg n "$npm_hash" \
  '{version: $v, srcHash: $s, npmDepsHash: $n}' \
  > "$HASHES_FILE"

echo "Updated to $latest_version"
