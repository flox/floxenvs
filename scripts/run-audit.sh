#!/usr/bin/env bash
#
# Audit a single Claude Code skill package: build it (if needed), stage
# its skill content as Agent Plugins, run `flox-agent audit` on it, and
# write audit/skill/<name>/metrics.json in the site's metrics schema
# (.website/src/lib/metricsSchema.ts). flox-agent's own result is kept
# beside it as flox-agent-audit.json.
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
# package carries as share/flox/claude/<plugin>/, holding
# .claude-plugin/plugin.json and skills/<skill>/SKILL.md. The other
# launcher dirs are copies of the same skills, so Claude's is the one
# audited.
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
# its worst plugin. A skills/ child without SKILL.md is support content
# Claude Code does not load as a skill and would fail validation, so it
# is left out; a plugin with no skills at all (an LSP plugin, say) has
# nothing SkillSpector scans and is left out too.
view="$(mktemp -d)"
trap 'chmod -R u+w "$view" 2>/dev/null; rm -rf "$view"' EXIT
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
  desc="$(jq -r '(.description | strings) // ""' \
    "$pdir.claude-plugin/plugin.json")"
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
  ' > "$out_file"
  rm -f "$raw_file"
  echo "wrote $out_file (no skills to audit in ${claude#"$ROOT"/})"
  exit 0
fi

# Quality: one check per plugin, from check-plugin (exit 1 = invalid).
quality="$(
  for plugin in "${staged[@]}"; do
    res="$("${runner[@]}" check-plugin --json \
      "$view/share/agent-plugins/$plugin" || true)"
    valid="$(jq -r 'if .valid == true then "true" else "false" end' \
      <<<"$res")"
    note="$(jq -r '"\(.errors | length) errors, \(.warnings | length) warnings"' \
      <<<"$res")"
    sh_check_json "check-plugin:$plugin" "$valid" 1 "$note"
  done | sh_aggregate_quality
)"

# Exit 3 (could not audit) fails the script via set -e; no --threshold
# is passed, so any score exits 0. Results are written in the view and
# moved into place, so a failure never leaves a truncated file behind.
"${runner[@]}" audit --json "$view" > "$view/result.json"
mv "$view/result.json" "$raw_file"

# Map the result into metricsSchema.ts. Security.findings there is a
# per-severity tally, not the per-finding shape scripts/lib/*-to-findings.sh
# produce. Reliability and impact are not measured for skills.
jq --argjson identity "$identity" --argjson quality "$quality" '
  def sevs: ["CRITICAL", "HIGH", "MEDIUM", "LOW", "INFO"];
  def pill:
    {"safe": "stable", "caution": "warn",
     "do not install": "risk", "incomplete": "risk"}[.]
    // error("unknown flox-agent audit status: \(.)");
  [.plugins[].components[].findings[].severity | ascii_upcase] as $all
  | ($all | map(select(. as $s | sevs | index($s) | not))) as $bad
  | if ($bad | length) > 0
    then error("unknown SkillSpector severity: \($bad | unique | join(", "))")
    else . end
  | {
      identity: $identity,
      overall: .score,
      status: (.status | pill),
      quality: $quality,
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
        findings: [sevs[] as $s
          | ($all | map(select(. == $s)) | length) as $n
          | select($n > 0)
          | {tool: "skillspector", level: $s, count: $n, status: "open"}]
      },
      impact: {}
    }
' "$raw_file" > "$view/metrics.json"
mv "$view/metrics.json" "$out_file"
echo "wrote $out_file (plugins: ${staged[*]})"
