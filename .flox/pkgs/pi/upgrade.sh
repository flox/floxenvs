#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HASHES_FILE="$SCRIPT_DIR/hashes.json"
LOCKFILE="$SCRIPT_DIR/package-lock.json"

NPM_PACKAGE="@earendil-works/pi-coding-agent"
FAKE_HASH="sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="

force=0
while [ $# -gt 0 ]; do
  case "$1" in
    -f | --force)
      force=1
      ;;
    -h | --help)
      echo "Usage: ${0##*/} [--force]"
      echo
      echo "  --force  Re-fetch the tarball and regenerate package-lock.json"
      echo "           and hashes.json even when already on the latest"
      echo "           version. Use after changing how the lockfile is"
      echo "           generated."
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      echo "Usage: ${0##*/} [--force]" >&2
      exit 2
      ;;
  esac
  shift
done

current_version=$(jq -r '.version' "$HASHES_FILE")

# Poll the registry once and keep the whole document, not just .version.
# The `deprecated` field is the only signal that the name we track has
# been abandoned, and dropping it is how this package sat on
# @mariozechner/pi-coding-agent@0.73.1 for four months: upstream renamed
# to @earendil-works and kept shipping, while the old endpoint went on
# serving 0.73.1, so every run compared 0.73.1 against 0.73.1 and
# reported "already up to date".
registry_json=$(curl -sfL "https://registry.npmjs.org/${NPM_PACKAGE}/latest")
latest_version=$(jq -r '.version' <<< "$registry_json")
deprecated=$(jq -r '.deprecated // empty' <<< "$registry_json")

# Fail loudly rather than silently tracking a dead name. This runs before
# the up-to-date check on purpose: a deprecated package is normally
# already "current", which is exactly the case that used to exit 0.
if [ -n "$deprecated" ]; then
  echo "ERROR: npm reports ${NPM_PACKAGE} as deprecated:" >&2
  echo "  $deprecated" >&2
  echo "Repoint NPM_PACKAGE (and the fetchurl url in default.nix) at the" >&2
  echo "replacement package before bumping further." >&2
  exit 1
fi

echo "Current: $current_version, Latest: $latest_version"

if [ "$current_version" = "$latest_version" ] && [ "$force" -eq 0 ]; then
  echo "Already up to date"
  exit 0
fi

if [ "$current_version" = "$latest_version" ]; then
  echo "Forcing regeneration of pi at $current_version"
else
  echo "Updating pi from $current_version to $latest_version"
fi

# Fetch and hash the published npm tarball. default.nix has to rebuild
# this URL in Nix from `version` alone, so cross-check the shape against
# what the registry actually advertises; a scope or basename change would
# otherwise only surface as a build-time 404.
src_url="https://registry.npmjs.org/${NPM_PACKAGE}/-/pi-coding-agent-${latest_version}.tgz"
registry_tarball=$(jq -r '.dist.tarball' <<< "$registry_json")
if [ "$src_url" != "$registry_tarball" ]; then
  echo "ERROR: constructed tarball URL does not match the registry's:" >&2
  echo "  constructed: $src_url" >&2
  echo "  registry:    $registry_tarball" >&2
  echo "Update src_url here and the fetchurl url in default.nix." >&2
  exit 1
fi
echo "Fetching source from $src_url ..."
src_hash=$(nix-prefetch-url "$src_url" 2>/dev/null)
src_sri=$(nix hash convert --hash-algo sha256 --to sri "$src_hash")
echo "  sourceHash: $src_sri"

# The published tarball has no package-lock.json (npm strips it on publish),
# so regenerate one from the tarball's package.json.
echo "Regenerating package-lock.json..."
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

tarball="$tmpdir/pi.tgz"
curl -sfL "$src_url" -o "$tarball"
mkdir -p "$tmpdir/extract"
tar -xzf "$tarball" -C "$tmpdir/extract" --strip-components=1

(
  cd "$tmpdir/extract"
  # Discard the npm-shrinkwrap.json upstream ships (unlike
  # package-lock.json, npm publishes shrinkwrap verbatim). Two reasons,
  # either one fatal:
  #
  #   1. npm prefers an existing shrinkwrap, so `npm install
  #      --package-lock-only` reports "up to date" and writes no
  #      package-lock.json at all — exit 0, no output file.
  #   2. That shrinkwrap gives no `integrity` for upstream's own five
  #      @earendil-works/* packages (it was generated from monorepo
  #      workspace links and had registry URLs written in afterwards).
  #      prefetch-npm-deps panics on those: "non-git dependencies should
  #      have associated integrity".
  #
  # Resolving from package.json instead produces a lockfile with
  # integrity for every entry. default.nix drops the same file from the
  # source it builds, so `npm ci` uses the committed lockfile.
  rm -f npm-shrinkwrap.json

  # Drop devDependencies before locking. `npm install
  # --package-lock-only` writes the *whole* dependency graph into the
  # lockfile no matter what --omit=dev says (it only changes what gets
  # installed), so upstream's test runners and bundlers end up in the
  # committed lockfile and Dependabot alerts on them. This package sets
  # dontNpmBuild — the tarball already ships a prebuilt dist/ — so none
  # of that tooling is ever run, and nixpkgs' npmInstallHook prunes it
  # from the output anyway. Removing it from package.json first is the
  # only way to keep it out of the lockfile. default.nix applies the
  # same deletion to the source it builds, because `npm ci` refuses to
  # run when package.json and package-lock.json disagree.
  jq 'del(.devDependencies)' package.json > package.json.tmp
  mv package.json.tmp package.json

  npm install --package-lock-only --ignore-scripts >/dev/null 2>&1
)

if [ ! -f "$tmpdir/extract/package-lock.json" ]; then
  echo "ERROR: npm wrote no package-lock.json. \`npm install" >&2
  echo "--package-lock-only\` exits 0 without producing one when the" >&2
  echo "source already carries a lockfile npm prefers, so this cannot" >&2
  echo "be caught by exit status alone." >&2
  exit 1
fi

cp "$tmpdir/extract/package-lock.json" "$LOCKFILE"

# Compute npmDepsHash with the fake-hash trick: write a known-bad hash,
# build the npmDeps FOD, and parse the "got:" line from the mismatch.
# This matches whatever fetchNpmDeps actually produces for this lockfile
# (more reliable than running prefetch-npm-deps manually, which can
# produce different hashes depending on fetcher internals).
tmp_hashes=$(mktemp)
cp "$HASHES_FILE" "$tmp_hashes"

jq -n \
  --arg v "$latest_version" \
  --arg s "$src_sri" \
  --arg nh "$FAKE_HASH" \
  '{version: $v, sourceHash: $s, npmDepsHash: $nh}' > "$HASHES_FILE"

echo "Computing npmDepsHash..."
prefetch_log=$(mktemp)
flox build pi > "$prefetch_log" 2>&1 || true

npm_deps_hash=$(awk '/hash mismatch in fixed-output derivation/,0 {
  if (/got:/) { print $NF; exit }
}' "$prefetch_log")

if [ -z "$npm_deps_hash" ]; then
  echo "ERROR: Could not extract npmDepsHash. Build output:" >&2
  tail -20 "$prefetch_log" >&2
  cp "$tmp_hashes" "$HASHES_FILE"
  rm -f "$tmp_hashes" "$prefetch_log"
  exit 1
fi
rm -f "$tmp_hashes" "$prefetch_log"

echo "  npmDepsHash: $npm_deps_hash"

jq -n \
  --arg v "$latest_version" \
  --arg s "$src_sri" \
  --arg nh "$npm_deps_hash" \
  '{version: $v, sourceHash: $s, npmDepsHash: $nh}' > "$HASHES_FILE"

echo "Updated to $latest_version"
