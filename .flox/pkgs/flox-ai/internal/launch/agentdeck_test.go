package launch

import (
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
