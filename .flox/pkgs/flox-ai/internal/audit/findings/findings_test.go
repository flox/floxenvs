package findings

import "testing"

func TestSortStable(t *testing.T) {
	in := []Finding{
		{Tool: "agnix", Severity: "warning", Rule: "b"},
		{Tool: "agnix", Severity: "error", Rule: "a"},
	}
	Sort(in)
	if in[0].Severity != "error" {
		t.Errorf("errors should sort first, got %q", in[0].Severity)
	}
}
