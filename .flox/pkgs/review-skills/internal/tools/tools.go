// Package tools is the registry of underlying linters review-skills runs.
// It is the single source of truth for each tool's invocation, scoring,
// finding collection, and ensemble weight.
package tools

import (
	"fmt"
	"os/exec"
	"strings"

	"flox.dev/review-skills/internal/detect"
	"flox.dev/review-skills/internal/findings"
)

// Tool is one registry entry.
type Tool struct {
	Name      string
	Bin       string
	Kinds     []detect.Kind
	Weight    map[detect.Kind]int // default ensemble weight per kind
	Dimension string              // "quality" | "security"
	Stage     bool                // needs a temp .claude project (claudelint/cclint)
	RunArgs   func(kind detect.Kind, path string) []string
	Score     func(out []byte) (int, bool)
	Collect   func(out []byte) []findings.Finding
}

func supports(t Tool, k detect.Kind) bool {
	for _, kk := range t.Kinds {
		if kk == k {
			return true
		}
	}
	return false
}

// Registry returns every known tool with the design's default weights.
func Registry() []Tool {
	both := []detect.Kind{detect.KindSkill, detect.KindAgent}
	return []Tool{
		{
			Name: "skill-tools", Bin: "skill-tools",
			Kinds:  []detect.Kind{detect.KindSkill},
			Weight: map[detect.Kind]int{detect.KindSkill: 40},
			Dimension: "quality",
			RunArgs:   func(_ detect.Kind, p string) []string { return []string{"score", p, "-f", "json"} },
			Score:     scoreSkillTools,
			Collect:   collectSkillTools,
		},
		{
			Name: "skill-validator", Bin: "skill-validator",
			Kinds:  []detect.Kind{detect.KindSkill},
			Weight: map[detect.Kind]int{detect.KindSkill: 30},
			Dimension: "quality",
			RunArgs:   func(_ detect.Kind, p string) []string { return []string{"check", p, "-o", "json"} },
			Score:     func(b []byte) (int, bool) { return scoreErrWarn(b, "errors", "warnings") },
			Collect:   collectSkillValidator,
		},
		{
			Name: "claudelint", Bin: "claudelint", Stage: true,
			Kinds:  both,
			Weight: map[detect.Kind]int{detect.KindSkill: 30, detect.KindAgent: 50},
			Dimension: "quality",
			RunArgs:   func(_ detect.Kind, _ string) []string { return []string{"check-all", "--format", "json"} },
			Score:     func(b []byte) (int, bool) { return scoreErrWarn(b, "errorCount", "warningCount") },
			Collect:   collectClaudelint,
		},
		{
			Name: "agnix", Bin: "agnix",
			Kinds:  []detect.Kind{detect.KindAgent},
			Weight: map[detect.Kind]int{detect.KindAgent: 30},
			Dimension: "quality",
			RunArgs: func(_ detect.Kind, p string) []string {
				return []string{"--format", "json", "--target", "claude-code", p}
			},
			Score:   scoreAgnix,
			Collect: collectAgnix,
		},
		{
			Name: "cclint", Bin: "cclint", Stage: true,
			Kinds:  []detect.Kind{detect.KindAgent},
			Weight: map[detect.Kind]int{detect.KindAgent: 20},
			Dimension: "quality",
			RunArgs:   func(_ detect.Kind, _ string) []string { return []string{"--format", "json"} },
			Score:     func(b []byte) (int, bool) { return scoreErrWarn(b, "totalErrors", "totalWarnings") },
			Collect:   collectCclint,
		},
		{
			Name: "skillcheck", Bin: "skillcheck",
			Kinds:     both,
			Weight:    map[detect.Kind]int{},
			Dimension: "security",
			RunArgs:   func(_ detect.Kind, p string) []string { return []string{p, "--format", "sarif"} },
			Collect:   collectSkillcheck,
		},
	}
}

// QualityTools returns the registry's quality tools that support the kind.
func QualityTools(kind detect.Kind) []Tool {
	var out []Tool
	for _, t := range Registry() {
		if t.Dimension == "quality" && supports(t, kind) {
			out = append(out, t)
		}
	}
	return out
}

// Find returns a registered tool by name.
func Find(name string) (Tool, bool) {
	for _, t := range Registry() {
		if t.Name == name {
			return t, true
		}
	}
	return Tool{}, false
}

// Select returns the quality ensemble for a kind, applying --tools (exact
// subset) or --disable (drop). The two are mutually exclusive. Unknown
// names error. Disabling every quality tool errors.
func Select(kind detect.Kind, tools, disable string) ([]Tool, error) {
	if tools != "" && disable != "" {
		return nil, fmt.Errorf("--tools and --disable are mutually exclusive")
	}
	quality := QualityTools(kind)
	byName := map[string]Tool{}
	for _, t := range quality {
		byName[t.Name] = t
	}
	if tools != "" {
		var out []Tool
		for _, n := range splitCSV(tools) {
			t, ok := byName[n]
			if !ok {
				return nil, fmt.Errorf("unknown tool for kind %s: %s", kind, n)
			}
			out = append(out, t)
		}
		if len(out) == 0 {
			return nil, fmt.Errorf("--tools selected no tools")
		}
		return out, nil
	}
	if disable != "" {
		drop := map[string]bool{}
		for _, n := range splitCSV(disable) {
			if _, ok := byName[n]; !ok {
				return nil, fmt.Errorf("unknown tool for kind %s: %s", kind, n)
			}
			drop[n] = true
		}
		var out []Tool
		for _, t := range quality {
			if !drop[t.Name] {
				out = append(out, t)
			}
		}
		if len(out) == 0 {
			return nil, fmt.Errorf("--disable removed every quality tool")
		}
		return out, nil
	}
	return quality, nil
}

func splitCSV(s string) []string {
	var out []string
	for _, p := range strings.Split(s, ",") {
		if p = strings.TrimSpace(p); p != "" {
			out = append(out, p)
		}
	}
	return out
}

// Status is a doctor availability result.
type Status struct {
	State   string // "ok" | "not-found" | "broken"
	Version string
}

// Available probes the tool binary with --version.
func Available(t Tool) Status {
	path, err := exec.LookPath(t.Bin)
	if err != nil {
		return Status{State: "not-found"}
	}
	out, err := exec.Command(path, "--version").CombinedOutput()
	if err != nil {
		return Status{State: "broken"}
	}
	return Status{State: "ok", Version: firstLine(strings.TrimSpace(string(out)))}
}

func firstLine(s string) string {
	if i := strings.IndexByte(s, '\n'); i >= 0 {
		return s[:i]
	}
	return s
}
