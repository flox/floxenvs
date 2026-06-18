package launch

import "os"

// deckAdapter launches the agent-deck TUI with a flox-managed config
// home. It ignores fragments: deck-spawned claude sessions are routed
// back through `flox-ai launch claude`, which injects fragments itself.
type deckAdapter struct{}

var _ Adapter = deckAdapter{}

func (deckAdapter) Name() string       { return "agent-deck" }
func (deckAdapter) InstallPkg() string { return "agent-deck" }

func (deckAdapter) Check(string) Status { return Status{Level: OK} }

func (deckAdapter) Build(ctx Context) (Spec, error) {
	xdgConfigHome, deckDir := DeckHome(ctx.ConfigDir)
	socketName := DeckSocketName(ctx.ConfigDir)
	source := findUserDeckConfig(os.Getenv("XDG_CONFIG_HOME"), os.Getenv("HOME"))
	if err := SeedDeckConfig(deckDir, source, socketName); err != nil {
		return Spec{}, err
	}
	argv := append([]string{ctx.Bin}, ctx.Passthrough...)
	env := deckChildEnv(ctx.BaseEnv, xdgConfigHome, ctx.ConfigDir)
	return Spec{Argv: argv, Env: env}, nil
}
