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

current_version=$(jq -r '.version' "$HASHES_FILE")
# Pick the newest stable CLI tag, not `releases/latest`. The repo
# publishes three independent lines from one repository — the CLI as
# `vX.Y.Z`, plus `sdk-typescript-vX.Y.Z` and `desktop-vX.Y.Z` — and
# GitHub's `releases/latest` returns whichever was published most
# recently regardless of line. It had started answering
# `sdk-typescript-v0.1.18`, which this script then fed to the CLI
# tarball URL as version "sdk-typescript-v0.1.18" and failed on.
#
# Releases are no use even filtered: of the last 100, the only stable
# `vX.Y.Z` release is v0.21.2, older than the pin this script is meant
# to advance. The CLI line is tagged rather than released, so read tags
# and sort them numerically, skipping the `-preview`/`-nightly`
# prereleases that share the prefix.
latest_tag=$(curl -sSfL "${auth_header[@]}" \
  "https://api.github.com/repos/QwenLM/qwen-code/tags?per_page=100" \
  | jq -r '[.[].name | select(test("^v[0-9]+\\.[0-9]+\\.[0-9]+$"))]
           | sort_by(sub("^v"; "") | split(".") | map(tonumber))
           | last')

if [ -z "$latest_tag" ] || [ "$latest_tag" = "null" ]; then
  echo "ERROR: failed to find a stable vX.Y.Z qwen-code tag" >&2
  exit 1
fi

latest_version="${latest_tag#v}"

echo "Current: $current_version, Latest: $latest_version"

if [ "$current_version" = "$latest_version" ]; then
  echo "Already up to date"
  exit 0
fi

echo "Updating qwen-code from $current_version to $latest_version"

src_url="https://github.com/QwenLM/qwen-code/archive/refs/tags/v${latest_version}.tar.gz"
src_hash=$(nix-prefetch-url --unpack "$src_url" 2>/dev/null)
src_sri=$(nix hash convert --hash-algo sha256 --to sri "$src_hash")
echo "  srcHash: $src_sri"

dummy="sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
jq -n \
  --arg v "$latest_version" \
  --arg s "$src_sri" \
  --arg n "$dummy" \
  '{version: $v, srcHash: $s, pnpmDepsHash: $n}' > "$HASHES_FILE"

echo "Building with dummy pnpmDepsHash to compute real one..."
pnpm_hash=$(flox build qwen-code 2>&1 \
  | grep -A2 "hash mismatch in fixed-output derivation" \
  | grep "got:" | head -1 | awk '{print $NF}') || true

if [ -z "$pnpm_hash" ]; then
  echo "ERROR: could not extract pnpmDepsHash from build output" >&2
  exit 1
fi

echo "  pnpmDepsHash: $pnpm_hash"

jq -n \
  --arg v "$latest_version" \
  --arg s "$src_sri" \
  --arg n "$pnpm_hash" \
  '{version: $v, srcHash: $s, pnpmDepsHash: $n}' > "$HASHES_FILE"

echo "Updated to $latest_version"
