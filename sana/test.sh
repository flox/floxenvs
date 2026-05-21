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
command_exists sana-generate
command_exists sana-pull
command_exists hf
command_exists python

# ── Environment variables ─────────────────────────────
if [ -z "${HF_HOME:-}" ]; then
  echo "Error: HF_HOME not set."
  exit 1
fi
echo ">>> HF_HOME=$HF_HOME"

if [ -z "${SANA_DATA_DIR:-}" ]; then
  echo "Error: SANA_DATA_DIR not set."
  exit 1
fi
echo ">>> SANA_DATA_DIR=$SANA_DATA_DIR"

if [ -z "${SANA_DEFAULT_MODEL:-}" ]; then
  echo "Error: SANA_DEFAULT_MODEL not set."
  exit 1
fi
echo ">>> SANA_DEFAULT_MODEL=$SANA_DEFAULT_MODEL"

# ── CLI surface checks ────────────────────────────────
echo ">>> sana-generate --help"
sana-generate --help >/dev/null

echo ">>> sana-pull --help"
sana-pull --help >/dev/null

echo ">>> sana-pull --list"
sana-pull --list

# ── Python import check ───────────────────────────────
echo ">>> python: importing SanaPipeline"
python -c "from diffusers import SanaPipeline; print('SanaPipeline ok')"

echo ">>> python: device selector"
python -c "
import sys
sys.path.insert(0, '$SANA_DATA_DIR/bin')
from _sana_device import best_device
d, dt = best_device()
print(f'device={d} dtype={dt}')
"

echo ">>> sana environment is working"
