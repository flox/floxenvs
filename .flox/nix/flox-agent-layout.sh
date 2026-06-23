# Sourced helper (not a package): defines flox_agent_layout, which builds the
# per-agent launch layout <share>/flox/<agent>/<plugin> from a package's staged
# <share>/claude-code content, then REMOVES <share>/claude-code so the only
# fragment layout shipped is <share>/flox. Content is COPIED (not symlinked)
# so the result is self-contained after claude-code is deleted.
#
# Inlined into each package's postInstall via builtins.readFile (no separate
# build-input derivation), so postInstall runs on the native builder and
# cross-system publish works.
#
# Usage in a package's postInstall:
#   ${builtins.readFile ../../nix/flox-agent-layout.sh}
#   flox_agent_layout "<plugin-name>" "$out/share"
#
# Two staged source shapes are handled:
#   - plugin-shaped: <share>/claude-code/plugins/<plugin>/ (a full plugin)
#   - flat-skills:   <share>/claude-code/skills/*/SKILL.md (no plugin dir)
flox_agent_layout() {
  local plugin="$1" share="$2"
  [ -n "$plugin" ] || { echo "flox_agent_layout: plugin name required" >&2; return 2; }
  [ -n "$share" ] || { echo "flox_agent_layout: share dir required" >&2; return 2; }

  local cc="$share/claude-code"
  local flox="$share/flox"
  [ -d "$cc" ] || { echo "flox_agent_layout: $cc not found" >&2; return 2; }

  # copy $2 (dir or file) to $1, making parent dirs. Preserves symlinks.
  _fal_copy() {
    local dst="$1" src="$2"
    mkdir -p "$(dirname "$dst")"
    cp -R "$src" "$dst"
  }

  # like _fal_copy but DEREFERENCES symlinks (cp -RL): some plugins expose
  # skills/<n> as relative symlinks to sibling dirs, so the per-agent skill
  # copies must materialize the real content or they end up dangling.
  _fal_copyL() {
    local dst="$1" src="$2"
    mkdir -p "$(dirname "$dst")"
    cp -RL "$src" "$dst"
  }

  local pdir="$cc/plugins/$plugin" skillsrc cdir="$flox/claude/$plugin"
  if [ -d "$pdir" ]; then
    # plugin-shaped: claude gets the whole valid plugin (copied).
    _fal_copy "$cdir" "$pdir"
    skillsrc="$cdir/skills"            # read skills from the COPY, not cc
  else
    # flat-skills: synthesize a Claude plugin from <cc>/skills.
    mkdir -p "$cdir/.claude-plugin"
    printf '{"name":"%s","description":"Flox-managed: %s"}\n' "$plugin" "$plugin" \
      > "$cdir/.claude-plugin/plugin.json"
    if [ -d "$cc/skills" ]; then
      local s
      for s in "$cc/skills"/*/; do
        [ -e "$s" ] || continue
        _fal_copy "$cdir/skills/$(basename "$s")" "$cc/skills/$(basename "$s")"
      done
    fi
    skillsrc="$cdir/skills"
  fi

  # codex + pi (bare skill roots) and opencode (skills/ subdir), from the COPY.
  if [ -d "$skillsrc" ]; then
    local s n
    for s in "$skillsrc"/*/; do
      [ -e "$s" ] || continue
      n="$(basename "$s")"
      _fal_copyL "$flox/codex/$plugin/$n" "$skillsrc/$n"
      _fal_copyL "$flox/pi/$plugin/$n" "$skillsrc/$n"
      _fal_copyL "$flox/opencode/$plugin/skills/$n" "$skillsrc/$n"
    done
  fi

  # rules: copy flat claude-code rules under common/<plugin>/rules.
  if [ -d "$cc/rules" ]; then
    local r
    for r in "$cc/rules"/*.md; do
      [ -e "$r" ] || continue
      _fal_copy "$flox/common/$plugin/rules/$(basename "$r")" "$cc/rules/$(basename "$r")"
    done
  fi

  # Remove THIS plugin's consumed claude-code staging (flox already built).
  if [ -d "$pdir" ]; then
    chmod -R u+w "$pdir" 2>/dev/null || true
    rm -rf "$pdir"
  elif [ -d "$cc/skills" ]; then
    chmod -R u+w "$cc/skills" 2>/dev/null || true
    rm -rf "$cc/skills"
  fi

  # Ship ONLY share/flox: drop the claude-code staging AND any other native
  # per-agent layout the package installed (e.g. share/opencode). Under
  # launch-only, agents get skills via flox-ai launch (which reads share/flox),
  # so the old auto-discovery trees must not ship.
  #
  # Multi-plugin packages call flox_agent_layout in a LOOP (once per plugin),
  # so only run this final sweep once the claude-code staging is DRAINED — no
  # staged plugins and no staged skills left — otherwise the next iteration
  # would find no claude-code. Read-only skill dirs (references/) need u+w
  # before rm.
  if [ -z "$(ls -A "$cc/plugins" 2>/dev/null)" ] && [ ! -d "$cc/skills" ]; then
    local entry
    for entry in "$share"/*; do
      [ -e "$entry" ] || continue
      [ "$(basename "$entry")" = "flox" ] && continue
      chmod -R u+w "$entry" 2>/dev/null || true
      rm -rf "$entry"
    done
  fi
}
