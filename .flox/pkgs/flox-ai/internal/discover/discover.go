package discover

import (
	"os"
	"path/filepath"
	"sort"
	"strings"
)

// Fragment represents a discovered config file.
type Fragment struct {
	Name string // filename without extension
	Path string // absolute path
}

// Result holds all discovered fragments, sorted by name.
type Result struct {
	Rules   []Fragment
	Skills  []Fragment
	Agents  []Fragment
	Plugins []Fragment
}

// IsEmpty returns true if no fragments were found.
func (r *Result) IsEmpty() bool {
	return len(r.Rules) == 0 &&
		len(r.Skills) == 0 &&
		len(r.Agents) == 0 &&
		len(r.Plugins) == 0
}

// globFragments reads all files matching pattern in dir and returns sorted Fragments.
func globFragments(dir, pattern string) ([]Fragment, error) {
	if _, err := os.Stat(dir); os.IsNotExist(err) {
		return nil, nil
	}

	matches, err := filepath.Glob(filepath.Join(dir, pattern))
	if err != nil {
		return nil, err
	}

	fragments := make([]Fragment, 0, len(matches))
	for _, path := range matches {
		base := filepath.Base(path)
		ext := filepath.Ext(base)
		name := strings.TrimSuffix(base, ext)
		fragments = append(fragments, Fragment{Name: name, Path: path})
	}

	sort.Slice(fragments, func(i, j int) bool {
		return fragments[i].Name < fragments[j].Name
	})

	return fragments, nil
}

// FloxResult holds the build-time layout for one agent: the prebuilt
// per-agent plugin dirs to point the agent at, and the shared rule files.
type FloxResult struct {
	AgentDirs []string   // <share>/flox/<agent>/* (sorted)
	Rules     []Fragment // <share>/flox/common/*/rules/*.md (sorted by name)
}

// ScanFlox enumerates the build-time layout under <shareDir>/flox for the
// given agent. Returns an empty result (no error) when the tree is absent.
func ScanFlox(shareDir, agent string) (*FloxResult, error) {
	res := &FloxResult{}

	agentRoot := filepath.Join(shareDir, "flox", agent)
	if entries, err := os.ReadDir(agentRoot); err == nil {
		for _, e := range entries {
			full := filepath.Join(agentRoot, e.Name())
			// Stat (follows symlinks), NOT DirEntry.IsDir(): a flox env
			// composes packages by exposing each one's
			// share/flox/<agent>/<plugin> as a SYMLINK into its store path,
			// and DirEntry.IsDir() is false for a symlink-to-dir — which
			// would skip every plugin in an activated env.
			if info, err := os.Stat(full); err == nil && info.IsDir() {
				res.AgentDirs = append(res.AgentDirs, full)
			}
		}
		sort.Strings(res.AgentDirs)
	} else if !os.IsNotExist(err) {
		return nil, err
	}

	commonRoot := filepath.Join(shareDir, "flox", "common")
	plugins, err := os.ReadDir(commonRoot)
	if err != nil && !os.IsNotExist(err) {
		return nil, err
	}
	for _, p := range plugins {
		full := filepath.Join(commonRoot, p.Name())
		// Follow symlinks (see above) — common/<plugin> is also symlinked.
		if info, err := os.Stat(full); err != nil || !info.IsDir() {
			continue
		}
		rules, err := globFragments(filepath.Join(full, "rules"), "*.md")
		if err != nil {
			return nil, err
		}
		res.Rules = append(res.Rules, rules...)
	}
	sort.Slice(res.Rules, func(i, j int) bool { return res.Rules[i].Name < res.Rules[j].Name })

	return res, nil
}
