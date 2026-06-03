# Source from your env's [profile.zsh]:
#   source "$FLOX_ENV/libexec/sfw-shims/activate.zsh"
# Use logical path (no :A symlink resolution) so this matches the
# $FLOX_ENV/libexec/... form a consumer's PATH actually has.
_sfw_shim_dir="$(cd "${${(%):-%N}:h}" && pwd)"
case ":$PATH:" in
  *":$_sfw_shim_dir:"*) ;;
  *) export PATH="$_sfw_shim_dir:$PATH" ;;
esac
_sfw_ensure_shim_path() {
  case ":$PATH:" in
    "$_sfw_shim_dir:"*) return ;;
  esac
  local cleaned=":$PATH:"
  cleaned="${cleaned//:$_sfw_shim_dir:/:}"
  cleaned="${cleaned#:}"; cleaned="${cleaned%:}"
  export PATH="$_sfw_shim_dir:$cleaned"
}
autoload -Uz add-zsh-hook 2>/dev/null
if (( $+functions[add-zsh-hook] )); then
  add-zsh-hook precmd _sfw_ensure_shim_path
fi
