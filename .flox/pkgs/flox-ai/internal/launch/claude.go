package launch

import (
	"fmt"

	"flox.dev/flox-ai/internal/discover"
)

// claudeAdapter launches Claude Code with a synthesized plugin (skills +
// agents), the env/user plugin dirs, and the merged rules file.
type claudeAdapter struct{}

var _ Adapter = claudeAdapter{}

func (claudeAdapter) Name() string       { return "claude" }
func (claudeAdapter) InstallPkg() string { return "claude-code" }

// Check passes as long as the binary resolved; claude needs no special
// build or capability.
func (claudeAdapter) Check(string) Status { return Status{Level: OK} }

func (claudeAdapter) Build(ctx Context) (Spec, error) {
	frags, err := discover.Scan(ctx.ShareDir)
	if err != nil {
		return Spec{}, fmt.Errorf("discover: %w", err)
	}
	synth, rulesFile, err := Prepare(ctx.LaunchDir, frags)
	if err != nil {
		return Spec{}, err
	}
	userPlugins, err := UserPluginDirs(ctx.ConfigDir)
	if err != nil {
		return Spec{}, err
	}
	plugins := make([]string, 0, len(frags.Plugins)+len(userPlugins))
	for _, p := range frags.Plugins {
		plugins = append(plugins, p.Path)
	}
	plugins = append(plugins, userPlugins...)
	plugins = dedupPluginDirs(plugins)

	plan := Plan{
		Bin:         ctx.Bin,
		SynthPlugin: synth,
		Plugins:     plugins,
		RulesFile:   rulesFile,
		Passthrough: ctx.Passthrough,
	}
	return Spec{Argv: plan.Argv(), Env: childEnv()}, nil
}
