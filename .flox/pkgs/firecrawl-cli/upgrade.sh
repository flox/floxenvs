#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HASHES_FILE="$SCRIPT_DIR/hashes.json"
LOCKFILE="$SCRIPT_DIR/package-lock.json"

NPM_PACKAGE="firecrawl-cli"
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
latest_version=$(curl -sSfL "https://registry.npmjs.org/${NPM_PACKAGE}/latest" \
  | jq -r '.version')

echo "Current: $current_version, Latest: $latest_version"

if [ "$current_version" = "$latest_version" ] && [ "$force" -eq 0 ]; then
  echo "Already up to date"
  exit 0
fi

if [ "$current_version" = "$latest_version" ]; then
  echo "Forcing regeneration of firecrawl-cli at $current_version"
else
  echo "Updating firecrawl-cli from $current_version to $latest_version"
fi

# Fetch and hash the published npm tarball
src_url="https://registry.npmjs.org/${NPM_PACKAGE}/-/${NPM_PACKAGE}-${latest_version}.tgz"
echo "Fetching source from $src_url ..."
# stderr carries `error: unable to download ...: HTTP error 404` on a bad
# version and only the line `path is '/nix/store/...'` on success, so
# suppressing it traded a usable message for a bare exit 1.
src_hash=$(nix-prefetch-url "$src_url")
src_sri=$(nix hash convert --hash-algo sha256 --to sri "$src_hash")
echo "  sourceHash: $src_sri"

# The published tarball has no package-lock.json (upstream uses pnpm and
# npm strips lockfiles on publish anyway). Regenerate one from the
# tarball's package.json.
echo "Regenerating package-lock.json..."
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

tarball="$tmpdir/firecrawl-cli.tgz"
curl -sSfL "$src_url" -o "$tarball"
mkdir -p "$tmpdir/extract"
tar -xzf "$tarball" -C "$tmpdir/extract" --strip-components=1

(
  cd "$tmpdir/extract"
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

  # stdout is discarded (it is just the install summary), but stderr is
  # not: `2>&1` here used to turn every failure into a bare exit code.
  # A missing npm is otherwise a silent 127 — this
  # script only has npm inside the repo's flox env. Note that npm's
  # audit summary ("N high severity vulnerabilities") goes to *stdout*,
  # so it stays hidden either way; default.nix's installCheckPhase is
  # what actually gates a regressed axios, not this output.
  npm install --package-lock-only --ignore-scripts >/dev/null
)

cp "$tmpdir/extract/package-lock.json" "$LOCKFILE"

# Compute npmDepsHash with the fake-hash trick: write a known-bad hash,
# build the npmDeps FOD, and parse the "got:" line from the mismatch.
tmp_hashes=$(mktemp)
cp "$HASHES_FILE" "$tmp_hashes"

jq -n \
  --arg v "$latest_version" \
  --arg s "$src_sri" \
  --arg nh "$FAKE_HASH" \
  '{version: $v, sourceHash: $s, npmDepsHash: $nh}' > "$HASHES_FILE"

echo "Computing npmDepsHash..."
prefetch_log=$(mktemp)
flox build firecrawl-cli > "$prefetch_log" 2>&1 || true

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
