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
	frags, err := discover.ScanFlox(ctx.ShareDir, "claude")
	if err != nil {
		return Spec{}, fmt.Errorf("discover: %w", err)
	}
	userPlugins, err := UserPluginDirs(ctx.ConfigDir)
	if err != nil {
		return Spec{}, err
	}
	// Each share/flox/claude/<plugin> dir is already a valid Claude plugin
	// (manifest + skills/ + agents/), so it goes straight to --plugin-dir.
	plugins := dedupPluginDirs(append(append([]string{}, frags.AgentDirs...), userPlugins...))

	argv := []string{ctx.Bin}
	for _, dir := range plugins {
		argv = append(argv, "--plugin-dir", dir)
	}
	if rules, err := MergeRules(ctx.LaunchDir, frags.Rules); err != nil {
		return Spec{}, err
	} else if rules != "" {
		argv = append(argv, "--append-system-prompt-file", rules)
	}
	argv = append(argv, ctx.Passthrough...)
	return Spec{Argv: argv, Env: childEnv()}, nil
}
