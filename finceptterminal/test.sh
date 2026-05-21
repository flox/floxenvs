#!/usr/bin/env bash
set -eo pipefail

# Verify the binary is on PATH.
if ! command -v finceptterminal >/dev/null 2>&1; then
  echo "Error: 'finceptterminal' command not found."
  exit 1
fi
echo ">>> finceptterminal present"

# Verify the install-dir sentinel is reachable.
# The wrapper sets FINCEPT_INSTALL_DIR to the in-store path; we
# derive the same path here defensively in case the wrapper is
# inactive during direct test invocation.
if [ -z "${FINCEPT_INSTALL_DIR:-}" ]; then
  bin_real=$(realpath "$(command -v finceptterminal)")
  FINCEPT_INSTALL_DIR="$(dirname "$bin_real")/../share/finceptterminal/install-dir"
fi
if [ ! -e "$FINCEPT_INSTALL_DIR/.fincept-nix-managed" ]; then
  echo "Error: \$FINCEPT_INSTALL_DIR/.fincept-nix-managed missing — patches did not fire."
  echo "  expected at: $FINCEPT_INSTALL_DIR/.fincept-nix-managed"
  exit 1
fi
echo ">>> install-dir sentinel present"

# Verify the Nix-derived venv has the expected Python modules.
PY="$FINCEPT_INSTALL_DIR/venv-numpy2/bin/python3"
if [ ! -x "$PY" ]; then
  echo "Error: venv-numpy2 python missing at $PY"
  exit 1
fi
"$PY" -c "import numpy, pandas, yfinance, ccxt; print('imports OK')"
echo ">>> Python env importable"

# Headless boot smoke test. We launch with offscreen QPA, give it
# a few seconds, and look for the absence of UV-download log
# messages — if patch 0002 fires, PythonSetupManager skips UV.
LOG=$(mktemp)
QT_QPA_PLATFORM=offscreen \
  timeout --preserve-status -s TERM 8 \
  finceptterminal 2>&1 | head -200 > "$LOG" || true

if grep -qE "Downloading UV|Installing Python via uv" "$LOG"; then
  echo "Error: PythonSetupManager attempted UV bootstrap; patch 0002 not firing."
  cat "$LOG"
  exit 1
fi
echo ">>> PythonSetupManager bypass confirmed"

echo ">>> finceptterminal environment is working"
