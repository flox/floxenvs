#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HASHES_FILE="$SCRIPT_DIR/hashes.json"

current_version=$(jq -r '.version' "$HASHES_FILE")

# Authenticated API calls use Actions' 5000/hr quota. The
# unauthenticated 60/hr is shared per egress IP and gets exhausted
# by parallel runners, surfacing as `curl exit 22`.
auth_header=()
[ -n "${GITHUB_TOKEN:-}" ] \
  && auth_header=(-H "Authorization: Bearer $GITHUB_TOKEN")

# Latest stable v* release (skip prereleases and drafts).
latest_version=$(
  curl -sfL --retry 3 --retry-delay 5 \
    -H "Accept: application/vnd.github+json" \
    "${auth_header[@]}" \
    "https://api.github.com/repos/Hmbown/DeepSeek-TUI/releases" \
  | jq -r '[.[] | select(.prerelease == false and .draft == false)][0].tag_name' \
  | sed 's/^v//'
)

echo "Current: $current_version, Latest: $latest_version"

if [ "$current_version" = "$latest_version" ]; then
  echo "Already up to date"
  exit 0
fi

echo "Updating deepseek-tui from $current_version to $latest_version"

# Prefetch source from GitHub. Matches what `fetchFromGitHub` produces:
# GitHub's archive tarball, unpacked and hashed.
src_url="https://github.com/Hmbown/DeepSeek-TUI/archive/refs/tags/v${latest_version}.tar.gz"
echo "Fetching source from $src_url ..."
src_raw=$(nix-prefetch-url --unpack "$src_url" 2>/dev/null)
src_hash=$(nix --extra-experimental-features nix-command \
  hash convert --hash-algo sha256 --to sri "$src_raw")
echo "  hash: $src_hash"

# Save original hashes for rollback on failure
tmp_hashes=$(mktemp)
cp "$HASHES_FILE" "$tmp_hashes"
trap 'cp "$tmp_hashes" "$HASHES_FILE"; rm -f "$tmp_hashes"' EXIT

write_hashes() {
  local cargo_hash="$1"
  jq -n \
    --arg v "$latest_version" \
    --arg h "$src_hash" \
    --arg c "$cargo_hash" \
    '{version: $v, hash: $h, cargoHash: $c}' > "$HASHES_FILE"
}

# Build with a dummy cargoHash to read the real one from the
# fixed-output derivation mismatch.
write_hashes "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="

echo "Building with dummy cargoHash to compute real one..."
prefetch_log=$(mktemp)
flox build deepseek-tui > "$prefetch_log" 2>&1 || true

cargo_hash=$(awk '/hash mismatch in fixed-output derivation/,0 {
  if (/got:/) { print $NF; exit }
}' "$prefetch_log")

if [[ "$cargo_hash" != sha256-* ]]; then
  echo "ERROR: Could not extract cargoHash. Build output:" >&2
  tail -30 "$prefetch_log" >&2
  rm -f "$prefetch_log"
  exit 1
fi
rm -f "$prefetch_log"
echo "  cargoHash: $cargo_hash"

write_hashes "$cargo_hash"

# Hashes are good; clear the rollback trap.
rm -f "$tmp_hashes"
trap - EXIT

echo "Updated to $latest_version"
