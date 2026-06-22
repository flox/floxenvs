package discover

import (
	"os"
	"path/filepath"
	"runtime"
	"testing"
)

// testdataDir returns the path to the testdata directory relative to this file.
func testdataDir() string {
	_, filename, _, _ := runtime.Caller(0)
	return filepath.Join(filepath.Dir(filename), "..", "testdata", "share", "claude-code")
}

func TestDiscover(t *testing.T) {
	result, err := Scan(testdataDir())
	if err != nil {
		t.Fatalf("Scan returned error: %v", err)
	}

	if got := len(result.Rules); got != 1 {
		t.Errorf("Rules: want 1, got %d", got)
	}
	if got := len(result.Skills); got != 1 {
		t.Errorf("Skills: want 1, got %d", got)
	}
	if got := len(result.Agents); got != 1 {
		t.Errorf("Agents: want 1, got %d", got)
	}

	// Verify skill name
	if len(result.Skills) == 1 && result.Skills[0].Name != "demo" {
		t.Errorf("Skills[0].Name: want demo, got %s", result.Skills[0].Name)
	}

	if got := len(result.Plugins); got != 1 {
		t.Errorf("Plugins: want 1, got %d", got)
	}
	if len(result.Plugins) == 1 && result.Plugins[0].Name != "test-plugin" {
		t.Errorf("Plugins[0].Name: want test-plugin, got %s", result.Plugins[0].Name)
	}

	if result.IsEmpty() {
		t.Error("IsEmpty() should be false")
	}
}

func TestDiscover_Empty(t *testing.T) {
	dir, err := os.MkdirTemp("", "discover-empty-*")
	if err != nil {
		t.Fatal(err)
	}
	defer os.RemoveAll(dir)

	result, err := Scan(dir)
	if err != nil {
		t.Fatalf("Scan returned error: %v", err)
	}

	if !result.IsEmpty() {
		t.Error("IsEmpty() should be true for empty dir")
	}
}

func TestDiscover_SymlinkedSkillDir(t *testing.T) {
	base := t.TempDir()

	// Create a "real" skill directory (simulates a Nix store path)
	realSkillDir := filepath.Join(base, "store", "my-skill")
	if err := os.MkdirAll(realSkillDir, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(realSkillDir, "SKILL.md"), []byte("---\nname: my-skill\n---\n"), 0o644); err != nil {
		t.Fatal(err)
	}

	// Create a "real" plugin directory (simulates a Nix store path)
	realPluginDir := filepath.Join(base, "store", "my-plugin")
	if err := os.MkdirAll(realPluginDir, 0o755); err != nil {
		t.Fatal(err)
	}

	// Create the share/claude-code layout with symlinks (as Nix profiles do)
	skillsDir := filepath.Join(base, "share", "claude-code", "skills")
	if err := os.MkdirAll(skillsDir, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(realSkillDir, filepath.Join(skillsDir, "my-skill")); err != nil {
		t.Fatal(err)
	}

	pluginsDir := filepath.Join(base, "share", "claude-code", "plugins")
	if err := os.MkdirAll(pluginsDir, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(realPluginDir, filepath.Join(pluginsDir, "my-plugin")); err != nil {
		t.Fatal(err)
	}

	result, err := Scan(filepath.Join(base, "share", "claude-code"))
	if err != nil {
		t.Fatalf("Scan returned error: %v", err)
	}

	if got := len(result.Skills); got != 1 {
		t.Errorf("Skills: want 1, got %d (symlinked skill dir not discovered)", got)
	}
	if len(result.Skills) == 1 && result.Skills[0].Name != "my-skill" {
		t.Errorf("Skills[0].Name: want my-skill, got %s", result.Skills[0].Name)
	}

	if got := len(result.Plugins); got != 1 {
		t.Errorf("Plugins: want 1, got %d (symlinked plugin dir not discovered)", got)
	}
	if len(result.Plugins) == 1 && result.Plugins[0].Name != "my-plugin" {
		t.Errorf("Plugins[0].Name: want my-plugin, got %s", result.Plugins[0].Name)
	}
}

func TestDiscover_Missing(t *testing.T) {
	result, err := Scan("/nonexistent/path/that/does/not/exist")
	if err != nil {
		t.Fatalf("Scan returned error for missing dir: %v", err)
	}

	if !result.IsEmpty() {
		t.Error("IsEmpty() should be true for nonexistent dir")
	}
}

func TestScanFlox(t *testing.T) {
	share := t.TempDir()
	// codex plugin dir with one skill
	cdir := filepath.Join(share, "flox", "codex", "demo")
	if err := os.MkdirAll(filepath.Join(cdir, "s1"), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(cdir, "s1", "SKILL.md"), []byte("x"), 0o644); err != nil {
		t.Fatal(err)
	}
	// shared rule
	rdir := filepath.Join(share, "flox", "common", "demo", "rules")
	if err := os.MkdirAll(rdir, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(rdir, "r.md"), []byte("R"), 0o644); err != nil {
		t.Fatal(err)
	}

	got, err := ScanFlox(share, "codex")
	if err != nil {
		t.Fatal(err)
	}
	if len(got.AgentDirs) != 1 || got.AgentDirs[0] != cdir {
		t.Fatalf("AgentDirs=%v want [%s]", got.AgentDirs, cdir)
	}
	if len(got.Rules) != 1 || filepath.Base(got.Rules[0].Path) != "r.md" {
		t.Fatalf("Rules=%v", got.Rules)
	}
}

// TestScanFloxAgentPaths locks the per-agent install layout: each agent's
// content lives under <share>/flox/<agent>, so the claude agent resolves
// to share/flox/claude and the opencode agent to share/flox/opencode.
func TestScanFloxAgentPaths(t *testing.T) {
	share := t.TempDir()
	agents := []string{"claude", "opencode", "codex", "pi"}
	// Stage one plugin dir per agent under its own share/flox/<agent>.
	for _, a := range agents {
		dir := filepath.Join(share, "flox", a, "demo")
		if err := os.MkdirAll(dir, 0o755); err != nil {
			t.Fatal(err)
		}
	}

	for _, a := range agents {
		want := filepath.Join(share, "flox", a, "demo")
		got, err := ScanFlox(share, a)
		if err != nil {
			t.Fatalf("%s: %v", a, err)
		}
		// Exactly its own dir — no other agent's tree leaks in.
		if len(got.AgentDirs) != 1 || got.AgentDirs[0] != want {
			t.Fatalf("agent %s: AgentDirs=%v want [%s]", a, got.AgentDirs, want)
		}
	}
}
