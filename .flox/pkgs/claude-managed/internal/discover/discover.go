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

// Scan walks baseDir and classifies fragments.
// Returns empty result (no error) if baseDir does not exist.
func Scan(baseDir string) (*Result, error) {
	result := &Result{}

	if _, err := os.Stat(baseDir); os.IsNotExist(err) {
		return result, nil
	}

	// rules/*.md
	rules, err := globFragments(filepath.Join(baseDir, "rules"), "*.md")
	if err != nil {
		return nil, err
	}
	result.Rules = rules

	// skills/*/SKILL.md (directory-based)
	skills, err := scanSkills(filepath.Join(baseDir, "skills"))
	if err != nil {
		return nil, err
	}
	result.Skills = skills

	// agents/*.md
	agents, err := globFragments(filepath.Join(baseDir, "agents"), "*.md")
	if err != nil {
		return nil, err
	}
	result.Agents = agents

	// plugins/*/
	plugins, err := scanPlugins(filepath.Join(baseDir, "plugins"))
	if err != nil {
		return nil, err
	}
	result.Plugins = plugins

	return result, nil
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

// scanPlugins looks for plugins/*/ directory entries.
func scanPlugins(pluginsDir string) ([]Fragment, error) {
	if _, err := os.Stat(pluginsDir); os.IsNotExist(err) {
		return nil, nil
	}

	entries, err := os.ReadDir(pluginsDir)
	if err != nil {
		return nil, err
	}

	var fragments []Fragment
	for _, entry := range entries {
		if !entry.IsDir() {
			continue
		}
		fragments = append(fragments, Fragment{
			Name: entry.Name(),
			Path: filepath.Join(pluginsDir, entry.Name()),
		})
	}

	sort.Slice(fragments, func(i, j int) bool {
		return fragments[i].Name < fragments[j].Name
	})

	return fragments, nil
}

// scanSkills looks for skills/*/SKILL.md entries.
func scanSkills(skillsDir string) ([]Fragment, error) {
	if _, err := os.Stat(skillsDir); os.IsNotExist(err) {
		return nil, nil
	}

	entries, err := os.ReadDir(skillsDir)
	if err != nil {
		return nil, err
	}

	var fragments []Fragment
	for _, entry := range entries {
		if !entry.IsDir() {
			continue
		}
		skillFile := filepath.Join(skillsDir, entry.Name(), "SKILL.md")
		if _, err := os.Stat(skillFile); err == nil {
			fragments = append(fragments, Fragment{
				Name: entry.Name(),
				Path: skillFile,
			})
		}
	}

	sort.Slice(fragments, func(i, j int) bool {
		return fragments[i].Name < fragments[j].Name
	})

	return fragments, nil
}
