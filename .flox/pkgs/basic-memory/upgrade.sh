#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HASHES_FILE="$SCRIPT_DIR/hashes.json"
PYPROJECT_FILE="$SCRIPT_DIR/pyproject.toml"

current_tag=$(jq -r '.tag // empty' "$HASHES_FILE")
latest_tag=$(curl -sfL \
  "https://api.github.com/repos/basicmachines-co/basic-memory/releases/latest" \
  | jq -r '.tag_name')

if [ -z "$latest_tag" ] || [ "$latest_tag" = "null" ]; then
  echo "ERROR: failed to fetch latest basic-memory tag (rate limited?)" >&2
  exit 1
fi

echo "Current: $current_tag, Latest: $latest_tag"

if [ "$current_tag" = "$latest_tag" ]; then
  echo "Already up to date"
  exit 0
fi

echo "Updating basic-memory to $latest_tag"

# Bump tag in pyproject.toml (matches `tag = "vX.Y.Z"` under [tool.uv.sources])
sed -i.bak \
  -E "s|tag = \"[^\"]+\"|tag = \"$latest_tag\"|" \
  "$PYPROJECT_FILE"
rm -f "$PYPROJECT_FILE.bak"

# Regenerate uv.lock
pushd "$SCRIPT_DIR" > /dev/null
uv lock --upgrade-package basic-memory
popd > /dev/null

# Update hashes.json
latest_version="${latest_tag#v}"
jq -n \
  --arg v "$latest_version" \
  --arg t "$latest_tag" \
  '{version: $v, tag: $t}' > "$HASHES_FILE"

echo "Updated to $latest_tag"
