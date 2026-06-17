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

func tmuxSocket(t *testing.T, doc map[string]any) string {
	t.Helper()
	tmux, _ := doc["tmux"].(map[string]any)
	s, _ := tmux["socket_name"].(string)
	return s
}

func TestInjectDeckConfig_Fresh(t *testing.T) {
	out, err := injectDeckConfig(nil, "")
	if err != nil {
		t.Fatal(err)
	}
	cmd, _ := parseClaudeCmd(t, out)
	if cmd != DeckClaudeCommand {
		t.Fatalf("got %q want %q", cmd, DeckClaudeCommand)
	}
}

func TestInjectDeckConfig_SocketName(t *testing.T) {
	out, err := injectDeckConfig([]byte("[mcps.exa]\ncommand = \"npx\"\n"), "flox-ai-deadbeef")
	if err != nil {
		t.Fatal(err)
	}
	cmd, doc := parseClaudeCmd(t, out)
	if cmd != DeckClaudeCommand {
		t.Fatalf("command not set: %q", cmd)
	}
	if got := tmuxSocket(t, doc); got != "flox-ai-deadbeef" {
		t.Fatalf("socket_name not set: %q", got)
	}
	if _, ok := doc["mcps"].(map[string]any); !ok {
		t.Fatalf("mcps table lost: %#v", doc)
	}
}

func TestInjectDeckConfig_EmptySocketOmitsTmux(t *testing.T) {
	out, err := injectDeckConfig(nil, "")
	if err != nil {
		t.Fatal(err)
	}
	var doc map[string]any
	if err := toml.Unmarshal(out, &doc); err != nil {
		t.Fatal(err)
	}
	if _, ok := doc["tmux"]; ok {
		t.Fatalf("tmux table should be absent when socketName empty: %#v", doc)
	}
}

func TestInjectDeckConfig_OverridesExisting(t *testing.T) {
	src := []byte("[claude]\ncommand = \"cdw\"\ndangerous_mode = true\n")
	out, err := injectDeckConfig(src, "")
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

func TestInjectDeckConfig_PreservesUserSocketSiblings(t *testing.T) {
	src := []byte("[tmux]\nsocket_name = \"old\"\nmouse = true\n")
	out, err := injectDeckConfig(src, "flox-ai-1234")
	if err != nil {
		t.Fatal(err)
	}
	var doc map[string]any
	if err := toml.Unmarshal(out, &doc); err != nil {
		t.Fatal(err)
	}
	tmux := doc["tmux"].(map[string]any)
	if tmux["socket_name"] != "flox-ai-1234" {
		t.Fatalf("socket_name not overridden: %v", tmux["socket_name"])
	}
	if tmux["mouse"] != true {
		t.Fatalf("tmux sibling key lost: %v", tmux["mouse"])
	}
}

func TestInjectDeckConfig_RejectsScalarClaude(t *testing.T) {
	src := []byte("claude = \"oops\"\n")
	_, err := injectDeckConfig(src, "")
	if err == nil {
		t.Fatal("expected error for scalar [claude], got nil")
	}
	if !strings.Contains(err.Error(), "not a table") {
		t.Fatalf("unexpected error: %v", err)
	}
}

func TestInjectDeckConfig_RejectsScalarTmux(t *testing.T) {
	src := []byte("tmux = \"oops\"\n")
	_, err := injectDeckConfig(src, "flox-ai-1234")
	if err == nil {
		t.Fatal("expected error for scalar [tmux], got nil")
	}
	if !strings.Contains(err.Error(), "not a table") {
		t.Fatalf("unexpected error: %v", err)
	}
}

func TestInjectDeckConfig_PreservesOtherTables(t *testing.T) {
	src := []byte("[mcps.exa]\ncommand = \"npx\"\nargs = [\"-y\", \"exa-mcp-server\"]\n")
	out, err := injectDeckConfig(src, "")
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

func TestDeckSocketName(t *testing.T) {
	a := DeckSocketName("/proj/.flox/cache/flox-ai")
	// stable for the same configDir
	if a != DeckSocketName("/proj/.flox/cache/flox-ai") {
		t.Fatalf("not stable: %q", a)
	}
	// distinct configDir -> distinct socket
	if a == DeckSocketName("/other/.flox/cache/flox-ai") {
		t.Fatalf("collision across configDirs: %q", a)
	}
	// filesystem-safe shape: flox-ai-<8 hex>
	if !strings.HasPrefix(a, "flox-ai-") || strings.ContainsAny(a, "/ ") {
		t.Fatalf("unsafe socket name: %q", a)
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
	if err := SeedDeckConfig(deckDir, src, "flox-ai-abcd"); err != nil {
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
	if got := tmuxSocket(t, doc); got != "flox-ai-abcd" {
		t.Fatalf("socket not seeded: %q", got)
	}
	if _, ok := doc["mcps"].(map[string]any); !ok {
		t.Fatalf("mcps not preserved: %#v", doc)
	}
}

func TestSeedDeckConfig_NoSource(t *testing.T) {
	deckDir := filepath.Join(t.TempDir(), "agents", "agent-deck")
	if err := SeedDeckConfig(deckDir, "", "flox-ai-abcd"); err != nil {
		t.Fatal(err)
	}
	out, _ := os.ReadFile(filepath.Join(deckDir, "config.toml"))
	if cmd, _ := parseClaudeCmd(t, out); cmd != DeckClaudeCommand {
		t.Fatalf("command not seeded: %q", cmd)
	}
}

func TestDeckHome(t *testing.T) {
	xdg, deck := DeckHome("/proj/.flox/cache/flox-ai")
	if xdg != "/proj/.flox/cache/flox-ai/agents" {
		t.Fatalf("xdg: %q", xdg)
	}
	if deck != "/proj/.flox/cache/flox-ai/agents/agent-deck" {
		t.Fatalf("deck: %q", deck)
	}
}

func TestDeckChildEnv(t *testing.T) {
	base := []string{"PATH=/bin", "XDG_CONFIG_HOME=/old", "FLOX_ENV=/env"}
	env := deckChildEnv(base, "/new/agents", "/cfg")
	has := func(want string) bool {
		for _, e := range env {
			if e == want {
				return true
			}
		}
		return false
	}
	if !has("XDG_CONFIG_HOME=/new/agents") {
		t.Fatalf("XDG_CONFIG_HOME not overridden: %v", env)
	}
	if !has("FLOX_AI=1") || !has("FLOX_AI_DIR=/cfg") {
		t.Fatalf("flox vars missing: %v", env)
	}
	// data home co-located with config home (per-env session isolation)
	if !has("XDG_DATA_HOME=/new/agents") {
		t.Fatalf("XDG_DATA_HOME not set to deck home: %v", env)
	}
	// no duplicate XDG_CONFIG_HOME
	n := 0
	for _, e := range env {
		if strings.HasPrefix(e, "XDG_CONFIG_HOME=") {
			n++
		}
	}
	if n != 1 {
		t.Fatalf("duplicate XDG_CONFIG_HOME: %v", env)
	}
	// cache left untouched
	for _, e := range env {
		if strings.HasPrefix(e, "XDG_CACHE_HOME=") {
			t.Fatalf("XDG_CACHE_HOME must not be set: %v", env)
		}
	}
}
