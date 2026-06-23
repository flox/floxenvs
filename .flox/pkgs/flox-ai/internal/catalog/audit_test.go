package catalog

import (
	"encoding/json"
	"testing"
)

func TestAuditJSON(t *testing.T) {
	data := []byte(`{"overall":89,"status":"stable",
	  "quality":{"score":92,"checks":[{"id":"skill-tools","weight":40,"pass":true,"note":"92"}]},
	  "reliability":{"score":85},
	  "security":{"score":90,"cap":100,"scanners":[{"tool":"gitleaks","level":"none","status":"clean"}],
	    "findings":[{"tool":"skillcheck","level":"LOW","status":"open","note":"x"}]},
	  "impact":{"pass":3,"total":4,"score":78}}`)
	var a Audit
	if err := json.Unmarshal(data, &a); err != nil {
		t.Fatal(err)
	}
	if a.Overall != 89 || a.Status != "stable" {
		t.Fatalf("overall/status: %+v", a)
	}
	if len(a.Quality.Checks) != 1 || a.Quality.Checks[0].ID != "skill-tools" {
		t.Fatalf("checks: %+v", a.Quality.Checks)
	}
	if len(a.Security.Findings) != 1 || a.Security.Findings[0].Level != "LOW" {
		t.Fatalf("findings: %+v", a.Security.Findings)
	}
}
