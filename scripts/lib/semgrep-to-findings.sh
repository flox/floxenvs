#!/usr/bin/env bash
# Convert semgrep --json output (on stdin) to the
# canonical finding shape used by the audit pipeline.
# Plan B's run-audit.sh expects each scanner to emit a
# JSON array of {scanner, severity, id, path, line,
# message} objects. Severity is mapped from semgrep's
# ERROR/WARNING/INFO to the spec's CRITICAL/HIGH/MEDIUM.
set -euo pipefail

jq -c '
  [ .results[]?
    | {
        scanner: "semgrep",
        severity: (
          if .extra.severity == "ERROR" then "CRITICAL"
          elif .extra.severity == "WARNING" then "HIGH"
          elif .extra.severity == "INFO" then "MEDIUM"
          else "LOW"
          end
        ),
        id: (.check_id | sub(".*\\."; "")),
        path: .path,
        line: .start.line,
        message: .extra.message
      }
  ]
'
