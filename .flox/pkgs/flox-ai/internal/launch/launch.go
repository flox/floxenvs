// Package launch runs an AI agent with flox-managed fragments injected
// for the child process only, without mutating the user's shell or config.
package launch

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"flox.dev/flox-ai/internal/discover"
	"flox.dev/flox-ai/internal/symlinks"
)

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

// Prepare wipes launchDir and rebuilds the synth plugin and merged rules
// file from the discovered fragments. Wiping each run keeps the tree free
// of stale entries and lets newly added fragments be picked up
// automatically. Returns the synth plugin path ("" if none) and the rules
// file path ("" if none).
func Prepare(launchDir string, frags *discover.Result) (synthPlugin, rulesFile string, err error) {
	if err := os.RemoveAll(launchDir); err != nil {
		return "", "", err
	}
	if err := os.MkdirAll(launchDir, 0755); err != nil {
		return "", "", err
	}
	synthPlugin, err = BuildSynthPlugin(launchDir, frags.Skills, frags.Agents)
	if err != nil {
		return "", "", err
	}
	rulesFile, err = MergeRules(launchDir, frags.Rules)
	if err != nil {
		return "", "", err
	}
	return synthPlugin, rulesFile, nil
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

// Options are the resolved inputs for Run.
type Options struct {
	AgentName   string
	ShareDir    string // share root ($FLOX_ENV/share); ScanFlox appends flox/<agent>
	ConfigDir   string // $FLOX_ENV_PROJECT/.flox/cache/flox-ai (or --config-dir)
	Passthrough []string
}

// dedupPluginDirs removes duplicate plugin directories, comparing by
// resolved (symlink-followed) path and keeping the first occurrence. This
// matters because an activated env mirrors share-dir plugins into
// configDir/plugins as symlinks, so the same plugin can arrive both as a
// share-dir path and as a configDir symlink.
func dedupPluginDirs(dirs []string) []string {
	seen := make(map[string]bool, len(dirs))
	var out []string
	for _, d := range dirs {
		key := d
		if resolved, err := filepath.EvalSymlinks(d); err == nil {
			key = resolved
		}
		if seen[key] {
			continue
		}
		seen[key] = true
		out = append(out, d)
	}
	return out
}

// childEnv returns the environment for the agent process: the parent
// environment plus FLOX_AI=1. It deliberately does NOT set
// CLAUDE_CONFIG_DIR — launch reuses the user's real config and login.
func childEnv() []string {
	return append(os.Environ(), "FLOX_AI=1")
}
