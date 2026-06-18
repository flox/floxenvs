package launch

import "testing"

func TestCheckAll_CoversRegistry(t *testing.T) {
	got := CheckAll()
	if len(got) != len(registry) {
		t.Fatalf("CheckAll returned %d, want %d (registry size)", len(got), len(registry))
	}
	names := map[string]bool{}
	for _, r := range got {
		names[r.Name] = true
		if r.Bin == "" && r.Status.Level != Fail {
			t.Fatalf("%s: no bin but level=%d (want Fail)", r.Name, r.Status.Level)
		}
		if r.Status.Level == Fail && r.Status.Reason == "" {
			t.Fatalf("%s: Fail with empty reason", r.Name)
		}
	}
	for name := range registry {
		if !names[name] {
			t.Fatalf("CheckAll missing %q", name)
		}
	}
}
