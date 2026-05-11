#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HASHES_FILE="$SCRIPT_DIR/hashes.json"

OWNER="huggingface"
REPO="huggingface_hub"

current_version=$(jq -r '.version' "$HASHES_FILE")

# Latest stable (non-prerelease, non-draft) release tag.
# Releases are tagged `v<x.y.z>`; strip the leading `v`.
latest_version=$(
  curl -sfL \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/repos/$OWNER/$REPO/releases/latest" \
  | jq -r '.tag_name' \
  | sed 's/^v//'
)

echo "Current: $current_version, Latest: $latest_version"

if [ "$current_version" = "$latest_version" ]; then
  echo "Already up to date"
  exit 0
fi

echo "Updating $REPO from $current_version to $latest_version"

# Prefetch source from GitHub. Matches what `fetchFromGitHub`
# produces: GitHub's archive tarball, unpacked and hashed.
src_url="https://github.com/$OWNER/$REPO/archive/refs/tags/v${latest_version}.tar.gz"
src_raw=$(nix-prefetch-url --unpack "$src_url" 2>/dev/null)
src_hash=$(nix --extra-experimental-features nix-command \
  hash convert --hash-algo sha256 --to sri "$src_raw")

echo "  srcHash: $src_hash"

jq -n \
  --arg v "$latest_version" \
  --arg h "$src_hash" \
  '{version: $v, srcHash: $h}' \
  > "$HASHES_FILE"

echo "Updated to $latest_version"
