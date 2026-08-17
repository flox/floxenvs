#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HASHES_FILE="$SCRIPT_DIR/hashes.json"

current_version=$(jq -r '.version' "$HASHES_FILE")

# Authenticate when a token is available: the shared unauthenticated
# 60/hr GitHub API quota per egress IP gets exhausted by parallel
# runners, surfacing as `curl exit 22`.
auth_header=()
[ -n "${GITHUB_TOKEN:-}" ] \
  && auth_header=(-H "Authorization: Bearer $GITHUB_TOKEN")

# Upstream tags skill releases as `vX.Y.Z` but also publishes binary
# releases tagged `bin-vX.Y.Z` (and `releases/latest` may point at
# one of those). Pick the newest stable `v*` release instead.
latest_tag=$(curl -sfL --retry 3 --retry-delay 5 \
  -H "Accept: application/vnd.github+json" \
  "${auth_header[@]}" \
  https://api.github.com/repos/JuliusBrussee/caveman/releases \
  | jq -r '[.[]
      | select(.prerelease == false and .draft == false)
      | select(.tag_name | test("^v[0-9]"))][0].tag_name')
latest_version="${latest_tag#v}"

echo "Current: $current_version, Latest: $latest_version"

if [ "$current_version" = "$latest_version" ]; then
  echo "Already up to date"
  exit 0
fi

echo "Updating skills-caveman from $current_version to $latest_version"

src_url="https://github.com/JuliusBrussee/caveman/archive/refs/tags/v${latest_version}.tar.gz"
echo "Fetching source from $src_url ..."
src_hash=$(nix-prefetch-url --unpack "$src_url" 2>/dev/null)
src_sri=$(nix --extra-experimental-features nix-command \
  hash convert --hash-algo sha256 --to sri "$src_hash")
echo "  srcHash: $src_sri"

jq -n \
  --arg v "$latest_version" \
  --arg s "$src_sri" \
  '{version: $v, srcHash: $s}' > "$HASHES_FILE"

echo "Updated to $latest_version"
