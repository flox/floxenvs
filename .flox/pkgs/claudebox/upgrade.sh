#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HASHES_FILE="$SCRIPT_DIR/hashes.json"

current_version=$(jq -r '.version' "$HASHES_FILE")
latest_tag=$(curl -sfL \
  https://api.github.com/repos/numtide/claudebox/releases/latest \
  | jq -r '.tag_name')
latest_version="${latest_tag#v}"

echo "Current: $current_version, Latest: $latest_version"

if [ "$current_version" = "$latest_version" ]; then
  echo "Already up to date"
  exit 0
fi

echo "Updating claudebox from $current_version to $latest_version"

src_url="https://github.com/numtide/claudebox/archive/refs/tags/v${latest_version}.tar.gz"
src_hash=$(nix-prefetch-url --unpack "$src_url" 2>/dev/null)
src_sri=$(nix hash convert --hash-algo sha256 --to sri "$src_hash")
echo "  srcHash: $src_sri"

jq -n \
  --arg v "$latest_version" \
  --arg s "$src_sri" \
  '{version: $v, srcHash: $s}' > "$HASHES_FILE"

# Refresh the vendored seatbelt.sbpl in case upstream tightened the
# policy. Best-effort — leave the existing one if upstream moved it.
sbpl_url="https://raw.githubusercontent.com/numtide/claudebox/v${latest_version}/seatbelt.sbpl"
if curl -sfL "$sbpl_url" -o "$SCRIPT_DIR/seatbelt.sbpl.tmp" 2>/dev/null; then
  mv "$SCRIPT_DIR/seatbelt.sbpl.tmp" "$SCRIPT_DIR/seatbelt.sbpl"
  echo "  refreshed seatbelt.sbpl from upstream"
else
  echo "  NOTE: could not fetch upstream seatbelt.sbpl;" \
    "review by hand if upstream changed it" >&2
fi

echo "Updated to $latest_version"
