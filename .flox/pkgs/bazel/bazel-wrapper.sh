#!@bash@
set -e

export PATH="@runtimeDeps@:$PATH"
export BAZEL_SH="${BAZEL_SH:-@bash@}"

launcher="@out@/libexec/bazel/bazel-launcher"

# Top-level pseudo-commands don't start the server and reject startup
# options like --install_base, so forward them untouched.
case "${1:-}" in
  --version|--help|-h)
    exec "$launcher" "$@"
    ;;
esac

# @out@/share/bazel/install holds the patchelf'd install tree baked at
# Nix build time. Bazel needs to write a lock file inside install_base,
# so we can't point at the read-only store path directly. Clone it
# into a writable per-user cache on first run; keyed by the store hash
# so different Bazel versions don't collide.
cache_root="${XDG_CACHE_HOME:-$HOME/.cache}/bazel-flox"
install_base="$cache_root/install/$(basename "@out@")"

if [ ! -d "$install_base" ]; then
  mkdir -p "$cache_root/install"
  staging="$cache_root/install/.tmp.$$"
  cp -rL "@out@/share/bazel/install" "$staging"
  chmod -R u+w "$staging"
  # Atomic rename — first loser loses, subsequent runs see the winner.
  if ! mv "$staging" "$install_base" 2>/dev/null; then
    rm -rf "$staging"
  fi
fi

exec "$launcher" "--install_base=$install_base" "$@"
