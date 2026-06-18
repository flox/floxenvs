package tui

import (
	"strings"
	"testing"

	"charm.land/lipgloss/v2"
)

func TestBadgeContainsLabel(t *testing.T) {
	if !strings.Contains(badge("staged", lipgloss.NewStyle()), "staged") {
		t.Error("badge must contain the label")
	}
}

func TestTypeIconsDefined(t *testing.T) {
	// The TUI requires a Nerd Font; every fragment type must map to a
	// non-empty Private-Use-Area glyph.
	for _, ty := range []string{"plugin", "skill", "agent", "rule"} {
		ic := typeIcon(ty)
		if ic == "" {
			t.Fatalf("type %q has no icon", ty)
		}
		for _, r := range ic {
			if r < 0xE000 || r > 0xF8FF {
				t.Errorf("type %q icon %q not in PUA (%U)", ty, ic, r)
			}
		}
	}
}
