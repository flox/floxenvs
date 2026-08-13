#!/usr/bin/env bash
# Tests for scripts/select-envs.sh
#
# select-envs.sh resolves REPO_ROOT from its own location and always
# operates against the real repository tree — unlike
# wait-should-poll.sh, it cannot be pointed at a synthetic fixture
# dir. These tests exercise it against real environments in this
# repo (worktrunk, redis) using changed-path strings that need not
# correspond to files that actually exist.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPER="$SCRIPT_DIR/../select-envs.sh"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

PASS=0
FAIL=0
FAILED_TESTS=()

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
  ( cd "$REPO_ROOT" && "$HELPER" "$@" )
}

# Count envs the same way select-envs.sh enumerates them: top-level
# dirs (non-hidden, via a plain glob — same as the helper) with
# .flox/env/manifest.toml, excluding -demo dirs.
env_count=0
for d in "$REPO_ROOT"/*/; do
  name="$(basename "$d")"
  case "$name" in *-demo) continue ;; esac
  [ -f "$d/.flox/env/manifest.toml" ] && env_count=$((env_count + 1))
done

# ── single env ──
assert_eq "single env changed → that env" '["worktrunk"]' \
  "$(printf 'worktrunk/test.sh\n' | run)"

# ── demo dir ──
assert_eq "demo dir changed → base env" '["worktrunk"]' \
  "$(printf 'worktrunk-demo/compose.yaml\n' | run)"

# ── shared path selects all ──
assert_eq "shared path (flake.nix) → all envs" "$env_count" \
  "$(printf 'flake.nix\n' | run | jq 'length')"

# ── unrelated path → empty ──
assert_eq "unrelated path → []" "[]" \
  "$(printf 'README.md\n' | run)"

# ── dispatch override ──
assert_eq "dispatch override single env" '["redis"]' \
  "$(printf '' | run redis)"

# ── unknown env exit 1 ──
out="$(printf '' | run nosuchenv 2>&1)"
code=$?
assert_eq "unknown env exit code" "1" "$code"
case "$out" in
  *"unknown environment"*) ok=true ;;
  *) ok=false ;;
esac
if [ "$ok" = "true" ]; then
  PASS=$((PASS + 1))
  echo "ok - unknown env error message"
else
  FAIL=$((FAIL + 1))
  FAILED_TESTS+=("unknown env message: got '$out'")
  echo "FAIL - unknown env error message"
fi

# ── multi-env ──
assert_eq "multi-env changed → both selected" '["redis","worktrunk"]' \
  "$(printf 'redis/test.sh\nworktrunk/test.sh\n' | run | jq -c 'sort')"

# ── anchored-regex negative ──
assert_eq "flake.nixbogus does not trigger shared match" "[]" \
  "$(printf 'flake.nixbogus\n' | run)"

# ── pkg-mapping positive (worktrunk's manifest declares
#    worktrunk.pkg-path = "flox/worktrunk") ──
assert_eq "pkg-path mapped pkg (worktrunk) → worktrunk env" '["worktrunk"]' \
  "$(printf '.flox/pkgs/worktrunk/build.nix\n' | run)"

# ── pkg-mapping negative (agent-browser isn't referenced by any
#    env manifest's pkg-path) ──
assert_eq "pkg-path unmapped pkg (agent-browser) → []" "[]" \
  "$(printf '.flox/pkgs/agent-browser/build.nix\n' | run)"

# ── --all flag ──
assert_eq "--all → all envs" "$env_count" \
  "$(run --all | jq 'length')"

echo
echo "Passed: $PASS  Failed: $FAIL"
if [ "$FAIL" -gt 0 ]; then
  for t in "${FAILED_TESTS[@]}"; do echo "  - $t"; done
  exit 1
fi
