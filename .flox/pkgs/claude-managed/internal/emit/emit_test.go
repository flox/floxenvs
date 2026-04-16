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
			Agents:  []discover.Fragment{{Name: "demo", Path: "/share/claude-code/agents/demo.md"}},
			Plugins: []discover.Fragment{{Name: "typescript-lsp", Path: "/share/claude-code/plugins/typescript-lsp"}},
		},
		ShareDir:  "/share/claude-code",
		ConfigDir: "/project/.claude-managed",
	})

	checks := []string{
		`CLAUDE_CONFIG_DIR="/project/.claude-managed"`,
		"export CLAUDE_CODE_DISABLE_AUTO_MEMORY=1",
		"export CLAUDE_MANAGED=1",
		"shasum -a 256",
		"security add-generic-password",
		`"$HOME/.claude.json"`,
		"|| true",
		"claude-managed rules clean",
		`claude-managed rules add "$FLOX_ENV/share/claude-code/rules/style.md"`,
		"claude-managed skills clean",
		`claude-managed skills add "$FLOX_ENV/share/claude-code/skills/coreutils"`,
		"claude-managed agents clean",
		`claude-managed agents add "$FLOX_ENV/share/claude-code/agents/demo.md"`,
		"claude-managed plugins clean",
		`claude-managed plugins add "$FLOX_ENV/share/claude-code/plugins/typescript-lsp"`,
		"_claude_managed_cleanup()",
		"security delete-generic-password",
	}
	for _, want := range checks {
		if !strings.Contains(result, want) {
			t.Errorf("hook output missing %q", want)
		}
	}

	unwanted := []string{
		"_cm_rellink",
		"_claude_managed_clean_symlinks()",
		"ln -sfn",
		"realpath --relative-to",
	}
	for _, bad := range unwanted {
		if strings.Contains(result, bad) {
			t.Errorf("hook output should NOT contain %q", bad)
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
	for _, cmd := range []string{"rules clean", "skills clean", "agents clean", "plugins clean"} {
		if !strings.Contains(result, "claude-managed "+cmd) {
			t.Errorf("missing %s", cmd)
		}
	}
	if strings.Contains(result, " add ") {
		t.Errorf("unexpected add command")
	}
	if !strings.Contains(result, "_claude_managed_cleanup()") {
		t.Errorf("missing cleanup function")
	}
}

func TestProfileCode(t *testing.T) {
	result := emit.ProfileCode(&emit.Params{
		Frags:     &discover.Result{},
		ShareDir:  "/share/claude-code",
		ConfigDir: "/project/.claude-managed",
	})

	if !strings.Contains(result, "trap _claude_managed_cleanup EXIT") {
		t.Errorf("profile must contain trap registration")
	}
	if !strings.Contains(result, "claude-managed rules clean") {
		t.Errorf("cleanup should call rules clean")
	}
	if !strings.Contains(result, "claude-managed plugins clean") {
		t.Errorf("cleanup should call plugins clean")
	}
}

func TestHookCode_NoShellHelpers(t *testing.T) {
	result := emit.HookCode(&emit.Params{
		Frags:     &discover.Result{},
		ShareDir:  "/share/claude-code",
		ConfigDir: "/project/.claude-managed",
	})

	unwanted := []string{
		"_cm_rellink",
		"_claude_managed_clean_symlinks()",
		"realpath --relative-to",
	}
	for _, bad := range unwanted {
		if strings.Contains(result, bad) {
			t.Errorf("should NOT contain shell helper %q", bad)
		}
	}
}
