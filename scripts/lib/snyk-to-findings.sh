#!/usr/bin/env bash
# Convert `snyk test --json` output (on stdin) to the
# canonical finding shape. Snyk uses lowercase severity;
# uppercase it for the canonical shape.
set -euo pipefail

jq -c '
  [ (.vulnerabilities // [])[]?
    | {
        scanner: "snyk",
        severity: (.severity | ascii_upcase),
        id: .id,
        path: (.packageName // .from[0] // ""),
        line: 0,
        message: (.title // .name // "")
      }
  ]
'
