# Sourced helper (not a package): defines flox_agent_layout, which derives
# the per-agent launch layout <share>/flox/<agent>/<plugin> from a package's
# already-installed <share>/claude-code content, using relative symlinks so
# nothing is duplicated and the tree is store-relocatable.
#
# Inlined into each package's postInstall via builtins.readFile so there is
# NO separate build-input derivation — the postInstall runs on whatever
# (native) builder builds the package, so cross-system publish works.
#
# Usage in a package's postInstall:
#   ${builtins.readFile ../../nix/flox-agent-layout.sh}
#   flox_agent_layout "<plugin-name>" "$out/share"
#
# Two source shapes are handled:
#   - plugin-shaped: <share>/claude-code/plugins/<plugin>/ (a full Claude plugin)
#   - flat-skills:   <share>/claude-code/skills/*/SKILL.md (no plugin dir)
flox_agent_layout() {
  local plugin="$1" share="$2"
  [ -n "$plugin" ] || { echo "flox_agent_layout: plugin name required" >&2; return 2; }
  [ -n "$share" ] || { echo "flox_agent_layout: share dir required" >&2; return 2; }

  local cc="$share/claude-code"
  local flox="$share/flox"
  [ -d "$cc" ] || { echo "flox_agent_layout: $cc not found" >&2; return 2; }

  # create a relative symlink at $1 pointing at $2 (absolute), making parents
  _fal_link() {
    local lp="$1" tgt="$2" dir rel
    dir="$(dirname "$lp")"
    mkdir -p "$dir"
    rel="$(realpath -m --relative-to="$dir" "$tgt")"
    ln -sfn "$rel" "$lp"
  }

  local pdir="$cc/plugins/$plugin" skillsrc
  if [ -d "$pdir" ]; then
    # plugin-shaped: claude gets the whole valid plugin; skills live under it.
    _fal_link "$flox/claude/$plugin" "$pdir"
    skillsrc="$pdir/skills"
  else
    # flat-skills: synthesize a Claude plugin from <cc>/skills.
    skillsrc="$cc/skills"
    local cdir="$flox/claude/$plugin"
    mkdir -p "$cdir/.claude-plugin"
    printf '{"name":"%s","description":"Flox-managed: %s"}\n' "$plugin" "$plugin" \
      > "$cdir/.claude-plugin/plugin.json"
    if [ -d "$skillsrc" ]; then
      local s
      for s in "$skillsrc"/*/; do
        [ -e "$s" ] || continue
        _fal_link "$cdir/skills/$(basename "$s")" "$skillsrc/$(basename "$s")"
      done
    fi
  fi

  # codex + pi (bare skill roots) and opencode (skills/ subdir).
  if [ -d "$skillsrc" ]; then
    local s n
    for s in "$skillsrc"/*/; do
      [ -e "$s" ] || continue
      n="$(basename "$s")"
      _fal_link "$flox/codex/$plugin/$n" "$skillsrc/$n"
      _fal_link "$flox/pi/$plugin/$n" "$skillsrc/$n"
      _fal_link "$flox/opencode/$plugin/skills/$n" "$skillsrc/$n"
    done
  fi

  # rules: link flat claude-code rules under common/<plugin>/rules.
  if [ -d "$cc/rules" ]; then
    local r
    for r in "$cc/rules"/*.md; do
      [ -e "$r" ] || continue
      _fal_link "$flox/common/$plugin/rules/$(basename "$r")" "$cc/rules/$(basename "$r")"
    done
  fi
}
