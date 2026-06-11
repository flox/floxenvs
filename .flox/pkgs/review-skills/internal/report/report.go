// Package report runs the selected tools and returns each one's raw native
// output verbatim — the "what would I see running these by hand" view, with
// no scoring or normalization. It backs the `report` command.
package report

import (
	"os"
	"os/exec"
	"path/filepath"

	"flox.dev/review-skills/internal/detect"
	"flox.dev/review-skills/internal/tools"
)

// Options configures a report run.
type Options struct {
	Path           string
	Kind           detect.Kind // "" = auto-detect
	Tools, Disable string
}

// ToolOutput is one tool's raw output.
type ToolOutput struct {
	Tool string `json:"tool"`
	Raw  string `json:"raw"`
}

func dry() bool { return os.Getenv("REVIEW_SKILLS_DRY_RUN") == "1" }

// Run executes the selected quality tools plus skillcheck and captures each
// one's raw combined output. Under REVIEW_SKILLS_DRY_RUN it returns a stub
// line per tool instead of executing anything.
func Run(opts Options) ([]ToolOutput, error) {
	kind := opts.Kind
	if kind == "" {
		kind = detect.Detect(opts.Path)
	}
	sel, err := tools.Select(kind, opts.Tools, opts.Disable)
	if err != nil {
		return nil, err
	}
	// Append the security tool so report covers the full audit surface.
	if sc, ok := tools.Find("skillcheck"); ok {
		sel = append(sel, sc)
	}

	var out []ToolOutput
	for _, t := range sel {
		if dry() {
			out = append(out, ToolOutput{Tool: t.Name, Raw: "(dry-run) would run " + t.Bin})
			continue
		}
		out = append(out, ToolOutput{Tool: t.Name, Raw: string(runRaw(t, kind, opts.Path))})
	}
	return out, nil
}

// runRaw returns a tool's combined output, staging a temp .claude project
// for stage tools (claudelint/cclint) so they see a valid layout.
func runRaw(t tools.Tool, kind detect.Kind, path string) []byte {
	cmd := exec.Command(t.Bin, t.RunArgs(kind, path)...)
	if t.Stage {
		cmd.Dir = stageProject(kind, path)
	}
	b, _ := cmd.CombinedOutput()
	return b
}

// stageProject builds a temp .claude project containing the artifact and
// returns its root, mirroring the audit package's staging.
func stageProject(kind detect.Kind, path string) string {
	proj, err := os.MkdirTemp("", "review-skills-report-")
	if err != nil {
		return path
	}
	if kind == detect.KindAgent {
		dst := filepath.Join(proj, ".claude", "agents")
		_ = os.MkdirAll(dst, 0o755)
		_ = copyFile(path, filepath.Join(dst, filepath.Base(path)))
	} else {
		name := filepath.Base(path)
		dst := filepath.Join(proj, ".claude", "skills", name)
		_ = os.MkdirAll(dst, 0o755)
		src := filepath.Join(path, "SKILL.md")
		if fi, err := os.Stat(path); err == nil && !fi.IsDir() {
			src = path
		}
		_ = copyFile(src, filepath.Join(dst, "SKILL.md"))
	}
	return proj
}

func copyFile(src, dst string) error {
	b, err := os.ReadFile(src)
	if err != nil {
		return err
	}
	return os.WriteFile(dst, b, 0o644)
}
