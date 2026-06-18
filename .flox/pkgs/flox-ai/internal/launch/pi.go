// pi.go: runs pi with flox fragments injected via session-scoped CLI
// flags. Skills are passed as --skill <dir> (pi scans the dir for
// SKILL.md); rules as repeated --append-system-prompt <file>. Standalone
// agents and Claude-format plugins are not injected (pi has no matching
// seam); a notice lists what was skipped.
package launch

import (
	"fmt"
	"os"
	"path/filepath"

	"flox.dev/flox-ai/internal/discover"
)

type piAdapter struct{}

var _ Adapter = piAdapter{}

func (piAdapter) Name() string        { return "pi" }
func (piAdapter) InstallPkg() string  { return "pi" }
func (piAdapter) Check(string) Status { return Status{Level: OK} }

func (piAdapter) Build(ctx Context) (Spec, error) {
	frags, err := discover.Scan(ctx.ShareDir)
	if err != nil {
		return Spec{}, fmt.Errorf("discover: %w", err)
	}

	argv := []string{ctx.Bin}
	for _, s := range frags.Skills {
		argv = append(argv, "--skill", filepath.Dir(s.Path))
	}
	for _, r := range frags.Rules {
		argv = append(argv, "--append-system-prompt", r.Path)
	}
	if len(frags.Agents) > 0 || len(frags.Plugins) > 0 {
		fmt.Fprintf(os.Stderr,
			"pi: injected %d skills, %d rules; skipped %d agents, %d plugins (no pi seam)\n",
			len(frags.Skills), len(frags.Rules), len(frags.Agents), len(frags.Plugins))
	}
	argv = append(argv, ctx.Passthrough...)

	env := setEnvVar(ctx.BaseEnv, "FLOX_AI", "1")
	return Spec{Argv: argv, Env: env}, nil
}
