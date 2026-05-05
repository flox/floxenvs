#!/usr/bin/env bash
# Tests for scripts/wait-should-poll.sh
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPER="$SCRIPT_DIR/../wait-should-poll.sh"

PASS=0
FAIL=0
FAILED_TESTS=()

# Build a temp dir that looks like the repo root so the
# helper can discover env names from ci_*.yml files.
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/.github/workflows"
# Mock env workflows
for env in redis postgresql go; do
  touch "$TMP/.github/workflows/ci_$env.yml"
done
touch "$TMP/.github/workflows/ci_pkgs.yml"
touch "$TMP/.github/workflows/ci.yml"

assert_eq() {
  local label="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    PASS=$((PASS + 1))
    echo "ok - $label"
  else
    FAIL=$((FAIL + 1))
    FAILED_TESTS+=("$label: expected=$expected actual=$actual")
    echo "FAIL - $label (expected=$expected actual=$actual)"
  fi
}

run() {
  # $1 = mode, stdin = changed paths
  ( cd "$TMP" && "$HELPER" "$1" )
}

# ── packages mode ──
assert_eq "pkgs: pkg change → true" "true" \
  "$(printf '.flox/pkgs/foo/default.nix\n' | run packages)"
assert_eq "pkgs: env change → false" "false" \
  "$(printf 'redis/test.sh\n' | run packages)"
assert_eq "pkgs: flake.lock → false" "false" \
  "$(printf 'flake.lock\n' | run packages)"
assert_eq "pkgs: empty → false" "false" \
  "$(printf '' | run packages)"
assert_eq "pkgs: ci_pkgs.yml only → false" "false" \
  "$(printf '.github/workflows/ci_pkgs.yml\n' | run packages)"
assert_eq "pkgs: .flox/env/ only → false" "false" \
  "$(printf '.flox/env/manifest.toml\n' | run packages)"
assert_eq "pkgs: combined → true" "true" \
  "$(printf 'redis/test.sh\n.flox/pkgs/x/default.nix\n' \
    | run packages)"

# ── envs mode ──
assert_eq "envs: env dir → true" "true" \
  "$(printf 'redis/test.sh\n' | run envs)"
assert_eq "envs: env-demo dir → true" "true" \
  "$(printf 'redis-demo/test.sh\n' | run envs)"
assert_eq "envs: flake.nix → true" "true" \
  "$(printf 'flake.nix\n' | run envs)"
assert_eq "envs: flake.lock → true" "true" \
  "$(printf 'flake.lock\n' | run envs)"
assert_eq "envs: scripts/ → true" "true" \
  "$(printf 'scripts/discover-envs.sh\n' | run envs)"
assert_eq "envs: environment.yml → true" "true" \
  "$(printf '.github/workflows/environment.yml\n' \
    | run envs)"
assert_eq "envs: ci_redis.yml → true" "true" \
  "$(printf '.github/workflows/ci_redis.yml\n' | run envs)"
assert_eq "envs: ci_pkgs.yml → false" "false" \
  "$(printf '.github/workflows/ci_pkgs.yml\n' | run envs)"
assert_eq "envs: ci.yml only → false" "false" \
  "$(printf '.github/workflows/ci.yml\n' | run envs)"
assert_eq "envs: pkg change only → false" "false" \
  "$(printf '.flox/pkgs/x/default.nix\n' | run envs)"
assert_eq "envs: docs only → false" "false" \
  "$(printf 'README.md\n' | run envs)"
assert_eq "envs: empty → false" "false" \
  "$(printf '' | run envs)"

# ── invalid mode ──
out="$(printf '' | run invalid 2>&1)" || true
case "$out" in
  *unknown*|*usage*|*Usage*) ok=true ;;
  *) ok=false ;;
esac
if [ "$ok" = "true" ]; then
  PASS=$((PASS + 1))
  echo "ok - invalid mode prints usage/unknown"
else
  FAIL=$((FAIL + 1))
  FAILED_TESTS+=("invalid mode: got '$out'")
  echo "FAIL - invalid mode"
fi

echo
echo "Passed: $PASS  Failed: $FAIL"
if [ "$FAIL" -gt 0 ]; then
  for t in "${FAILED_TESTS[@]}"; do echo "  - $t"; done
  exit 1
fi
