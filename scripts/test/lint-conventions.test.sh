#!/usr/bin/env bash
# Tests for scripts/lint-conventions.sh
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPER="$SCRIPT_DIR/../lint-conventions.sh"

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
mkdir -p "$TMP/clean/.flox/env"
cat > "$TMP/clean/.flox/env/manifest.toml" <<'EOF'
schema-version = "1.10.0"

# Minimal clean env.
#
#   [include]
#   environments = ["flox/clean"]

[install]
foo.pkg-path = "foo"
foo.pkg-group = "clean"

[hook]
on-activate = '''
mkdir -p "$FLOX_ENV_CACHE/clean"
'''
EOF

mkdir -p "$TMP/dirty/.flox/env"
cat > "$TMP/dirty/.flox/env/manifest.toml" <<'EOF'
schema-version = "1.8.0"

[install]
foo.pkg-path = "foo"

[hook]
on-activate = '''
echo "loading..."
mkdir -p /tmp/dirty
'''
EOF

REPO_ROOT="$TMP" "$HELPER" clean > /tmp/o.json
score=$(jq -r '.score' /tmp/o.json)
assert_eq "clean env score 100" "100" "$score"

REPO_ROOT="$TMP" "$HELPER" dirty > /tmp/o.json
fails=$(jq -r '[.checks[] | select(.pass==false) | .id] | length' /tmp/o.json)
assert_eq "dirty has multiple failures (>=3)" "true" \
  "$(awk -v f="$fails" 'BEGIN { print (f >= 3) ? "true" : "false" }')"

echo "--- $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
