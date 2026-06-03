#!/usr/bin/env bash

set -eo pipefail

if ! command -v sfw >/dev/null 2>&1; then
  echo "Error: 'sfw' command not found."
  exit 1
fi
echo ">>> sfw version: $(sfw --version)"

# The package ships PATH shims; the hook prepends their dir to PATH.
shim_dir="$FLOX_ENV/libexec/sfw-shims"
if [ ! -x "$shim_dir/sfw-shim" ]; then
  echo "Error: sfw shim not found at $shim_dir/sfw-shim"
  exit 1
fi

case ":$PATH:" in
  *":$shim_dir:"*) ;;
  *)
    echo "Error: shim dir not on PATH: $shim_dir"
    exit 1
    ;;
esac
echo ">>> sfw shim dir is on PATH"

# Each supported package manager resolves to the shim, so a plain
# `npm`/`pip`/`cargo` call routes through sfw transparently.
for cmd in npm yarn pnpm pip uv cargo; do
  if [ ! -L "$shim_dir/$cmd" ]; then
    echo "Error: missing shim for '$cmd'"
    exit 1
  fi
done
echo ">>> shims present: npm yarn pnpm pip uv cargo"

echo ">>> sfw environment is working"
