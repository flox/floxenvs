package doctor

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strings"

	"flox.dev/claude-managed/internal/discover"
)

type Issue struct {
	Type    string // "rules", "skills", "agents"
	Name    string // fragment name
	Path    string // file path
	Message string
}

func (i Issue) String() string {
	return fmt.Sprintf("[%s/%s] %s (%s)", i.Type, i.Name, i.Message, i.Path)
}

// CheckResult holds the outcome of a doctor check.
type CheckResult struct {
	Issues  []Issue
	Checked []CheckedFragment
}

// CheckedFragment records a fragment that was validated.
type CheckedFragment struct {
	Type string
	Name string
	OK   bool
}

// Check validates all fragments and returns detailed results.
func Check(frags *discover.Result) *CheckResult {
	r := &CheckResult{}

	for _, f := range frags.Rules {
		issues := validateRule(f)
		ok := len(issues) == 0
		r.Issues = append(r.Issues, issues...)
		r.Checked = append(r.Checked, CheckedFragment{Type: "rules", Name: f.Name, OK: ok})
	}

	for _, f := range frags.Skills {
		issues := validateSkill(f)
		ok := len(issues) == 0
		r.Issues = append(r.Issues, issues...)
		r.Checked = append(r.Checked, CheckedFragment{Type: "skills", Name: f.Name, OK: ok})
	}

	for _, f := range frags.Agents {
		issues := validateAgent(f)
		ok := len(issues) == 0
		r.Issues = append(r.Issues, issues...)
		r.Checked = append(r.Checked, CheckedFragment{Type: "agents", Name: f.Name, OK: ok})
	}

	for _, f := range frags.Plugins {
		issues := validatePlugin(f)
		ok := len(issues) == 0
		r.Issues = append(r.Issues, issues...)
		r.Checked = append(r.Checked, CheckedFragment{Type: "plugins", Name: f.Name, OK: ok})
	}

	return r
}

// Known frontmatter keys per fragment type.
var (
	ruleKeys = map[string]bool{
		"paths": true,
	}

	skillKeys = map[string]bool{
		"name":                     true,
		"description":              true,
		"when_to_use":              true,
		"argument-hint":            true,
		"disable-model-invocation": true,
		"user-invocable":           true,
		"allowed-tools":            true,
		"model":                    true,
		"effort":                   true,
		"context":                  true,
		"agent":                    true,
		"hooks":                    true,
		"paths":                    true,
		"shell":                    true,
	}

	agentKeys = map[string]bool{
		"name":            true,
		"description":     true,
		"model":           true,
		"effort":          true,
		"maxturns":        true,
		"disallowedtools": true,
		"tools":           true,
		"skills":          true,
		"memory":          true,
		"background":      true,
		"isolation":       true,
	}

	// Fields not allowed in agent definitions (security).
	agentDisallowed = map[string]bool{
		"hooks":          true,
		"mcpservers":     true,
		"permissionmode": true,
	}

	kebabRe = regexp.MustCompile(`^[a-z0-9]+(-[a-z0-9]+)*$`)
)

func validateRule(f discover.Fragment) []Issue {
	data, err := os.ReadFile(f.Path)
	if err != nil {
		return []Issue{{Type: "rules", Name: f.Name, Path: f.Path, Message: "file not readable"}}
	}

	var issues []Issue

	if !strings.HasSuffix(f.Path, ".md") {
		issues = append(issues, Issue{Type: "rules", Name: f.Name, Path: f.Path, Message: "must be a .md file"})
	}

	fm := parseFrontmatter(string(data))
	if fm != nil {
		for key := range fm {
			if !ruleKeys[key] {
				issues = append(issues, Issue{Type: "rules", Name: f.Name, Path: f.Path,
					Message: fmt.Sprintf("unknown frontmatter key %q (expected: paths)", key)})
			}
		}
	}

	return issues
}

func validateSkill(f discover.Fragment) []Issue {
	data, err := os.ReadFile(f.Path)
	if err != nil {
		return []Issue{{Type: "skills", Name: f.Name, Path: f.Path, Message: "SKILL.md not readable"}}
	}

	var issues []Issue

	// SKILL.md must exist in a directory named after the skill.
	if filepath.Base(f.Path) != "SKILL.md" {
		issues = append(issues, Issue{Type: "skills", Name: f.Name, Path: f.Path, Message: "skill entry point must be SKILL.md"})
	}

	fm := parseFrontmatter(string(data))
	if fm != nil {
		for key := range fm {
			if !skillKeys[key] {
				issues = append(issues, Issue{Type: "skills", Name: f.Name, Path: f.Path,
					Message: fmt.Sprintf("unknown frontmatter key %q", key)})
			}
		}

		// name must be kebab-case, max 64 chars.
		if name, ok := fm["name"]; ok {
			if len(name) > 64 {
				issues = append(issues, Issue{Type: "skills", Name: f.Name, Path: f.Path,
					Message: fmt.Sprintf("name %q exceeds 64 characters", name)})
			}
			if !kebabRe.MatchString(name) {
				issues = append(issues, Issue{Type: "skills", Name: f.Name, Path: f.Path,
					Message: fmt.Sprintf("name %q must be kebab-case", name)})
			}
		}

		// effort must be a known value.
		if effort, ok := fm["effort"]; ok {
			switch effort {
			case "low", "medium", "high", "max":
			default:
				issues = append(issues, Issue{Type: "skills", Name: f.Name, Path: f.Path,
					Message: fmt.Sprintf("effort %q must be low|medium|high|max", effort)})
			}
		}
	}

	return issues
}

func validateAgent(f discover.Fragment) []Issue {
	data, err := os.ReadFile(f.Path)
	if err != nil {
		return []Issue{{Type: "agents", Name: f.Name, Path: f.Path, Message: "file not readable"}}
	}

	var issues []Issue

	if !strings.HasSuffix(f.Path, ".md") {
		issues = append(issues, Issue{Type: "agents", Name: f.Name, Path: f.Path, Message: "must be a .md file"})
	}

	fm := parseFrontmatter(string(data))
	if fm != nil {
		for key := range fm {
			lower := strings.ToLower(key)
			if agentDisallowed[lower] {
				issues = append(issues, Issue{Type: "agents", Name: f.Name, Path: f.Path,
					Message: fmt.Sprintf("forbidden frontmatter key %q (security restriction)", key)})
			} else if !agentKeys[lower] {
				issues = append(issues, Issue{Type: "agents", Name: f.Name, Path: f.Path,
					Message: fmt.Sprintf("unknown frontmatter key %q", key)})
			}
		}

		// effort must be a known value.
		if effort, ok := fm["effort"]; ok {
			switch effort {
			case "low", "medium", "high", "max":
			default:
				issues = append(issues, Issue{Type: "agents", Name: f.Name, Path: f.Path,
					Message: fmt.Sprintf("effort %q must be low|medium|high|max", effort)})
			}
		}

		// isolation only supports "worktree".
		if iso, ok := fm["isolation"]; ok {
			if iso != "worktree" {
				issues = append(issues, Issue{Type: "agents", Name: f.Name, Path: f.Path,
					Message: fmt.Sprintf("isolation %q must be \"worktree\"", iso)})
			}
		}
	}

	return issues
}

func validatePlugin(f discover.Fragment) []Issue {
	var issues []Issue

	if _, err := os.Stat(f.Path); err != nil {
		return []Issue{{Type: "plugins", Name: f.Name,
			Path: f.Path, Message: "directory not readable"}}
	}

	// check .claude-plugin/plugin.json if present
	pluginJSON := filepath.Join(f.Path, ".claude-plugin", "plugin.json")
	if data, err := os.ReadFile(pluginJSON); err == nil {
		var obj map[string]interface{}
		if err := json.Unmarshal(data, &obj); err != nil {
			issues = append(issues, Issue{Type: "plugins", Name: f.Name,
				Path: pluginJSON, Message: "plugin.json: invalid JSON"})
		} else {
			name, ok := obj["name"]
			if !ok {
				issues = append(issues, Issue{Type: "plugins", Name: f.Name,
					Path: pluginJSON, Message: "plugin.json: missing \"name\" field"})
			} else if _, isStr := name.(string); !isStr {
				issues = append(issues, Issue{Type: "plugins", Name: f.Name,
					Path: pluginJSON, Message: "plugin.json: \"name\" must be a string"})
			}
		}
	}

	// at least one recognized component
	components := []string{".lsp.json", ".mcp.json", "skills", "agents", "hooks", "commands", "bin"}
	hasComponent := false
	for _, c := range components {
		if _, err := os.Stat(filepath.Join(f.Path, c)); err == nil {
			hasComponent = true
			break
		}
	}
	if !hasComponent {
		issues = append(issues, Issue{Type: "plugins", Name: f.Name,
			Path: f.Path, Message: "no recognized components found"})
	}

	// validate installed_plugins.json if present
	ipPath := filepath.Join(f.Path, "installed_plugins.json")
	if data, err := os.ReadFile(ipPath); err == nil {
		var obj map[string]interface{}
		if err := json.Unmarshal(data, &obj); err != nil {
			issues = append(issues, Issue{Type: "plugins", Name: f.Name,
				Path: ipPath, Message: "installed_plugins.json: invalid JSON"})
		}
	}

	// validate known_marketplaces.json if present
	kmPath := filepath.Join(f.Path, "known_marketplaces.json")
	if data, err := os.ReadFile(kmPath); err == nil {
		var obj map[string]interface{}
		if err := json.Unmarshal(data, &obj); err != nil {
			issues = append(issues, Issue{Type: "plugins", Name: f.Name,
				Path: kmPath, Message: "known_marketplaces.json: invalid JSON"})
		}
	}

	return issues
}

// ParseFrontmatterForTest is exported for testing only.
var ParseFrontmatterForTest = parseFrontmatter

// parseFrontmatter extracts YAML frontmatter key-value pairs from
// markdown content. Returns nil if no frontmatter block is found.
// Only handles simple "key: value" lines (no nested YAML).
func parseFrontmatter(content string) map[string]string {
	content = strings.TrimSpace(content)
	if !strings.HasPrefix(content, "---") {
		return nil
	}

	end := strings.Index(content[3:], "\n---")
	if end < 0 {
		return nil
	}

	block := content[3 : 3+end]
	result := make(map[string]string)

	for _, line := range strings.Split(block, "\n") {
		line = strings.TrimSpace(line)
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		// Skip list items (e.g. "  - value" under a key).
		if strings.HasPrefix(line, "-") || strings.HasPrefix(line, "  -") {
			continue
		}
		idx := strings.Index(line, ":")
		if idx < 0 {
			continue
		}
		key := strings.TrimSpace(line[:idx])
		val := strings.TrimSpace(line[idx+1:])
		val = strings.Trim(val, "\"'")
		if key != "" {
			result[key] = val
		}
	}

	return result
}
