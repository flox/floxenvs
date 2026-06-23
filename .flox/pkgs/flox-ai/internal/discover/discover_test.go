package discover

import (
	"os"
	"path/filepath"
	"testing"
)

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

// TestScanFlox_FollowsSymlinks: a flox env composes packages by symlinking
// each one's share/flox/<agent>/<plugin> into the merged tree. ScanFlox must
// follow those symlinks (DirEntry.IsDir() would skip them).
func TestScanFlox_FollowsSymlinks(t *testing.T) {
	base := t.TempDir()
	real := filepath.Join(base, "store", "caveman")
	if err := os.MkdirAll(real, 0o755); err != nil {
		t.Fatal(err)
	}
	claudeDir := filepath.Join(base, "share", "flox", "claude")
	if err := os.MkdirAll(claudeDir, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(real, filepath.Join(claudeDir, "caveman")); err != nil {
		t.Fatal(err)
	}
	got, err := ScanFlox(filepath.Join(base, "share"), "claude")
	if err != nil {
		t.Fatal(err)
	}
	if len(got.AgentDirs) != 1 || filepath.Base(got.AgentDirs[0]) != "caveman" {
		t.Fatalf("AgentDirs=%v; want the symlinked caveman dir", got.AgentDirs)
	}
}
