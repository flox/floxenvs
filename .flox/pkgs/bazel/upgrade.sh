#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HASHES_FILE="$SCRIPT_DIR/hashes.json"

current_version=$(jq -r '.version' "$HASHES_FILE")
latest_version=$(curl -sf \
  https://api.github.com/repos/bazelbuild/bazel/releases/latest \
  | jq -r '.tag_name')

echo "Current: $current_version, Latest: $latest_version"

if [ "$current_version" = "$latest_version" ]; then
  echo "Already up to date"
  exit 0
fi

echo "Updating bazel from $current_version to $latest_version"

declare -A NIX_TO_SUFFIX=(
  [aarch64-darwin]=darwin-arm64
  [x86_64-darwin]=darwin-x86_64
  [aarch64-linux]=linux-arm64
  [x86_64-linux]=linux-x86_64
)

base="https://github.com/bazelbuild/bazel/releases/download/${latest_version}"

tmp_json=$(mktemp)
jq -n --arg v "$latest_version" '{version: $v, hashes: {}}' > "$tmp_json"

for sys in "${!NIX_TO_SUFFIX[@]}"; do
  suffix="${NIX_TO_SUFFIX[$sys]}"
  sha_url="${base}/bazel-${latest_version}-${suffix}.sha256"

  echo "  ${sys} <- ${suffix}"
  hex=$(curl -sfL "$sha_url" | awk '{print $1}')
  if [ -z "$hex" ] || [ "${#hex}" -ne 64 ]; then
    echo "ERROR: bad sha256 for $sys from $sha_url" >&2
    rm -f "$tmp_json"
    exit 1
  fi

  sri=$(nix hash convert --hash-algo sha256 --to sri "$hex")
  jq --arg s "$sys" --arg h "$sri" \
    '.hashes[$s] = $h' "$tmp_json" > "$tmp_json.new"
  mv "$tmp_json.new" "$tmp_json"
done

mv "$tmp_json" "$HASHES_FILE"
echo "Updated to $latest_version"
