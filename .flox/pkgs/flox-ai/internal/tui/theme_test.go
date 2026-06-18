package tui

import "testing"

func TestNewStyledTheme(t *testing.T) {
	s := newStyledTheme(DefaultTheme())
	if s.Title.Render("x") == "" || s.SelectedRow.Render("y") == "" {
		t.Error("styles must render non-empty")
	}
}
