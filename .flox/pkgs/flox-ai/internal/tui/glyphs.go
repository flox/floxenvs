package tui

import "charm.land/lipgloss/v2"

// Nerd Font icons. The flox-ai TUI requires a Nerd Font (documented in the
// README); there is intentionally no ASCII fallback. We support a smaller
// surface and make that experience good rather than degrade everywhere.
const (
	// Brand / chrome.
	logoMark   = "▰" // flox parallelogram mark
	iconSearch = "󰍉" // nf-md-magnify (bolder than nf-fa-search)
	caretDown  = "" // nf-fa-caret_down — agent selector affordance

	// Fragment type icons (leading glyph in a list row).
	iconPlugin  = "" // nf-fa-puzzle_piece
	iconSkill   = "" // nf-fa-magic
	iconAgent   = "" // nf-fa-robot
	iconRule    = "" // nf-fa-book
	iconUnknown = "" // nf-fa-question

	// Status icons (trailing badge on a row + detail header).
	iconInstalled = "" // nf-fa-check_circle
	iconStaged    = "" // nf-fa-plus_circle
	iconRemove    = "" // nf-fa-minus_circle

	// Structural marks (BMP, universally present).
	cursorMark = "▸" // U+25B8 row pointer
	ruleH      = "─" // U+2500
	ruleV      = "│" // U+2502
)

// typeIcon returns the Nerd Font glyph for a fragment type.
func typeIcon(t string) string {
	switch t {
	case "plugin":
		return iconPlugin
	case "skill":
		return iconSkill
	case "agent":
		return iconAgent
	case "rule":
		return iconRule
	default:
		return iconUnknown
	}
}

// badge renders a small colored status label.
func badge(label string, st lipgloss.Style) string { return st.Render(label) }
