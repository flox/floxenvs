# common.bash — shared helpers for review-skills E2E tests
#
# Loaded by every .bats file via:
#   load test_helper/common

# bats-support and bats-assert
load "${BATS_SUPPORT_LIB}/load.bash"
load "${BATS_ASSERT_LIB}/load.bash"

# Detect execution mode (kept for parity with claude-managed; the
# review-skills binary behaves identically in either mode).
if [[ -n "${FLOX_ENV:-}" ]]; then
  TEST_MODE="flox"
else
  TEST_MODE="nix"
fi

# Path to the static fixtures shipped next to the .bats files.
FIXTURES_DIR="$(cd "$(dirname "${BATS_TEST_FILENAME}")/fixtures" && pwd)"

# Copy the whole fixtures tree into a fresh, writable temp dir and echo its
# path. The tools stage copies of the artifacts, but several of them (and the
# inline frontmatter gate) prefer a writable source, and the fixtures may live
# read-only in the nix store, so always work from a copy.
#
# Usage: dir=$(setup_fixtures)
setup_fixtures() {
  local dest="$BATS_TEST_TMPDIR/fixtures"
  if [[ ! -d "$dest" ]]; then
    mkdir -p "$dest"
    cp -R "$FIXTURES_DIR/." "$dest/"
    # nix store files are read-only; make the working copy writable.
    chmod -R u+w "$dest"
  fi
  echo "$dest"
}

# Echo the path to a named fixture (skill dir or agent file) inside a fresh
# writable copy of the fixtures tree.
#
# Usage:
#   good=$(fixture good-skill)
#   bad=$(fixture bad-skill)
#   agent=$(fixture good-agent.md)
fixture() {
  local name="$1"
  echo "$(setup_fixtures)/$name"
}
