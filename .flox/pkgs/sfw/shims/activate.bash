# Source from your env's [profile.bash]:
#   source "$FLOX_ENV/libexec/sfw-shims/activate.bash"
_sfw_shim_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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
case ";${PROMPT_COMMAND:-};" in
  *";_sfw_ensure_shim_path;"*) ;;
  *) PROMPT_COMMAND="_sfw_ensure_shim_path;${PROMPT_COMMAND:-}" ;;
esac
