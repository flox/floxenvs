#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HASHES_FILE="$SCRIPT_DIR/hashes.json"

auth_header=()
if [ -n "${GITHUB_TOKEN:-}" ]; then
  auth_header=(-H "Authorization: Bearer $GITHUB_TOKEN")
fi

current_version=$(jq -r '.version' "$HASHES_FILE")
latest_tag=$(curl -sfL "${auth_header[@]}" \
  https://api.github.com/repos/vercel-labs/agent-browser/releases/latest \
  | jq -r '.tag_name')
latest_version="${latest_tag#v}"

echo "Current: $current_version, Latest: $latest_version"

if [ "$current_version" = "$latest_version" ]; then
  echo "Already up to date"
  exit 0
fi

echo "Updating agent-browser from $current_version to $latest_version"

src_url="https://github.com/vercel-labs/agent-browser/archive/refs/tags/v${latest_version}.tar.gz"
src_hash=$(nix-prefetch-url --unpack "$src_url" 2>/dev/null)
src_sri=$(nix hash convert --hash-algo sha256 --to sri "$src_hash")
echo "  srcHash: $src_sri"

dummy="sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="

write_hashes() {
  jq -n \
    --arg v "$latest_version" \
    --arg s "$src_sri" \
    --arg c "$cargo_hash" \
    --arg p "$pnpm_hash" \
    '{version: $v, srcHash: $s, cargoHash: $c, pnpmDepsHash: $p}' \
    > "$HASHES_FILE"
}

# Extract the `got:` hash from the mismatch block whose fixed-output
# derivation name contains the given substring. Keying on the drv name
# (not log position) is required because the pnpm-deps and cargo
# vendor-staging FODs build in parallel and either can surface first.
extract_got() {
  awk -v pat="$1" '
    /hash mismatch in fixed-output derivation/ { cur = ($0 ~ pat) ? 1 : 0; next }
    cur && /got:/ { print $NF; cur = 0 }
  ' "$2"
}

backup=$(mktemp)
cp "$HASHES_FILE" "$backup"
build_log=$(mktemp)
cleanup() { rm -f "$backup" "$build_log"; }
trap cleanup EXIT

# The dashboard's pnpm deps (`*-pnpm-deps`) and the Rust crate's cargo
# vendor (`*-vendor-staging`) are independent fixed-output derivations.
# Nix stops at the first one that fails, so a single build may reveal
# only one real hash. Loop: feed back each hash we learn until a build
# completes with no remaining mismatch.
pnpm_hash="$dummy"
cargo_hash="$dummy"

echo "Building with dummy hashes to compute real ones..."
for attempt in 1 2 3 4; do
  write_hashes
  if flox build agent-browser > "$build_log" 2>&1; then
    echo "Build succeeded with resolved hashes"
    break
  fi

  changed=0
  new_pnpm=$(extract_got 'pnpm-deps' "$build_log")
  new_cargo=$(extract_got 'vendor-staging' "$build_log")
  if [ -n "$new_pnpm" ] && [ "$new_pnpm" != "$pnpm_hash" ]; then
    pnpm_hash="$new_pnpm"
    echo "  pnpmDepsHash: $pnpm_hash"
    changed=1
  fi
  if [ -n "$new_cargo" ] && [ "$new_cargo" != "$cargo_hash" ]; then
    cargo_hash="$new_cargo"
    echo "  cargoHash: $cargo_hash"
    changed=1
  fi

  if [ "$changed" -eq 0 ]; then
    echo "ERROR: build failed without a resolvable hash mismatch." >&2
    tail -30 "$build_log" >&2
    cp "$backup" "$HASHES_FILE"
    exit 1
  fi
done

if [ "$pnpm_hash" = "$dummy" ] || [ "$cargo_hash" = "$dummy" ]; then
  echo "ERROR: failed to resolve both hashes after retries." >&2
  tail -30 "$build_log" >&2
  cp "$backup" "$HASHES_FILE"
  exit 1
fi

write_hashes
echo "Updated to $latest_version"
