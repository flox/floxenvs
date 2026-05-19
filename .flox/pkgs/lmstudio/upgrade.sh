#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HASHES_FILE="$SCRIPT_DIR/hashes.json"

current_version=$(jq -r '.version' "$HASHES_FILE")

# Parse current version "M.m.p-b" into components.
if ! [[ "$current_version" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)-([0-9]+)$ ]]; then
  echo "ERROR: cannot parse current version '$current_version'" >&2
  exit 1
fi
cur_maj="${BASH_REMATCH[1]}"
cur_min="${BASH_REMATCH[2]}"
cur_pat="${BASH_REMATCH[3]}"
cur_bld="${BASH_REMATCH[4]}"

# Probe installers.lmstudio.ai with HEAD requests. The aarch64-darwin
# DMG is the canonical existence check — if it returns 200, the
# version exists for all 3 supported systems (upstream ships them
# together).
probe_exists() {
  local v="$1"
  local code
  code=$(curl -sI -o /dev/null -w "%{http_code}" \
    "https://installers.lmstudio.ai/darwin/arm64/${v}/LM-Studio-${v}-arm64.dmg")
  [ "$code" = "200" ]
}

# Walk forward from the current version, checking
#   <maj>.<min>.<pat+N>-1  for N in 1..20
#   <maj>.<min+M>.0-1      for M in 1..5, with sub-probes for patches
# Pick the highest reachable. We only probe build-id "-1"; LM Studio
# has not shipped any "-2" rebuild to date. If that ever changes,
# bump the parsed cur_bld and re-run manually.
# Break on the first miss within each series: LM Studio ships
# patches consecutively, so a 404 means we've passed the frontier.
latest_version=""
# Same minor, higher patch.
for ((p = cur_pat + 1; p <= cur_pat + 20; p++)); do
  v="${cur_maj}.${cur_min}.${p}-1"
  if probe_exists "$v"; then
    latest_version="$v"
  else
    break
  fi
done
# Next minor versions. If <maj>.<m>.0-1 doesn't exist, that minor
# series hasn't shipped yet — skip the whole series.
for ((m = cur_min + 1; m <= cur_min + 5; m++)); do
  v="${cur_maj}.${m}.0-1"
  if ! probe_exists "$v"; then
    break
  fi
  latest_version="$v"
  for ((p = 1; p <= 20; p++)); do
    v="${cur_maj}.${m}.${p}-1"
    if probe_exists "$v"; then
      latest_version="$v"
    else
      break
    fi
  done
done

if [ -z "$latest_version" ]; then
  echo "Already up to date (current: $current_version)"
  exit 0
fi

echo "Updating lmstudio from $current_version to $latest_version"

# Prefetch hashes for all 3 supported systems.
declare -A URLS=(
  [x86_64-linux]="https://installers.lmstudio.ai/linux/x64/${latest_version}/LM-Studio-${latest_version}-x64.AppImage"
  [aarch64-linux]="https://installers.lmstudio.ai/linux/arm64/${latest_version}/LM-Studio-${latest_version}-arm64.AppImage"
  [aarch64-darwin]="https://installers.lmstudio.ai/darwin/arm64/${latest_version}/LM-Studio-${latest_version}-arm64.dmg"
)

sources_json="{}"
for sys in "${!URLS[@]}"; do
  url="${URLS[$sys]}"
  echo "  prefetching $sys ..."
  hex=$(nix-prefetch-url "$url" 2>/dev/null)
  if [ -z "$hex" ]; then
    echo "ERROR: nix-prefetch-url failed for $url" >&2
    exit 1
  fi
  sri=$(nix --extra-experimental-features nix-command \
    hash convert --hash-algo sha256 --to sri "$hex")
  sources_json=$(echo "$sources_json" \
    | jq --arg s "$sys" --arg u "$url" --arg h "$sri" \
        '.[$s] = {url: $u, hash: $h}')
done

jq -n \
  --arg v "$latest_version" \
  --argjson s "$sources_json" \
  '{version: $v, sources: $s}' > "$HASHES_FILE"

echo "Updated to $latest_version"

# Sanity: unused so far, but keep the value referenced so shellcheck
# doesn't complain if we later add a build-id comparison.
: "$cur_bld"
