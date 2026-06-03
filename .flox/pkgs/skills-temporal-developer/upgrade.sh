#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HASHES_FILE="$SCRIPT_DIR/hashes.json"

OWNER="temporalio"
REPO="skill-temporal-developer"

current_version=$(jq -r '.version // ""' "$HASHES_FILE")

# Upstream ships real tagged releases with a matching `version`
# field in SKILL.md frontmatter, so pin to the latest release tag
# rather than chasing the default branch.
release_json=$(curl -sfL \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/$OWNER/$REPO/releases/latest")
tag=$(echo "$release_json" | jq -r '.tag_name')

if [ -z "$tag" ] || [ "$tag" = "null" ]; then
  echo "Failed to resolve latest release for $OWNER/$REPO" >&2
  exit 1
fi

new_version="${tag#v}"

# Resolve the tag to a full commit SHA. Prefer the dereferenced
# (^{}) object so annotated tags resolve to their commit.
rev=$(git ls-remote "https://github.com/$OWNER/$REPO.git" \
  "refs/tags/$tag^{}" | awk '{print $1}')
if [ -z "$rev" ]; then
  rev=$(git ls-remote "https://github.com/$OWNER/$REPO.git" \
    "refs/tags/$tag" | awk '{print $1}')
fi

if [ -z "$rev" ]; then
  echo "Failed to resolve tag $tag to a commit" >&2
  exit 1
fi

echo "Current: $current_version"
echo "Latest:  $new_version ($tag)"

if [ "$current_version" = "$new_version" ]; then
  echo "Already up to date"
  exit 0
fi

echo "Updating skills-temporal-developer to $new_version"

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
