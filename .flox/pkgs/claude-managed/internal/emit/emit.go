package emit

import (
	"fmt"
	"strings"

	"flox.dev/claude-managed/internal/discover"
)

// Params holds everything needed to emit shell code.
type Params struct {
	Frags     *discover.Result
	ShareDir  string // $FLOX_ENV/share/claude-code
	ConfigDir string // absolute path for CLAUDE_CONFIG_DIR
}

// HookCode emits shell for on-activate: env vars,
// keychain bridge, subcommand calls for fragment management.
func HookCode(p *Params) string {
	var sb strings.Builder

	fmt.Fprintf(&sb, "export CLAUDE_CONFIG_DIR=%q\n", p.ConfigDir)
	sb.WriteString("export CLAUDE_CODE_DISABLE_AUTO_MEMORY=1\n")
	sb.WriteString("export CLAUDE_MANAGED=1\n")
	sb.WriteString("mkdir -p \"$CLAUDE_CONFIG_DIR\"\n")

	emitKeychainBridge(&sb)
	emitFragments(&sb, p)
	emitCleanupFunc(&sb)

	return sb.String()
}

// ProfileCode emits shell for profile: cleanup function + trap.
func ProfileCode(p *Params) string {
	var sb strings.Builder
	emitCleanupFunc(&sb)
	sb.WriteString("trap _claude_managed_cleanup EXIT\n")
	return sb.String()
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

func emitFragments(sb *strings.Builder, p *Params) {
	if p.ShareDir == "" {
		return
	}

	type fragGroup struct {
		label string
		items []discover.Fragment
	}

	groups := []fragGroup{
		{"rules", p.Frags.Rules},
		{"skills", p.Frags.Skills},
		{"agents", p.Frags.Agents},
	}

	for _, g := range groups {
		fmt.Fprintf(sb, "\nclaude-managed --config-dir \"$CLAUDE_CONFIG_DIR\" %s clean\n", g.label)
		for _, f := range g.items {
			fmt.Fprintf(sb, "claude-managed --config-dir \"$CLAUDE_CONFIG_DIR\" %s add \"$FLOX_ENV/share/claude-code/%s/%s\"\n",
				g.label, g.label, nameForFragment(g.label, f))
		}
	}

	// plugins (always clean, even if none discovered)
	sb.WriteString("\nclaude-managed --config-dir \"$CLAUDE_CONFIG_DIR\" plugins clean\n")
	for _, f := range p.Frags.Plugins {
		fmt.Fprintf(sb, "claude-managed --config-dir \"$CLAUDE_CONFIG_DIR\" plugins add \"$FLOX_ENV/share/claude-code/plugins/%s\"\n", f.Name)
	}

	if len(p.Frags.Plugins) > 0 {
		emitPluginWrapper(sb, p)
	}
}

// nameForFragment returns the name to use in the add command path.
// Skills use the directory name. Rules and agents use the filename.
func nameForFragment(typeName string, f discover.Fragment) string {
	if typeName == "skills" {
		return f.Name
	}
	return f.Name + ".md"
}

func emitPluginWrapper(sb *strings.Builder, p *Params) {
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

func emitCleanupFunc(sb *strings.Builder) {
	sb.WriteString(`
# cleanup function (trap registered in profile, not here)
_claude_managed_cleanup() {
  claude-managed --config-dir "$CLAUDE_CONFIG_DIR" rules clean
  claude-managed --config-dir "$CLAUDE_CONFIG_DIR" skills clean
  claude-managed --config-dir "$CLAUDE_CONFIG_DIR" agents clean
  claude-managed --config-dir "$CLAUDE_CONFIG_DIR" plugins clean
  # remove bridged keychain entry (macOS only)
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
