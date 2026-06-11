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
command_exists review-skills

# ── The scoring tools the runner calls (quality + security) ──
command_exists skill-tools
command_exists claudelint
command_exists cclint
command_exists skill-validator
command_exists agnix
command_exists skillcheck
command_exists skillspector

# ── Optional behavioral stage ─────────────────────────
command_exists promptfoo

# ── Runner smoke ──────────────────────────────────────
# The Go runner prints its semver on `version`.
echo ">>> review-skills version: $(review-skills version 2>&1 | head -1 || true)"

echo ">>> review-skills environment is working"
