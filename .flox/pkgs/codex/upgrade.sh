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

# Prefetch source from GitHub. Matches what `fetchFromGitHub` produces:
# GitHub's archive tarball, unpacked and hashed.
src_url="https://github.com/openai/codex/archive/refs/tags/rust-v${latest_version}.tar.gz"
src_raw=$(nix-prefetch-url --unpack "$src_url" 2>/dev/null)
src_hash=$(nix --extra-experimental-features nix-command \
  hash convert --hash-algo sha256 --to sri "$src_raw")
echo "  hash: $src_hash"

# Compute cargoHash by building the cargoDeps FOD with a fake hash
# and reading the real one from the mismatch error. Mirrors the
# crush/openclaw pattern; previously used `nix run nixpkgs#nix-prefetch`,
# which broke in CI ("file 'nixpkgs' was not found in the Nix search
# path") and silently emitted a placeholder before that.
#
# Read the v8 and livekit hashes (rarely change) so we can rewrite
# the file with a fake cargoHash without losing them.
v8_version=$(jq -r '.librusty_v8.version' "$HASHES_FILE")
v8_hashes=$(jq '.librusty_v8.hashes' "$HASHES_FILE")
lk_tag=$(jq -r '.livekit_webrtc.tag' "$HASHES_FILE")
lk_hashes=$(jq '.livekit_webrtc.hashes' "$HASHES_FILE")

tmp_hashes=$(mktemp)
cp "$HASHES_FILE" "$tmp_hashes"
trap 'cp "$tmp_hashes" "$HASHES_FILE"; rm -f "$tmp_hashes"' EXIT

write_hashes() {
  local cargo_hash="$1"
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
}

write_hashes "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="

echo "Building with dummy cargoHash to compute real one..."
prefetch_log=$(mktemp)
flox build codex > "$prefetch_log" 2>&1 || true

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
echo "NOTE: librusty_v8 and livekit_webrtc hashes were kept as-is."
echo "      If the build fails, check if those deps changed upstream."
