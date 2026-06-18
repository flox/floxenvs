package launch

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestDeckAdapter_Identity(t *testing.T) {
	var a deckAdapter
	if a.Name() != "agent-deck" {
		t.Fatalf("Name=%q", a.Name())
	}
	if a.InstallPkg() != "agent-deck" {
		t.Fatalf("InstallPkg=%q", a.InstallPkg())
	}
	if a.Check("/bin/agent-deck").Level != OK {
		t.Fatalf("Check not OK")
	}
}

func TestDeckAdapter_Build(t *testing.T) {
	// Isolate findUserDeckConfig so it finds no user config and seeds fresh.
	empty := t.TempDir()
	t.Setenv("XDG_CONFIG_HOME", empty)
	t.Setenv("HOME", empty)

	configDir := t.TempDir()
	ctx := Context{
		Bin:         "/env/bin/agent-deck",
		ConfigDir:   configDir,
		Passthrough: []string{"--foo"},
		BaseEnv:     []string{"HOME=" + empty},
	}

	var a deckAdapter
	spec, err := a.Build(ctx)
	if err != nil {
		t.Fatal(err)
	}

	if len(spec.Argv) != 2 || spec.Argv[0] != "/env/bin/agent-deck" || spec.Argv[1] != "--foo" {
		t.Fatalf("argv=%v", spec.Argv)
	}

	xdgConfigHome, deckDir := DeckHome(configDir)
	data, err := os.ReadFile(filepath.Join(deckDir, "config.toml"))
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(string(data), DeckClaudeCommand) {
		t.Fatalf("config.toml missing claude command %q: %s", DeckClaudeCommand, data)
	}

	wantXDG := "XDG_CONFIG_HOME=" + xdgConfigHome
	found := false
	for _, e := range spec.Env {
		if e == wantXDG {
			found = true
		}
	}
	if !found {
		t.Fatalf("env missing %q: %v", wantXDG, spec.Env)
	}
}
