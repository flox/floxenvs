package emit_test

import (
	"strings"
	"testing"

	"flox.dev/flox-ai/internal/discover"
	"flox.dev/flox-ai/internal/emit"
)

func TestHookCode_Full(t *testing.T) {
	result := emit.HookCode(&emit.Params{
		Frags: &discover.Result{
			Skills:  []discover.Fragment{{Name: "coreutils", Path: "/share/claude-code/skills/coreutils/SKILL.md"}},
			Rules:   []discover.Fragment{{Name: "style", Path: "/share/claude-code/rules/style.md"}},
			Agents:  []discover.Fragment{{Name: "demo", Path: "/share/claude-code/agents/demo.md"}},
			Plugins: []discover.Fragment{{Name: "typescript-lsp", Path: "/share/claude-code/plugins/typescript-lsp"}},
		},
		ShareDir:  "/share/claude-code",
		ConfigDir: "/project/.flox-ai",
	})

	// plugin wrapper must reference env vars, not baked-in absolute paths
	if !strings.Contains(result, `exec "$FLOX_ENV/bin/claude"`) {
		t.Errorf("wrapper body must reference $FLOX_ENV/bin/claude at runtime")
	}
	// wrapper must discover plugins at exec time, not bake them in at hook time
	if !strings.Contains(result, `for d in "$CLAUDE_CONFIG_DIR/plugins"/*`) {
		t.Errorf("wrapper must iterate $CLAUDE_CONFIG_DIR/plugins/* at runtime")
	}
	if !strings.Contains(result, `[ -L "$d" ] && [ -d "$d" ] || continue`) {
		t.Errorf("wrapper must only follow symlinks (skip data/, cache/, marketplaces/ dirs Claude Code creates)")
	}
	if !strings.Contains(result, `plugin_args+=(--plugin-dir`) {
		t.Errorf("wrapper must build --plugin-dir args at runtime")
	}
	if strings.Contains(result, `--plugin-dir "$CLAUDE_CONFIG_DIR/plugins/typescript-lsp"`) {
		t.Errorf("wrapper should NOT bake plugin names in at hook time")
	}
	if strings.Contains(result, `_cm_real=`) {
		t.Errorf("wrapper should not resolve claude eagerly; use $FLOX_ENV at runtime")
	}

	checks := []string{
		`CLAUDE_CONFIG_DIR="/project/.flox-ai"`,
		"export CLAUDE_CODE_DISABLE_AUTO_MEMORY=1",
		"export FLOX_AI=1",
		`mkdir -p "$CLAUDE_CONFIG_DIR/bin"`,
		`export PATH="$CLAUDE_CONFIG_DIR/bin:$PATH"`,
		"shasum -a 256",
		"security add-generic-password",
		`"$HOME/.claude.json"`,
		"|| true",
		`flox-ai --config-dir "$CLAUDE_CONFIG_DIR" rules clean`,
		`flox-ai --config-dir "$CLAUDE_CONFIG_DIR" rules add "$FLOX_ENV/share/claude-code/rules/style.md"`,
		`flox-ai --config-dir "$CLAUDE_CONFIG_DIR" skills clean`,
		`flox-ai --config-dir "$CLAUDE_CONFIG_DIR" skills add "$FLOX_ENV/share/claude-code/skills/coreutils"`,
		`flox-ai --config-dir "$CLAUDE_CONFIG_DIR" agents clean`,
		`flox-ai --config-dir "$CLAUDE_CONFIG_DIR" agents add "$FLOX_ENV/share/claude-code/agents/demo.md"`,
		`flox-ai --config-dir "$CLAUDE_CONFIG_DIR" plugins clean`,
		`flox-ai --config-dir "$CLAUDE_CONFIG_DIR" plugins add "$FLOX_ENV/share/claude-code/plugins/typescript-lsp"`,
		"_flox_ai_cleanup()",
		"security delete-generic-password",
	}
	for _, want := range checks {
		if !strings.Contains(result, want) {
			t.Errorf("hook output missing %q", want)
		}
	}

	unwanted := []string{
		"_cm_rellink",
		"_flox_ai_clean_symlinks()",
		"ln -sfn",
		"realpath --relative-to",
	}
	for _, bad := range unwanted {
		if strings.Contains(result, bad) {
			t.Errorf("hook output should NOT contain %q", bad)
		}
	}

	if strings.Contains(result, "trap _flox_ai_cleanup EXIT") {
		t.Errorf("hook must NOT contain trap registration")
	}
}

func TestHookCode_NoFragments(t *testing.T) {
	result := emit.HookCode(&emit.Params{
		Frags:     &discover.Result{},
		ShareDir:  "/share/claude-code",
		ConfigDir: "/project/.flox-ai",
	})

	if !strings.Contains(result, `CLAUDE_CONFIG_DIR="/project/.flox-ai"`) {
		t.Errorf("missing CLAUDE_CONFIG_DIR")
	}
	if !strings.Contains(result, `export PATH="$CLAUDE_CONFIG_DIR/bin:$PATH"`) {
		t.Errorf("missing PATH export even without plugins")
	}
	for _, cmd := range []string{"rules clean", "skills clean", "agents clean", "plugins clean"} {
		if !strings.Contains(result, `flox-ai --config-dir "$CLAUDE_CONFIG_DIR" `+cmd) {
			t.Errorf("missing %s", cmd)
		}
	}
	if strings.Contains(result, " add ") {
		t.Errorf("unexpected add command")
	}
	if !strings.Contains(result, "_flox_ai_cleanup()") {
		t.Errorf("missing cleanup function")
	}
	// wrapper is emitted unconditionally so manually-added plugins
	// (flox-ai plugins add <abspath>) work without re-activation
	if !strings.Contains(result, `cat > "$CLAUDE_CONFIG_DIR/bin/claude"`) {
		t.Errorf("wrapper must be emitted even when no plugins are discovered")
	}
	if !strings.Contains(result, `for d in "$CLAUDE_CONFIG_DIR/plugins"/*`) {
		t.Errorf("wrapper must iterate plugins at runtime even when none discovered")
	}
}

func TestProfileCode(t *testing.T) {
	result := emit.ProfileCode(&emit.Params{
		Frags:     &discover.Result{},
		ShareDir:  "/share/claude-code",
		ConfigDir: "/project/.flox-ai",
	})

	if !strings.Contains(result, `export PATH="$CLAUDE_CONFIG_DIR/bin:$PATH"`) {
		t.Errorf("profile must re-export PATH for interactive shells")
	}
	if !strings.Contains(result, "trap _flox_ai_cleanup EXIT") {
		t.Errorf("profile must contain trap registration")
	}
	if !strings.Contains(result, `flox-ai --config-dir "$CLAUDE_CONFIG_DIR" rules clean`) {
		t.Errorf("cleanup should call rules clean")
	}
	if !strings.Contains(result, `flox-ai --config-dir "$CLAUDE_CONFIG_DIR" plugins clean`) {
		t.Errorf("cleanup should call plugins clean")
	}
}

func TestProfileCodeFish(t *testing.T) {
	result := emit.ProfileCodeFish(&emit.Params{
		Frags:     &discover.Result{},
		ShareDir:  "/share/claude-code",
		ConfigDir: "/project/.flox-ai",
	})

	checks := []string{
		`set -gx PATH "$CLAUDE_CONFIG_DIR/bin" $PATH`,
		"function _flox_ai_cleanup --on-event fish_exit",
		`flox-ai --config-dir "$CLAUDE_CONFIG_DIR" rules clean`,
		`flox-ai --config-dir "$CLAUDE_CONFIG_DIR" plugins clean`,
		"end",
	}
	for _, want := range checks {
		if !strings.Contains(result, want) {
			t.Errorf("fish profile output missing %q", want)
		}
	}

	unwanted := []string{
		"trap ",
		"_flox_ai_cleanup()",
	}
	for _, bad := range unwanted {
		if strings.Contains(result, bad) {
			t.Errorf("fish profile should NOT contain %q (POSIX syntax)", bad)
		}
	}
}

func TestHookCode_NoShellHelpers(t *testing.T) {
	result := emit.HookCode(&emit.Params{
		Frags:     &discover.Result{},
		ShareDir:  "/share/claude-code",
		ConfigDir: "/project/.flox-ai",
	})

	unwanted := []string{
		"_cm_rellink",
		"_flox_ai_clean_symlinks()",
		"realpath --relative-to",
	}
	for _, bad := range unwanted {
		if strings.Contains(result, bad) {
			t.Errorf("should NOT contain shell helper %q", bad)
		}
	}
}
