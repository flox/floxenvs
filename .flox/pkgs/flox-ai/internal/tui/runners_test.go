package tui

import (
	"testing"
)

func TestFakeDoctorRunner(t *testing.T) {
	var dr DoctorRunner = DoctorFunc(func(share, cfg string, out LineFunc) error {
		out("doctor:" + share)
		return nil
	})
	var got []string
	if err := dr.Run("S", "C", func(s string) { got = append(got, s) }); err != nil {
		t.Fatal(err)
	}
	if len(got) != 1 || got[0] != "doctor:S" {
		t.Fatalf("doctor lines %v", got)
	}
}
