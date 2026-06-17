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
	claude, ok := doc["claude"].(map[string]any)
	if !ok {
		claude = map[string]any{}
		doc["claude"] = claude
	}
	claude["command"] = DeckClaudeCommand
	out, err := toml.Marshal(doc)
	if err != nil {
		return nil, fmt.Errorf("marshal agent-deck config: %w", err)
	}
	return out, nil
}
