package tui

import (
	"path/filepath"
	"strings"

	"flox.dev/flox-ai/internal/audit/audit"
	"flox.dev/flox-ai/internal/audit/detect"
	"flox.dev/flox-ai/internal/discover"
	"flox.dev/flox-ai/internal/doctor"
)

// Auditor produces structured review results: a per-tool availability check
// (doctor) and a 0-100 audit per present skill/agent. ReviewSkills implements
// it against the in-process engine; tests inject a fake.
type Auditor interface {
	DoctorTools(shareDir string) ([]toolStatus, error)
	Audit(shareDir string) ([]auditResult, error)
}

// toolStatus is one row of `review-skills doctor`: a quality tool and whether
// it is available on PATH.
type toolStatus struct {
	Name  string
	State string // "found", "not-found", …
}

func (t toolStatus) missing() bool { return t.State == "not-found" }

// auditCheck is one weighted quality check within an audit (e.g. claudelint).
type auditCheck struct {
	ID     string `json:"id"`
	Weight int    `json:"weight"`
	Note   string `json:"note"`
	Pass   bool   `json:"pass"`
}

// auditFinding is a single diagnostic finding from a quality/security tool.
type auditFinding struct {
	Tool, Severity, Rule, Message, File string
	Line                                int
}

// auditResult is the parsed audit of a single skill/agent.
type auditResult struct {
	Kind        string
	Name        string
	Overall     int
	Status      string
	Quality     int
	Checks      []auditCheck
	Reliability int
	Security    int
	SecSeverity string
	Impact      int
	Findings    []auditFinding
	Raw         map[string]string
	Err         string
}

// fromEngine converts an audit.Result into the TUI's auditResult.
func fromEngine(r audit.Result) auditResult {
	checks := make([]auditCheck, len(r.Quality.Checks))
	for i, c := range r.Quality.Checks {
		checks[i] = auditCheck{ID: c.ID, Weight: c.Weight, Note: c.Note, Pass: c.Pass}
	}
	fs := make([]auditFinding, len(r.Findings))
	for i, f := range r.Findings {
		fs[i] = auditFinding{Tool: f.Tool, Severity: f.Severity, Rule: f.Rule, Message: f.Message, File: f.File, Line: f.Line}
	}
	return auditResult{
		Kind: r.Identity.Kind, Name: r.Identity.Name,
		Overall: r.Overall, Status: r.Status,
		Quality: r.Quality.Score, Checks: checks,
		Reliability: r.Reliability.Score, Security: r.Security.Score,
		SecSeverity: r.Security.Severity, Impact: r.Impact.Score,
		Findings: fs, Raw: r.RawByTool,
	}
}

// reviewTargets returns the present skills/agents with their kind.
func reviewTargets(shareDir string) ([]struct {
	kind string
	frag discover.Fragment
}, error) {
	frags, err := discover.Scan(shareDir)
	if err != nil {
		return nil, err
	}
	var out []struct {
		kind string
		frag discover.Fragment
	}
	for _, f := range frags.Skills {
		out = append(out, struct {
			kind string
			frag discover.Fragment
		}{"skill", f})
	}
	for _, f := range frags.Agents {
		out = append(out, struct {
			kind string
			frag discover.Fragment
		}{"agent", f})
	}
	return out, nil
}

// targetDir resolves a fragment to the directory review-skills expects.
func targetDir(p string) string {
	if strings.HasSuffix(p, ".md") {
		return filepath.Dir(p)
	}
	return p
}

// Audit runs the in-process audit engine for each present skill/agent.
func (ReviewSkills) Audit(shareDir string) ([]auditResult, error) {
	targets, err := reviewTargets(shareDir)
	if err != nil {
		return nil, err
	}
	var out []auditResult
	for _, t := range targets {
		res, runErr := audit.Run(audit.Options{
			Path:       targetDir(t.frag.Path),
			Kind:       detect.Kind(t.kind),
			Findings:   true,
			IncludeRaw: true,
		})
		ar := fromEngine(res)
		if ar.Name == "" {
			ar.Name = t.frag.Name
		}
		if runErr != nil {
			ar.Status, ar.Err = "error", runErr.Error()
		}
		out = append(out, ar)
	}
	return out, nil
}

// DoctorTools calls the in-process doctor probe for per-tool availability.
func (ReviewSkills) DoctorTools(shareDir string) ([]toolStatus, error) {
	var out []toolStatus
	for _, r := range doctor.Probe() {
		state := "found"
		if r.State != "ok" {
			state = "not-found"
		}
		out = append(out, toolStatus{Name: r.Tool, State: state})
	}
	return out, nil
}

// missingTools returns the names of unavailable quality tools.
func missingTools(tools []toolStatus) []string {
	var out []string
	for _, t := range tools {
		if t.missing() {
			out = append(out, t.Name)
		}
	}
	return out
}

// missingToolPkgs maps each missing tool to its flox catalog package
// (review tools publish as "flox/<tool>").
func missingToolPkgs(tools []toolStatus) []string {
	miss := missingTools(tools)
	pkgs := make([]string, len(miss))
	for i, name := range miss {
		pkgs[i] = "flox/" + name
	}
	return pkgs
}

func (m model) reviewSel() (auditResult, bool) {
	if len(m.reviewResults) == 0 {
		return auditResult{}, false
	}
	return m.reviewResults[clamp(m.reviewCur[0], 0, len(m.reviewResults)-1)], true
}

func (m model) reviewSelTool() string {
	sel, ok := m.reviewSel()
	if !ok || len(sel.Checks) == 0 {
		return ""
	}
	return sel.Checks[clamp(m.reviewCur[1], 0, len(sel.Checks)-1)].ID
}

func (m model) reviewFindings() []auditFinding {
	sel, ok := m.reviewSel()
	if !ok {
		return nil
	}
	tool := m.reviewSelTool()
	var out []auditFinding
	for _, f := range sel.Findings {
		if f.Tool == tool {
			out = append(out, f)
		}
	}
	return out
}

func (m model) reviewPaneLen(i int) int {
	switch i {
	case 0:
		return len(m.reviewResults)
	case 1:
		if sel, ok := m.reviewSel(); ok {
			return len(sel.Checks)
		}
	case 2:
		return len(m.reviewFindings())
	}
	return 0 // pane 3 (raw) scrolls, not a list
}
