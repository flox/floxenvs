#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HASHES_FILE="$SCRIPT_DIR/hashes.json"

current_version=$(jq -r '.version' "$HASHES_FILE")

# Get latest stable rust-v* tag from GitHub (skip prereleases and drafts)
latest_version=$(
  curl -sfL \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/repos/openai/codex/releases" \
  | jq -r '[.[] | select(.prerelease == false and .draft == false and (.tag_name | startswith("rust-v")))][0].tag_name' \
  | sed 's/^rust-v//'
)

echo "Current: $current_version, Latest: $latest_version"

if [ "$current_version" = "$latest_version" ]; then
  echo "Already up to date"
  exit 0
fi

echo "Updating codex from $current_version to $latest_version"

# Prefetch source from GitHub
src_hash=$(nix-prefetch-fetchFromGitHub \
  --owner openai \
  --repo codex \
  --tag "rust-v${latest_version}" 2>/dev/null)
echo "  hash: $src_hash"

# Prefetch cargo deps
workdir=$(mktemp -d)
trap 'rm -rf "$workdir"' EXIT

git clone --depth 1 --branch "rust-v${latest_version}" \
  https://github.com/openai/codex.git "$workdir/codex"

cargo_hash=$(
  nix run nixpkgs#nix-prefetch -- \
    fetchCargoVendor \
    --src "$workdir/codex" \
    --source-root "source/codex-rs" 2>/dev/null \
  || echo "MANUAL_UPDATE_NEEDED"
)
echo "  cargoHash: $cargo_hash"

# Read current v8 and livekit values (these change less often)
v8_version=$(jq -r '.librusty_v8.version' "$HASHES_FILE")
v8_hashes=$(jq '.librusty_v8.hashes' "$HASHES_FILE")
lk_tag=$(jq -r '.livekit_webrtc.tag' "$HASHES_FILE")
lk_hashes=$(jq '.livekit_webrtc.hashes' "$HASHES_FILE")

# Write updated hashes (v8 and livekit hashes kept as-is)
jq -n \
  --arg v "$latest_version" \
  --arg h "$src_hash" \
  --arg c "$cargo_hash" \
  --arg v8v "$v8_version" \
  --argjson v8h "$v8_hashes" \
  --arg lkt "$lk_tag" \
  --argjson lkh "$lk_hashes" \
  '{
    version: $v,
    hash: $h,
    cargoHash: $c,
    librusty_v8: { version: $v8v, hashes: $v8h },
    livekit_webrtc: { tag: $lkt, hashes: $lkh }
  }' > "$HASHES_FILE"

echo "Updated to $latest_version"
echo "NOTE: librusty_v8 and livekit_webrtc hashes were kept as-is."
echo "      If the build fails, check if those deps changed upstream."
