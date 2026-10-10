#!/usr/bin/env bash

set -euo pipefail

# Authenticate when a token is available (CI) so the GitHub API applies the
# 5000/hr limit instead of the shared 60/hr anonymous one. Must stay
# conditional: an empty Bearer value makes GitHub reject the request, which
# would break local runs where GITHUB_TOKEN is unset.
auth_header=()
if [ -n "${GITHUB_TOKEN:-}" ]; then
  auth_header=(-H "Authorization: Bearer $GITHUB_TOKEN")
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HASHES_FILE="$SCRIPT_DIR/hashes.json"

# This script bumps the main mistral-vibe version + srcHash, and
# recomputes the Rust vendor hash for harness/core.
# Python dep overrides in default.nix (textual, pydantic-settings,
# mistralai, agent-client-protocol, otel) are pinned to versions that
# match the API contract upstream pins. If a new mistral-vibe release
# requires different dep versions, those hashes must be updated by
# hand alongside this script's output.

current_version=$(jq -r '.version' "$HASHES_FILE")
latest_tag=$(curl -sSfL "${auth_header[@]}" \
  https://api.github.com/repos/mistralai/mistral-vibe/releases/latest \
  | jq -r '.tag_name')
latest_version="${latest_tag#v}"

echo "Current: $current_version, Latest: $latest_version"

if [ "$current_version" = "$latest_version" ]; then
  echo "Already up to date"
  exit 0
fi

echo "Updating mistral-vibe from $current_version to $latest_version"

src_url="https://github.com/mistralai/mistral-vibe/archive/refs/tags/v${latest_version}.tar.gz"
echo "Fetching source from $src_url ..."
src_hash=$(nix-prefetch-url --unpack "$src_url" 2>/dev/null)
src_sri=$(nix hash convert --hash-algo sha256 --to sri "$src_hash")
echo "  srcHash: $src_sri"

# harness/core carries its own Cargo.lock, so a release that touches it
# changes the vendor hash. Stage a known-bad one, let the build report
# the real value, and parse it out — the same fake-hash trick the other
# packages here use. Without this step every bump failed with
#   hash mismatch in fixed-output derivation
#   '...-harness-core-vendor-staging.drv'
# because the hash lived inline in default.nix where this script could
# not reach it.
fake_hash="sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="

jq -n \
  --arg v "$latest_version" \
  --arg s "$src_sri" \
  --arg c "$fake_hash" \
  '{version: $v, srcHash: $s, cargoVendorHash: $c}' > "$HASHES_FILE"

echo "Building with a dummy cargoVendorHash to compute the real one..."
prefetch_log=$(mktemp)
flox build mistral-vibe > "$prefetch_log" 2>&1 || true

# `|| true`: under `set -o pipefail` a grep that matches nothing would
# kill the script here, before the diagnostic below can print.
vendor_hash=$(
  grep -A2 'hash mismatch in fixed-output derivation' "$prefetch_log" \
  | grep 'got:' \
  | head -1 \
  | awk '{print $NF}' \
  || true
)

if [ -z "$vendor_hash" ]; then
  echo "ERROR: could not extract cargoVendorHash. Build output:" >&2
  tail -30 "$prefetch_log" >&2
  rm -f "$prefetch_log"
  exit 1
fi
rm -f "$prefetch_log"

echo "  cargoVendorHash: $vendor_hash"

jq -n \
  --arg v "$latest_version" \
  --arg s "$src_sri" \
  --arg c "$vendor_hash" \
  '{version: $v, srcHash: $s, cargoVendorHash: $c}' > "$HASHES_FILE"

echo "Updated to $latest_version"
echo "WARNING: Python dep overrides in default.nix may need" \
  "hand-updating to match new upstream constraints." >&2
