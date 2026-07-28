#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HASHES_FILE="$SCRIPT_DIR/hashes.json"

REPO="scaccogatto/okf-skills"

current_rev=$(jq -r '.rev' "$HASHES_FILE")
current_version=$(jq -r '.version' "$HASHES_FILE")

# Upstream's release tags (`okf--vX.Y.Z`) lag the plugin: `main` carried
# 0.6.0 while the newest tag was okf--v0.4.0. Track the branch head and
# take the version from the plugin manifest at that commit.
latest_rev=$(curl -sf \
  "https://api.github.com/repos/${REPO}/commits/main" | jq -r '.sha')

if [ -z "$latest_rev" ] || [ "$latest_rev" = "null" ]; then
  echo "Failed to resolve main" >&2
  exit 1
fi

latest_version=$(curl -sf \
  "https://raw.githubusercontent.com/${REPO}/${latest_rev}/.claude-plugin/plugin.json" \
  | jq -r '.version')

echo "Current: $current_version ($current_rev)"
echo "Latest:  $latest_version ($latest_rev)"

if [ "$current_rev" = "$latest_rev" ]; then
  echo "Already up to date"
  exit 0
fi

echo "Updating skills-okf to $latest_version ($latest_rev)"

src_url="https://github.com/${REPO}/archive/${latest_rev}.tar.gz"
echo "Fetching source from $src_url ..."
src_hash=$(nix-prefetch-url --unpack "$src_url" 2>/dev/null)
src_sri=$(nix --extra-experimental-features nix-command \
  hash convert --hash-algo sha256 --to sri "$src_hash")
echo "  srcHash: $src_sri"

jq -n \
  --arg v "$latest_version" \
  --arg r "$latest_rev" \
  --arg s "$src_sri" \
  '{version: $v, rev: $r, srcHash: $s}' > "$HASHES_FILE"

echo "Updated to $latest_version"
