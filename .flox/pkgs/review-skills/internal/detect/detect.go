// Package detect classifies a path as a Claude skill or agent.
package detect

import (
	"os"
	"path/filepath"
	"strings"
)

type Kind string

const (
	KindSkill Kind = "skill"
	KindAgent Kind = "agent"
)

var agentKeys = []string{"model:", "tools:", "disallowedTools:", "permissionMode:", "color:", "maxTurns:"}

// Detect returns KindSkill for a dir containing SKILL.md, KindAgent for a
// .md whose frontmatter carries agent-only keys or lives under agents/.
// Defaults to KindSkill.
func Detect(path string) Kind {
	if fi, err := os.Stat(path); err == nil && fi.IsDir() {
		if _, err := os.Stat(filepath.Join(path, "SKILL.md")); err == nil {
			return KindSkill
		}
	}
	if data, err := os.ReadFile(path); err == nil {
		fm := frontmatter(string(data))
		for _, k := range agentKeys {
			for _, line := range strings.Split(fm, "\n") {
				if strings.HasPrefix(strings.TrimSpace(line), k) {
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
