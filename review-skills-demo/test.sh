#!/usr/bin/env bash

set -eo pipefail

command_exists() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Error: '$1' command not found."
    return 1
  fi
  echo ">>> '$1' command exists"
}

# ── Required commands (runner inherited from review-skills) ──
command_exists review-skills
command_exists gum

# ── Sample artifacts present ────────────────────────────────
for f in samples/good-skill/SKILL.md samples/bad-skill/SKILL.md \
         samples/good-agent.md; do
  if [ ! -f "$f" ]; then
    echo "Error: sample '$f' missing."
    exit 1
  fi
done
echo ">>> sample artifacts present"

# ── Scoring contrast: the clean skill must beat the broken one ──
# Real-mode (no REVIEW_SKILLS_DRY_RUN): the bad skill fails the
# structural gate while the good one passes, so good > bad even
# before the scoring tools weigh in.
good=$(review-skills audit --json samples/good-skill | jq -r '.overall')
bad=$(review-skills audit --json samples/bad-skill | jq -r '.overall')
if [ "$good" -le "$bad" ]; then
  echo "Error: expected good > bad (good=$good bad=$bad)"
  exit 1
fi
echo ">>> demo scores: good=$good bad=$bad (good > bad)"

# ── Agent is detected as an agent ───────────────────────────
kind=$(review-skills audit --json samples/good-agent.md | jq -r '.identity.kind')
if [ "$kind" != "agent" ]; then
  echo "Error: expected agent kind, got '$kind'"
  exit 1
fi
echo ">>> good-agent detected as: $kind"

# ── Agent sample is genuinely clean ─────────────────────────
# It must pass the deterministic lint gate (exit 0) and audit to a
# stable score (overall >= 80) so the README's "clean agent" claim
# holds against the real claudelint/agnix/cclint ensemble.
if ! review-skills lint --kind agent samples/good-agent.md >/dev/null 2>&1; then
  echo "Error: good-agent failed lint gate (expected pass)"
  exit 1
fi
echo ">>> good-agent passes lint gate"

agent_audit=$(review-skills audit --json --kind agent samples/good-agent.md)
agent_overall=$(echo "$agent_audit" | jq -r '.overall')
agent_status=$(echo "$agent_audit" | jq -r '.status')
if [ "$agent_status" != "stable" ] || [ "$agent_overall" -lt 80 ]; then
  echo "Error: expected good-agent stable (>=80), got $agent_overall ($agent_status)"
  exit 1
fi
echo ">>> good-agent audits stable: $agent_overall ($agent_status)"

echo ">>> review-skills-demo environment is working"
