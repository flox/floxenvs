// agentdeck.go: runs the agent-deck TUI with a flox-managed config home

package launch

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/pelletier/go-toml/v2"
)

// DeckClaudeCommand is the [claude].command value forced into the
// agent-deck config so deck-spawned claude sessions run through flox-ai.
const DeckClaudeCommand = "flox-ai launch claude --"

// injectClaudeCommand parses src (TOML; may be empty), forces
// claude.command = DeckClaudeCommand while preserving every other table
// and key, and returns the re-marshaled document.
func injectClaudeCommand(src []byte) ([]byte, error) {
	doc := map[string]any{}
	if len(src) > 0 {
		if err := toml.Unmarshal(src, &doc); err != nil {
			return nil, fmt.Errorf("parse agent-deck config: %w", err)
		}
	}
	switch existing := doc["claude"].(type) {
	case map[string]any:
		existing["command"] = DeckClaudeCommand
	case nil:
		doc["claude"] = map[string]any{"command": DeckClaudeCommand}
	default:
		return nil, fmt.Errorf("agent-deck config: [claude] is not a table (got %T)", doc["claude"])
	}
	out, err := toml.Marshal(doc)
	if err != nil {
		return nil, fmt.Errorf("marshal agent-deck config: %w", err)
	}
	return out, nil
}

// findUserDeckConfig returns the path of the user's existing agent-deck
// config.toml, searching agent-deck's own order: $XDG_CONFIG_HOME, then
// ~/.config, then legacy ~/.agent-deck. Returns "" when none exists.
func findUserDeckConfig(xdgConfigHome, home string) string {
	var candidates []string
	if xdgConfigHome != "" {
		candidates = append(candidates,
			filepath.Join(xdgConfigHome, "agent-deck", "config.toml"))
	}
	if home != "" {
		candidates = append(candidates,
			filepath.Join(home, ".config", "agent-deck", "config.toml"),
			filepath.Join(home, ".agent-deck", "config.toml"),
		)
	}
	for _, c := range candidates {
		if fi, err := os.Stat(c); err == nil && !fi.IsDir() {
			return c
		}
	}
	return ""
}

// SeedDeckConfig writes <deckDir>/config.toml from sourcePath (when
// non-empty) with claude.command forced to DeckClaudeCommand, creating
// deckDir as needed. Overwrites any existing file.
func SeedDeckConfig(deckDir, sourcePath string) error {
	var src []byte
	if sourcePath != "" {
		data, err := os.ReadFile(sourcePath)
		if err != nil {
			return fmt.Errorf("read source config %s: %w", sourcePath, err)
		}
		src = data
	}
	out, err := injectClaudeCommand(src)
	if err != nil {
		return err
	}
	if err := os.MkdirAll(deckDir, 0755); err != nil {
		return err
	}
	return os.WriteFile(filepath.Join(deckDir, "config.toml"), out, 0644)
}

// DeckHome derives the agent-deck XDG layout from the flox-ai configDir.
// agent-deck resolves ConfigDir as $XDG_CONFIG_HOME/agent-deck, so the
// XDG_CONFIG_HOME we hand it is <configDir>/agents and the deck config
// home is <configDir>/agents/agent-deck.
func DeckHome(configDir string) (xdgConfigHome, deckDir string) {
	xdgConfigHome = filepath.Join(configDir, "agents")
	deckDir = filepath.Join(xdgConfigHome, "agent-deck")
	return
}

// setEnvVar returns env with key=val, replacing any existing assignment
// rather than appending a duplicate.
func setEnvVar(env []string, key, val string) []string {
	prefix := key + "="
	out := make([]string, 0, len(env)+1)
	replaced := false
	for _, e := range env {
		if strings.HasPrefix(e, prefix) {
			out = append(out, prefix+val)
			replaced = true
			continue
		}
		out = append(out, e)
	}
	if !replaced {
		out = append(out, prefix+val)
	}
	return out
}

// deckChildEnv builds the environment for the agent-deck process: the
// parent env with XDG_CONFIG_HOME pointed at the flox deck home,
// FLOX_AI=1, and FLOX_AI_DIR pinned to configDir so the nested
// `flox-ai launch claude` resolves this env's fragments. XDG_DATA_HOME
// and XDG_CACHE_HOME are intentionally left untouched so deck sessions
// persist in the user's global agent-deck data.
func deckChildEnv(base []string, xdgConfigHome, configDir string) []string {
	env := setEnvVar(base, "XDG_CONFIG_HOME", xdgConfigHome)
	env = setEnvVar(env, "FLOX_AI", "1")
	env = setEnvVar(env, "FLOX_AI_DIR", configDir)
	return env
}
