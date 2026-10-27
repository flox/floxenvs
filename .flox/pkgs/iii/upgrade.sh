#!/usr/bin/env bash

set -euo pipefail

# iii is packaged for the agentmemory environment, whose CLI only runs
# the exact iii version it pins. Track that pin, not iii's latest
# release: read AGENTMEMORY_VERSION from the agentmemory manifest and
# take the iii version, and the sha256 of each release asset, out of
# that @agentmemory/agentmemory release. hashes.json records which
# agentmemory release it was derived from, so unchanged pins cost no
# network.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HASHES_FILE="$SCRIPT_DIR/hashes.json"
MANIFEST="$SCRIPT_DIR/../../../agentmemory/.flox/env/manifest.toml"

agentmemory_version=$(sed -nE 's/^AGENTMEMORY_VERSION[[:space:]]*=[[:space:]]*"([^"]+)".*/\1/p' "$MANIFEST")
if [ -z "$agentmemory_version" ]; then
  echo "AGENTMEMORY_VERSION not found in $MANIFEST" >&2
  exit 1
fi

recorded=$(jq -r '.agentmemoryVersion // empty' "$HASHES_FILE")
if [ "$recorded" = "$agentmemory_version" ]; then
  echo "Already derived from agentmemory $agentmemory_version"
  exit 0
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
curl -sSfL -o "$tmp/agentmemory.tgz" \
  "https://registry.npmjs.org/@agentmemory/agentmemory/-/agentmemory-$agentmemory_version.tgz"
tar -xzf "$tmp/agentmemory.tgz" -C "$tmp"
cli="$tmp/package/dist/cli.mjs"

pin=$(sed -nE 's/.*III_PINNED_VERSION = "([^"]+)".*/\1/p' "$tmp"/package/dist/*.mjs | sort -u)
if [ -z "$pin" ] || [ "$(wc -l <<<"$pin")" -ne 1 ]; then
  echo "Expected one III_PINNED_VERSION in agentmemory $agentmemory_version, got: ${pin:-none}" >&2
  exit 1
fi

# The CLI ships the sha256 of every asset of the pinned release in
# III_RELEASE_SHA256, keyed by version then asset name. Print the
# entries of the pinned version's block.
release_sha256() {
  awk -v ver="\"$pin\": {" '
    index($0, ver) { inblock = 1; next }
    inblock && /^}/ { exit }
    inblock && /^\t?"iii-/ { print }
  ' "$cli" | sed -nE 's/^[[:space:]]*"([^"]+)": "([0-9a-f]{64})".*/\1 \2/p'
}
sums=$(release_sha256)

echo "agentmemory $agentmemory_version pins iii $pin (packaged: $(jq -r '.version' "$HASHES_FILE"))"

# <flox system>=<iii release target>, as a list rather than an
# associative array so this also runs under macOS's bash 3.2.
PLATFORMS=(
  "aarch64-darwin=aarch64-apple-darwin"
  "aarch64-linux=aarch64-unknown-linux-gnu"
  "x86_64-linux=x86_64-unknown-linux-gnu"
)

hashes_json="{}"
for entry in "${PLATFORMS[@]}"; do
  system="${entry%%=*}"
  asset="iii-${entry#*=}.tar.gz"
  hex=$(awk -v a="$asset" '$1 == a { print $2 }' <<<"$sums")
  if [ -z "$hex" ]; then
    echo "No sha256 for $asset in agentmemory $agentmemory_version's III_RELEASE_SHA256" >&2
    exit 1
  fi
  sri=$(nix hash convert --hash-algo sha256 --from base16 --to sri "$hex")
  echo "  $system: $sri"
  hashes_json=$(echo "$hashes_json" \
    | jq --arg p "$system" --arg h "$sri" '.[$p] = $h')
done

jq -n \
  --arg v "$pin" \
  --arg a "$agentmemory_version" \
  --argjson h "$hashes_json" \
  '{version: $v, agentmemoryVersion: $a, hashes: ($h | to_entries | sort_by(.key) | from_entries)}' \
  > "$HASHES_FILE"

echo "Updated to iii $pin"
