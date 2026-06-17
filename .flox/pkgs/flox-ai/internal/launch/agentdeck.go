// agentdeck.go: runs the agent-deck TUI with a flox-managed config home

package launch

import (
	"fmt"
	"os"
	"path/filepath"

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
