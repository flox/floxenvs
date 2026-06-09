#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "$0")/.." && pwd)"
. "$DIR/lib/adapters.sh"
F="$DIR/test/fixtures"

# skill-tools: native quality score lives at top-level .score
[ "$(adapt_skill_tools "$F/skill-tools.json")" = "61" ] \
  || { echo "FAIL skill-tools"; exit 1; }

# adapt_errwarn_json <file> <err-jq> <warn-jq> -> "<err> <warn>"
# skill-validator check -o json: top-level .errors / .warnings (integers)
read -r e w < <(adapt_errwarn_json "$F/skill-validator.json" '.errors' '.warnings')
[ "$e" = "1" ] && [ "$w" = "0" ] || { echo "FAIL skill-validator ew ($e $w)"; exit 1; }

# claudelint check-all --format json: top-level .errorCount / .warningCount
read -r e w < <(adapt_errwarn_json "$F/claudelint.json" '.errorCount' '.warningCount')
[ "$e" = "1" ] && [ "$w" = "1" ] || { echo "FAIL claudelint ew ($e $w)"; exit 1; }

# cclint --format json: top-level .totalErrors / .totalWarnings
read -r e w < <(adapt_errwarn_json "$F/cclint.json" '.totalErrors' '.totalWarnings')
[ "$e" = "0" ] && [ "$w" = "0" ] || { echo "FAIL cclint ew ($e $w)"; exit 1; }

# agnix --format json: nested .summary.errors / .summary.warnings
read -r e w < <(adapt_errwarn_json "$F/agnix.json" '.summary.errors' '.summary.warnings')
[ "$e" = "0" ] && [ "$w" = "0" ] || { echo "FAIL agnix ew ($e $w)"; exit 1; }

# adapt_sarif_severity <file> -> highest severity token.
# skillcheck SARIF results carry only .level (error/warning/note); the
# CRITICAL/HIGH split lives on the matching rule's security-severity, so
# the adapter joins result.ruleId -> rule.properties["security-severity"].
[ "$(adapt_sarif_severity "$F/skillcheck.sarif")" = "CRITICAL" ] \
  || { echo "FAIL sarif sev (got $(adapt_sarif_severity "$F/skillcheck.sarif"))"; exit 1; }

# A clean scan (no results) -> none.
[ "$(adapt_sarif_severity "$F/skillcheck-clean.sarif")" = "none" ] \
  || { echo "FAIL sarif clean"; exit 1; }

echo "PASS adapters"
