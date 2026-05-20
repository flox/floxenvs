#!/usr/bin/env bash
# Tests for scripts/lint-meta.sh
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPER="$SCRIPT_DIR/../lint-meta.sh"

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

mkdir -p "$TMP/good"
cat > "$TMP/good/meta.yaml" <<'EOF'
kind: env
name: good
title: Good
publisher: flox
tagline: A complete env.
category: ai
ai_role: tooling
tags: [a, b]
status: stable
license: MIT
install:
  include: "[include]\nenvironments = [\"flox/good\"]\n"
links:
  source: https://example.com
EOF

mkdir -p "$TMP/bad"
cat > "$TMP/bad/meta.yaml" <<'EOF'
kind: env
title: Missing name
publisher: flox
category: ai
EOF

mkdir -p "$TMP/pkg-good"
cat > "$TMP/pkg-good/meta.yaml" <<'EOF'
kind: pkg
subkind: plain
name: pkg-good
title: Pkg
publisher: flox
tagline: A pkg.
category: tool
tags: [a]
status: stable
license: MIT
install:
  pkg: "[install]\nfoo.pkg-path = \"foo\"\n"
links:
  source: https://example.com
EOF

REPO_ROOT="$TMP" "$HELPER" env good > /tmp/o.json
score=$(jq -r '.score' /tmp/o.json)
assert_eq "env good score 100" "100" "$score"

REPO_ROOT="$TMP" "$HELPER" env bad > /tmp/o.json
pass=$(jq -r '
  [.checks[] | select(.id == "meta-yaml-name")] | .[0].pass
' /tmp/o.json)
assert_eq "env bad fails name check" "false" "$pass"

if REPO_ROOT="$TMP" "$HELPER" plugin foo 2>/dev/null; then
  FAIL=$((FAIL + 1))
  echo "FAIL - unknown kind should exit non-zero"
else
  PASS=$((PASS + 1))
  echo "ok - unknown kind exits non-zero"
fi

REPO_ROOT="$TMP" "$HELPER" pkg pkg-good > /tmp/o.json
score=$(jq -r '.score' /tmp/o.json)
assert_eq "pkg good score 100" "100" "$score"

echo "--- $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
