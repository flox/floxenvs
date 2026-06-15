#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HASHES_FILE="$SCRIPT_DIR/hashes.json"

OWNER="mvanhorn"
REPO="last30days-skill"
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

# Anchor the base version on the skill's own frontmatter version
# (skills/last30days/SKILL.md), which is the number the engine
# stamps into its output badge.
skill_md=$(curl -sfL \
  "https://raw.githubusercontent.com/$OWNER/$REPO/$rev/skills/last30days/SKILL.md")
# Match only the first `version:` line, but keep reading to EOF (no awk
# `exit`) so the upstream `echo` never gets SIGPIPE on this large file —
# under `set -o pipefail` that early close would abort the script (141).
base_version=$(printf '%s\n' "$skill_md" \
  | awk '/^version:/ && !seen { gsub(/"/, "", $2); print $2; seen = 1 }')

if [ -z "$base_version" ]; then
  echo "Failed to extract version from SKILL.md" >&2
  exit 1
fi

new_version="${base_version}+unstable-${commit_date}.${short_sha}"

echo "Current: $current_version"
echo "Latest:  $new_version"

if [ "$current_version" = "$new_version" ]; then
  echo "Already up to date"
  exit 0
fi

echo "Updating skills-last30days to $new_version"

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
