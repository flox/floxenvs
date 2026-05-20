#!/usr/bin/env bash
# Convert `trivy image --format json` output (on stdin)
# to the canonical finding shape. Trivy already speaks
# CRITICAL/HIGH/MEDIUM/LOW so the severity map is direct.
set -euo pipefail

jq -c '
  [
    (.Results // [])[]?
    | .Target as $target
    | (.Vulnerabilities // [])[]?
    | {
        scanner: "trivy",
        severity: .Severity,
        id: .VulnerabilityID,
        path: $target,
        line: 0,
        message: (
          .PkgName + " " + (.InstalledVersion // "?")
            + " — " + (.Title // .Description // "")
        )
      }
  ]
'
