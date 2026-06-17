// agentdeck.go: runs the agent-deck TUI with a flox-managed config home

package launch

import (
	"fmt"

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
