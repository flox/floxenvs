package launch

import (
	"os"
	"path/filepath"
	"testing"
)

func TestCodexAdapter_Identity(t *testing.T) {
	var a codexAdapter
	if a.Name() != "codex" {
		t.Fatalf("Name=%q", a.Name())
	}
	if a.InstallPkg() != "codex" {
		t.Fatalf("InstallPkg=%q", a.InstallPkg())
	}
	// Check behavior (patched vs unpatched) is covered by
	// TestCodexCheck_PatchedAndUnpatched.
}

func TestCodexAdapter_Build(t *testing.T) {
	share := t.TempDir()

	skillRoot := filepath.Join(share, "flox", "codex", "demo")
	if err := os.MkdirAll(skillRoot, 0o755); err != nil {
		t.Fatal(err)
	}
	rulesDir := filepath.Join(share, "flox", "common", "demo", "rules")
	if err := os.MkdirAll(rulesDir, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(rulesDir, "r.md"), []byte("R"), 0o644); err != nil {
		t.Fatal(err)
	}

	launchDir := filepath.Join(t.TempDir(), "launch", "codex")
	ctx := Context{
		Bin:       "/env/bin/codex",
		ShareDir:  share,
		LaunchDir: launchDir,
		ConfigDir: t.TempDir(),
		BaseEnv:   []string{"HOME=/h"},
	}

	var a codexAdapter
	spec, err := a.Build(ctx)
	if err != nil {
		t.Fatal(err)
	}

	if len(spec.Argv) == 0 || spec.Argv[0] != "/env/bin/codex" {
		t.Fatalf("argv[0]=%v", spec.Argv)
	}

	wantRoots := EnvCodexSkillRoots + "=" + skillRoot
	wantRules := EnvCodexInstructionsFile + "=" + filepath.Join(launchDir, "rules.md")
	var gotRoots, gotRules, gotFloxAI bool
	for _, e := range spec.Env {
		switch e {
		case wantRoots:
			gotRoots = true
		case wantRules:
			gotRules = true
		case "FLOX_AI=1":
			gotFloxAI = true
		}
	}
	if !gotRoots {
		t.Fatalf("env missing %q: %v", wantRoots, spec.Env)
	}
	if !gotRules {
		t.Fatalf("env missing %q: %v", wantRules, spec.Env)
	}
	if !gotFloxAI {
		t.Fatalf("env missing FLOX_AI=1: %v", spec.Env)
	}
}
