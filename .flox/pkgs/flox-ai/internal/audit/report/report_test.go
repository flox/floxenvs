package report

import (
	"os"
	"path/filepath"
	"testing"
)

func tmpSkill(t *testing.T) string {
	t.Helper()
	sk := filepath.Join(t.TempDir(), "good")
	if err := os.MkdirAll(sk, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(sk, "SKILL.md"),
		[]byte("---\nname: good\ndescription: Use when testing.\n---\n# good\nDo it.\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	return sk
}

func TestReportDryRunNamesTools(t *testing.T) {
	t.Setenv("REVIEW_SKILLS_DRY_RUN", "1")
	out, err := Run(Options{Path: tmpSkill(t)})
	if err != nil {
		t.Fatal(err)
	}
	got := map[string]bool{}
	for _, o := range out {
		got[o.Tool] = true
		if o.Raw == "" {
			t.Errorf("empty raw for %s", o.Tool)
		}
	}
	// skill quality ensemble + skillcheck.
	for _, want := range []string{"skill-tools", "skill-validator", "claudelint", "skillcheck"} {
		if !got[want] {
			t.Errorf("report missing tool %s (got %v)", want, got)
		}
	}
}

func TestReportDisable(t *testing.T) {
	t.Setenv("REVIEW_SKILLS_DRY_RUN", "1")
	out, err := Run(Options{Path: tmpSkill(t), Disable: "claudelint"})
	if err != nil {
		t.Fatal(err)
	}
	for _, o := range out {
		if o.Tool == "claudelint" {
			t.Errorf("claudelint should be disabled in report")
		}
	}
}
