#!/usr/bin/env bash
# upgrade.sh -- refresh hashes.json for finceptterminal.
#
# Strategy:
#   1. Fetch the upstream tag list. Pick the highest semver tag.
#      If it differs from the current upstream.tag in hashes.json,
#      use it. Otherwise re-pin the same tag (handles upstream
#      force-pushes).
#   2. For each FetchContent dep, re-resolve the rev from the
#      fresh upstream CMakeLists.txt -- upstream may bump a dep's
#      commit without bumping its own version.
#   3. Re-prefetch every source and dep, recording the SRI hash
#      back into hashes.json.
#   4. Dry-run apply both patches against the fresh tree and warn
#      if they no longer apply.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HASHES_FILE="$SCRIPT_DIR/hashes.json"

UPSTREAM_REPO="https://github.com/Fincept-Corporation/FinceptTerminal.git"

# nix-prefetch-git isn't always on PATH (it isn't in this repo's
# flox env). `nix run nixpkgs#nix-prefetch-git` works everywhere
# Nix is available, which is the same precondition the rest of
# upgrade_pkgs.yml already assumes.
prefetch_git() {
  local url="$1" rev="$2"
  nix --extra-experimental-features 'nix-command flakes' \
    run nixpkgs#nix-prefetch-git -- \
    --quiet --url "$url" --rev "$rev" \
    | jq -r '.hash'
}

current_tag=$(jq -r '.upstream.tag' "$HASHES_FILE")
echo "Current upstream tag: $current_tag"

# --- Find the highest semver tag ------------------------------
latest_tag=$(git ls-remote --tags --refs "$UPSTREAM_REPO" \
  | awk '{print $2}' \
  | sed 's|refs/tags/||' \
  | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' \
  | sort -V \
  | tail -1)

if [ -z "$latest_tag" ]; then
  echo "ERROR: could not enumerate upstream tags" >&2
  exit 1
fi
echo "Latest upstream tag: $latest_tag"

# --- Resolve tag to commit ------------------------------------
latest_rev=$(git ls-remote "$UPSTREAM_REPO" "refs/tags/$latest_tag" \
  | awk '{print $1}')
if [ -z "$latest_rev" ]; then
  echo "ERROR: could not resolve $latest_tag" >&2
  exit 1
fi
echo "Latest commit: $latest_rev"

# --- Prefetch upstream source ---------------------------------
echo "Prefetching upstream source ..."
upstream_sri=$(prefetch_git "$UPSTREAM_REPO" "$latest_rev")
if [ -z "$upstream_sri" ] || [ "$upstream_sri" = "null" ]; then
  echo "ERROR: nix-prefetch-git failed for upstream" >&2
  exit 1
fi
echo "  upstream hash: $upstream_sri"

# --- Re-read upstream CMakeLists.txt for current dep revs -----
WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT
git clone --quiet --depth 1 --branch "$latest_tag" \
  "$UPSTREAM_REPO" "$WORKDIR/src" >/dev/null 2>&1
CMAKE="$WORKDIR/src/fincept-qt/CMakeLists.txt"
if [ ! -f "$CMAKE" ]; then
  echo "ERROR: $CMAKE not found in fresh checkout" >&2
  exit 1
fi

# extract_rev: given a FetchContent_Declare name (e.g. "QXlsx"),
# return its GIT_TAG (40-hex commit) value. We walk
# FetchContent_Declare( ... ) blocks, identify the one whose
# first token after '(' is the requested name, then pull out
# the 40-hex GIT_TAG argument. Awk's enough; avoids the Apple
# python3 stub headache on macOS dev shells.
extract_rev() {
  local declare_name="$1"
  awk -v name="$declare_name" '
    /FetchContent_Declare[[:space:]]*\(/ {
      in_block = 1; depth = 1; buf = ""; next
    }
    in_block {
      buf = buf " " $0
      n_open = gsub(/\(/, "&", $0); depth += n_open
      n_close = gsub(/\)/, "&", $0); depth -= n_close
      if (depth <= 0) {
        if (buf ~ "^[[:space:]]+" name "[[:space:]]") {
          if (match(buf, /GIT_TAG[[:space:]]+[0-9a-fA-F]{40}/)) {
            s = substr(buf, RSTART, RLENGTH)
            sub(/GIT_TAG[[:space:]]+/, "", s)
            print s; exit
          }
        }
        in_block = 0
      }
    }
  ' "$CMAKE"
}

# Sanity-check: upstream has exactly 5 FetchContent_Declare
# blocks at v4.0.3. If a 6th appears, hashes.json (and
# fetchcontent.nix) need a corresponding new entry -- bail so a
# human notices.
fc_count=$(grep -c '^[[:space:]]*FetchContent_Declare' "$CMAKE" || true)
if [ "$fc_count" != "5" ]; then
  echo "ERROR: expected 5 FetchContent_Declare blocks in" \
    "upstream CMakeLists.txt, found $fc_count -- a dep was" \
    "added or removed; update upgrade.sh, hashes.json, and" \
    "fetchcontent.nix together." >&2
  exit 1
fi

declare -A DEP_URLS=(
  [qxlsx]="https://github.com/QtExcel/QXlsx.git"
  [md4c]="https://github.com/mity/md4c.git"
  [qgeoview]="https://github.com/AmonRaNet/QGeoView.git"
  [qtads]="https://github.com/githubuser0xFFFF/Qt-Advanced-Docking-System.git"
  [ed25519]="https://github.com/orlp/ed25519.git"
)

declare -A DEP_DECLARE_NAMES=(
  [qxlsx]="QXlsx"
  [md4c]="md4c"
  [qgeoview]="QGeoView"
  [qtads]="QtADS"
  [ed25519]="ed25519"
)

declare -A NEW_DEP_REVS NEW_DEP_HASHES
for key in qxlsx md4c qgeoview qtads ed25519; do
  decl="${DEP_DECLARE_NAMES[$key]}"
  rev=$(extract_rev "$decl")
  if [ -z "$rev" ]; then
    echo "ERROR: could not extract $decl rev from" \
      "CMakeLists.txt" >&2
    exit 1
  fi
  echo "  $key rev: $rev"
  sri=$(prefetch_git "${DEP_URLS[$key]}" "$rev")
  if [ -z "$sri" ] || [ "$sri" = "null" ]; then
    echo "ERROR: nix-prefetch-git failed for $key" >&2
    exit 1
  fi
  echo "  $key hash: $sri"
  NEW_DEP_REVS[$key]="$rev"
  NEW_DEP_HASHES[$key]="$sri"
done

# --- Write hashes.json ----------------------------------------
tmp=$(mktemp)
jq \
  --arg tag "$latest_tag" \
  --arg rev "$latest_rev" \
  --arg hash "$upstream_sri" \
  '.upstream = {tag: $tag, rev: $rev, hash: $hash}' \
  "$HASHES_FILE" > "$tmp"
mv "$tmp" "$HASHES_FILE"

for key in qxlsx md4c qgeoview qtads ed25519; do
  jq \
    --arg k "$key" \
    --arg r "${NEW_DEP_REVS[$key]}" \
    --arg h "${NEW_DEP_HASHES[$key]}" \
    '.fetchcontent[$k].rev = $r
     | .fetchcontent[$k].hash = $h' \
    "$HASHES_FILE" > "$tmp"
  mv "$tmp" "$HASHES_FILE"
done

echo "Updated hashes.json:"
jq . "$HASHES_FILE"

# --- Patch-drift check ----------------------------------------
# If either patch no longer applies cleanly against the new
# upstream tree, warn (don't fail -- patch refresh is a separate
# manual step). The upgrade_pkgs.yml job opens a PR when
# hashes.json changes; the reviewer sees this warning and
# refreshes patches by hand.
patches_root="$SCRIPT_DIR/patches"
cd "$WORKDIR/src/fincept-qt"
drift=0
for p in "$patches_root"/*.patch; do
  if ! patch -p1 --dry-run --silent < "$p" >/dev/null 2>&1; then
    echo "WARNING: patch $(basename "$p") no longer applies" \
      "-- needs refresh." >&2
    drift=1
  fi
done

if [ "$drift" -eq 0 ]; then
  echo "All patches still apply cleanly."
fi

echo "upgrade.sh complete: $current_tag -> $latest_tag"
