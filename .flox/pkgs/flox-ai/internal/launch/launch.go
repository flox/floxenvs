// Package launch runs an AI agent with flox-managed fragments injected
// for the child process only, without mutating the user's shell or config.
package launch

import (
	"path/filepath"
	"sort"
	"strings"
)

// Agent describes how to launch a specific AI agent binary.
type Agent struct {
	Name       string // agent name as typed on the CLI, e.g. "claude"
	BinSubpath string // binary path relative to $FLOX_ENV
}

// Supported lists the agents launch knows how to run.
var Supported = map[string]Agent{
	"claude": {Name: "claude", BinSubpath: filepath.Join("bin", "claude")},
}

// SupportedNames returns the supported agent names, sorted and
// comma-joined, for error messages.
func SupportedNames() string {
	names := make([]string, 0, len(Supported))
	for n := range Supported {
		names = append(names, n)
	}
	sort.Strings(names)
	return strings.Join(names, ", ")
}

// Plan is the fully-resolved set of inputs to launch an agent.
type Plan struct {
	Bin         string   // absolute path to the agent binary (argv[0])
	SynthPlugin string   // synth plugin dir; "" if no skills/agents
	Plugins     []string // additional plugin dirs (env + user)
	RulesFile   string   // merged rules file; "" if no rules
	Passthrough []string // verbatim args after the agent name
}

// Argv builds the full argv (argv[0] = Bin) for the agent process.
func (p Plan) Argv() []string {
	argv := []string{p.Bin}
	if p.SynthPlugin != "" {
		argv = append(argv, "--plugin-dir", p.SynthPlugin)
	}
	for _, dir := range p.Plugins {
		argv = append(argv, "--plugin-dir", dir)
	}
	if p.RulesFile != "" {
		argv = append(argv, "--append-system-prompt-file", p.RulesFile)
	}
	return append(argv, p.Passthrough...)
}
