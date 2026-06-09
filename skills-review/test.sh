#!/usr/bin/env bash

set -eo pipefail

command_exists() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Error: '$1' command not found."
    return 1
  fi
  echo ">>> '$1' command exists"
}

# ── The runner ────────────────────────────────────────
command_exists skills-review

# ── The six scoring tools the runner calls ────────────
command_exists skill-tools
command_exists claudelint
command_exists cclint
command_exists skill-validator
command_exists agnix
command_exists skillcheck

# ── Optional behavioral stage ─────────────────────────
command_exists promptfoo

# ── Runner usage ──────────────────────────────────────
# The runner has no --help; a no-arg call prints its usage
# line and exits nonzero, so capture it without failing.
echo ">>> skills-review usage: $(skills-review 2>&1 | grep -o 'usage:.*' | head -1 || true)"

echo ">>> skills-review environment is working"
