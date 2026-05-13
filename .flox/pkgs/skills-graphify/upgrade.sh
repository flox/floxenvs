#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HASHES_FILE="$SCRIPT_DIR/hashes.json"

PKG="graphifyy"

current_version=$(jq -r '.version // ""' "$HASHES_FILE")

# Fetch the latest release info from the PyPI JSON API.
# We pin to the sdist (tar.gz) because the skill.md lives
# inside the source distribution at graphify/skill.md.
pypi_json=$(curl -sfL "https://pypi.org/pypi/$PKG/json")

new_version=$(echo "$pypi_json" | jq -r '.info.version')
sdist=$(echo "$pypi_json" | jq -r \
  --arg v "$new_version" \
  '.releases[$v][] | select(.packagetype == "sdist")')

if [ -z "$sdist" ] || [ "$sdist" = "null" ]; then
  echo "No sdist found for $PKG $new_version" >&2
  exit 1
fi

new_url=$(echo "$sdist" | jq -r '.url')
sha256_hex=$(echo "$sdist" | jq -r '.digests.sha256')

# Convert hex sha256 → SRI sha256-...
sri_hash=$(nix --extra-experimental-features nix-command \
  hash convert --hash-algo sha256 --to sri "$sha256_hex")

echo "Current: $current_version"
echo "Latest:  $new_version"

if [ "$current_version" = "$new_version" ]; then
  echo "Already up to date"
  exit 0
fi

echo "Updating skills-graphify to $new_version"

jq -n \
  --arg v "$new_version" \
  --arg u "$new_url" \
  --arg h "$sri_hash" \
  '{version: $v, url: $u, srcHash: $h}' \
  > "$HASHES_FILE"

echo "Wrote $HASHES_FILE:"
cat "$HASHES_FILE"
