package tui

import "testing"

func TestStylesDefined(t *testing.T) {
	s := newStyles()
	if got := s.Accent.Render("x"); got == "" {
		t.Error("accent render empty")
	}
	if got := s.Selected.Render("y"); got == "" {
		t.Error("selected render empty")
	}
}
