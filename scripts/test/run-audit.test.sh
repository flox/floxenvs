#!/usr/bin/env bash
# Integration test for scripts/run-audit.sh (skills only).
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

# Copy the scripts so internal helpers resolve correctly.
mkdir -p "$TMP/scripts/lib"
cp -r "$SCRIPTS"/*.sh "$TMP/scripts/"
cp -r "$SCRIPTS/lib"/*.sh "$TMP/scripts/lib/"

# ── non-skill kinds are rejected ──────────────────────────────────────
REPO_ROOT="$TMP" "$TMP/scripts/run-audit.sh" env sample >/dev/null 2>&1
assert_eq "rejects non-skill kind (env)" "2" "$?"

# ── skill kind: build is skipped, Claude content is audited ───────────
# Stage a stub flox-ai on PATH that records the audited dir and emits a
# valid metrics.json, plus a pre-built result-<name> so run-audit.sh
# skips `flox build`. The build emits the same skill under several agent
# layouts; the Claude copy must win.
mkdir -p "$TMP/bin"
cat > "$TMP/bin/flox-ai" <<EOF
#!/usr/bin/env bash
# args: audit --json --kind <kind> <content-dir>
echo "\${@: -1}" > "$TMP/audited-dir.txt"
cat <<'JSON'
{
  "identity": {"kind": "skill", "name": "skills-humanizer",
               "dir": ".flox/pkgs/skills-humanizer"},
  "overall": 82,
  "status": "stable",
  "quality": {"score": 80, "checks": []},
  "reliability": {"score": 80},
  "security": {"score": 100, "scanners": [], "findings": []},
  "impact": {"score": 50}
}
JSON
EOF
chmod +x "$TMP/bin/flox-ai"

mkdir -p "$TMP/.flox/pkgs/skills-humanizer"
# Same skill present under the Claude AND a non-Claude launcher layout.
mkdir -p "$TMP/result-skills-humanizer/share/flox/claude/humanizer"
mkdir -p "$TMP/result-skills-humanizer/share/flox/opencode/humanizer"
cat > "$TMP/result-skills-humanizer/share/flox/claude/humanizer/SKILL.md" <<'EOF'
---
name: humanizer
description: Use when you need a tidy example skill for tests.
---

# Humanizer

Do the thing. Then do the next thing.
EOF

PATH="$TMP/bin:$PATH" REPO_ROOT="$TMP" \
  "$TMP/scripts/run-audit.sh" skill skills-humanizer
sk="$TMP/audit/skill/skills-humanizer/metrics.json"
assert_eq "skill metrics.json written" "true" \
  "$([ -f "$sk" ] && echo true || echo false)"

# Claude launcher folder is preferred over the opencode copy.
assert_eq "audited the Claude content dir" "true" \
  "$(grep -q 'share/flox/claude/humanizer$' "$TMP/audited-dir.txt" \
       && echo true || echo false)"

for dim in quality reliability security impact identity; do
  present=$(jq "has(\"$dim\")" "$sk" 2>/dev/null || echo false)
  assert_eq "skill section $dim present" "true" "$present"
done

assert_eq "skill identity.kind == skill" "skill" \
  "$(jq -r '.identity.kind' "$sk" 2>/dev/null)"

sov=$(jq -r '.overall' "$sk" 2>/dev/null)
assert_eq "skill overall is integer 0-100" "true" \
  "$(awk -v v="$sov" 'BEGIN { print (v ~ /^[0-9]+$/ && v <= 100 && v >= 0) ? "true" : "false" }')"

assert_eq "skill status is a pill" "true" \
  "$(jq -r '.status' "$sk" 2>/dev/null | grep -qxE 'stable|warn|risk' && echo true || echo false)"

echo "--- $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
