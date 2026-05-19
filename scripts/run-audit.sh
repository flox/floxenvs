#!/usr/bin/env bash
#
# Orchestrate the per-item audit and write a single JSON
# blob to audit/<kind>/<name>/metrics.json.
#
# Usage: run-audit.sh <kind> <name>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib/sh-helpers.sh"
ROOT="${REPO_ROOT:-$(sh_repo_root)}"

KIND="${1:?kind}"
NAME="${2:?name}"

dir=$(sh_item_dir "$KIND" "$NAME")
abs_dir="$ROOT/$dir"
out_dir="$ROOT/audit/$KIND/$NAME"
mkdir -p "$out_dir"
out_file="$out_dir/metrics.json"

# ── 1. quality (lint-meta + lint-conventions + metrics.sh)
meta_json=$(REPO_ROOT="$ROOT" \
  "$SCRIPT_DIR/lint-meta.sh" "$KIND" "$NAME")

conv_json='{"score":100,"checks":[]}'
if [ "$KIND" = "env" ]; then
  conv_json=$(REPO_ROOT="$ROOT" \
    "$SCRIPT_DIR/lint-conventions.sh" "$NAME")
fi

# Defaults from metrics-defaults.sh.
# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib/metrics-defaults.sh"
case "$KIND" in
  env) defaults_json=$(default_env_checks "$NAME" "$abs_dir") ;;
  pkg) defaults_json=$(default_pkg_checks "$NAME" "$abs_dir") ;;
esac

custom_json='{"score":null,"checks":[]}'
if [ -x "$abs_dir/metrics.sh" ]; then
  set +e
  custom_json=$(
    REPO_ROOT="$ROOT" \
    "$abs_dir/metrics.sh" "$KIND" "$NAME" 2>/dev/null \
    || true
  )
  set -e
  if [ -z "$custom_json" ]; then
    custom_json='{"score":null,"checks":[]}'
  fi
fi

quality_json=$(jq -nc \
  --argjson defaults "$defaults_json" \
  --argjson meta "$meta_json" \
  --argjson conv "$conv_json" \
  --argjson custom "$custom_json" \
  '
  ($defaults.checks + $meta.checks
   + $conv.checks + $custom.checks) as $all
  | {
      score: (
        if ($all | length) == 0 then 0
        else
          ([$all[] | select(.pass) | .weight] | add // 0)
          * 100 / ([$all[].weight] | add // 1)
          | floor
        end
      ),
      checks: $all,
    }
  ')

# ── 2. security (gitleaks + shellcheck) ──────────────────
sec_findings='[]'

if command -v gitleaks >/dev/null 2>&1; then
  set +e
  gitleaks detect --config "$ROOT/.gitleaks.toml" \
    --no-banner --no-git --source "$abs_dir" \
    --redact --report-format json \
    --report-path "$out_dir/gitleaks.json" >/dev/null
  gl_code=$?
  set -e
  if [ "$gl_code" != "0" ] && [ -f "$out_dir/gitleaks.json" ]; then
    n=$(jq 'length' "$out_dir/gitleaks.json")
    if [ "$n" -gt 0 ]; then
      sec_findings=$(jq --argjson n "$n" \
        '[{tool:"gitleaks", level:"HIGH",
           count:$n, status:"failed"}]' \
        "$out_dir/gitleaks.json")
    fi
  fi
else
  sec_findings=$(echo "$sec_findings" | jq \
    '. + [{tool:"gitleaks", level:"INFO",
           status:"skipped",
           note:"gitleaks not installed"}]')
fi

if command -v shellcheck >/dev/null 2>&1; then
  sh_files=$(find "$abs_dir" -maxdepth 2 -name '*.sh' \
              -type f 2>/dev/null || true)
  if [ -n "$sh_files" ]; then
    set +e
    # shellcheck disable=SC2086
    shellcheck -S warning -f json $sh_files \
      > "$out_dir/shellcheck.json" 2>/dev/null
    sc_code=$?
    set -e
    if [ "$sc_code" != "0" ] && [ -f "$out_dir/shellcheck.json" ]; then
      n=$(jq 'length' "$out_dir/shellcheck.json" 2>/dev/null || echo 0)
      if [ "$n" -gt 0 ]; then
        sec_findings=$(echo "$sec_findings" | jq \
          --argjson n "$n" \
          '. + [{tool:"shellcheck", level:"MEDIUM",
                 count:$n, status:"warnings"}]')
      fi
    fi
  fi
else
  sec_findings=$(echo "$sec_findings" | jq \
    '. + [{tool:"shellcheck", level:"INFO",
           status:"skipped",
           note:"shellcheck not installed"}]')
fi

# Always-on row: gitleaks reported "Passed" when no
# findings; mirror that for shellcheck.
sec_rows=$(jq -n \
  --argjson findings "$sec_findings" \
  '
  [
    {tool:"gitleaks",
     level: ($findings | map(select(.tool=="gitleaks"))
             | (first.level // "INFO")),
     status: ($findings | any(.tool == "gitleaks")
              | if . then
                  ([$findings[] | select(.tool=="gitleaks")
                    | .status] | first // "Passed")
                else "Passed"
                end)},
    {tool:"shellcheck",
     level: ($findings | map(select(.tool=="shellcheck"))
             | (first.level // "INFO")),
     status: ($findings | any(.tool == "shellcheck")
              | if . then
                  ([$findings[] | select(.tool=="shellcheck")
                    | .status] | first // "Passed")
                else "Passed"
                end)},
    {tool:"floxenv-scan", level:"INFO",  status:"Pending (v2)"},
    {tool:"trivy",        level:"INFO",  status:"Pending (v2)"},
    {tool:"snyk",         level:"INFO",  status:"Pending (v2)"}
  ]
  ')

# Risk-derived caps (CRITICAL → 50, HIGH → 75).
cap=100
sec_score=100
for level in $(echo "$sec_findings" | jq -r '.[].level'); do
  case "$level" in
    CRITICAL) cap=50
              sec_score=$(( sec_score - 30 )) ;;
    HIGH)     [ "$cap" -gt 75 ] && cap=75
              sec_score=$(( sec_score - 20 )) ;;
    MEDIUM)   sec_score=$(( sec_score - 10 )) ;;
    LOW)      sec_score=$(( sec_score - 5  )) ;;
  esac
done
[ "$sec_score" -lt 0 ] && sec_score=0

security_json=$(jq -nc \
  --argjson rows "$sec_rows" \
  --argjson findings "$sec_findings" \
  --argjson score "$sec_score" \
  --argjson cap "$cap" \
  '{score:$score, cap:$cap, scanners:$rows, findings:$findings}')

# ── 3. reliability ───────────────────────────────────────
reliability_json=$(REPO_ROOT="$ROOT" \
  "$SCRIPT_DIR/compute-reliability.sh" "$KIND" "$NAME")

# ── 4. impact (evals.yaml or adoption fallback) ─────────
impact_json=$(REPO_ROOT="$ROOT" \
  FLOX_EVAL_DRY_RUN="${FLOX_EVAL_DRY_RUN:-}" \
  "$SCRIPT_DIR/run-flox-evals.sh" "$KIND" "$NAME")

# ── 5. overall ──────────────────────────────────────────
# Weighted average; cap by security cap.
overall=$(jq -nr \
  --argjson q "$quality_json" \
  --argjson r "$reliability_json" \
  --argjson s "$security_json" \
  --argjson i "$impact_json" \
  '
  (($q.score // 0) * 0.35
   + ($r.score // 0) * 0.35
   + ($s.score // 0) * 0.20
   + ($i.score // 50) * 0.10)    # 50 = neutral when no evals
  | floor
  | if . > ($s.cap // 100) then ($s.cap // 100) else . end
  ')

# Status pill: stable | warn | risk
status="stable"
if [ "$overall" -lt 60 ]; then status="risk"
elif [ "$overall" -lt 80 ]; then status="warn"
fi

identity_json=$(jq -nc \
  --arg kind "$KIND" \
  --arg name "$NAME" \
  --arg dir  "$dir" \
  '{kind:$kind, name:$name, dir:$dir}')

jq -nc \
  --argjson identity "$identity_json" \
  --argjson quality "$quality_json" \
  --argjson reliability "$reliability_json" \
  --argjson security "$security_json" \
  --argjson impact "$impact_json" \
  --argjson overall "$overall" \
  --arg     status  "$status" \
  '{
    identity: $identity,
    overall: $overall,
    status: $status,
    quality: $quality,
    reliability: $reliability,
    security: $security,
    impact: $impact,
  }' > "$out_file"

echo "wrote $out_file"
