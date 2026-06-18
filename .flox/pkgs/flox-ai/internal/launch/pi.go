// pi.go: runs pi with flox fragments injected via session-scoped CLI
// flags. Skills are passed as --skill <dir> (pi scans the dir for
// SKILL.md); rules as repeated --append-system-prompt <file>. Standalone
// agents and Claude-format plugins are not injected (pi has no matching
// seam); a notice lists what was skipped.
package launch

import (
	"fmt"

	"flox.dev/flox-ai/internal/discover"
)

type piAdapter struct{}

var _ Adapter = piAdapter{}

func (piAdapter) Name() string        { return "pi" }
func (piAdapter) InstallPkg() string  { return "pi" }
func (piAdapter) Check(string) Status { return Status{Level: OK} }

func (piAdapter) Build(ctx Context) (Spec, error) {
	frags, err := discover.ScanFlox(ctx.ShareDir, "pi")
	if err != nil {
		return Spec{}, fmt.Errorf("discover: %w", err)
	}

	argv := []string{ctx.Bin}
	for _, dir := range frags.AgentDirs {
		argv = append(argv, "--skill", dir)
	}
	for _, r := range frags.Rules {
		argv = append(argv, "--append-system-prompt", r.Path)
	}
	argv = append(argv, ctx.Passthrough...)

	env := setEnvVar(ctx.BaseEnv, "FLOX_AI", "1")
	return Spec{Argv: argv, Env: env}, nil
}
