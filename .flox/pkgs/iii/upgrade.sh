#!/usr/bin/env bash

set -euo pipefail

# iii is packaged for the agentmemory environment, whose CLI only runs
# the exact iii version it pins. Track that pin, not iii's latest
# release: read AGENTMEMORY_VERSION from the agentmemory manifest and
# take the iii version out of that @agentmemory/agentmemory release.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HASHES_FILE="$SCRIPT_DIR/hashes.json"
MANIFEST="$SCRIPT_DIR/../../../agentmemory/.flox/env/manifest.toml"

agentmemory_version=$(sed -n 's/^AGENTMEMORY_VERSION = "\(.*\)"$/\1/p' "$MANIFEST")
if [ -z "$agentmemory_version" ]; then
  echo "AGENTMEMORY_VERSION not found in $MANIFEST" >&2
  exit 1
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
curl -sSfL -o "$tmp/agentmemory.tgz" \
  "https://registry.npmjs.org/@agentmemory/agentmemory/-/agentmemory-$agentmemory_version.tgz"
tar -xzf "$tmp/agentmemory.tgz" -C "$tmp"
# Newer releases declare `III_PINNED_VERSION = "x"`; older ones inline
# the pin behind an AGENTMEMORY_III_VERSION override.
latest_version=$(grep -hoE \
  '(III_PINNED_VERSION = |IIPINNED_VERSION = process\.env\["AGENTMEMORY_III_VERSION"\] \|\| )"[0-9][^"]*"' \
  "$tmp"/package/dist/*.mjs | head -1 | sed 's/.*"\(.*\)"/\1/' || true)
if [ -z "$latest_version" ]; then
  echo "No iii version pin found in @agentmemory/agentmemory@$agentmemory_version" >&2
  exit 1
fi

current_version=$(jq -r '.version' "$HASHES_FILE")

echo "Current: $current_version, pinned by agentmemory $agentmemory_version: $latest_version"

if [ "$current_version" = "$latest_version" ]; then
  echo "Already up to date"
  exit 0
fi

# Never downgrade: the package can land before the manifest bump
# that moves AGENTMEMORY_VERSION up to it.
newest=$(printf '%s\n%s\n' "$current_version" "$latest_version" | sort -V | tail -1)
if [ "$newest" = "$current_version" ]; then
  echo "Pinned version is older than the packaged one; leaving it"
  exit 0
fi

echo "Updating iii from $current_version to $latest_version"

declare -A PLATFORMS=(
  ["aarch64-darwin"]="aarch64-apple-darwin"
  ["aarch64-linux"]="aarch64-unknown-linux-gnu"
  ["x86_64-linux"]="x86_64-unknown-linux-gnu"
)

hashes_json="{}"
for system in "${!PLATFORMS[@]}"; do
  target="${PLATFORMS[$system]}"
  url="https://github.com/iii-hq/iii/releases/download/iii/v$latest_version/iii-$target.tar.gz"
  echo "  fetching $system"
  hash=$(nix-prefetch-url "$url" 2>/dev/null)
  sri=$(nix hash convert --hash-algo sha256 --to sri "$hash")
  echo "    $system: $sri"
  hashes_json=$(echo "$hashes_json" \
    | jq --arg p "$system" --arg h "$sri" '.[$p] = $h')
done

jq -n \
  --arg v "$latest_version" \
  --argjson h "$hashes_json" \
  '{version: $v, hashes: ($h | to_entries | sort_by(.key) | from_entries)}' \
  > "$HASHES_FILE"

echo "Updated to $latest_version"
