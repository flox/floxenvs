#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HASHES_FILE="$SCRIPT_DIR/hashes.json"

# This package stands in for the catalog's ruby_3_3, so it only ever tracks
# the 3.3 series. When 3.3 is no longer supported, delete the package rather
# than moving SERIES.
SERIES="3.3"
END_OF_SUPPORT="2027-03-31"

if [ "$(date -u +%F)" \> "$END_OF_SUPPORT" ]; then
  echo "::warning title=ruby_3_3::Ruby $SERIES reached end of support on $END_OF_SUPPORT; delete .flox/pkgs/ruby_3_3"
fi

current_version=$(jq -r '.version' "$HASHES_FILE")

# index.txt columns: name, url, sha1, sha256, sha512. Previews and release
# candidates have a suffix after the patch number, so the anchored match
# skips them.
index=$(curl -sfL 'https://cache.ruby-lang.org/pub/ruby/index.txt')

latest_version=$(echo "$index" \
  | awk -F'\t' -v s="$SERIES" \
    '$1 ~ "^ruby-" s "\\.[0-9]+$" && $2 ~ /\.tar\.gz$/ {sub(/^ruby-/, "", $1); print $1}' \
  | sort -V | tail -n 1)

if [ -z "$latest_version" ]; then
  echo "No ruby-$SERIES.x release found in the upstream index" >&2
  exit 1
fi

echo "Current: $current_version, Latest: $latest_version"

if [ "$current_version" = "$latest_version" ]; then
  echo "Already up to date"
  exit 0
fi

echo "Updating ruby_3_3 from $current_version to $latest_version"

sha256=$(echo "$index" \
  | awk -F'\t' -v n="ruby-$latest_version" \
    '$1 == n && $2 ~ /\.tar\.gz$/ {print $4}')
sri_hash=$(nix --extra-experimental-features nix-command \
  hash convert --hash-algo sha256 --to sri "$sha256")

# cargoHash vendors yjit/Cargo.lock, which rarely changes within a series.
# It is kept as is; a build that fails on a vendor hash mismatch means the
# new release changed it.
updated=$(jq --arg v "$latest_version" --arg h "$sri_hash" \
  '.version = $v | .hash = $h' "$HASHES_FILE")
echo "$updated" > "$HASHES_FILE"

echo "Updated to $latest_version"
