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
trap 'chmod -R u+w "$TMP" 2>/dev/null; rm -rf "$TMP"' EXIT

# Copy the scripts so internal helpers resolve correctly.
mkdir -p "$TMP/scripts/lib"
cp -r "$SCRIPTS"/*.sh "$TMP/scripts/"
cp -r "$SCRIPTS/lib"/*.sh "$TMP/scripts/lib/"

# ── non-skill kinds are rejected ──────────────────────────────────────
REPO_ROOT="$TMP" "$TMP/scripts/run-audit.sh" env sample >/dev/null 2>&1
assert_eq "rejects non-skill kind (env)" "2" "$?"

# ── stub flox-agent ───────────────────────────────────────────────────
# check-plugin reports valid with one warning (STUB_CHECK_RC overrides
# its exit code and makes it print a non-result). audit snapshots the
# staged view (it is deleted when run-audit.sh exits) and prints a
# result in flox-agent's audit JSON shape; STUB_SCORE and STUB_AUDIT_RC
# override its score and exit code.
mkdir -p "$TMP/bin"
cat > "$TMP/bin/flox-agent" <<EOF
#!/usr/bin/env bash
case "\$1" in
  check-plugin)
    if [ -n "\${STUB_CHECK_RC:-}" ]; then
      echo "ERROR: cannot read" >&2; exit "\$STUB_CHECK_RC"
    fi
    echo '{"valid":true,"specVersion":"1.0.0","errors":[],"warnings":[{"path":"skills/x/SKILL.md","message":"w"}]}'
    ;;
  audit)
    dir="\${@: -1}"
    echo "\$dir" > "$TMP/audited-dir.txt"
    if [ -n "\${STUB_AUDIT_RC:-}" ]; then
      echo "ERROR: cannot audit \$dir: api.osv.dev is unreachable" >&2
      exit "\$STUB_AUDIT_RC"
    fi
    ( cd "\$dir" && find . | sort ) > "$TMP/view-tree.txt"
    ( cd "\$dir" && find ./share/agent-plugins/*/skills -type l ) \
      > "$TMP/view-skill-links.txt"
    cp "\$dir/share/agent-plugins/humanizer/plugin.json" "$TMP/humanizer-plugin.json"
    cp "\$dir/share/agent-plugins/second/plugin.json" "$TMP/second-plugin.json"
    score="\${STUB_SCORE:-62}"
    cat <<JSON
{
  "target": "\$dir",
  "resolved": {"kind": "path", "storePath": null},
  "plugins": [
    {"name": "humanizer", "score": \$score, "status": "caution",
     "coverage": {"scanned": ["skills/humanizer"], "validated": ["plugin.json"],
                  "notChecked": [{"path": "hooks/", "reason": "outside the spec"}]},
     "components": [
       {"path": "skills/humanizer", "score": \$score, "status": "caution",
        "partial": false, "coverage": 100,
        "findings": [
          {"id": "P1", "severity": "HIGH", "message": "m", "file": "f", "line": 1},
          {"id": "P2", "severity": "HIGH", "message": "m", "file": "f", "line": 2},
          {"id": "L1", "severity": "LOW", "message": "m", "file": "f", "line": 3}
        ]}
     ]},
    {"name": "second", "score": 100, "status": "incomplete",
     "coverage": {"scanned": ["skills/two"], "validated": ["plugin.json"], "notChecked": []},
     "components": [{"path": "skills/two", "score": 100, "status": "incomplete",
                     "partial": true, "coverage": 10.5, "findings": []}]}
  ],
  "score": \$score,
  "status": "caution",
  "tool": {"name": "skillspector", "version": "2.12.0", "mode": "static",
           "osv": {"live": true, "checkedAt": "2026-10-20T00:00:00Z"}}
}
JSON
    ;;
  *) echo "unexpected stub call: \$*" >&2; exit 2 ;;
esac
EOF
chmod +x "$TMP/bin/flox-agent"

run() {
  PATH="$TMP/bin:$PATH" REPO_ROOT="$TMP" "$TMP/scripts/run-audit.sh" skill "$@"
}

# ── fixture: a pre-built multi-plugin fragment (skips `flox build`) ───
claude="$TMP/result-skills-humanizer/share/flox/claude"
skill_md() {
  mkdir -p "$1"
  printf -- '---\nname: %s\ndescription: Use when testing.\n---\n\nBody.\n' \
    "$(basename "$1")" > "$1/SKILL.md"
}
mkdir -p "$claude/humanizer/.claude-plugin"
echo '{"name":"humanizer","description":"Humanize text."}' \
  > "$claude/humanizer/.claude-plugin/plugin.json"
skill_md "$claude/humanizer/skills/humanizer"
# skills/ child with no SKILL.md: support content, not a skill.
mkdir -p "$claude/humanizer/skills/support"
echo data > "$claude/humanizer/skills/support/notes.txt"
# A skill exposed as a relative symlink must be materialized.
skill_md "$claude/humanizer/shared/linked"
ln -s ../shared/linked "$claude/humanizer/skills/linked"
# Non-skill plugin content goes into the view for the audit to list.
mkdir -p "$claude/humanizer/hooks"
echo '{}' > "$claude/humanizer/hooks/hooks.json"
# A stray root plugin.json is replaced by the staged manifest.
echo '{"name":"Not Valid"}' > "$claude/humanizer/plugin.json"
# A plugin with no .claude-plugin manifest is staged without a description.
skill_md "$claude/second/skills/two"
# A plugin with no skills (an LSP plugin) is not staged.
mkdir -p "$claude/lsp-only/.claude-plugin"
echo '{"name":"lsp-only"}' > "$claude/lsp-only/.claude-plugin/plugin.json"
echo '{}' > "$claude/lsp-only/.lsp.json"
# Other launcher layouts are ignored.
skill_md "$TMP/result-skills-humanizer/share/flox/opencode/humanizer/skills/humanizer"

run skills-humanizer
assert_eq "run-audit exits 0" "0" "$?"
sk="$TMP/audit/skill/skills-humanizer/metrics.json"
assert_eq "skill metrics.json written" "true" \
  "$([ -f "$sk" ] && echo true || echo false)"
assert_eq "flox-agent result kept" "true" \
  "$([ -f "$TMP/audit/skill/skills-humanizer/flox-agent-audit.json" ] \
       && echo true || echo false)"

# ── the staged Agent Plugins view ─────────────────────────────────────
assert_eq "staged view removed after the run" "false" \
  "$([ -e "$(cat "$TMP/audited-dir.txt")" ] && echo true || echo false)"
tree="$(cat "$TMP/view-tree.txt")"
has() { grep -qxF "$1" <<<"$tree" && echo true || echo false; }
assert_eq "humanizer manifest at plugin root" "true" \
  "$(has ./share/agent-plugins/humanizer/plugin.json)"
assert_eq "humanizer skill staged" "true" \
  "$(has ./share/agent-plugins/humanizer/skills/humanizer/SKILL.md)"
assert_eq "symlinked skill staged" "true" \
  "$(has ./share/agent-plugins/humanizer/skills/linked/SKILL.md)"
assert_eq "no symlinks under skills/" "" \
  "$(cat "$TMP/view-skill-links.txt")"
assert_eq "skills/ child without SKILL.md left out" "false" \
  "$(has ./share/agent-plugins/humanizer/skills/support)"
assert_eq "non-skill content copied for the audit to list" "true" \
  "$(has ./share/agent-plugins/humanizer/hooks/hooks.json)"
assert_eq ".claude-plugin copied for the audit to list" "true" \
  "$(has ./share/agent-plugins/humanizer/.claude-plugin/plugin.json)"
assert_eq "second plugin staged" "true" \
  "$(has ./share/agent-plugins/second/skills/two/SKILL.md)"
assert_eq "plugin with no skills left out" "false" \
  "$(has ./share/agent-plugins/lsp-only)"
assert_eq "manifest \$schema" \
  "https://agent-plugins.org/schemas/1.0.0/plugin.schema.json" \
  "$(jq -r '."$schema"' "$TMP/humanizer-plugin.json")"
assert_eq "manifest name and description" "humanizer|Humanize text." \
  "$(jq -r '"\(.name)|\(.description)"' "$TMP/humanizer-plugin.json")"
assert_eq "no .claude-plugin manifest: no description" "second|false" \
  "$(jq -r '"\(.name)|\(has("description"))"' "$TMP/second-plugin.json")"

# ── metrics.json in the site schema ───────────────────────────────────
for dim in quality reliability security impact identity; do
  present=$(jq "has(\"$dim\")" "$sk" 2>/dev/null || echo false)
  assert_eq "skill section $dim present" "true" "$present"
done
assert_eq "identity" "skill|skills-humanizer" \
  "$(jq -r '"\(.identity.kind)|\(.identity.name)"' "$sk")"
assert_eq "overall is the audit score" "62" "$(jq -r '.overall' "$sk")"
assert_eq "status from overall (62 -> warn)" "warn" "$(jq -r '.status' "$sk")"
assert_eq "security score" "62" "$(jq -r '.security.score' "$sk")"
assert_eq "scanner keeps flox-agent's status and worst severity" \
  "caution|HIGH" \
  "$(jq -r '.security.scanners[0] | "\(.status)|\(.level)"' "$sk")"
assert_eq "findings tallied by severity" "HIGH=2,LOW=1" \
  "$(jq -r '[.security.findings[] | select(.status == "open")
             | "\(.level)=\(.count)"] | join(",")' "$sk")"
assert_eq "incomplete scan recorded" "second/skills/two 10%" \
  "$(jq -r '.security.findings[] | select(.status == "incomplete") | .note' "$sk")"
assert_eq "unchecked entries recorded" "humanizer/hooks/" \
  "$(jq -r '.security.findings[] | select(.status == "not checked") | .note' "$sk")"
assert_eq "one check-plugin check per staged plugin" \
  "check-plugin:humanizer,check-plugin:second" \
  "$(jq -r '[.quality.checks[].id] | join(",")' "$sk")"
assert_eq "quality scores warnings (1 warning -> 95)" "95" \
  "$(jq -r '.quality.score' "$sk")"
assert_eq "a check with warnings does not pass" "false" \
  "$(jq -r '.quality.checks[0].pass' "$sk")"

# ── status follows the site's thresholds, not SkillSpector's bands ────
STUB_SCORE=55 run skills-humanizer >/dev/null
assert_eq "score 55 (caution) -> risk, as overallStatus shows it" "risk" \
  "$(jq -r '.status' "$sk")"

# ── could not audit: warn, keep no stale result, exit 0 ───────────────
out="$(STUB_AUDIT_RC=3 run skills-humanizer 2>/dev/null)"
assert_eq "exit 3 is not a failure" "0" "$?"
assert_eq "exit 3 emits a CI warning" "true" \
  "$(grep -q '^::warning title=audit skills-humanizer::not audited: ERROR: cannot audit' \
       <<<"$out" && echo true || echo false)"
assert_eq "exit 3 leaves no metrics.json" "false" \
  "$([ -f "$sk" ] && echo true || echo false)"
assert_eq "exit 3 leaves no earlier flox-agent result" "false" \
  "$([ -f "$TMP/audit/skill/skills-humanizer/flox-agent-audit.json" ] \
       && echo true || echo false)"

# ── any other audit failure fails the run ─────────────────────────────
STUB_AUDIT_RC=2 run skills-humanizer >/dev/null 2>&1
assert_eq "audit exit 2 fails the run" "2" "$?"

# ── a check-plugin failure is never a silently missing check ──────────
STUB_CHECK_RC=2 run skills-humanizer >/dev/null 2>&1
rc=$?
assert_eq "check-plugin exit 2 fails the run" "true" \
  "$([ "$rc" -ne 0 ] && echo true || echo false)"
assert_eq "check-plugin failure writes no metrics.json" "false" \
  "$([ -f "$sk" ] && echo true || echo false)"

# ── a package with no skills is recorded as not audited ───────────────
lsp="$TMP/result-skills-lsp/share/flox/claude/lsp/.claude-plugin"
mkdir -p "$lsp"
echo '{"name":"lsp"}' > "$lsp/plugin.json"
rm -f "$TMP/audited-dir.txt"
run skills-lsp >/dev/null
assert_eq "skill-less package exits 0" "0" "$?"
assert_eq "skill-less package status missing" "missing" \
  "$(jq -r '.status' "$TMP/audit/skill/skills-lsp/metrics.json")"
assert_eq "skill-less package not sent to audit" "false" \
  "$([ -f "$TMP/audited-dir.txt" ] && echo true || echo false)"

echo "--- $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
