#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HASHES_FILE="$SCRIPT_DIR/hashes.json"

OWNER="heygen-com"
REPO="hyperframes"

current_commit=$(jq -r '.commit' "$HASHES_FILE")

# heygen-com/hyperframes tags many npm packages (the CLI, @hyperframes/*)
# but does not maintain a single "skills bundle" tag, so HEAD of `main`
# is the canonical source — exactly like remotion-dev/skills. Pin to
# the committer date so the floxhub version field stays monotonic.
latest_commit=$(curl -sf \
  "https://api.github.com/repos/$OWNER/$REPO/commits/main" \
  | jq -r '.sha')
latest_date=$(curl -sf \
  "https://api.github.com/repos/$OWNER/$REPO/commits/$latest_commit" \
  | jq -r '.commit.committer.date')
latest_version=$(echo "$latest_date" | cut -dT -f1 | tr - .)

echo "Current commit: $current_commit"
echo "Latest commit:  $latest_commit ($latest_version)"

if [ "$current_commit" = "$latest_commit" ]; then
  echo "Already up to date"
  exit 0
fi

echo "Updating claude-code-plugin-hyperframes to $latest_version ($latest_commit)"

src_url="https://github.com/$OWNER/$REPO/archive/${latest_commit}.tar.gz"
echo "Fetching source from $src_url ..."
src_hash=$(nix-prefetch-url --unpack "$src_url" 2>/dev/null)
src_sri=$(nix --extra-experimental-features nix-command \
  hash convert --hash-algo sha256 --to sri "$src_hash")
echo "  srcHash: $src_sri"

jq -n \
  --arg v "$latest_version" \
  --arg c "$latest_commit" \
  --arg s "$src_sri" \
  '{version: $v, commit: $c, srcHash: $s}' > "$HASHES_FILE"

echo "Updated to $latest_version"
