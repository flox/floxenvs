package doctor

import (
	"strings"
	"testing"

	"flox.dev/review-skills/internal/detect"
	"flox.dev/review-skills/internal/tools"
)

func TestResolveWarnsMissing(t *testing.T) {
	// agnix missing from the agent quality ensemble.
	avail := map[string]bool{"claudelint": true, "cclint": true}
	res := Resolve(detect.KindAgent, avail)
	if !strings.Contains(res.Warning, "agnix") {
		t.Fatalf("expected agnix missing warning, got %q", res.Warning)
	}
	if res.OK {
		t.Fatalf("should not be OK with a missing default tool")
	}
}

func TestResolveOKWhenAllPresent(t *testing.T) {
	avail := map[string]bool{}
	for _, t := range tools.QualityTools(detect.KindAgent) {
		avail[t.Name] = true
	}
	res := Resolve(detect.KindAgent, avail)
	if !res.OK {
		t.Fatalf("should be OK when all default tools present, warning=%q", res.Warning)
	}
	if res.Warning != "" {
		t.Fatalf("expected no warning, got %q", res.Warning)
	}
	if len(res.Tools) == 0 {
		t.Fatalf("expected a non-empty resolved ensemble")
	}
}

func TestProbeRows(t *testing.T) {
	rows := Probe()
	if len(rows) != len(tools.Registry()) {
		t.Fatalf("Probe returned %d rows, want %d (one per registry tool)",
			len(rows), len(tools.Registry()))
	}
	for _, row := range rows {
		if row.Tool == "" {
			t.Fatalf("row has empty Tool: %+v", row)
		}
		if row.State == "" {
			t.Fatalf("row %q has empty State", row.Tool)
		}
	}
}
