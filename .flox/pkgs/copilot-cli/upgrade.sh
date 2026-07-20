#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HASHES_FILE="$SCRIPT_DIR/hashes.json"

current_version=$(jq -r '.version' "$HASHES_FILE")
latest_version=$(curl -sfL https://registry.npmjs.org/@github/copilot \
  | jq -r '."dist-tags".latest')

echo "Current: $current_version, Latest: $latest_version"

if [ "$current_version" = "$latest_version" ]; then
  echo "Already up to date"
  exit 0
fi

echo "Updating copilot-cli from $current_version to $latest_version"

# default.nix fetches the per-platform `@github/copilot-<platform>-<arch>`
# package (not the thin meta-package), so prefetch one hash per system.
declare -A platform_suffixes=(
  [aarch64-darwin]=darwin-arm64
  [x86_64-darwin]=darwin-x64
  [aarch64-linux]=linux-arm64
  [x86_64-linux]=linux-x64
)

src_hashes="{}"
for system in "${!platform_suffixes[@]}"; do
  suffix="${platform_suffixes[$system]}"
  src_url="https://registry.npmjs.org/@github/copilot-${suffix}/-/copilot-${suffix}-${latest_version}.tgz"
  echo "Fetching $system from $src_url ..."
  src_hash=$(nix-prefetch-url "$src_url" 2>/dev/null)
  src_sri=$(nix hash convert --hash-algo sha256 --to sri "$src_hash")
  echo "  $system: $src_sri"
  src_hashes=$(jq --arg k "$system" --arg v "$src_sri" '.[$k] = $v' <<<"$src_hashes")
done

jq -n \
  --arg v "$latest_version" \
  --argjson h "$src_hashes" \
  '{version: $v, srcHashes: $h}' > "$HASHES_FILE"

echo "Updated to $latest_version"
