#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HASHES_FILE="$SCRIPT_DIR/hashes.json"

current_version=$(jq -r '.version' "$HASHES_FILE")
latest_version=$(curl -sf https://api.github.com/repos/ollama/ollama/releases/latest \
  | jq -r '.tag_name' | sed 's/^v//')

echo "Current: $current_version, Latest: $latest_version"

if [ "$current_version" = "$latest_version" ]; then
  echo "Already up to date"
  exit 0
fi

echo "Updating ollama from $current_version to $latest_version"

# Download and hash the new source tarball
src_url="https://github.com/ollama/ollama/archive/refs/tags/v${latest_version}.tar.gz"
echo "Fetching source from $src_url ..."
src_hash=$(nix-prefetch-url --unpack "$src_url" 2>/dev/null)
src_sri=$(nix hash convert --hash-algo sha256 --to sri "$src_hash")
echo "  srcHash: $src_sri"

# ollama 0.30+ fetches a pinned llama.cpp revision via CMake FetchContent.
# The pin lives in the repo's LLAMA_CPP_VERSION file; prefetch that exact
# revision so default.nix can supply it to the sandboxed build offline.
llama_cpp_tag=$(curl -sfL \
  "https://raw.githubusercontent.com/ollama/ollama/v${latest_version}/LLAMA_CPP_VERSION" \
  | tr -d '[:space:]')
echo "Pinned llama.cpp: $llama_cpp_tag"
llama_url="https://github.com/ggml-org/llama.cpp/archive/refs/tags/${llama_cpp_tag}.tar.gz"
llama_hash=$(nix-prefetch-url --unpack "$llama_url" 2>/dev/null)
llama_sri=$(nix hash convert --hash-algo sha256 --to sri "$llama_hash")
echo "  llamaCppHash: $llama_sri"

# Build with a dummy vendorHash to get the real one. The goModules
# fixed-output derivation is built before compilation, so the hash
# mismatch surfaces immediately.
tmp_hashes=$(mktemp)
cp "$HASHES_FILE" "$tmp_hashes"

jq -n \
  --arg v "$latest_version" \
  --arg s "$src_sri" \
  --arg vh "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=" \
  --arg lt "$llama_cpp_tag" \
  --arg lh "$llama_sri" \
  '{version: $v, srcHash: $s, vendorHash: $vh, llamaCppTag: $lt, llamaCppHash: $lh}' \
  > "$HASHES_FILE"

echo "Building with dummy vendorHash to compute real one..."
prefetch_log=$(mktemp)
flox build ollama > "$prefetch_log" 2>&1 || true

vendor_hash=$(awk '/hash mismatch in fixed-output derivation/,0 {
  if (/got:/) { print $NF; exit }
}' "$prefetch_log")

if [ -z "$vendor_hash" ]; then
  echo "ERROR: Could not extract vendorHash. Build output:" >&2
  tail -20 "$prefetch_log" >&2
  cp "$tmp_hashes" "$HASHES_FILE"
  rm -f "$tmp_hashes" "$prefetch_log"
  exit 1
fi
rm -f "$tmp_hashes" "$prefetch_log"

echo "  vendorHash: $vendor_hash"

# Write final hashes
jq -n \
  --arg v "$latest_version" \
  --arg s "$src_sri" \
  --arg vh "$vendor_hash" \
  --arg lt "$llama_cpp_tag" \
  --arg lh "$llama_sri" \
  '{version: $v, srcHash: $s, vendorHash: $vh, llamaCppTag: $lt, llamaCppHash: $lh}' \
  > "$HASHES_FILE"

echo "Updated to $latest_version"
