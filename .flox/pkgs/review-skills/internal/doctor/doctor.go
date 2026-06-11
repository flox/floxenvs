// Package doctor implements `review-skills doctor`: it probes every linter in
// the tool registry for availability + version, smoke-tests that each one can
// actually execute against a valid embedded fixture, and resolves the default
// quality ensemble per kind so a missing default member is flagged loudly
// (making doctor usable as a CI preflight gate).
package doctor

import (
	"embed"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"flox.dev/review-skills/internal/detect"
	"flox.dev/review-skills/internal/tools"
)

// fixtures holds the minimal valid skill + agent artifacts the smoke test
// stages into a temp project. Embedding keeps doctor self-contained: it never
// depends on testdata/ or the caller's working directory.
//
//go:embed fixtures/*
var fixtures embed.FS

// Row is one line of the doctor availability table.
type Row struct {
	Tool    string
	State   string // ok | not-found | broken
	Version string
	Smoke   string // ok | fail | skip
}

// ResolveResult reports the resolved default quality ensemble for a kind.
type ResolveResult struct {
	Tools   []string // names of the kind's default quality ensemble
	Warning string   // names any default member missing from avail
	OK      bool     // false if any default member is unavailable
}

// Probe returns one Row per registered tool: its availability (via
// tools.Available) plus a smoke test confirming it can execute against a clean
// embedded fixture. A tool that is not "ok" is not smoke-tested (Smoke="skip").
func Probe() []Row {
	var rows []Row
	for _, t := range tools.Registry() {
		st := tools.Available(t)
		row := Row{Tool: t.Name, State: st.State, Version: st.Version}
		if st.State != "ok" {
			row.Smoke = "skip"
		} else if smoke(t) {
			row.Smoke = "ok"
		} else {
			row.Smoke = "fail"
		}
		rows = append(rows, row)
	}
	return rows
}

// smoke runs the tool's real argv against a clean embedded fixture and reports
// whether the binary actually executed. A linter that exits nonzero while
// emitting output still counts as a successful smoke (it ran and produced
// findings); Smoke is "fail" only when the binary could not execute at all or
// produced nothing on either stream.
func smoke(t tools.Tool) bool {
	kind := smokeKind(t)
	dir, err := os.MkdirTemp("", "review-skills-doctor-")
	if err != nil {
		return false
	}
	defer os.RemoveAll(dir)

	artifact, runDir, ok := stageFixture(t, kind, dir)
	if !ok {
		return false
	}

	cmd := exec.Command(t.Bin, t.RunArgs(kind, artifact)...)
	cmd.Dir = runDir
	out, err := cmd.CombinedOutput()
	if err != nil {
		// A nonzero exit that still produced output is a healthy linter run
		// (e.g. it found issues in the fixture). Only a launch failure or a
		// silent crash counts as a smoke failure.
		if _, isExit := err.(*exec.ExitError); isExit && len(out) > 0 {
			return true
		}
		return false
	}
	return true
}

// smokeKind picks which fixture to smoke a tool with: its first supported kind.
func smokeKind(t tools.Tool) detect.Kind {
	if len(t.Kinds) > 0 {
		return t.Kinds[0]
	}
	return detect.KindSkill
}

// stageFixture writes the embedded fixture for kind into dir. For Stage tools
// (claudelint/cclint) it builds a .claude/{skills,agents}/<name>/ project and
// returns (artifactPath, projectRoot); otherwise the tool runs against the
// artifact directly and runDir is dir. The bool reports staging success.
func stageFixture(t tools.Tool, kind detect.Kind, dir string) (artifact, runDir string, ok bool) {
	if kind == detect.KindAgent {
		data, err := fixtures.ReadFile("fixtures/agent.md")
		if err != nil {
			return "", "", false
		}
		if t.Stage {
			adir := filepath.Join(dir, ".claude", "agents")
			if err := os.MkdirAll(adir, 0o755); err != nil {
				return "", "", false
			}
			p := filepath.Join(adir, "doctor-smoke.md")
			if os.WriteFile(p, data, 0o644) != nil {
				return "", "", false
			}
			return p, dir, true
		}
		p := filepath.Join(dir, "doctor-smoke.md")
		if os.WriteFile(p, data, 0o644) != nil {
			return "", "", false
		}
		return p, dir, true
	}

	data, err := fixtures.ReadFile("fixtures/skill/SKILL.md")
	if err != nil {
		return "", "", false
	}
	if t.Stage {
		sdir := filepath.Join(dir, ".claude", "skills", "doctor-smoke")
		if err := os.MkdirAll(sdir, 0o755); err != nil {
			return "", "", false
		}
		if os.WriteFile(filepath.Join(sdir, "SKILL.md"), data, 0o644) != nil {
			return "", "", false
		}
		return sdir, dir, true
	}
	sdir := filepath.Join(dir, "doctor-smoke")
	if err := os.MkdirAll(sdir, 0o755); err != nil {
		return "", "", false
	}
	if os.WriteFile(filepath.Join(sdir, "SKILL.md"), data, 0o644) != nil {
		return "", "", false
	}
	return sdir, dir, true
}

// Resolve reports the default quality ensemble for kind and flags any default
// member absent from avail. OK is false when any default member is missing, so
// `doctor` can exit nonzero and gate CI.
func Resolve(kind detect.Kind, avail map[string]bool) ResolveResult {
	res := ResolveResult{OK: true}
	var missing []string
	for _, t := range tools.QualityTools(kind) {
		res.Tools = append(res.Tools, t.Name)
		if !avail[t.Name] {
			missing = append(missing, t.Name)
			res.OK = false
		}
	}
	if len(missing) > 0 {
		res.Warning = strings.Join(missing, ", ") + " missing"
	}
	return res
}
