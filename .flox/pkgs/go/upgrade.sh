#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HASHES_FILE="$SCRIPT_DIR/hashes.json"

# default.nix overrides nixpkgs' go_1_27, whose patches target this series.
SERIES="1.27"

current_version=$(jq -r '.version' "$HASHES_FILE")

release=$(curl -sfL 'https://go.dev/dl/?mode=json&include=all' \
  | jq -c --arg s "go${SERIES}." \
    '[.[] | select(.stable and (.version | startswith($s)))][0]')

latest_version=$(echo "$release" | jq -r '.version | ltrimstr("go")')

echo "Current: $current_version, Latest: $latest_version"

if [ "$current_version" = "$latest_version" ]; then
  echo "Already up to date"
  exit 0
fi

echo "Updating go from $current_version to $latest_version"

sha256=$(echo "$release" | jq -r '.files[] | select(.kind == "source") | .sha256')
sri_hash=$(nix --extra-experimental-features nix-command \
  hash convert --hash-algo sha256 --to sri "$sha256")

jq -n --arg v "$latest_version" --arg h "$sri_hash" \
  '{version: $v, hash: $h}' > "$HASHES_FILE"

echo "Updated to $latest_version"
