# common.bash — shared helpers for claude-managed E2E tests
#
# Loaded by every .bats file via:
#   load test_helper/common

# bats-support and bats-assert
load "${BATS_SUPPORT_LIB}/load.bash"
load "${BATS_ASSERT_LIB}/load.bash"

# Detect execution mode
if [[ -n "${FLOX_ENV:-}" ]]; then
  TEST_MODE="flox"
else
  TEST_MODE="nix"
fi

# Path to static fixtures
FIXTURES_DIR="$(cd "$(dirname "${BATS_TEST_FILENAME}")/fixtures" && pwd)"

# Copy a fixture subtree into a fresh temp dir.
# Usage: dir=$(setup_fixtures share/claude-code)
setup_fixtures() {
  local name="${1:-share/claude-code}"
  local dest="$BATS_TEST_TMPDIR/fixtures/$name"
  mkdir -p "$dest"
  cp -R "$FIXTURES_DIR/$name/." "$dest/"
  # nix store files are read-only; make copies writable
  chmod -R u+w "$dest"
  echo "$dest"
}

# Create a fresh, empty config dir.
# Usage: dir=$(setup_config_dir)
setup_config_dir() {
  local dir="$BATS_TEST_TMPDIR/config"
  mkdir -p "$dir"
  echo "$dir"
}

# Run claude-managed with appropriate flags per mode.
#
# Both modes use --dir to point at test fixtures.
# In nix mode: also passes --config-dir (no FLOX_ENV_PROJECT).
# In flox mode: --config-dir falls back to FLOX_ENV_PROJECT default.
#
# Uses bats `run` — sets $status, $output, $lines.
#
# Usage:
#   run_cm setup-hook
#   run_cm doctor
#   CM_DIR=/custom/path run_cm doctor
run_cm() {
  local cmd="$1"; shift
  local dir="${CM_DIR:-$(setup_fixtures)}"
  if [[ "$TEST_MODE" == "nix" ]]; then
    local config_dir="${CM_CONFIG_DIR:-$(setup_config_dir)}"
    case "$cmd" in
      setup-hook|setup-profile|status)
        run claude-managed --dir "$dir" --config-dir "$config_dir" "$cmd" "$@"
        ;;
      doctor)
        run claude-managed --dir "$dir" "$cmd" "$@"
        ;;
      *)
        run claude-managed "$cmd" "$@"
        ;;
    esac
  else
    case "$cmd" in
      setup-hook|setup-profile|status)
        run claude-managed --dir "$dir" "$cmd" "$@"
        ;;
      doctor)
        run claude-managed --dir "$dir" "$cmd" "$@"
        ;;
      *)
        run claude-managed "$cmd" "$@"
        ;;
    esac
  fi
}

# Run claude-managed and capture stdout/stderr separately.
# Sets: CM_STDOUT, CM_STDERR, CM_STATUS
run_cm_split() {
  local cmd="$1"; shift
  local tmpout="$BATS_TEST_TMPDIR/stdout"
  local tmperr="$BATS_TEST_TMPDIR/stderr"
  local dir="${CM_DIR:-$(setup_fixtures)}"
  CM_STATUS=0
  if [[ "$TEST_MODE" == "nix" ]]; then
    local config_dir="${CM_CONFIG_DIR:-$(setup_config_dir)}"
    case "$cmd" in
      setup-hook|setup-profile|status)
        claude-managed --dir "$dir" --config-dir "$config_dir" "$cmd" "$@" \
          >"$tmpout" 2>"$tmperr" || CM_STATUS=$?
        ;;
      doctor)
        claude-managed --dir "$dir" "$cmd" "$@" \
          >"$tmpout" 2>"$tmperr" || CM_STATUS=$?
        ;;
      *)
        claude-managed "$cmd" "$@" \
          >"$tmpout" 2>"$tmperr" || CM_STATUS=$?
        ;;
    esac
  else
    case "$cmd" in
      setup-hook|setup-profile|status)
        claude-managed --dir "$dir" "$cmd" "$@" \
          >"$tmpout" 2>"$tmperr" || CM_STATUS=$?
        ;;
      doctor)
        claude-managed --dir "$dir" "$cmd" "$@" \
          >"$tmpout" 2>"$tmperr" || CM_STATUS=$?
        ;;
      *)
        claude-managed "$cmd" "$@" \
          >"$tmpout" 2>"$tmperr" || CM_STATUS=$?
        ;;
    esac
  fi
  CM_STDOUT="$(cat "$tmpout")"
  CM_STDERR="$(cat "$tmperr")"
}
