package audit

import (
	"os"
	"path/filepath"
	"testing"

	"flox.dev/review-skills/internal/detect"
)

func tmpSkill(t *testing.T) string {
	t.Helper()
	tmp := t.TempDir()
	sk := filepath.Join(tmp, "good")
	if err := os.MkdirAll(sk, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(sk, "SKILL.md"),
		[]byte("---\nname: good\ndescription: Use when testing.\n---\n# good\nDo it.\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	return sk
}

func tmpAgent(t *testing.T) string {
	t.Helper()
	tmp := t.TempDir()
	ag := filepath.Join(tmp, "good.md")
	if err := os.WriteFile(ag,
		[]byte("---\nname: good\ndescription: Use proactively to test.\nmodel: sonnet\ntools:\n  - Read\n---\nYou are a tidy test agent.\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	return ag
}

func TestAuditDryRunSkill(t *testing.T) {
	t.Setenv("REVIEW_SKILLS_DRY_RUN", "1")
	sk := tmpSkill(t)

	r, err := Run(Options{Path: sk})
	if err != nil {
		t.Fatal(err)
	}
	if r.Identity.Kind != "skill" {
		t.Errorf("kind=%s want skill", r.Identity.Kind)
	}
	if r.Identity.Name != "good" {
		t.Errorf("name=%s want good", r.Identity.Name)
	}
	if r.Overall < 0 || r.Overall > 100 {
		t.Errorf("overall=%d out of range", r.Overall)
	}
	if r.Status != "stable" && r.Status != "warn" && r.Status != "risk" {
		t.Errorf("status=%s invalid", r.Status)
	}
	if len(r.Quality.Checks) == 0 {
		t.Errorf("no quality checks")
	}
	for _, c := range r.Quality.Checks {
		if c.ID == "" {
			t.Errorf("check missing id: %+v", c)
		}
	}
	// security defaults to none/100 in dry-run.
	if r.Security.Severity != "none" || r.Security.Score != 100 {
		t.Errorf("security = %+v want none/100", r.Security)
	}
	// impact is estimated (70) without --with-behavioral.
	if !r.Impact.Estimated || r.Impact.Score != 70 {
		t.Errorf("impact = %+v want estimated 70", r.Impact)
	}
}

func TestAuditDryRunAgentAuto(t *testing.T) {
	t.Setenv("REVIEW_SKILLS_DRY_RUN", "1")
	ag := tmpAgent(t)

	r, err := Run(Options{Path: ag})
	if err != nil {
		t.Fatal(err)
	}
	if r.Identity.Kind != "agent" {
		t.Errorf("auto-detect kind=%s want agent", r.Identity.Kind)
	}
	if len(r.Quality.Checks) == 0 {
		t.Errorf("no quality checks for agent")
	}
}

func TestAuditExplicitKind(t *testing.T) {
	t.Setenv("REVIEW_SKILLS_DRY_RUN", "1")
	ag := tmpAgent(t)

	r, err := Run(Options{Path: ag, Kind: detect.KindAgent})
	if err != nil {
		t.Fatal(err)
	}
	if r.Identity.Kind != "agent" {
		t.Errorf("explicit kind=%s want agent", r.Identity.Kind)
	}
}

func TestLintDryRun(t *testing.T) {
	t.Setenv("REVIEW_SKILLS_DRY_RUN", "1")
	ok, err := Lint(Options{Path: tmpSkill(t)})
	if err != nil {
		t.Fatal(err)
	}
	if !ok {
		t.Errorf("dry-run lint should pass")
	}
}

func TestLintInlineFrontmatter(t *testing.T) {
	// Without dry-run, a well-formed skill should pass the inline
	// frontmatter gate (no quick_validate.py on PATH in tests).
	sk := tmpSkill(t)
	ok, err := Lint(Options{Path: sk})
	if err != nil {
		t.Fatal(err)
	}
	if !ok {
		t.Errorf("well-formed skill should pass the inline gate")
	}

	// A skill missing description should fail the gate.
	bad := filepath.Join(t.TempDir(), "bad")
	if err := os.MkdirAll(bad, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(bad, "SKILL.md"),
		[]byte("---\nname: bad\n---\n# bad\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	ok, err = Lint(Options{Path: bad})
	if err != nil {
		t.Fatal(err)
	}
	if ok {
		t.Errorf("skill without description should fail the inline gate")
	}
}
