package launch

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/pelletier/go-toml/v2"
)

func parseClaudeCmd(t *testing.T, data []byte) (string, map[string]any) {
	t.Helper()
	var doc map[string]any
	if err := toml.Unmarshal(data, &doc); err != nil {
		t.Fatalf("re-parse failed: %v", err)
	}
	claude, _ := doc["claude"].(map[string]any)
	cmd, _ := claude["command"].(string)
	return cmd, doc
}

func TestInjectClaudeCommand_Fresh(t *testing.T) {
	out, err := injectClaudeCommand(nil)
	if err != nil {
		t.Fatal(err)
	}
	cmd, _ := parseClaudeCmd(t, out)
	if cmd != DeckClaudeCommand {
		t.Fatalf("got %q want %q", cmd, DeckClaudeCommand)
	}
}

func TestInjectClaudeCommand_OverridesExisting(t *testing.T) {
	src := []byte("[claude]\ncommand = \"cdw\"\ndangerous_mode = true\n")
	out, err := injectClaudeCommand(src)
	if err != nil {
		t.Fatal(err)
	}
	cmd, doc := parseClaudeCmd(t, out)
	if cmd != DeckClaudeCommand {
		t.Fatalf("command not overridden: %q", cmd)
	}
	claude := doc["claude"].(map[string]any)
	if claude["dangerous_mode"] != true {
		t.Fatalf("sibling key lost: %v", claude["dangerous_mode"])
	}
}

func TestInjectClaudeCommand_RejectsScalarClaude(t *testing.T) {
	src := []byte("claude = \"oops\"\n")
	_, err := injectClaudeCommand(src)
	if err == nil {
		t.Fatal("expected error for scalar [claude], got nil")
	}
	if !strings.Contains(err.Error(), "not a table") {
		t.Fatalf("unexpected error: %v", err)
	}
}

func TestInjectClaudeCommand_PreservesOtherTables(t *testing.T) {
	src := []byte("[mcps.exa]\ncommand = \"npx\"\nargs = [\"-y\", \"exa-mcp-server\"]\n")
	out, err := injectClaudeCommand(src)
	if err != nil {
		t.Fatal(err)
	}
	cmd, doc := parseClaudeCmd(t, out)
	if cmd != DeckClaudeCommand {
		t.Fatalf("command not set: %q", cmd)
	}
	mcps, ok := doc["mcps"].(map[string]any)
	if !ok {
		t.Fatalf("mcps table lost: %#v", doc)
	}
	if _, ok := mcps["exa"]; !ok {
		t.Fatalf("mcps.exa lost: %#v", mcps)
	}
}

func TestFindUserDeckConfig(t *testing.T) {
	home := t.TempDir()
	// none present
	if got := findUserDeckConfig("", home); got != "" {
		t.Fatalf("expected empty, got %q", got)
	}
	// legacy present
	legacy := filepath.Join(home, ".agent-deck")
	os.MkdirAll(legacy, 0755)
	legacyCfg := filepath.Join(legacy, "config.toml")
	os.WriteFile(legacyCfg, []byte("[claude]\n"), 0644)
	if got := findUserDeckConfig("", home); got != legacyCfg {
		t.Fatalf("legacy not found: %q", got)
	}
	// xdg present takes precedence
	xdg := t.TempDir()
	xdgCfgDir := filepath.Join(xdg, "agent-deck")
	os.MkdirAll(xdgCfgDir, 0755)
	xdgCfg := filepath.Join(xdgCfgDir, "config.toml")
	os.WriteFile(xdgCfg, []byte("[claude]\n"), 0644)
	if got := findUserDeckConfig(xdg, home); got != xdgCfg {
		t.Fatalf("xdg should win: %q", got)
	}
}

func TestSeedDeckConfig(t *testing.T) {
	src := filepath.Join(t.TempDir(), "config.toml")
	os.WriteFile(src, []byte("[mcps.exa]\ncommand = \"npx\"\n"), 0644)
	deckDir := filepath.Join(t.TempDir(), "agents", "agent-deck")
	if err := SeedDeckConfig(deckDir, src); err != nil {
		t.Fatal(err)
	}
	out, err := os.ReadFile(filepath.Join(deckDir, "config.toml"))
	if err != nil {
		t.Fatal(err)
	}
	cmd, doc := parseClaudeCmd(t, out)
	if cmd != DeckClaudeCommand {
		t.Fatalf("command not seeded: %q", cmd)
	}
	if _, ok := doc["mcps"].(map[string]any); !ok {
		t.Fatalf("mcps not preserved: %#v", doc)
	}
}

func TestSeedDeckConfig_NoSource(t *testing.T) {
	deckDir := filepath.Join(t.TempDir(), "agents", "agent-deck")
	if err := SeedDeckConfig(deckDir, ""); err != nil {
		t.Fatal(err)
	}
	out, _ := os.ReadFile(filepath.Join(deckDir, "config.toml"))
	if cmd, _ := parseClaudeCmd(t, out); cmd != DeckClaudeCommand {
		t.Fatalf("command not seeded: %q", cmd)
	}
}
