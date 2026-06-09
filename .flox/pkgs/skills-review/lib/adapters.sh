#!/usr/bin/env bash
# Adapters: turn each tool's machine output into score / err+warn / severity.
#
# Real tool output contracts (verified against the built binaries):
#   skill-tools     score -f json            -> top-level .score (0-100)
#   skill-validator check -o json            -> top-level .errors / .warnings
#   claudelint      check-all --format json  -> top-level .errorCount / .warningCount
#   cclint          --format json            -> top-level .totalErrors / .totalWarnings
#   agnix           --format json            -> nested  .summary.errors / .summary.warnings
#   skillcheck      --format sarif           -> SARIF; result.level only, the
#       CRITICAL/HIGH/MEDIUM/LOW split is recovered from the matching rule's
#       properties["security-severity"] (9.0/7.0/5.0/3.0).

# skill-tools native quality score.
adapt_skill_tools() { jq -r '.score // 0' "$1"; }

# Echo "<errors> <warnings>" from a JSON file using the given jq paths.
adapt_errwarn_json() {
  local file="$1" errq="$2" warnq="$3"
  local e w
  e=$(jq -r "(${errq}) // 0" "$file" 2>/dev/null || echo 0)
  w=$(jq -r "(${warnq}) // 0" "$file" 2>/dev/null || echo 0)
  echo "${e:-0} ${w:-0}"
}

# Highest SARIF severity across results: CRITICAL>HIGH>MEDIUM>LOW>none.
# Severity is derived by joining each result's ruleId to the matching
# rule's "security-severity" (skillcheck emits 9.0/7.0/5.0/3.0). If a
# rule has no security-severity, fall back to the SARIF level.
adapt_sarif_severity() {
  local file="$1"
  jq -r '
    . as $doc
    # Build a ruleId -> numeric security-severity map from rule defs.
    | ( [ $doc.runs[]?.tool.driver.rules[]?
          | { (.id): (.properties["security-severity"] // empty | tonumber) } ]
        | add // {} ) as $sevmap
    | [ $doc.runs[]?.results[]?
        | ($sevmap[.ruleId] // null) as $num
        | if $num != null then
            (if   $num >= 9 then "CRITICAL"
             elif $num >= 7 then "HIGH"
             elif $num >= 5 then "MEDIUM"
             else "LOW" end)
          else
            # No security-severity on the rule: map from the SARIF level.
            (if   (.level == "error")   then "HIGH"
             elif (.level == "warning") then "MEDIUM"
             elif (.level == "note")    then "LOW"
             else "LOW" end)
          end ] as $sevs
    | (["CRITICAL","HIGH","MEDIUM","LOW"]
        | map(select(. as $x | $sevs | index($x)))
        | .[0]) // "none"
  ' "$file"
}
