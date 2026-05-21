#!/usr/bin/env bash

set -eo pipefail

command_exists() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Error: '$1' command not found."
    return 1
  fi
  echo ">>> '$1' command exists"
}

# ── Required commands (incl. those from include) ──────
command_exists sana-generate
command_exists sana-pull
command_exists hf
command_exists python
command_exists gum
command_exists sana-gradio

echo ">>> gum version: $(gum --version)"

# ── Configuration variables ───────────────────────────
if [ -z "${SANA_GRADIO_HOST:-}" ]; then
  echo "Error: SANA_GRADIO_HOST not set."
  exit 1
fi
echo ">>> SANA_GRADIO_HOST=$SANA_GRADIO_HOST"

if [ -z "${SANA_GRADIO_PORT:-}" ]; then
  echo "Error: SANA_GRADIO_PORT not set."
  exit 1
fi
echo ">>> SANA_GRADIO_PORT=$SANA_GRADIO_PORT"

# ── Gradio import ─────────────────────────────────────
echo ">>> python: importing gradio"
python -c "import gradio; print('gradio', gradio.__version__)"

# ── Service start in skip-load mode ───────────────────
echo ">>> starting sana-gradio service in SKIP_LOAD mode"
export SANA_SKIP_LOAD=1

flox services start sana-gradio
trap 'flox services stop sana-gradio 2>/dev/null || true' EXIT

# Wait up to 30s for the port to bind
bound=0
for i in $(seq 1 30); do
  if curl -fsS \
      "http://${SANA_GRADIO_HOST}:${SANA_GRADIO_PORT}/" \
      >/dev/null 2>&1; then
    bound=1
    break
  fi
  sleep 1
done

if [ "$bound" -ne 1 ]; then
  echo "Error: sana-gradio did not bind within 30s"
  exit 1
fi
echo ">>> sana-gradio bound on port $SANA_GRADIO_PORT"

# Stop cleanly
flox services stop sana-gradio
trap - EXIT
echo ">>> sana-gradio stopped cleanly"

# ── Sample prompt exists ──────────────────────────────
test -f sample_prompt.txt
echo ">>> sample_prompt.txt exists"

echo ">>> sana-demo environment is working"
