package doctor

import "testing"

// Probe returns one Row per registered tool; with no review tools on PATH,
// every row is not-found and smoke is skipped. This exercises the merged
// probing path without requiring the external binaries.
func TestProbe_RowsForEveryTool(t *testing.T) {
	rows := Probe()
	if len(rows) == 0 {
		t.Fatal("Probe returned no rows")
	}
	for _, r := range rows {
		if r.Tool == "" {
			t.Errorf("row with empty tool name: %+v", r)
		}
		if r.State != "ok" && r.Smoke != "skip" {
			t.Errorf("%s: non-ok tool must skip smoke, got %q", r.Tool, r.Smoke)
		}
	}
}

// Resolve names the default quality ensemble for a kind and flags missing
// members when none are available.
func TestResolve_FlagsMissing(t *testing.T) {
	res := Resolve("skill", map[string]bool{})
	if len(res.Tools) == 0 {
		t.Fatal("Resolve returned no ensemble for skill")
	}
	if res.OK {
		t.Error("Resolve OK should be false when no tools are available")
	}
}
