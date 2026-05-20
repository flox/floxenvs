#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HASHES_FILE="$SCRIPT_DIR/hashes.json"
PYPROJECT_FILE="$SCRIPT_DIR/pyproject.toml"

current_rev=$(jq -r '.rev // empty' "$HASHES_FILE")
latest_rev=$(gh api --method GET \
  repos/NVIDIA/SkillSpector/commits/main \
  --jq '.sha')

if [ -z "$latest_rev" ] || [ "$latest_rev" = "null" ]; then
  echo "ERROR: failed to fetch latest skillspector commit" >&2
  exit 1
fi

echo "Current: $current_rev, Latest: $latest_rev"

if [ "$current_rev" = "$latest_rev" ]; then
  echo "Already up to date"
  exit 0
fi

# Pull version from upstream pyproject.toml at the new rev.
latest_version=$(gh api --method GET \
  "repos/NVIDIA/SkillSpector/contents/pyproject.toml?ref=$latest_rev" \
  --jq '.content' \
  | base64 -d \
  | awk -F'"' '/^version = /{ print $2; exit }')

if [ -z "$latest_version" ]; then
  echo "ERROR: failed to extract version" >&2
  exit 1
fi

echo "Updating skillspector to $latest_version ($latest_rev)"

# Bump rev in pyproject.toml (matches `rev = "..."` under
# [tool.uv.sources]).
sed -i.bak \
  -E "s|rev = \"[^\"]+\"|rev = \"$latest_rev\"|" \
  "$PYPROJECT_FILE"
rm -f "$PYPROJECT_FILE.bak"

# Regenerate uv.lock.
pushd "$SCRIPT_DIR" > /dev/null
uv lock --upgrade-package skillspector
popd > /dev/null

# Update hashes.json.
jq -n \
  --arg v "$latest_version" \
  --arg r "$latest_rev" \
  '{version: $v, rev: $r}' > "$HASHES_FILE"

echo "Updated to $latest_version ($latest_rev)"
