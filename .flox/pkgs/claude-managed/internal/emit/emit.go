package emit

import (
	"fmt"
	"path/filepath"
	"strings"

	"flox.dev/claude-managed/internal/discover"
)

// Params holds everything needed to emit shell code.
type Params struct {
	Frags     *discover.Result
	ShareDir  string // $FLOX_ENV/share/claude-code
	ConfigDir string // absolute path for CLAUDE_CONFIG_DIR
}

// HookCode emits shell for on-activate: env vars, functions,
// keychain bridge, symlinks. Side effects persist because
// on-activate eval runs in the hook context.
func HookCode(p *Params) string {
	var sb strings.Builder

	fmt.Fprintf(&sb, "export CLAUDE_CONFIG_DIR=%q\n", p.ConfigDir)
	sb.WriteString("export CLAUDE_CODE_DISABLE_AUTO_MEMORY=1\n")
	sb.WriteString("export CLAUDE_MANAGED=1\n")

	emitHelpers(&sb, p)
	emitKeychainBridge(&sb)
	emitSymlinks(&sb, p)
	emitCleanupFunc(&sb, p)

	return sb.String()
}

// ProfileCode emits shell for profile: cleanup function + trap.
// EXIT traps must not be in on-activate (they fire when
// the hook subshell exits, not when the user's shell exits).
// Function definitions also don't survive, so we emit them here.
func ProfileCode(p *Params) string {
	var sb strings.Builder
	emitHelpers(&sb, p)
	emitCleanupFunc(&sb, p)
	emitClaudeWrapper(&sb, p)
	sb.WriteString("trap _claude_managed_cleanup EXIT\n")
	return sb.String()
}

func emitClaudeWrapper(sb *strings.Builder, p *Params) {
	// no-op in profile — wrapper is created in hook via
	// emitPluginWrapper (filesystem side effect persists)
}

func emitHelpers(sb *strings.Builder, p *Params) {
	if p.ShareDir == "" {
		return
	}
	sb.WriteString(`
# remove symlinks whose targets point into the flox share dir
_claude_managed_clean_symlinks() {
  local _dir="$CLAUDE_CONFIG_DIR/$1"
  [ -d "$_dir" ] || return 0
  for _link in "$_dir"/*; do
    [ -L "$_link" ] || continue
    _target="$(readlink "$_link")"
    case "$_target" in "$FLOX_ENV/share/claude-code"/*)
      rm -f "$_link" ;;
    esac
  done
}
`)
}

func emitKeychainBridge(sb *strings.Builder) {
	sb.WriteString(`
# bridge keychain credentials for isolated CLAUDE_CONFIG_DIR (macOS only)
if [ "$(uname -s)" = "Darwin" ]; then
  _cm_user="${USER:-claude-code-user}"
  _cm_src_service="Claude Code-credentials"
  _cm_hash="$(printf '%s' "$CLAUDE_CONFIG_DIR" | shasum -a 256 | cut -c1-8)"
  _cm_dst_service="Claude Code-credentials-${_cm_hash}"

  # only bridge if isolated entry doesn't exist yet
  # note: || true guards against set -e in flox hooks
  if ! security find-generic-password -a "$_cm_user" -s "$_cm_dst_service" >/dev/null 2>&1; then
    _cm_plain="$(security find-generic-password -a "$_cm_user" -w -s "$_cm_src_service" 2>/dev/null || true)"
    if [ -n "$_cm_plain" ]; then
      _cm_hex="$(printf '%s' "$_cm_plain" | xxd -p | tr -d '\n')"
      security add-generic-password -U -a "$_cm_user" -s "$_cm_dst_service" -X "$_cm_hex" 2>/dev/null || true
    fi
  fi

  # copy global config for oauthAccount metadata
  mkdir -p "$CLAUDE_CONFIG_DIR"
  if [ -f "$HOME/.claude.json" ] && [ ! -f "$CLAUDE_CONFIG_DIR/.claude.json" ]; then
    cp "$HOME/.claude.json" "$CLAUDE_CONFIG_DIR/.claude.json"
    chmod 600 "$CLAUDE_CONFIG_DIR/.claude.json"
  fi

  unset _cm_user _cm_src_service _cm_hash _cm_dst_service _cm_plain _cm_hex
fi
`)
}

func emitSymlinks(sb *strings.Builder, p *Params) {
	if p.ShareDir == "" {
		return
	}

	// helper to create relative symlinks at shell eval time
	sb.WriteString("\n# relative symlink helper\n")
	sb.WriteString("_cm_rellink() {\n")
	sb.WriteString("  local _target=\"$1\" _link=\"$2\"\n")
	sb.WriteString("  local _linkdir _rel\n")
	sb.WriteString("  _linkdir=\"$(dirname \"$_link\")\"\n")
	sb.WriteString("  _rel=\"$(realpath --relative-to=\"$_linkdir\" \"$_target\" 2>/dev/null)\" || _rel=\"$_target\"\n")
	sb.WriteString("  ln -sfn \"$_rel\" \"$_link\"\n")
	sb.WriteString("}\n")

	sb.WriteString("\n# clean stale symlinks\n")
	for _, sub := range []string{"skills", "rules", "agents"} {
		fmt.Fprintf(sb, "_claude_managed_clean_symlinks %s\n", sub)
	}

	if len(p.Frags.Skills) > 0 {
		sb.WriteString("\n# create skill symlinks\n")
		sb.WriteString("mkdir -p \"$CLAUDE_CONFIG_DIR/skills\"\n")
		for _, f := range p.Frags.Skills {
			fmt.Fprintf(sb, "_cm_rellink \"$FLOX_ENV/share/claude-code/skills/%s\" \"$CLAUDE_CONFIG_DIR/skills/%s\"\n", f.Name, f.Name)
		}
	}

	if len(p.Frags.Rules) > 0 {
		sb.WriteString("\n# create rule symlinks\n")
		sb.WriteString("mkdir -p \"$CLAUDE_CONFIG_DIR/rules\"\n")
		for _, f := range p.Frags.Rules {
			base := filepath.Base(f.Path)
			fmt.Fprintf(sb, "_cm_rellink \"$FLOX_ENV/share/claude-code/rules/%s\" \"$CLAUDE_CONFIG_DIR/rules/%s\"\n", base, base)
		}
	}

	if len(p.Frags.Agents) > 0 {
		sb.WriteString("\n# create agent symlinks\n")
		sb.WriteString("mkdir -p \"$CLAUDE_CONFIG_DIR/agents\"\n")
		for _, f := range p.Frags.Agents {
			base := filepath.Base(f.Path)
			fmt.Fprintf(sb, "_cm_rellink \"$FLOX_ENV/share/claude-code/agents/%s\" \"$CLAUDE_CONFIG_DIR/agents/%s\"\n", base, base)
		}
	}

	if len(p.Frags.Plugins) > 0 {
		sb.WriteString("\n# install plugins\n")
		sb.WriteString("claude-managed plugins clean\n")
		for _, f := range p.Frags.Plugins {
			fmt.Fprintf(sb, "claude-managed plugins add \"$FLOX_ENV/share/claude-code/plugins/%s\"\n", f.Name)
		}

		// create claude wrapper script that injects --plugin-dir
		sb.WriteString("\n# create claude wrapper to load plugins\n")
		sb.WriteString("mkdir -p \"$CLAUDE_CONFIG_DIR/bin\"\n")
		sb.WriteString("_cm_real=\"$(command -v claude)\"\n")
		sb.WriteString("{\n")
		sb.WriteString("  echo '#!/usr/bin/env bash'\n")
		sb.WriteString("  printf 'exec \"%s\"' \"$_cm_real\"\n")
		for _, f := range p.Frags.Plugins {
			fmt.Fprintf(sb, "  printf ' --plugin-dir \"%%s\"' \"$CLAUDE_CONFIG_DIR/plugins/%s\"\n", f.Name)
		}
		sb.WriteString("  printf ' \"$@\"\\n'\n")
		sb.WriteString("} > \"$CLAUDE_CONFIG_DIR/bin/claude\"\n")
		sb.WriteString("chmod +x \"$CLAUDE_CONFIG_DIR/bin/claude\"\n")
		sb.WriteString("export PATH=\"$CLAUDE_CONFIG_DIR/bin:$PATH\"\n")
		sb.WriteString("unset _cm_real\n")
	}
}

func emitCleanupFunc(sb *strings.Builder, p *Params) {
	sb.WriteString(`
# cleanup function (trap registered in profile, not here)
_claude_managed_cleanup() {
`)
	if p.ShareDir != "" {
		for _, sub := range []string{"skills", "rules", "agents"} {
			sb.WriteString("  _claude_managed_clean_symlinks " + sub + "\n")
		}
	}
	sb.WriteString("  claude-managed plugins clean\n")
	sb.WriteString(`  # remove bridged keychain entry (macOS only)
  if [ "$(uname -s)" = "Darwin" ]; then
    _cm_user="${USER:-claude-code-user}"
    _cm_hash="$(printf '%s' "$CLAUDE_CONFIG_DIR" | shasum -a 256 | cut -c1-8)"
    _cm_dst_service="Claude Code-credentials-${_cm_hash}"
    security delete-generic-password -a "$_cm_user" -s "$_cm_dst_service" >/dev/null 2>&1 || true
    rm -f "$CLAUDE_CONFIG_DIR/.claude.json"
    unset _cm_user _cm_hash _cm_dst_service
  fi
}
`)
}
