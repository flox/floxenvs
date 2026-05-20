#!/usr/bin/env bash
# Integration test for scripts/run-audit.sh
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS="$SCRIPT_DIR/.."

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

# Stage a minimal env so each linter has something
# to look at, and copy the scripts so internal helpers
# resolve correctly.
mkdir -p "$TMP/scripts/lib" "$TMP/scripts/test"
cp -r "$SCRIPTS"/*.sh "$TMP/scripts/"
cp -r "$SCRIPTS/lib"/*.sh "$TMP/scripts/lib/"

mkdir -p "$TMP/sample/.flox/env"
cat > "$TMP/sample/.flox/env/manifest.toml" <<'EOF'
schema-version = "1.10.0"

# Sample env.
#
#   [include]
#   environments = ["flox/sample"]

[install]
foo.pkg-path = "foo"
foo.pkg-group = "sample"

[hook]
on-activate = '''
mkdir -p "$FLOX_ENV_CACHE/sample"
'''
EOF
mkdir -p "$TMP/sample-demo"
echo "demo" > "$TMP/sample-demo/README.md"
echo "readme" > "$TMP/sample/README.md"
cat > "$TMP/sample/test.sh" <<'EOF'
#!/usr/bin/env bash
true
EOF
cat > "$TMP/sample/meta.yaml" <<'EOF'
kind: env
name: sample
title: Sample
publisher: flox
tagline: A complete env.
category: ai
ai_role: tooling
tags: [a]
status: stable
license: MIT
install:
  include: "[include]\nenvironments = [\"flox/sample\"]\n"
links:
  source: https://example.com
EOF

REPO_ROOT="$TMP" FLOX_EVAL_DRY_RUN=1 \
  "$TMP/scripts/run-audit.sh" env sample
out="$TMP/audit/env/sample/metrics.json"
test -f "$out"
assert_eq "metrics.json written" "true" "$([ -f "$out" ] && echo true || echo false)"

# Has all required top-level sections.
for sec in quality reliability security impact identity; do
  present=$(jq "has(\"$sec\")" "$out")
  assert_eq "section $sec present" "true" "$present"
done

# Overall is an integer 0–100.
ov=$(jq -r '.overall' "$out")
assert_eq "overall is integer" "true" \
  "$(awk -v v="$ov" 'BEGIN { print (v ~ /^[0-9]+$/ && v <= 100 && v >= 0) ? "true" : "false" }')"

echo "--- $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
