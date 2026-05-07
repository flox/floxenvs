package doctor

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strings"

	"gopkg.in/yaml.v3"

	"flox.dev/claude-managed/internal/discover"
)

// Severity classifies an Issue. Errors mean the fragment is broken;
// warnings flag noteworthy state (unknown keys, exceeded length limits)
// without failing the fragment.
type Severity int

const (
	SeverityError Severity = iota
	SeverityWarning
)

type Issue struct {
	Type     string // "rules", "skills", "agents"
	Name     string // fragment name
	Path     string // file path
	Message  string
	Severity Severity
}

// IsError reports whether the issue blocks the fragment from loading.
func (i Issue) IsError() bool { return i.Severity == SeverityError }

func (i Issue) String() string {
	prefix := "ERROR"
	if i.Severity == SeverityWarning {
		prefix = "WARN"
	}
	return fmt.Sprintf("[%s/%s] %s: %s (%s)", i.Type, i.Name, prefix, i.Message, i.Path)
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

// Errors returns only the error-severity issues.
func (cr *CheckResult) Errors() []Issue {
	var out []Issue
	for _, i := range cr.Issues {
		if i.IsError() {
			out = append(out, i)
		}
	}
	return out
}

// Warnings returns only the warning-severity issues.
func (cr *CheckResult) Warnings() []Issue {
	var out []Issue
	for _, i := range cr.Issues {
		if !i.IsError() {
			out = append(out, i)
		}
	}
	return out
}

// Check validates all fragments and returns detailed results.
func Check(frags *discover.Result) *CheckResult {
	r := &CheckResult{}

	for _, f := range frags.Rules {
		issues := validateRule(f)
		r.Issues = append(r.Issues, issues...)
		r.Checked = append(r.Checked, CheckedFragment{Type: "rules", Name: f.Name, OK: !hasError(issues)})
	}

	for _, f := range frags.Skills {
		issues := validateSkill(f)
		r.Issues = append(r.Issues, issues...)
		r.Checked = append(r.Checked, CheckedFragment{Type: "skills", Name: f.Name, OK: !hasError(issues)})
	}

	for _, f := range frags.Agents {
		issues := validateAgent(f)
		r.Issues = append(r.Issues, issues...)
		r.Checked = append(r.Checked, CheckedFragment{Type: "agents", Name: f.Name, OK: !hasError(issues)})
	}

	for _, f := range frags.Plugins {
		issues := validatePlugin(f)
		r.Issues = append(r.Issues, issues...)
		r.Checked = append(r.Checked, CheckedFragment{Type: "plugins", Name: f.Name, OK: !hasError(issues)})
	}

	return r
}

func hasError(issues []Issue) bool {
	for _, i := range issues {
		if i.IsError() {
			return true
		}
	}
	return false
}

// Known frontmatter keys per fragment type.
var (
	ruleKeys = map[string]bool{
		"paths": true,
	}

	// specSkillKeys is the closed set of top-level keys defined by the
	// agentskills.io open standard. Source:
	//   https://agentskills.io/specification
	specSkillKeys = map[string]bool{
		"name":          true,
		"description":   true,
		"license":       true,
		"compatibility": true,
		"metadata":      true,
		"allowed-tools": true,
	}

	// ccExtensionKeys are vendor extensions added by Claude Code on top
	// of the agentskills.io spec. Source:
	//   https://code.claude.com/docs/en/skills
	ccExtensionKeys = map[string]bool{
		"when_to_use":              true,
		"argument-hint":            true,
		"arguments":                true,
		"disable-model-invocation": true,
		"user-invocable":           true,
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

// Spec-defined length limits (agentskills.io).
const (
	maxDescriptionLen   = 1024
	maxCompatibilityLen = 500
	maxNameLen          = 64
)

func validateRule(f discover.Fragment) []Issue {
	data, err := os.ReadFile(f.Path)
	if err != nil {
		return []Issue{{Type: "rules", Name: f.Name, Path: f.Path,
			Severity: SeverityError, Message: "file not readable"}}
	}

	var issues []Issue

	if !strings.HasSuffix(f.Path, ".md") {
		issues = append(issues, Issue{Type: "rules", Name: f.Name, Path: f.Path,
			Severity: SeverityError, Message: "must be a .md file"})
	}

	fm, err := parseFrontmatter(string(data))
	if err != nil {
		issues = append(issues, Issue{Type: "rules", Name: f.Name, Path: f.Path,
			Severity: SeverityError, Message: "frontmatter: invalid YAML: " + err.Error()})
		return issues
	}
	if fm == nil {
		return issues
	}
	for key := range fm {
		if !ruleKeys[key] {
			issues = append(issues, Issue{Type: "rules", Name: f.Name, Path: f.Path,
				Severity: SeverityWarning,
				Message:  fmt.Sprintf("unknown frontmatter key %q (expected: paths)", key)})
		}
	}

	return issues
}

func validateSkill(f discover.Fragment) []Issue {
	data, err := os.ReadFile(f.Path)
	if err != nil {
		return []Issue{{Type: "skills", Name: f.Name, Path: f.Path,
			Severity: SeverityError, Message: "SKILL.md not readable"}}
	}

	var issues []Issue

	if filepath.Base(f.Path) != "SKILL.md" {
		issues = append(issues, Issue{Type: "skills", Name: f.Name, Path: f.Path,
			Severity: SeverityError, Message: "skill entry point must be SKILL.md"})
	}

	fm, err := parseFrontmatter(string(data))
	if err != nil {
		issues = append(issues, Issue{Type: "skills", Name: f.Name, Path: f.Path,
			Severity: SeverityError, Message: "frontmatter: invalid YAML: " + err.Error()})
		return issues
	}
	if fm == nil {
		return issues
	}

	for key := range fm {
		if specSkillKeys[key] || ccExtensionKeys[key] {
			continue
		}
		issues = append(issues, Issue{Type: "skills", Name: f.Name, Path: f.Path,
			Severity: SeverityWarning,
			Message: fmt.Sprintf(
				"unknown frontmatter key %q — agentskills.io recommends nesting non-standard fields under \"metadata:\"",
				key)})
	}

	// name: required, kebab-case, ≤64 chars.
	name, hasName := stringField(fm, "name")
	if !hasName {
		issues = append(issues, Issue{Type: "skills", Name: f.Name, Path: f.Path,
			Severity: SeverityError, Message: `missing required frontmatter key "name"`})
	} else {
		if len(name) > maxNameLen {
			issues = append(issues, Issue{Type: "skills", Name: f.Name, Path: f.Path,
				Severity: SeverityError,
				Message:  fmt.Sprintf("name %q exceeds %d characters", name, maxNameLen)})
		}
		if !kebabRe.MatchString(name) {
			issues = append(issues, Issue{Type: "skills", Name: f.Name, Path: f.Path,
				Severity: SeverityError,
				Message:  fmt.Sprintf("name %q must be kebab-case", name)})
		}
	}

	// description: required, ≤1024 chars (warning if exceeded).
	desc, hasDesc := stringField(fm, "description")
	if !hasDesc {
		issues = append(issues, Issue{Type: "skills", Name: f.Name, Path: f.Path,
			Severity: SeverityError, Message: `missing required frontmatter key "description"`})
	} else if len(desc) > maxDescriptionLen {
		issues = append(issues, Issue{Type: "skills", Name: f.Name, Path: f.Path,
			Severity: SeverityWarning,
			Message:  fmt.Sprintf("description is %d characters, agentskills.io recommends ≤%d", len(desc), maxDescriptionLen)})
	}

	// compatibility: ≤500 chars (warning if exceeded).
	if compat, ok := stringField(fm, "compatibility"); ok && len(compat) > maxCompatibilityLen {
		issues = append(issues, Issue{Type: "skills", Name: f.Name, Path: f.Path,
			Severity: SeverityWarning,
			Message:  fmt.Sprintf("compatibility is %d characters, agentskills.io recommends ≤%d", len(compat), maxCompatibilityLen)})
	}

	// effort: must be a known value.
	if effort, ok := stringField(fm, "effort"); ok {
		switch effort {
		case "low", "medium", "high", "max":
		default:
			issues = append(issues, Issue{Type: "skills", Name: f.Name, Path: f.Path,
				Severity: SeverityError,
				Message:  fmt.Sprintf("effort %q must be low|medium|high|max", effort)})
		}
	}

	return issues
}

func validateAgent(f discover.Fragment) []Issue {
	data, err := os.ReadFile(f.Path)
	if err != nil {
		return []Issue{{Type: "agents", Name: f.Name, Path: f.Path,
			Severity: SeverityError, Message: "file not readable"}}
	}

	var issues []Issue

	if !strings.HasSuffix(f.Path, ".md") {
		issues = append(issues, Issue{Type: "agents", Name: f.Name, Path: f.Path,
			Severity: SeverityError, Message: "must be a .md file"})
	}

	fm, err := parseFrontmatter(string(data))
	if err != nil {
		issues = append(issues, Issue{Type: "agents", Name: f.Name, Path: f.Path,
			Severity: SeverityError, Message: "frontmatter: invalid YAML: " + err.Error()})
		return issues
	}
	if fm == nil {
		return issues
	}

	for key := range fm {
		lower := strings.ToLower(key)
		if agentDisallowed[lower] {
			issues = append(issues, Issue{Type: "agents", Name: f.Name, Path: f.Path,
				Severity: SeverityError,
				Message:  fmt.Sprintf("forbidden frontmatter key %q (security restriction)", key)})
		} else if !agentKeys[lower] {
			issues = append(issues, Issue{Type: "agents", Name: f.Name, Path: f.Path,
				Severity: SeverityWarning,
				Message:  fmt.Sprintf("unknown frontmatter key %q", key)})
		}
	}

	if effort, ok := stringField(fm, "effort"); ok {
		switch effort {
		case "low", "medium", "high", "max":
		default:
			issues = append(issues, Issue{Type: "agents", Name: f.Name, Path: f.Path,
				Severity: SeverityError,
				Message:  fmt.Sprintf("effort %q must be low|medium|high|max", effort)})
		}
	}

	if iso, ok := stringField(fm, "isolation"); ok && iso != "worktree" {
		issues = append(issues, Issue{Type: "agents", Name: f.Name, Path: f.Path,
			Severity: SeverityError,
			Message:  fmt.Sprintf("isolation %q must be \"worktree\"", iso)})
	}

	return issues
}

func validatePlugin(f discover.Fragment) []Issue {
	var issues []Issue

	if _, err := os.Stat(f.Path); err != nil {
		return []Issue{{Type: "plugins", Name: f.Name, Path: f.Path,
			Severity: SeverityError, Message: "directory not readable"}}
	}

	pluginJSON := filepath.Join(f.Path, ".claude-plugin", "plugin.json")
	if data, err := os.ReadFile(pluginJSON); err == nil {
		var obj map[string]interface{}
		if err := json.Unmarshal(data, &obj); err != nil {
			issues = append(issues, Issue{Type: "plugins", Name: f.Name, Path: pluginJSON,
				Severity: SeverityError, Message: "plugin.json: invalid JSON"})
		} else {
			name, ok := obj["name"]
			if !ok {
				issues = append(issues, Issue{Type: "plugins", Name: f.Name, Path: pluginJSON,
					Severity: SeverityError, Message: "plugin.json: missing \"name\" field"})
			} else if _, isStr := name.(string); !isStr {
				issues = append(issues, Issue{Type: "plugins", Name: f.Name, Path: pluginJSON,
					Severity: SeverityError, Message: "plugin.json: \"name\" must be a string"})
			}
		}
	}

	components := []string{".lsp.json", ".mcp.json", "skills", "agents", "hooks", "commands", "bin"}
	hasComponent := false
	for _, c := range components {
		if _, err := os.Stat(filepath.Join(f.Path, c)); err == nil {
			hasComponent = true
			break
		}
	}
	if !hasComponent {
		issues = append(issues, Issue{Type: "plugins", Name: f.Name, Path: f.Path,
			Severity: SeverityError, Message: "no recognized components found"})
	}

	ipPath := filepath.Join(f.Path, "installed_plugins.json")
	if data, err := os.ReadFile(ipPath); err == nil {
		var obj map[string]interface{}
		if err := json.Unmarshal(data, &obj); err != nil {
			issues = append(issues, Issue{Type: "plugins", Name: f.Name, Path: ipPath,
				Severity: SeverityError, Message: "installed_plugins.json: invalid JSON"})
		}
	}

	kmPath := filepath.Join(f.Path, "known_marketplaces.json")
	if data, err := os.ReadFile(kmPath); err == nil {
		var obj map[string]interface{}
		if err := json.Unmarshal(data, &obj); err != nil {
			issues = append(issues, Issue{Type: "plugins", Name: f.Name, Path: kmPath,
				Severity: SeverityError, Message: "known_marketplaces.json: invalid JSON"})
		}
	}

	return issues
}

// stringField returns the string value at key (if present and a string).
func stringField(fm map[string]any, key string) (string, bool) {
	v, ok := fm[key]
	if !ok {
		return "", false
	}
	s, ok := v.(string)
	if !ok {
		return "", false
	}
	return s, true
}

// ParseFrontmatterForTest is exported for testing only.
var ParseFrontmatterForTest = parseFrontmatter

// parseFrontmatter extracts the YAML mapping at the top of a markdown
// document. Returns (nil, nil) when no frontmatter block is present or
// when the closing `---` is missing. Returns an error only on YAML
// parse failure inside an otherwise well-formed `---`-delimited block.
func parseFrontmatter(content string) (map[string]any, error) {
	content = strings.TrimSpace(content)
	if !strings.HasPrefix(content, "---") {
		return nil, nil
	}
	rest := content[3:]
	// Require the opener to terminate with a newline (or be the only line).
	if !strings.HasPrefix(rest, "\n") && rest != "" {
		return nil, nil
	}
	end := strings.Index(rest, "\n---")
	if end < 0 {
		return nil, nil
	}
	block := rest[:end]

	var fm map[string]any
	if err := yaml.Unmarshal([]byte(block), &fm); err != nil {
		return nil, err
	}
	return fm, nil
}
