package tools

import (
	"os"
	"path/filepath"
	"testing"

	"flox.dev/review-skills/internal/score"
)

func readFixture(t *testing.T, rel string) []byte {
	t.Helper()
	b, err := os.ReadFile(filepath.Join("..", "..", "testdata", "out", rel))
	if err != nil {
		t.Fatalf("read fixture %s: %v", rel, err)
	}
	return b
}

func TestScoreSkillTools(t *testing.T) {
	s, ok := scoreSkillTools(readFixture(t, "skill-tools.json"))
	if !ok || s < 0 || s > 100 {
		t.Fatalf("scoreSkillTools=%d ok=%v", s, ok)
	}
}

func TestScoreErrWarnFailsClosed(t *testing.T) {
	if _, ok := scoreErrWarn([]byte("not json"), "errors", "warnings"); ok {
		t.Fatalf("garbage must fail closed (ok=false)")
	}
	if _, ok := scoreErrWarn(nil, "errors", "warnings"); ok {
		t.Fatalf("empty must fail closed")
	}
	s, ok := scoreErrWarn(readFixture(t, "skill-validator.json"), "errors", "warnings")
	if !ok || s < 0 || s > 100 {
		t.Fatalf("skill-validator score=%d ok=%v", s, ok)
	}
}

func TestScoreAgnix(t *testing.T) {
	s, ok := scoreAgnix(readFixture(t, "agnix.json"))
	if !ok || s < 0 || s > 100 {
		t.Fatalf("scoreAgnix=%d ok=%v", s, ok)
	}
	if _, ok := scoreAgnix([]byte("garbage")); ok {
		t.Fatalf("agnix garbage must fail closed")
	}
}

func validSeverity(s string) bool {
	return s == "error" || s == "warning" || s == "info"
}

func TestCollectAgnix(t *testing.T) {
	for _, f := range collectAgnix(readFixture(t, "agnix.json")) {
		if f.Tool != "agnix" || !validSeverity(f.Severity) {
			t.Fatalf("bad agnix finding: %+v", f)
		}
	}
}

func TestCollectSkillValidator(t *testing.T) {
	// Clean fixture: all results are level "pass" -> zero findings.
	for _, f := range collectSkillValidator(readFixture(t, "skill-validator.json")) {
		if f.Tool != "skill-validator" || !validSeverity(f.Severity) {
			t.Fatalf("bad skill-validator finding: %+v", f)
		}
	}
}

func TestCollectClaudelintFindings(t *testing.T) {
	fs := collectClaudelint(readFixture(t, "claudelint-findings.json"))
	var errs int
	for _, f := range fs {
		if f.Tool != "claudelint" || !validSeverity(f.Severity) {
			t.Fatalf("bad claudelint finding: %+v", f)
		}
		if f.Severity == "error" {
			errs++
		}
	}
	if errs == 0 {
		t.Fatalf("expected >=1 claudelint error finding from the bad-skill fixture")
	}
}

func TestCollectCclintFindings(t *testing.T) {
	fs := collectCclint(readFixture(t, "cclint-findings.json"))
	var errs int
	for _, f := range fs {
		if f.Tool != "cclint" || !validSeverity(f.Severity) {
			t.Fatalf("bad cclint finding: %+v", f)
		}
		if f.Severity == "error" {
			errs++
		}
	}
	if errs == 0 {
		t.Fatalf("expected >=1 cclint error finding from the bad-agent fixture")
	}
}

func TestCollectSkillToolsSuggestions(t *testing.T) {
	fs := collectSkillTools(readFixture(t, "skill-tools-suggestions.json"))
	if len(fs) == 0 {
		t.Fatalf("expected suggestions from the mediocre-skill fixture")
	}
	for _, f := range fs {
		if f.Tool != "skill-tools" || f.Severity != "info" || f.Message == "" {
			t.Fatalf("bad skill-tools finding: %+v", f)
		}
	}
}

func TestCollectSkillcheckAndSeverity(t *testing.T) {
	b := readFixture(t, "skillcheck-findings.sarif")
	fs := collectSkillcheck(b)
	if len(fs) == 0 {
		t.Fatalf("expected skillcheck findings from the secret fixture")
	}
	for _, f := range fs {
		if f.Tool != "skillcheck" || !validSeverity(f.Severity) {
			t.Fatalf("bad skillcheck finding: %+v", f)
		}
	}
	if got := SkillcheckSeverity(b); got != score.SevCritical {
		t.Fatalf("expected CRITICAL from the GitHub-token fixture, got %q", got)
	}
	// A clean SARIF (empty results) -> no severity.
	if got := SkillcheckSeverity(readFixture(t, "skillcheck.sarif")); got != score.SevNone {
		t.Fatalf("clean skillcheck should be SevNone, got %q", got)
	}
}
