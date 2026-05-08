#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HASHES_FILE="$SCRIPT_DIR/hashes.json"

OWNER="anthropics"
REPO="skills"
BRANCH="main"

current_version=$(jq -r '.version // ""' "$HASHES_FILE")

# Resolve current HEAD on main to a full SHA.
rev=$(git ls-remote "https://github.com/$OWNER/$REPO.git" \
  "refs/heads/$BRANCH" | awk '{print $1}')

if [ -z "$rev" ]; then
  echo "Failed to resolve $BRANCH on $OWNER/$REPO" >&2
  exit 1
fi

short_sha="${rev:0:7}"

# Committer date (YYYY-MM-DD) via the GitHub commits API.
commit_json=$(curl -sfL \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/$OWNER/$REPO/commits/$rev")
commit_date=$(echo "$commit_json" \
  | jq -r '.commit.committer.date' \
  | cut -c1-10)

# Upstream SKILL.md has no frontmatter `version:` field — version
# the package solely on the upstream commit date + short SHA.
new_version="unstable-${commit_date}.${short_sha}"

echo "Current: $current_version"
echo "Latest:  $new_version"

if [ "$current_version" = "$new_version" ]; then
  echo "Already up to date"
  exit 0
fi

echo "Updating skills-frontend-design to $new_version"

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
