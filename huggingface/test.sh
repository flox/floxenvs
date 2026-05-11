#!/usr/bin/env bash

set -eo pipefail

command_exists() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Error: '$1' command not found."
    return 1
  fi
  echo ">>> '$1' command exists"
}

# ── Required commands ─────────────────────────────────
command_exists hf
command_exists huggingface-cli
command_exists tiny-agents

echo ">>> hf version: $(hf version)"

# ── Cache directory ───────────────────────────────────
if [ -z "${HF_HOME:-}" ]; then
  echo "Error: HF_HOME not set."
  exit 1
fi
echo ">>> HF_HOME=$HF_HOME"

if [ ! -d "$HF_HOME" ]; then
  echo "Error: HF_HOME directory does not exist: $HF_HOME"
  exit 1
fi
echo ">>> HF_HOME directory exists"

# ── Hub query (offline-safe metadata check) ───────────
echo ">>> querying hub for a small public model..."
hf download hf-internal-testing/tiny-random-gpt2 \
  config.json --quiet
echo ">>> downloaded config.json from tiny-random-gpt2"

echo ">>> huggingface environment is working"
