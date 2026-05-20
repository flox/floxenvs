#!/usr/bin/env bash
# Tests for scripts/compute-reliability.sh
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$SCRIPT_DIR/../compute-reliability.sh"

PASS=0
FAIL=0

assert_eq() {
  local label="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    PASS=$((PASS + 1))
    echo "ok - $label"
  else
    FAIL=$((FAIL + 1))
    echo "FAIL - $label"
    echo "  expected: $expected"
    echo "  actual:   $actual"
  fi
}

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# ── env with lockfile ──────────────────────────────────────
ENV_DIR="$TMP/sample-env"
mkdir -p "$ENV_DIR/.flox/env"
touch "$ENV_DIR/.flox/env/manifest.lock"

out=$(unset GITHUB_TOKEN; \
  REPO_ROOT="$TMP" "$SCRIPT" env sample-env 2>/dev/null)

assert_eq "no-token env: valid JSON" "0" \
  "$(echo "$out" | jq 'empty' >/dev/null 2>&1; echo $?)"

assert_eq "no-token env: score=80" "80" \
  "$(echo "$out" | jq -r '.score')"

note=$(echo "$out" | jq -r '.note')
assert_eq "no-token env: note mentions GITHUB_TOKEN" "true" \
  "$(echo "$note" | grep -qi 'github_token' && echo true || echo false)"

assert_eq "no-token env: lockfile_fresh=true" "true" \
  "$(echo "$out" | jq -r '.lockfile_fresh')"

# ── env without lockfile ───────────────────────────────────
ENV2_DIR="$TMP/bare-env"
mkdir -p "$ENV2_DIR/.flox/env"

out2=$(unset GITHUB_TOKEN; \
  REPO_ROOT="$TMP" "$SCRIPT" env bare-env 2>/dev/null)

assert_eq "no-lockfile env: lockfile_fresh=false" "false" \
  "$(echo "$out2" | jq -r '.lockfile_fresh')"

assert_eq "no-lockfile env: score=80 (no token, no deduction)" "80" \
  "$(echo "$out2" | jq -r '.score')"

# ── pkg with valid hashes.json ─────────────────────────────
PKG_DIR="$TMP/.flox/pkgs/sample-pkg"
mkdir -p "$PKG_DIR"
printf '{"version":"1.0.0","srcHash":"sha256-AAA"}\n' \
  > "$PKG_DIR/hashes.json"

out3=$(unset GITHUB_TOKEN; \
  REPO_ROOT="$TMP" "$SCRIPT" pkg sample-pkg 2>/dev/null)

assert_eq "no-token pkg: valid JSON" "0" \
  "$(echo "$out3" | jq 'empty' >/dev/null 2>&1; echo $?)"

assert_eq "no-token pkg: score=80" "80" \
  "$(echo "$out3" | jq -r '.score')"

assert_eq "no-token pkg: lockfile_fresh=true" "true" \
  "$(echo "$out3" | jq -r '.lockfile_fresh')"

# ── pkg without hashes.json ────────────────────────────────
PKG2_DIR="$TMP/.flox/pkgs/bare-pkg"
mkdir -p "$PKG2_DIR"

out4=$(unset GITHUB_TOKEN; \
  REPO_ROOT="$TMP" "$SCRIPT" pkg bare-pkg 2>/dev/null)

assert_eq "no-hashes pkg: lockfile_fresh=false" "false" \
  "$(echo "$out4" | jq -r '.lockfile_fresh')"

# ── required output keys present ──────────────────────────
for key in ci_green_streak_days last_test_at lockfile_fresh \
           test_duration_s score note; do
  val=$(echo "$out" | jq --arg k "$key" 'has($k)')
  assert_eq "env output has key: $key" "true" "$val"
done

# ── unknown kind exits non-zero ────────────────────────────
if REPO_ROOT="$TMP" "$SCRIPT" bad name 2>/dev/null; then
  FAIL=$((FAIL + 1))
  echo "FAIL - unknown kind should exit non-zero"
else
  PASS=$((PASS + 1))
  echo "ok - unknown kind exits non-zero"
fi

echo "--- $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
