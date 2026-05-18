#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HASHES_FILE="$SCRIPT_DIR/hashes.json"

OWNER="garrytan"
REPO="gstack"
BRANCH="main"

current_version=$(jq -r '.version // ""' "$HASHES_FILE")
current_rev=$(jq -r '.rev // ""' "$HASHES_FILE")

# Resolve current HEAD on main to a full SHA.
rev=$(git ls-remote "https://github.com/$OWNER/$REPO.git" \
  "refs/heads/$BRANCH" | awk '{print $1}')

if [ -z "$rev" ]; then
  echo "Failed to resolve $BRANCH on $OWNER/$REPO" >&2
  exit 1
fi

# Read upstream VERSION file at this commit. gstack publishes
# 4-segment versions (e.g. 1.40.0.0) in `VERSION` rather than
# git tags or GitHub releases.
upstream_version=$(curl -sfL \
  "https://raw.githubusercontent.com/$OWNER/$REPO/$rev/VERSION" \
  | tr -d '[:space:]')

if [ -z "$upstream_version" ]; then
  echo "Failed to read VERSION from $OWNER/$REPO@$rev" >&2
  exit 1
fi

short_sha="${rev:0:7}"
new_version="${upstream_version}-${short_sha}"

echo "Current: $current_version (rev: ${current_rev:0:7})"
echo "Latest:  $new_version (rev: $short_sha)"

if [ "$current_rev" = "$rev" ]; then
  echo "Already up to date"
  exit 0
fi

echo "Updating claude-code-plugin-gstack to $new_version"

# Prefetch the source tarball and compute SRI hash.
sha256_base32=$(nix-prefetch-url --unpack \
  "https://github.com/$OWNER/$REPO/archive/$rev.tar.gz")
sri_hash=$(nix --extra-experimental-features nix-command \
  hash convert --hash-algo sha256 --to sri "$sha256_base32")

jq -n \
  --arg v "$new_version" \
  --arg r "$rev" \
  --arg h "$sri_hash" \
  '{version: $v, rev: $r, srcHash: $h}' \
  > "$HASHES_FILE"

echo "Wrote $HASHES_FILE:"
cat "$HASHES_FILE"
