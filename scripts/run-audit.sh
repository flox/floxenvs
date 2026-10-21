#!/usr/bin/env bash
#
# Audit a single Claude Code skill package: build it (if needed), stage
# its skill content as Agent Plugins, run `flox-agent audit` on it, and
# write audit/skill/<name>/metrics.json in the site's metrics schema
# (.website/src/lib/metricsSchema.ts). flox-agent's own result is kept
# beside it as flox-agent-audit.json.
#
# When flox-agent cannot audit the package (exit 3: osv.dev unreachable,
# a scan timed out, a SKILL.md fails validation, ...) this prints a CI
# warning, writes no metrics, and exits 0, so the site keeps the
# package's previous metrics instead of the build going red.
#
# This script audits SKILLS ONLY. Other item kinds (env, pkg, agent)
# are not handled here.
#
# Usage: run-audit.sh skill <name>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib/sh-helpers.sh"
ROOT="${REPO_ROOT:-$(sh_repo_root)}"

KIND="${1:?kind}"
NAME="${2:?name}"

if [ "$KIND" != "skill" ]; then
  echo "run-audit.sh audits skills only (got kind '$KIND')" >&2
  exit 2
fi

out_dir="$ROOT/audit/$KIND/$NAME"
mkdir -p "$out_dir"
out_file="$out_dir/metrics.json"
raw_file="$out_dir/flox-agent-audit.json"
# A run that ends without a result must not leave an earlier one behind.
rm -f "$out_file" "$raw_file"

# The .flox/pkgs/<name> source holds only packaging files — the actual
# skill content (SKILL.md, .claude-plugin) is produced by the build,
# fetched from upstream. Build to materialize it. `flox build` must NOT
# run inside an activated env (it breaks with "attribute 'lib' missing"),
# so CI pre-builds in a separate, non-activated step and this script just
# consumes result-<name>; standalone/local use builds on demand.
built="$ROOT/result-$NAME"
if [ ! -d "$built" ]; then
  ( cd "$ROOT" && flox build "$NAME" ) \
    || { echo "build failed for $NAME" >&2; exit 1; }
fi

# flox_agent_layout (.flox/nix/flox-agent-layout.sh) emits every plugin a
# package carries as share/flox/claude/<plugin>/, holding skills/<skill>/
# and usually .claude-plugin/plugin.json. The other launcher dirs are
# copies of the same skills, so Claude's is the one audited.
claude="$built/share/flox/claude"
if [ ! -d "$claude" ]; then
  echo "no share/flox/claude in result-$NAME; not a fragment build" >&2
  exit 1
fi

if command -v flox-agent >/dev/null 2>&1; then
  runner=(flox-agent)
elif [ -x "$ROOT/result-flox-agent/bin/flox-agent" ]; then
  runner=("$ROOT/result-flox-agent/bin/flox-agent")
else
  echo "flox-agent audit runner not found" >&2; exit 1
fi

# `flox-agent audit` reads Agent Plugins only: plugin.json at the plugin
# root, and skills/<skill>/ as real directories holding SKILL.md (it
# never follows a symlink). Stage that view of each Claude plugin under
# <view>/share/agent-plugins/, which audit takes as one target scored by
# its worst plugin.
#   - A skills/ child without SKILL.md is support content Claude Code
#     does not load as a skill and would fail validation: left out.
#   - Every other top-level entry (hooks/, commands/, bin/, ...) is
#     copied as-is, so the audit lists it under coverage.notChecked
#     instead of the view hiding that it exists.
#   - A plugin with no skills at all (an LSP plugin, say) has nothing
#     SkillSpector scans: left out.
work="$(mktemp -d)"
trap 'chmod -R u+w "$work" 2>/dev/null; rm -rf "$work"' EXIT
view="$work/view"
staged=()
for pdir in "$claude"/*/; do
  [ -d "$pdir" ] || continue
  plugin="$(basename "$pdir")"
  dst="$view/share/agent-plugins/$plugin"
  for sdir in "$pdir"skills/*/; do
    [ -f "${sdir}SKILL.md" ] || continue
    mkdir -p "$dst/skills"
    cp -RL "$sdir" "$dst/skills/$(basename "$sdir")"
  done
  [ -d "$dst" ] || continue
  for entry in "$pdir".[!.]* "$pdir"*; do
    [ -e "$entry" ] || [ -L "$entry" ] || continue
    case "$(basename "$entry")" in skills|plugin.json) continue ;; esac
    cp -R "$entry" "$dst/"
  done
  manifest="$pdir.claude-plugin/plugin.json"
  desc=""
  if [ -f "$manifest" ]; then
    desc="$(jq -r '(.description | strings) // ""' "$manifest")"
  fi
  jq -n --arg name "$plugin" --arg desc "$desc" '
    {"$schema": "https://agent-plugins.org/schemas/1.0.0/plugin.schema.json",
     name: $name}
    + (if $desc == "" then {} else {description: $desc} end)
  ' > "$dst/plugin.json"
  staged+=("$plugin")
done

identity="$(jq -nc --arg name "$NAME" --arg dir "${claude#"$ROOT"/}" \
  '{kind: "skill", name: $name, dir: $dir}')"

if [ ${#staged[@]} -eq 0 ]; then
  # Nothing to scan. Record the package as not audited rather than
  # inventing a score; the site renders status "missing" as no data.
  jq -n --argjson identity "$identity" '
    {identity: $identity, overall: 0, status: "missing",
     quality: {score: 0, checks: []}, reliability: {},
     security: {score: 0, cap: 100, scanners: [], findings: []},
     impact: {}}
  ' > "$work/metrics.json"
  mv "$work/metrics.json" "$out_file"
  echo "wrote $out_file (no skills to audit in ${claude#"$ROOT"/})"
  exit 0
fi

# No --threshold is passed, so any score exits 0. Exit 3 means the
# package could not be audited; anything else is a failure of the run.
rc=0
"${runner[@]}" audit --json "$view" > "$work/result.json" \
  2> "$work/audit.err" || rc=$?
cat "$work/audit.err" >&2
if [ "$rc" -eq 3 ]; then
  reason="$(grep -m1 . "$work/audit.err" || echo "flox-agent audit exit 3")"
  echo "::warning title=audit $NAME::not audited: ${reason//$'\r'/}"
  echo "no metrics written for $NAME; the site keeps its previous ones" >&2
  exit 0
elif [ "$rc" -ne 0 ]; then
  echo "flox-agent audit failed for $NAME (exit $rc)" >&2
  exit "$rc"
fi

# Quality: one check-plugin check per plugin (exit 0 valid, 1 invalid;
# anything else, or output that is not a check-plugin result, is a
# failure of the run, never a silently missing check).
: > "$work/checks.jsonl"
for plugin in "${staged[@]}"; do
  rc=0
  "${runner[@]}" check-plugin --json "$view/share/agent-plugins/$plugin" \
    > "$work/check.json" || rc=$?
  if [ "$rc" -gt 1 ] \
     || ! jq -e '(.valid | type) == "boolean"' "$work/check.json" >/dev/null 2>&1
  then
    echo "check-plugin failed for $plugin in $NAME (exit $rc)" >&2
    exit 1
  fi
  jq -c --arg plugin "$plugin" '
    {plugin: $plugin, valid,
     errors: (.errors | length), warnings: (.warnings | length)}
  ' "$work/check.json" >> "$work/checks.jsonl"
done

mv "$work/result.json" "$raw_file"

# Map the result into metricsSchema.ts.
#   - status comes from overall by the site's own thresholds (overallStatus
#     in .website/src/lib/scoring.ts), since ScorePanel derives it that
#     way; flox-agent's own status stays on the scanner row.
#   - quality scores check-plugin errors and warnings with the formula the
#     earlier flox-agent ensemble used (100 - 25*errors - 5*warnings,
#     clamped to 0-100), averaged over plugins.
#   - security.findings is a per-severity tally (not the per-finding shape
#     scripts/lib/*-to-findings.sh produce), plus INFO rows for components
#     scanned incompletely and entries the audit did not check.
#   - reliability and impact are not measured for skills.
jq --argjson identity "$identity" --slurpfile checks "$work/checks.jsonl" '
  def sevs: ["CRITICAL", "HIGH", "MEDIUM", "LOW", "INFO"];
  def pill:
    if . >= 80 then "stable" elif . >= 60 then "warn" else "risk" end;
  def clamp: if . < 0 then 0 elif . > 100 then 100 else . end;
  def listed: if length > 5 then (.[:5] + ["…"]) else . end | join(", ");
  (.plugins | length > 1) as $multi
  | def where($p): if $multi then "\($p.name)/" else "" end;
  [.plugins[].components[].findings[].severity | ascii_upcase] as $all
  | ($all | map(select(. as $s | sevs | index($s) | not))) as $bad
  | if ($bad | length) > 0
    then error("unknown SkillSpector severity: \($bad | unique | join(", "))")
    else . end
  | [.plugins[] as $p | $p.components[]
      | select(.partial and (.coverage // 100) < 100)
      | "\(where($p))\(.path) \(.coverage | floor)%"] as $incomplete
  | [.plugins[] as $p | $p.coverage.notChecked[]
      | "\(where($p))\(.path)"] as $unchecked
  | {
      identity: $identity,
      overall: .score,
      status: (.score | pill),
      quality: {
        score: ($checks
          | map(100 - 25 * .errors - 5 * .warnings | clamp)
          | add / length | floor),
        checks: [$checks[] | {
          id: "check-plugin:\(.plugin)",
          pass: (.valid and .errors == 0 and .warnings == 0),
          weight: 1,
          note: "\(.errors) errors, \(.warnings) warnings"
        }]
      },
      reliability: {},
      security: {
        score: .score,
        cap: 100,
        scanners: [{
          tool: "\(.tool.name) \(.tool.version)",
          level: (first(sevs[] as $s | select($all | index($s)) | $s)
                  // "INFO"),
          status: .status
        }],
        findings: (
          [sevs[] as $s
            | ($all | map(select(. == $s)) | length) as $n
            | select($n > 0)
            | {tool: "skillspector", level: $s, count: $n, status: "open"}]
          + (if ($incomplete | length) > 0 then [{
              tool: "skillspector", level: "INFO",
              count: ($incomplete | length), status: "incomplete",
              note: ($incomplete | listed)}] else [] end)
          + (if ($unchecked | length) > 0 then [{
              tool: "flox-agent", level: "INFO",
              count: ($unchecked | length), status: "not checked",
              note: ($unchecked | listed)}] else [] end)
        )
      },
      impact: {}
    }
' "$raw_file" > "$work/metrics.json"
mv "$work/metrics.json" "$out_file"
echo "wrote $out_file (plugins: ${staged[*]})"
