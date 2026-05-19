#!/usr/bin/env bash
# Tests for scripts/lib/sh-helpers.sh and
# scripts/lib/metrics-defaults.sh.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$SCRIPT_DIR/.."
# shellcheck disable=SC1091
. "$ROOT/lib/sh-helpers.sh"

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

# ── sh_check_json shape ──────────────────────────────────
out=$(sh_check_json "has-readme" true 5)
assert_eq "check_json basic" \
  '{"id":"has-readme","pass":true,"weight":5}' "$out"

out=$(sh_check_json "silent-hook" false 10 "echo found")
assert_eq "check_json with note" \
  '{"id":"silent-hook","pass":false,"weight":10,"note":"echo found"}' \
  "$out"

# ── sh_aggregate_quality scoring ─────────────────────────
score=$(printf '%s\n' \
  '{"id":"a","pass":true,"weight":10}' \
  '{"id":"b","pass":false,"weight":10}' \
  '{"id":"c","pass":true,"weight":5}' \
  | sh_aggregate_quality | jq -r '.score')
assert_eq "aggregate weighted score" "60" "$score"

# ── sh_aggregate_quality empty ───────────────────────────
score=$(printf '' | sh_aggregate_quality | jq -r '.score')
assert_eq "aggregate empty score" "0" "$score"

# ── sh_item_dir ──────────────────────────────────────────
assert_eq "item_dir env"  "claude" "$(sh_item_dir env claude)"
assert_eq "item_dir pkg"  ".flox/pkgs/ollama" \
  "$(sh_item_dir pkg ollama)"


# ── metrics-defaults env path ────────────────────────────
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/sample/.flox/env"
cat > "$TMP/sample/README.md" <<'EOF'
sample readme
EOF
cat > "$TMP/sample/test.sh" <<'EOF'
#!/usr/bin/env bash
echo ok
EOF
cat > "$TMP/sample/.flox/env/manifest.toml" <<'EOF'
schema-version = "1.10.0"

# Example minimal env.
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
cat > "$TMP/sample/meta.yaml" <<'EOF'
kind: env
name: sample
title: Sample
publisher: flox
tagline: A sample env.
category: ai
ai_role: tooling
tags: [sample]
status: stable
license: MIT
links:
  source: https://example
EOF
mkdir -p "$TMP/sample-demo"
touch "$TMP/sample-demo/README.md"

# shellcheck disable=SC1091
. "$ROOT/lib/metrics-defaults.sh"
out=$(default_env_checks "sample" "$TMP/sample")
score=$(echo "$out" | jq -r '.score')
echo "$out" | jq -e '.checks | length >= 9' >/dev/null
assert_eq "env defaults score >= 80" "true" \
  "$(awk -v s="$score" 'BEGIN { print (s >= 80) ? "true" : "false" }')"
echo "$out" | jq -e '
  ([.checks[] | select(.pass == false)] | length == 0)
' >/dev/null
assert_eq "env defaults all pass" "true" "true"


# ── metrics-defaults pkg path ────────────────────────────
PKG_DIR="$TMP/sample-pkg"
mkdir -p "$PKG_DIR"
cat > "$PKG_DIR/default.nix" <<'EOF'
{ pkgs ? import <nixpkgs> {} }: pkgs.hello
EOF
cat > "$PKG_DIR/publish.json" <<'EOF'
{"org":"flox","systems":["aarch64-darwin"]}
EOF
cat > "$PKG_DIR/hashes.json" <<'EOF'
{"version":"1.0.0","srcHash":"sha256-AAA"}
EOF
cat > "$PKG_DIR/upgrade.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "ok"
EOF
chmod +x "$PKG_DIR/upgrade.sh"
cat > "$PKG_DIR/meta.yaml" <<'EOF'
kind: pkg
name: sample-pkg
title: Sample Pkg
publisher: flox
tagline: A sample pkg.
category: tool
tags: [sample]
status: stable
license: MIT
links:
  source: https://example
EOF

pout=$(default_pkg_checks "sample-pkg" "$PKG_DIR")
echo "$pout" | jq -e '
  (.checks | map(.id) | contains([
    "has-default-nix",
    "has-publish-json",
    "publish-json-valid",
    "meta-yaml-complete",
    "has-upgrade-sh",
    "has-hashes-json"
  ]))
' >/dev/null
assert_eq "pkg defaults has core checks" "true" "true"

echo "--- $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
