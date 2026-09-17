#!/usr/bin/env bash

set -eo pipefail

if ! command -v omlx >/dev/null 2>&1; then
  echo "Error: 'omlx' command not found."
  exit 1
fi
echo ">>> omlx command present"

# Confirm the CLI is wired up (no --version flag exists; --help works).
if ! omlx --help >/dev/null 2>&1; then
  echo "Error: 'omlx --help' failed."
  exit 1
fi
echo ">>> omlx --help ... OK"

if ! omlx serve --help >/dev/null 2>&1; then
  echo "Error: 'omlx serve --help' failed."
  exit 1
fi
echo ">>> omlx serve --help ... OK"

if ! python3 -c "import omlx" 2>/dev/null; then
  echo "Error: failed to 'import omlx'"
  exit 1
fi
echo ">>> import omlx ... OK"

# webrtcvad and the mlx-audio modules that import it unguarded at
# module level: a nix build proves installation, not importability
# (.github/AGENTS.md), so check the actual import here, outside the
# sandbox, where Metal is also reachable.
if ! python3 -c "import webrtcvad" 2>/dev/null; then
  echo "Error: failed to 'import webrtcvad'"
  exit 1
fi
echo ">>> import webrtcvad ... OK"

if ! python3 -c "import mlx_audio.server" 2>/dev/null; then
  echo "Error: failed to 'import mlx_audio.server'"
  exit 1
fi
echo ">>> import mlx_audio.server ... OK"

if ! python3 -c "import mlx_audio.sts.voice_pipeline" 2>/dev/null; then
  echo "Error: failed to 'import mlx_audio.sts.voice_pipeline'"
  exit 1
fi
echo ">>> import mlx_audio.sts.voice_pipeline ... OK"

echo ">>> omlx environment is working"
