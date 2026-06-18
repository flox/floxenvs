// Package detect classifies a path as a Claude skill or agent.
package detect

import (
	"os"
	"path/filepath"
	"strings"

	"gopkg.in/yaml.v3"
)

type Kind string

const (
	KindSkill Kind = "skill"
	KindAgent Kind = "agent"
)

// agentKeys are frontmatter fields only an agent definition carries.
var agentKeys = []string{"model", "tools", "disallowedTools", "permissionMode", "color", "maxTurns"}

// Detect returns KindSkill for a directory containing SKILL.md, KindAgent for
// a .md whose top-level frontmatter carries an agent-only key, or which lives
// under an agents/ path. Defaults to KindSkill. Parsing the frontmatter as
// YAML (rather than scanning line prefixes) avoids classifying a body or a
// nested/indented key as an agent signal.
func Detect(path string) Kind {
	if fi, err := os.Stat(path); err == nil && fi.IsDir() {
		if _, err := os.Stat(filepath.Join(path, "SKILL.md")); err == nil {
			return KindSkill
		}
	}
	if data, err := os.ReadFile(path); err == nil {
		var doc map[string]any
		if yaml.Unmarshal([]byte(frontmatter(string(data))), &doc) == nil {
			for _, k := range agentKeys {
				if _, ok := doc[k]; ok {
					return KindAgent
				}
			}
		}
		if strings.Contains(filepath.ToSlash(path), "/agents/") {
			return KindAgent
		}
	}
	return KindSkill
}

// frontmatter returns the text between the first two --- fences.
func frontmatter(s string) string {
	lines := strings.Split(s, "\n")
	if len(lines) == 0 || strings.TrimSpace(lines[0]) != "---" {
		return ""
	}
	var out []string
	for _, l := range lines[1:] {
		if strings.TrimSpace(l) == "---" {
			break
		}
		out = append(out, l)
	}
	return strings.Join(out, "\n")
}
