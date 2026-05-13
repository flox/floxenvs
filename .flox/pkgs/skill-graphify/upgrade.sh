#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HASHES_FILE="$SCRIPT_DIR/hashes.json"

OWNER="safishamsi"
REPO="graphify"

current_version=$(jq -r '.version // ""' "$HASHES_FILE")

# Upstream cuts a new long-lived branch per major version
# (v1, v2, ..., v7, ...) and points `default_branch` at the
# latest. Track whatever the default branch currently is.
default_branch=$(curl -sfL \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/$OWNER/$REPO" \
  | jq -r '.default_branch')

if [ -z "$default_branch" ] || [ "$default_branch" = "null" ]; then
  echo "Failed to resolve default_branch on $OWNER/$REPO" >&2
  exit 1
fi

rev=$(git ls-remote "https://github.com/$OWNER/$REPO.git" \
  "refs/heads/$default_branch" | awk '{print $1}')

if [ -z "$rev" ]; then
  echo "Failed to resolve $default_branch on $OWNER/$REPO" >&2
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

# Upstream skill.md frontmatter has no `version:` field, so
# synthesize a date+sha pseudo-version. The "0+" prefix keeps
# this lower than any future real version per semver-pre.
new_version="0+unstable-${commit_date}.${short_sha}"

echo "Tracking branch: $default_branch"
echo "Current: $current_version"
echo "Latest:  $new_version"

if [ "$current_version" = "$new_version" ]; then
  echo "Already up to date"
  exit 0
fi

echo "Updating skill-graphify to $new_version"

# Prefetch the .tar.gz and compute SRI hash of the raw
# tarball bytes (no --unpack). fetchurl in default.nix
# verifies the same hash, which is stable across platforms
# — unlike fetchFromGitHub's unpacked-tree hash, which can
# diverge between linux x86_64 and other systems.
sha256_base32=$(nix-prefetch-url \
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
