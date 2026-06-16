// Package launch runs an AI agent with flox-managed fragments injected
// for the child process only, without mutating the user's shell or config.
package launch

import (
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"flox.dev/flox-ai/internal/discover"
	"flox.dev/flox-ai/internal/symlinks"
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

// MergeRules concatenates all rule fragments into launchDir/rules.md and
// returns its path. Each rule is preceded by an HTML comment naming its
// source. Returns "" (and writes nothing) when there are no rules.
func MergeRules(launchDir string, rules []discover.Fragment) (string, error) {
	if len(rules) == 0 {
		return "", nil
	}
	if err := os.MkdirAll(launchDir, 0755); err != nil {
		return "", err
	}
	var sb strings.Builder
	for _, r := range rules {
		content, err := os.ReadFile(r.Path)
		if err != nil {
			return "", fmt.Errorf("read rule %s: %w", r.Name, err)
		}
		fmt.Fprintf(&sb, "<!-- source: %s -->\n", r.Name)
		sb.Write(content)
		if !strings.HasSuffix(string(content), "\n") {
			sb.WriteString("\n")
		}
		sb.WriteString("\n")
	}
	out := filepath.Join(launchDir, "rules.md")
	if err := os.WriteFile(out, []byte(sb.String()), 0644); err != nil {
		return "", err
	}
	return out, nil
}

// BuildSynthPlugin creates a Claude Code plugin under launchDir/plugin
// containing the given skills and agents as symlinks, and returns the
// plugin path. Skills are linked as directories (the skill dir holding
// SKILL.md); agents are linked as <name>.md files. Returns "" (and writes
// nothing) when there are no skills or agents.
func BuildSynthPlugin(launchDir string, skills, agents []discover.Fragment) (string, error) {
	if len(skills) == 0 && len(agents) == 0 {
		return "", nil
	}
	pluginDir := filepath.Join(launchDir, "plugin")
	metaDir := filepath.Join(pluginDir, ".claude-plugin")
	if err := os.MkdirAll(metaDir, 0755); err != nil {
		return "", err
	}
	meta := `{"name":"flox","description":"Flox-managed skills and agents"}` + "\n"
	if err := os.WriteFile(filepath.Join(metaDir, "plugin.json"), []byte(meta), 0644); err != nil {
		return "", err
	}

	if len(skills) > 0 {
		skillsDir := filepath.Join(pluginDir, "skills")
		if err := os.MkdirAll(skillsDir, 0755); err != nil {
			return "", err
		}
		for _, s := range skills {
			// s.Path is the SKILL.md file; link its directory.
			target := filepath.Dir(s.Path)
			if err := os.Symlink(target, filepath.Join(skillsDir, s.Name)); err != nil {
				return "", err
			}
		}
	}

	if len(agents) > 0 {
		agentsDir := filepath.Join(pluginDir, "agents")
		if err := os.MkdirAll(agentsDir, 0755); err != nil {
			return "", err
		}
		for _, a := range agents {
			if err := os.Symlink(a.Path, filepath.Join(agentsDir, a.Name+".md")); err != nil {
				return "", err
			}
		}
	}

	return pluginDir, nil
}

// UserPluginDirs returns the plugin symlink paths added via
// `flox-ai plugins add` (configDir/plugins/*). Only non-broken symlinks
// are returned, matching how the existing claude wrapper filters out
// Claude Code's own runtime state directories. Returns nil when the
// plugins dir is absent.
func UserPluginDirs(configDir string) ([]string, error) {
	entries, err := symlinks.List(filepath.Join(configDir, "plugins"))
	if err != nil {
		return nil, err
	}
	var dirs []string
	for _, e := range entries {
		if e.Broken {
			continue
		}
		dirs = append(dirs, e.Path)
	}
	return dirs, nil
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
