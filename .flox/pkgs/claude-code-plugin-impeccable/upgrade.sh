#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HASHES_FILE="$SCRIPT_DIR/hashes.json"

current_version=$(jq -r '.version' "$HASHES_FILE")

# Upstream tags releases as `skill-vX.Y.Z`. Pull the latest such tag.
latest_tag=$(curl -sf \
  https://api.github.com/repos/pbakaus/impeccable/releases/latest \
  | jq -r '.tag_name')
latest_version="${latest_tag#skill-v}"

echo "Current: $current_version, Latest: $latest_version"

if [ "$current_version" = "$latest_version" ]; then
  echo "Already up to date"
  exit 0
fi

echo "Updating claude-code-plugin-impeccable from $current_version to $latest_version"

src_url="https://github.com/pbakaus/impeccable/archive/refs/tags/skill-v${latest_version}.tar.gz"
echo "Fetching source from $src_url ..."
src_hash=$(nix-prefetch-url --unpack "$src_url" 2>/dev/null)
src_sri=$(nix --extra-experimental-features nix-command \
  hash convert --hash-algo sha256 --to sri "$src_hash")
echo "  srcHash: $src_sri"

# Resolve the tag to its commit SHA — Claude Code's installed_plugins.json
# records gitCommitSha per entry, and shipping the real SHA lets users
# reproduce or audit exactly which upstream commit they have.
commit_sha=$(git ls-remote https://github.com/pbakaus/impeccable.git \
  "refs/tags/skill-v${latest_version}" | awk '{print $1}')
if [ -z "$commit_sha" ]; then
  echo "ERROR: could not resolve skill-v${latest_version} to a commit SHA"
  exit 1
fi
echo "  commitSha: $commit_sha"

jq -n \
  --arg v "$latest_version" \
  --arg s "$src_sri" \
  --arg c "$commit_sha" \
  '{version: $v, srcHash: $s, commitSha: $c}' > "$HASHES_FILE"

echo "Updated to $latest_version"
