#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HASHES_FILE="$SCRIPT_DIR/hashes.json"

auth_header=()
if [ -n "${GITHUB_TOKEN:-}" ]; then
  auth_header=(-H "Authorization: Bearer $GITHUB_TOKEN")
fi

prefetch() {
  # $1 = tarball URL -> SRI hash on stdout
  local url="$1" hash
  hash=$(nix-prefetch-url --unpack "$url" 2>/dev/null)
  nix hash convert --hash-algo sha256 --to sri "$hash"
}

submodule_sha() {
  # $1 = path of a submodule inside the mkslides tree at $2 (a ref)
  curl -sfL "${auth_header[@]}" \
    "https://api.github.com/repos/MartenBE/mkslides/contents/$1?ref=$2" \
    | jq -r '.sha'
}

current_version=$(jq -r '.version' "$HASHES_FILE")
latest_version=$(curl -sfL "${auth_header[@]}" \
  https://api.github.com/repos/MartenBE/mkslides/releases/latest \
  | jq -r '.tag_name')

echo "Current: $current_version, Latest: $latest_version"

if [ "$current_version" = "$latest_version" ]; then
  echo "Already up to date"
  exit 0
fi

echo "Updating mkslides from $current_version to $latest_version"

src_sri=$(prefetch \
  "https://github.com/MartenBE/mkslides/archive/refs/tags/${latest_version}.tar.gz")
echo "  srcHash: $src_sri"

# reveal.js and the highlight.js cdn-release are submodules, empty in the
# release tarball, so their pinned revisions are read from the tree and
# fetched separately (see default.nix).
revealjs_rev=$(submodule_sha src/mkslides/assets/reveal.js "$latest_version")
revealjs_sri=$(prefetch \
  "https://github.com/hakimel/reveal.js/archive/${revealjs_rev}.tar.gz")
echo "  revealjs: $revealjs_rev $revealjs_sri"

highlightjs_rev=$(submodule_sha src/mkslides/assets/highlight.js \
  "$latest_version")
highlightjs_sri=$(prefetch \
  "https://github.com/highlightjs/cdn-release/archive/${highlightjs_rev}.tar.gz")
echo "  highlightjs: $highlightjs_rev $highlightjs_sri"

jq -n \
  --arg v "$latest_version" \
  --arg s "$src_sri" \
  --arg rr "$revealjs_rev" \
  --arg rh "$revealjs_sri" \
  --arg hr "$highlightjs_rev" \
  --arg hh "$highlightjs_sri" \
  '{version: $v, srcHash: $s,
    revealjsRev: $rr, revealjsHash: $rh,
    highlightjsRev: $hr, highlightjsHash: $hh}' > "$HASHES_FILE"

echo "Updated to $latest_version"
