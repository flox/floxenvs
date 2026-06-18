package launch

import "testing"

func TestLevelOrdering(t *testing.T) {
	if !(OK < Degraded && Degraded < Fail) {
		t.Fatalf("level ordering wrong: OK=%d Degraded=%d Fail=%d", OK, Degraded, Fail)
	}
}

func TestStatusZeroValueIsOK(t *testing.T) {
	var s Status
	if s.Level != OK {
		t.Fatalf("zero-value Status.Level = %d, want OK(%d)", s.Level, OK)
	}
}
