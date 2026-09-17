#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HASHES_FILE="$SCRIPT_DIR/hashes.json"
LOCKFILE="$SCRIPT_DIR/package-lock.json"

NPM_PACKAGE="firecrawl-cli"
FAKE_HASH="sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="

# The axios override is keyed to this exact firecrawl pin and is only
# correct while firecrawl-cli declares it. The pre-flight check and the
# injection both read it from here so the two cannot drift apart.
FIRECRAWL_PIN="4.24.0"
AXIOS_FLOOR="^1.18.0"

# Classify a dependency spec against an override key the way npm does,
# printing either "conflict" or "inert". Callers handle the equal case
# themselves, since that is the only one npm accepts.
#
# npm resolves this with its own bundled semver. Under Nix npm and node
# are separate store paths, so `npm root -g` points into node's tree and
# does not contain semver; resolving from npm's real entry point finds
# it wherever npm actually lives.
override_key_match() {
  node -e '
    const fs = require("fs");
    const { createRequire } = require("module");
    const semver = createRequire(fs.realpathSync(process.argv[1]))("semver");
    const spec = process.argv[2], key = process.argv[3];
    // Mirrors arborist OverrideSet.getEdgeRule(): version and range
    // specs are compared with semver.intersects(), while a spec npm
    // cannot read as a range (a dist-tag, git or file spec) has no
    // versions to compare and the rule is accepted outright.
    if (semver.validRange(spec) === null || semver.intersects(spec, key)) {
      console.log("conflict");
    } else {
      console.log("inert");
    }
  ' "$(command -v npm)" "$1" "$2"
}

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

  # Force axios off 1.15.2, which firecrawl 4.24.0 pins exactly and
  # firecrawl-cli in turn pins exactly — two exact pins in a row, so
  # npm has no resolution freedom and re-locking alone changes nothing.
  # See default.nix for the full rationale; it injects this same field
  # into the source it builds, because `npm ci` refuses to run when
  # package.json and package-lock.json disagree. Without this step the
  # next run of this script would silently re-lock axios back to the
  # vulnerable 1.15.2.
  #
  # `^1.18.0` is a floor, not a pin: 1.18.0 is the first release clear
  # of all 18 advisories, and the caret lets this script pick up later
  # 1.x as they ship. An exact `1.18.0` would have re-pinned axios
  # there on every run — this script runs every six hours — so an
  # advisory against 1.18.0 itself could never be cleared here, and it
  # disagreed with the `>=` floor default.nix asserts at build time.
  #
  # Check the key still fits firecrawl-cli's firecrawl dependency
  # BEFORE injecting it, and stop the run if it does not.
  #
  # npm does not match override keys by equality, so "the key stopped
  # matching" is not the only way this pin can go wrong. arborist's
  # OverrideSet.getEdgeRule() picks a rule with
  # semver.intersects(edge.rawSpec, rule.keySpec), so a firecrawl pin
  # that moves to a *range* covering 4.24.0 (`^4.24.0`, `>=4.24.0`,
  # `4.x`) still matches this key. The rule's value is 4.24.0 — an
  # override entry with no "." key takes its keySpec as its value — so
  # npm rewrites the root's firecrawl edge to 4.24.0,
  # Node.assertRootOverrides() sees that differ from the range actually
  # declared, and `npm install` aborts with `EOVERRIDE: Override for
  # firecrawl@<range> conflicts with direct dependency`. Only a move to
  # a non-intersecting exact version is the silent no-op this key was
  # designed to become.
  #
  # Fatal rather than a warning, and ahead of the injection rather than
  # after it. This script runs unattended every six hours and
  # upgrade_pkgs.yml gives the PR it opens a fixed template body, so a
  # note on stderr reaches nothing but the Actions log. Exiting non-zero
  # fails the step, which means no PR is opened and nothing reaches
  # auto-merge — the right outcome when the alternative is quietly
  # relocking axios back onto 18 advisories.
  firecrawl_pin=$(jq -r '.dependencies.firecrawl // empty' package.json)
  if [ "$firecrawl_pin" != "$FIRECRAWL_PIN" ]; then
    # Classify before printing anything. A failure here must not fall
    # through to one of the specific branches: reporting "the override
    # is inert" about a pin that actually conflicts is the exact
    # mistake this check replaced, so an unusable classifier says so.
    if [ -z "$firecrawl_pin" ]; then
      key_match="absent"
    else
      key_match=$(override_key_match "$firecrawl_pin" "$FIRECRAWL_PIN") \
        || key_match="unknown"
    fi

    {
      echo "ERROR: the axios override no longer fits firecrawl-cli's"
      echo "       firecrawl dependency. Stopping before the lockfile"
      echo "       is regenerated."
      echo
      case "$key_match" in
        absent)
          echo "  firecrawl-cli no longer depends on firecrawl at all,"
          echo "  so the override key \"firecrawl@$FIRECRAWL_PIN\""
          echo "  matches nothing and would contribute no axios floor."
          echo
          echo "  Work out what pulls in axios now, then re-key or"
          echo "  delete the override in upgrade.sh and default.nix."
          ;;
        conflict)
          echo "  firecrawl-cli now declares firecrawl"
          echo "  $firecrawl_pin, which intersects the override key"
          echo "  \"firecrawl@$FIRECRAWL_PIN\" without being equal to"
          echo "  it. npm rejects that: it rewrites the firecrawl spec"
          echo "  to $FIRECRAWL_PIN, finds it differs from what"
          echo "  package.json declares, and fails with \"EOVERRIDE:"
          echo "  Override for firecrawl@$firecrawl_pin conflicts with"
          echo "  direct dependency\"."
          echo
          echo "  Re-key the override to"
          echo "  \"firecrawl@$firecrawl_pin\", or delete it from"
          echo "  upgrade.sh and default.nix if $firecrawl_pin already"
          echo "  resolves axios $AXIOS_FLOOR."
          ;;
        inert)
          echo "  firecrawl-cli now declares firecrawl"
          echo "  $firecrawl_pin, which does not intersect the override"
          echo "  key \"firecrawl@$FIRECRAWL_PIN\", so npm would"
          echo "  ignore the override and relock axios to whatever"
          echo "  firecrawl $firecrawl_pin pins. That is not"
          echo "  automatically an improvement: firecrawl 4.25.0 still"
          echo "  pins the vulnerable axios 1.15.2, and only 4.26.0"
          echo "  onward moved to 1.18.0."
          echo
          echo "  Confirm $firecrawl_pin resolves axios $AXIOS_FLOOR"
          echo "  and then delete the override from upgrade.sh and"
          echo "  default.nix; if it does not, re-key the override to"
          echo "  \"firecrawl@$firecrawl_pin\" instead."
          ;;
        *)
          echo "  firecrawl-cli now declares firecrawl"
          echo "  $firecrawl_pin rather than $FIRECRAWL_PIN, and the"
          echo "  override key could not be classified — node, which"
          echo "  supplies npm's semver, did not run. Both outcomes"
          echo "  need a human either way: if $firecrawl_pin"
          echo "  intersects $FIRECRAWL_PIN, npm will fail with"
          echo "  EOVERRIDE; if it does not, the override is silently"
          echo "  ignored and axios relocks to firecrawl's own pin."
          echo
          echo "  Re-run inside the repo's flox env to get the"
          echo "  specific diagnosis."
          ;;
      esac
    } >&2
    exit 1
  fi

  # Merged with `+=` rather than assigned, so an `overrides` field
  # added upstream keeps its own entries instead of being clobbered
  # (jq's `null + object` yields the object, so it is a drop-in while
  # the field is absent). default.nix merges the same way.
  jq --arg key "firecrawl@$FIRECRAWL_PIN" --arg floor "$AXIOS_FLOOR" \
    '.overrides += { ($key): { "axios": $floor } }' \
    package.json > package.json.tmp
  mv package.json.tmp package.json

  # stdout is discarded (it is just the install summary), but stderr is
  # not: `2>&1` here used to turn every failure into a bare exit code.
  # npm reports `EOVERRIDE` on stderr when the override above conflicts
  # with a direct dependency, and a missing npm is a silent 127 — this
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
