#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HASHES_FILE="$SCRIPT_DIR/hashes.json"
PYPROJECT_FILE="$SCRIPT_DIR/pyproject.toml"

current_tag=$(jq -r '.tag // empty' "$HASHES_FILE")

# Honcho doesn't publish GitHub Releases — only tags. Pick the
# highest non-prerelease tag matching vX.Y.Z.
latest_tag=$(curl -sfL \
  "https://api.github.com/repos/plastic-labs/honcho/tags?per_page=100" \
  | jq -r '[.[].name | select(test("^v[0-9]+\\.[0-9]+\\.[0-9]+$"))]
           | sort_by(split(".") | map(tonumber? // (sub("^v"; "") | tonumber? // 0)))
           | last')

if [ -z "$latest_tag" ] || [ "$latest_tag" = "null" ]; then
  echo "ERROR: failed to fetch latest honcho tag (rate limited?)" >&2
  exit 1
fi

echo "Current: $current_tag, Latest: $latest_tag"

if [ "$current_tag" = "$latest_tag" ]; then
  echo "Already up to date"
  exit 0
fi

echo "Updating honcho to $latest_tag"

# Bump both `tag = "vX.Y.Z"` occurrences (honcho + honcho-ai sources).
sed -i.bak \
  -E "s|tag = \"v[0-9]+\\.[0-9]+\\.[0-9]+\"|tag = \"$latest_tag\"|g" \
  "$PYPROJECT_FILE"
rm -f "$PYPROJECT_FILE.bak"

# Regenerate uv.lock
pushd "$SCRIPT_DIR" > /dev/null
uv lock --upgrade-package honcho --upgrade-package honcho-ai
popd > /dev/null

# Update hashes.json
latest_version="${latest_tag#v}"
jq -n \
  --arg v "$latest_version" \
  --arg t "$latest_tag" \
  '{version: $v, tag: $t}' > "$HASHES_FILE"

echo "Updated to $latest_tag"
