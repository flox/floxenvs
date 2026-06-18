package launch

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestClaudeAdapter_Identity(t *testing.T) {
	var a claudeAdapter
	if a.Name() != "claude" {
		t.Fatalf("Name=%q", a.Name())
	}
	if a.InstallPkg() != "claude-code" {
		t.Fatalf("InstallPkg=%q", a.InstallPkg())
	}
	if a.Check("/bin/claude").Level != OK {
		t.Fatalf("Check not OK")
	}
}

func TestClaudeAdapter_Build(t *testing.T) {
	share := t.TempDir()

	// a prebuilt claude plugin dir: share/flox/claude/demo
	pluginDir := filepath.Join(share, "flox", "claude", "demo")
	if err := os.MkdirAll(pluginDir, 0o755); err != nil {
		t.Fatal(err)
	}
	// a shared rule: share/flox/common/demo/rules/r.md
	rulesDir := filepath.Join(share, "flox", "common", "demo", "rules")
	if err := os.MkdirAll(rulesDir, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(rulesDir, "r.md"), []byte("R"), 0o644); err != nil {
		t.Fatal(err)
	}

	launchDir := filepath.Join(t.TempDir(), "launch", "claude")
	ctx := Context{
		Bin:       "/env/bin/claude",
		ShareDir:  share,
		LaunchDir: launchDir,
		ConfigDir: t.TempDir(), // no plugins/ subdir -> no user plugins
		BaseEnv:   []string{"HOME=/h"},
	}

	var a claudeAdapter
	spec, err := a.Build(ctx)
	if err != nil {
		t.Fatal(err)
	}

	if len(spec.Argv) == 0 || spec.Argv[0] != "/env/bin/claude" {
		t.Fatalf("argv[0]=%v", spec.Argv)
	}
	joined := strings.Join(spec.Argv, " ")
	wantPlugin := "--plugin-dir " + pluginDir
	if !strings.Contains(joined, wantPlugin) {
		t.Fatalf("argv missing %q: %v", wantPlugin, spec.Argv)
	}
	wantRules := "--append-system-prompt-file " + filepath.Join(launchDir, "rules.md")
	if !strings.Contains(joined, wantRules) {
		t.Fatalf("argv missing %q: %v", wantRules, spec.Argv)
	}

	foundFloxAI := false
	for _, e := range spec.Env {
		if e == "FLOX_AI=1" {
			foundFloxAI = true
		}
	}
	if !foundFloxAI {
		t.Fatalf("env missing FLOX_AI=1: %v", spec.Env)
	}
}
