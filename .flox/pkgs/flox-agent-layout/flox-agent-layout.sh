#!/usr/bin/env bash
# flox-agent-layout --plugin <name> --share <out/share>
#
# Derives the per-agent launch layout <share>/flox/<agent>/<plugin> from a
# package's already-installed <share>/claude-code content, using relative
# symlinks so nothing is duplicated and the tree is store-relocatable. Run
# at package build time, after the package has populated share/claude-code.
#
# Two source shapes are handled:
#   - plugin-shaped: <share>/claude-code/plugins/<plugin>/ (a full Claude
#     plugin with skills/ and agents/);
#   - flat-skills:   <share>/claude-code/skills/*/SKILL.md (no plugin dir).
#
# Per agent it emits:
#   claude/<plugin>     -> the whole plugin (plugin-shaped), or a synthesized
#                          plugin (manifest + skills symlinks) for flat-skills
#   codex/<plugin>/<s>  -> each skill dir
#   pi/<plugin>/<s>     -> each skill dir
#   opencode/<plugin>/skills/<s> -> each skill dir
# Rules (<share>/claude-code/rules/*.md) are linked under
#   common/<plugin>/rules/ for the launch-time merge.
set -euo pipefail

plugin=""
share=""
while [ $# -gt 0 ]; do
  case "$1" in
    --plugin) plugin="$2"; shift 2 ;;
    --share)  share="$2";  shift 2 ;;
    *) echo "flox-agent-layout: unknown arg $1" >&2; exit 2 ;;
  esac
done
[ -n "$plugin" ] || { echo "flox-agent-layout: --plugin required" >&2; exit 2; }
[ -n "$share" ]  || { echo "flox-agent-layout: --share required" >&2; exit 2; }

cc="$share/claude-code"
flox="$share/flox"
[ -d "$cc" ] || { echo "flox-agent-layout: $cc not found" >&2; exit 2; }

# mklink <linkpath> <target-abs>: create a relative symlink at linkpath
# pointing at target, creating parent dirs.
mklink() {
  local lp="$1" tgt="$2" dir rel
  dir="$(dirname "$lp")"
  mkdir -p "$dir"
  rel="$(realpath -m --relative-to="$dir" "$tgt")"
  ln -sfn "$rel" "$lp"
}

pdir="$cc/plugins/$plugin"
if [ -d "$pdir" ]; then
  # plugin-shaped: claude gets the whole valid plugin; skills live under it.
  mklink "$flox/claude/$plugin" "$pdir"
  skillsrc="$pdir/skills"
else
  # flat-skills: synthesize a Claude plugin from <cc>/skills.
  skillsrc="$cc/skills"
  cdir="$flox/claude/$plugin"
  mkdir -p "$cdir/.claude-plugin"
  printf '{"name":"%s","description":"Flox-managed: %s"}\n' "$plugin" "$plugin" \
    > "$cdir/.claude-plugin/plugin.json"
  if [ -d "$skillsrc" ]; then
    for s in "$skillsrc"/*/; do
      [ -e "$s" ] || continue
      mklink "$cdir/skills/$(basename "$s")" "$skillsrc/$(basename "$s")"
    done
  fi
fi

# codex + pi (bare skill roots) and opencode (skills/ subdir).
if [ -d "$skillsrc" ]; then
  for s in "$skillsrc"/*/; do
    [ -e "$s" ] || continue
    n="$(basename "$s")"
    mklink "$flox/codex/$plugin/$n" "$skillsrc/$n"
    mklink "$flox/pi/$plugin/$n" "$skillsrc/$n"
    mklink "$flox/opencode/$plugin/skills/$n" "$skillsrc/$n"
  done
fi

# rules: link flat claude-code rules under common/<plugin>/rules.
if [ -d "$cc/rules" ]; then
  for r in "$cc/rules"/*.md; do
    [ -e "$r" ] || continue
    mklink "$flox/common/$plugin/rules/$(basename "$r")" "$cc/rules/$(basename "$r")"
  done
fi
