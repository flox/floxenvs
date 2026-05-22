#!/usr/bin/env bash
#
# Runs once after the devcontainer is built.
# - Symlinks the nix glibc loader + libs at FHS paths so
#   VS Code Remote Server's glibc-linked node can exec on
#   the Nix-only flox image.
# - Pre-resolves and downloads the env's packages so the
#   first VS Code shell doesn't sit on a cold nix pull.
# - Adds an auto-activate snippet to /root/.bashrc so VS
#   Code terminals inherit the env vars.
#
set -euo pipefail

ENV_DIR="${1:?usage: post-create.sh <env-dir>}"
WS_ENV="/workspaces/floxenvs/$ENV_DIR"

# Codespaces clones repos as root with non-root file
# ownership in some setups. Mark the workspace safe.
git config --global --add safe.directory \
  /workspaces/floxenvs

# VS Code Remote Server ships a prebuilt, glibc-linked
# node. The flox image is Nix-only (no /lib64, no FHS
# libs), so the ELF interpreter lookup fails and the
# workbench reports "failed to start vs code remote
# server". Point the canonical loader + libc paths at
# nix glibc / gcc-lib so it can exec.
case "$(uname -m)" in
  x86_64)  LDR=ld-linux-x86-64.so.2 ; LDR_DIR=/lib64 ;;
  aarch64) LDR=ld-linux-aarch64.so.1 ; LDR_DIR=/lib  ;;
  *)       LDR= ; LDR_DIR= ;;
esac
NIX_GLIBC=
for c in /nix/store/*-glibc-2*; do
  case "$c" in *-bin|*-dev|*-debug|*-static) continue;; esac
  [ -e "$c/lib/$LDR" ] || continue
  NIX_GLIBC="$c/lib"
  break
done
NIX_GCC=
for c in /nix/store/*-gcc-*-lib*/lib; do
  [ -e "$c/libstdc++.so.6" ] || continue
  NIX_GCC="$c"
  break
done
if [ -n "$LDR" ] && [ -n "$NIX_GLIBC" ]; then
  mkdir -p "$LDR_DIR" /lib /usr/lib
  ln -sf "$NIX_GLIBC/$LDR" "$LDR_DIR/$LDR"
  for lib in libc.so.6 libdl.so.2 libpthread.so.0 \
             librt.so.1 libm.so.6 libresolv.so.2 \
             libutil.so.1 libnsl.so.1; do
    [ -e "$NIX_GLIBC/$lib" ] || continue
    ln -sf "$NIX_GLIBC/$lib" "/lib/$lib"
    ln -sf "$NIX_GLIBC/$lib" "/usr/lib/$lib"
  done
  if [ -n "$NIX_GCC" ]; then
    for lib in libstdc++.so.6 libgcc_s.so.1; do
      [ -e "$NIX_GCC/$lib" ] || continue
      ln -sf "$NIX_GCC/$lib" "/lib/$lib"
      ln -sf "$NIX_GCC/$lib" "/usr/lib/$lib"
    done
  fi
fi

# Pre-resolve. The `-- true` form runs activation hooks
# and exits — perfect for warm-up.
flox activate -d "$WS_ENV" -- true

# Auto-activate in every new bash shell.
cat >> /root/.bashrc <<EOF

# Added by floxenvs devcontainer post-create.sh
if [ -z "\${FLOX_ENV:-}" ] && [ -d "$WS_ENV/.flox" ]; then
  eval "\$(flox activate -d "$WS_ENV" \\
    --print-script 2>/dev/null || true)"
fi
EOF

echo "post-create.sh done for $ENV_DIR"
