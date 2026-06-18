// agentdeck.go: runs the agent-deck TUI with a flox-managed config home

package launch

import (
	"fmt"
	"hash/fnv"
	"os"
	"path/filepath"
	"strings"
	"syscall"

	"github.com/pelletier/go-toml/v2"
)

// DeckClaudeCommand is the [claude].command value forced into the
// agent-deck config so deck-spawned claude sessions run through flox-ai.
const DeckClaudeCommand = "flox-ai launch claude --"

// setTableKey forces doc[table][key] = value, creating the table when
// absent and preserving its other keys. It errors when table exists but
// is not a TOML table (e.g. a scalar), which would otherwise be silently
// discarded.
func setTableKey(doc map[string]any, table, key string, value any) error {
	switch existing := doc[table].(type) {
	case map[string]any:
		existing[key] = value
	case nil:
		doc[table] = map[string]any{key: value}
	default:
		return fmt.Errorf("agent-deck config: [%s] is not a table (got %T)", table, doc[table])
	}
	return nil
}

// injectDeckConfig parses src (TOML; may be empty) and forces the flox
// overrides — claude.command = DeckClaudeCommand and, when socketName is
// non-empty, tmux.socket_name = socketName — preserving every other table
// and key, then returns the re-marshaled document.
func injectDeckConfig(src []byte, socketName string) ([]byte, error) {
	doc := map[string]any{}
	if len(src) > 0 {
		if err := toml.Unmarshal(src, &doc); err != nil {
			return nil, fmt.Errorf("parse agent-deck config: %w", err)
		}
	}
	if err := setTableKey(doc, "claude", "command", DeckClaudeCommand); err != nil {
		return nil, err
	}
	if socketName != "" {
		if err := setTableKey(doc, "tmux", "socket_name", socketName); err != nil {
			return nil, err
		}
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
// non-empty) with the flox overrides applied (claude.command and, when
// socketName is non-empty, tmux.socket_name), creating deckDir as needed.
// Overwrites any existing file.
func SeedDeckConfig(deckDir, sourcePath, socketName string) error {
	var src []byte
	if sourcePath != "" {
		data, err := os.ReadFile(sourcePath)
		if err != nil {
			return fmt.Errorf("read source config %s: %w", sourcePath, err)
		}
		src = data
	}
	out, err := injectDeckConfig(src, socketName)
	if err != nil {
		return err
	}
	if err := os.MkdirAll(deckDir, 0755); err != nil {
		return err
	}
	return os.WriteFile(filepath.Join(deckDir, "config.toml"), out, 0644)
}

// DeckHome derives the agent-deck home from the flox-ai configDir. The
// patched agent-deck reads config, data, and cache directly from the
// directory named by AGENT_DECK_HOME, so this single path is both where we
// seed config.toml and what we export to the deck.
func DeckHome(configDir string) string {
	return filepath.Join(configDir, "agents", "agent-deck")
}

// DeckSocketName returns a stable, per-environment tmux socket name
// derived from configDir. Distinct flox environments get distinct tmux
// servers — isolating each deck's shell environment and running panes —
// while relaunching the same environment reuses its server. The name is
// filesystem-safe (it becomes a tmux `-L <name>` socket file).
func DeckSocketName(configDir string) string {
	h := fnv.New32a()
	_, _ = h.Write([]byte(configDir))
	return fmt.Sprintf("flox-ai-%08x", h.Sum32())
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
// parent env with AGENT_DECK_HOME pointed at the flox deck home (so the
// deck's config, data, and cache live together under one isolated, per-env
// home), FLOX_AI=1, and FLOX_AI_DIR pinned to configDir so the nested
// `flox-ai launch claude` resolves this env's fragments.
//
// Crucially it leaves XDG_CONFIG_HOME/XDG_DATA_HOME untouched. agent-deck
// spawns a tmux server that inherits this env, and every pane inherits the
// server's env; overriding XDG here would leak the deck home into those
// panes and break unrelated programs that read XDG to find their own config.
// AGENT_DECK_HOME isolates the deck without that side effect.
func deckChildEnv(base []string, deckHome, configDir string) []string {
	env := setEnvVar(base, "AGENT_DECK_HOME", deckHome)
	env = setEnvVar(env, "FLOX_AI", "1")
	env = setEnvVar(env, "FLOX_AI_DIR", configDir)
	return env
}

// RunDeck seeds the flox-managed agent-deck config (forcing the claude
// command to route through flox-ai and a per-env tmux socket), points
// agent-deck at it via AGENT_DECK_HOME, exports FLOX_AI_DIR for nested
// flox-ai invocations, and execs agent-deck (replacing this process).
func RunDeck(opts Options) error {
	agent := Supported[opts.AgentName] // caller guarantees agent-deck
	bin, err := resolveBinary(agent)
	if err != nil {
		return err
	}

	deckHome := DeckHome(opts.ConfigDir)
	socketName := DeckSocketName(opts.ConfigDir)

	source := findUserDeckConfig(os.Getenv("XDG_CONFIG_HOME"), os.Getenv("HOME"))
	if err := SeedDeckConfig(deckHome, source, socketName); err != nil {
		return err
	}

	argv := append([]string{bin}, opts.Passthrough...)
	env := deckChildEnv(os.Environ(), deckHome, opts.ConfigDir)
	return syscall.Exec(bin, argv, env)
}
