#!/usr/bin/env bash

set -euo pipefail

# Authenticate when a token is available (CI) so the GitHub API applies the
# 5000/hr limit instead of the shared 60/hr anonymous one. Must stay
# conditional: an empty Bearer value makes GitHub reject the request, which
# would break local runs where GITHUB_TOKEN is unset.
auth_header=()
if [ -n "${GITHUB_TOKEN:-}" ]; then
  auth_header=(-H "Authorization: Bearer $GITHUB_TOKEN")
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HASHES_FILE="$SCRIPT_DIR/hashes.json"
PYPROJECT_FILE="$SCRIPT_DIR/pyproject.toml"

current_tag=$(jq -r '.tag // empty' "$HASHES_FILE")
latest_tag=$(curl -sSfL "${auth_header[@]}" \
  "https://api.github.com/repos/oraios/serena/releases/latest" \
  | jq -r '.tag_name')

if [ -z "$latest_tag" ] || [ "$latest_tag" = "null" ]; then
  echo "ERROR: failed to fetch latest serena tag (rate limited?)" >&2
  exit 1
fi

echo "Current: $current_tag, Latest: $latest_tag"

# Refresh transitive dependencies on every run, before the
# "already up to date" early exit below. The `uv lock
# --upgrade-package` further down only re-resolves the pinned
# upstream source; every transitive PyPI dependency stays frozen at
# whatever was picked when the lock was first written. Since this
# script exits early whenever upstream has no new release, those
# transitive pins never moved and accumulated Dependabot alerts.
pushd "$SCRIPT_DIR" > /dev/null
uv lock --upgrade
popd > /dev/null

if [ "$current_tag" = "$latest_tag" ]; then
  echo "Already up to date"
  exit 0
fi

echo "Updating serena to $latest_tag"

# Bump tag in pyproject.toml (matches `tag = "vX.Y.Z"` under
# [tool.uv.sources])
sed -i.bak \
  -E "s|tag = \"[^\"]+\"|tag = \"$latest_tag\"|" \
  "$PYPROJECT_FILE"
rm -f "$PYPROJECT_FILE.bak"

# Regenerate uv.lock
pushd "$SCRIPT_DIR" > /dev/null
uv lock --upgrade-package serena-agent
popd > /dev/null

# Update hashes.json
latest_version="${latest_tag#v}"
jq -n \
  --arg v "$latest_version" \
  --arg t "$latest_tag" \
  '{version: $v, tag: $t}' > "$HASHES_FILE"

echo "Updated to $latest_tag"
