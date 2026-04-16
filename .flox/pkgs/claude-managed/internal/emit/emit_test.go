package emit_test

import (
	"strings"
	"testing"

	"flox.dev/claude-managed/internal/discover"
	"flox.dev/claude-managed/internal/emit"
)

func TestHookCode_Full(t *testing.T) {
	result := emit.HookCode(&emit.Params{
		Frags: &discover.Result{
			Skills:  []discover.Fragment{{Name: "coreutils", Path: "/share/claude-code/skills/coreutils/SKILL.md"}},
			Rules:   []discover.Fragment{{Name: "style", Path: "/share/claude-code/rules/style.md"}},
			Plugins: []discover.Fragment{{Name: "typescript-lsp", Path: "/share/claude-code/plugins/typescript-lsp"}},
		},
		ShareDir:  "/share/claude-code",
		ConfigDir: "/project/.claude-managed",
	})

	checks := []string{
		`CLAUDE_CONFIG_DIR="/project/.claude-managed"`,
		"export CLAUDE_CODE_DISABLE_AUTO_MEMORY=1",
		"export CLAUDE_MANAGED=1",
		"_claude_managed_clean_symlinks()",
		"shasum -a 256",
		"security add-generic-password",
		`"$HOME/.claude.json"`,
		"|| true",
		`_cm_rellink "$FLOX_ENV/share/claude-code/skills/coreutils" "$CLAUDE_CONFIG_DIR/skills/coreutils"`,
		`_cm_rellink "$FLOX_ENV/share/claude-code/rules/style.md" "$CLAUDE_CONFIG_DIR/rules/style.md"`,
		"_claude_managed_cleanup()",
		"security delete-generic-password",
		"claude-managed plugins clean",
		`claude-managed plugins add "$FLOX_ENV/share/claude-code/plugins/typescript-lsp"`,
	}
	for _, want := range checks {
		if !strings.Contains(result, want) {
			t.Errorf("hook output missing %q", want)
		}
	}

	if strings.Contains(result, "trap _claude_managed_cleanup EXIT") {
		t.Errorf("hook must NOT contain trap registration")
	}
}

func TestHookCode_NoFragments(t *testing.T) {
	result := emit.HookCode(&emit.Params{
		Frags:     &discover.Result{},
		ShareDir:  "/share/claude-code",
		ConfigDir: "/project/.claude-managed",
	})

	if !strings.Contains(result, `CLAUDE_CONFIG_DIR="/project/.claude-managed"`) {
		t.Errorf("missing CLAUDE_CONFIG_DIR")
	}
	if strings.Contains(result, "_cm_rellink \"$FLOX_ENV") {
		t.Errorf("unexpected symlink creation")
	}
	if !strings.Contains(result, "security add-generic-password") {
		t.Errorf("missing keychain bridge")
	}
	if !strings.Contains(result, "_claude_managed_cleanup()") {
		t.Errorf("missing cleanup function")
	}
	if strings.Contains(result, "plugins add") {
		t.Errorf("unexpected plugins add")
	}
	if !strings.Contains(result, "claude-managed plugins clean") {
		t.Errorf("missing plugins clean in cleanup")
	}
}

func TestProfileCode(t *testing.T) {
	result := emit.ProfileCode(&emit.Params{
		Frags:     &discover.Result{},
		ShareDir:  "/share/claude-code",
		ConfigDir: "/project/.claude-managed",
	})

	if !strings.Contains(result, "trap _claude_managed_cleanup EXIT") {
		t.Errorf("profile must contain trap registration, got: %s", result)
	}
}

func TestHookCode_EnvVars(t *testing.T) {
	result := emit.HookCode(&emit.Params{
		Frags:     &discover.Result{},
		ShareDir:  "/share/claude-code",
		ConfigDir: "/project/.claude-managed",
	})

	if !strings.Contains(result, `"$FLOX_ENV/share/claude-code"/*)`) {
		t.Errorf("helper should use $FLOX_ENV")
	}
	if !strings.Contains(result, `"$CLAUDE_CONFIG_DIR/$1"`) {
		t.Errorf("helper should use $CLAUDE_CONFIG_DIR")
	}
}
