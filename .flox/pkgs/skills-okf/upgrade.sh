#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HASHES_FILE="$SCRIPT_DIR/hashes.json"

REPO="scaccogatto/okf-skills"

current_rev=$(jq -r '.rev' "$HASHES_FILE")
current_version=$(jq -r '.version' "$HASHES_FILE")

# Authenticated API calls use Actions' 5000/hr quota. The
# unauthenticated 60/hr is shared per egress IP and gets exhausted
# by parallel runners, surfacing as `curl exit 22`.
auth_header=()
[ -n "${GITHUB_TOKEN:-}" ] \
  && auth_header=(-H "Authorization: Bearer $GITHUB_TOKEN")

# Upstream's release tags (`okf--vX.Y.Z`) lag the plugin: `main` carried
# 0.6.0 while the newest tag was okf--v0.4.0. Track the branch head and
# take the version from the plugin manifest at that commit.
commit_json=$(curl -sfL --retry 3 --retry-delay 5 \
  -H "Accept: application/vnd.github+json" \
  "${auth_header[@]}" \
  "https://api.github.com/repos/${REPO}/commits/main")
latest_rev=$(echo "$commit_json" | jq -r '.sha')

if [ -z "$latest_rev" ] || [ "$latest_rev" = "null" ]; then
  echo "Failed to resolve main" >&2
  exit 1
fi

short_sha="${latest_rev:0:7}"

# Committer date (YYYY-MM-DD), taken from the commits/main response
# already fetched above rather than spending a second API call on it.
commit_date=$(echo "$commit_json" \
  | jq -r '.commit.committer.date' | cut -c1-10)

plugin_version=$(curl -sfL --retry 3 --retry-delay 5 \
  "${auth_header[@]}" \
  "https://raw.githubusercontent.com/${REPO}/${latest_rev}/.claude-plugin/plugin.json" \
  | jq -r '.version')

if [ -z "$plugin_version" ] || [ "$plugin_version" = "null" ]; then
  echo "Failed to resolve version" >&2
  exit 1
fi

# Upstream lands commits on main without always bumping plugin.json, so
# a bare semver would let the unattended workflow republish the same
# version tag over different content. Compose the recorded version with
# the commit date and short SHA so every rev gets a distinct version.
latest_version="${plugin_version}+unstable-${commit_date}.${short_sha}"

echo "Current: $current_version ($current_rev)"
echo "Latest:  $latest_version ($latest_rev)"

if [ "$current_rev" = "$latest_rev" ]; then
  echo "Already up to date"
  exit 0
fi

echo "Updating skills-okf to $latest_version ($latest_rev)"

src_url="https://github.com/${REPO}/archive/${latest_rev}.tar.gz"
echo "Fetching source from $src_url ..."
src_hash=$(nix-prefetch-url --unpack "$src_url" 2>/dev/null)
src_sri=$(nix --extra-experimental-features nix-command \
  hash convert --hash-algo sha256 --to sri "$src_hash")
echo "  srcHash: $src_sri"

jq -n \
  --arg v "$latest_version" \
  --arg r "$latest_rev" \
  --arg s "$src_sri" \
  '{version: $v, rev: $r, srcHash: $s}' > "$HASHES_FILE"

echo "Updated to $latest_version"
