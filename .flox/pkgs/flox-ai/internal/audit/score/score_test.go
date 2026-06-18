package score

import "testing"

func TestNormalizeErrWarn(t *testing.T) {
	cases := []struct{ e, w, want int }{{0, 0, 100}, {1, 3, 60}, {5, 0, 0}, {0, 2, 90}}
	for _, c := range cases {
		if got := NormalizeErrWarn(c.e, c.w); got != c.want {
			t.Errorf("NormalizeErrWarn(%d,%d)=%d want %d", c.e, c.w, got, c.want)
		}
	}
}

func TestEnsemble(t *testing.T) {
	got := Ensemble([]Weighted{{40, 82}, {30, 90}, {30, 60}})
	if got != 78 {
		t.Errorf("Ensemble skill = %d want 78", got)
	}
	// dropping a tool re-normalizes via the denominator: weights 30/30
	if got := Ensemble([]Weighted{{30, 90}, {30, 60}}); got != 75 {
		t.Errorf("Ensemble re-normalized = %d want 75", got)
	}
}

func TestFuseCapPill(t *testing.T) {
	if got := Fuse(78, 85, 80, 70); got != 80 {
		t.Errorf("Fuse=%d want 80", got)
	}
	if got := ApplyCap(80, SevHigh); got != 75 {
		t.Errorf("ApplyCap HIGH=%d want 75", got)
	}
	if got := ApplyCap(80, SevCritical); got != 50 {
		t.Errorf("ApplyCap CRITICAL=%d want 50", got)
	}
	if Pill(80) != "stable" || Pill(75) != "warn" || Pill(59) != "risk" {
		t.Errorf("Pill wrong")
	}
}
