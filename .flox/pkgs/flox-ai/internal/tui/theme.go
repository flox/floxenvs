package tui

import (
	"image/color"

	"charm.land/lipgloss/v2"
	"charm.land/lipgloss/v2/compat"
)

// Theme holds the semantic color roles for the TUI.
//
// The palette is a curated, harmonious scheme (Tokyo Night for dark
// backgrounds, a GitHub-light-style set for light) rather than the raw
// ANSI-16 brights, which are harsh and clash. compat.AdaptiveColor resolves
// the right variant once at startup from the detected background.
type Theme struct {
	Accent     color.Color // cyan: titles, selection accent, staged
	Action     color.Color // blue: call-to-action keys
	Primary    color.Color // purple: headline actions (agents, launch)
	Text       color.Color // primary foreground
	Muted      color.Color // secondary / dim text
	Faint      color.Color // borders, rules, gentle dividers
	SelectedBg color.Color // hovered-row background
	Success    color.Color // installed / ok
	Warning    color.Color // caution
	Danger     color.Color // remove / error
}

// blend mixes color a toward b by f (0..1).
func blend(a, b color.Color, f float64) color.Color {
	ar, ag, ab, _ := a.RGBA()
	br, bg, bb, _ := b.RGBA()
	mix := func(x, y uint32) uint8 {
		v := float64(x>>8)*(1-f) + float64(y>>8)*f
		if v > 255 {
			v = 255
		}
		return uint8(v)
	}
	return color.RGBA{R: mix(ar, br), G: mix(ag, bg), B: mix(ab, bb), A: 0xff}
}

// hexA picks a hex color per background darkness (light, dark).
func hexA(light, dark string) color.Color {
	return compat.AdaptiveColor{Light: lipgloss.Color(light), Dark: lipgloss.Color(dark)}
}

// DefaultTheme is the curated, eye-friendly palette.
func DefaultTheme() Theme {
	return Theme{
		Accent:     hexA("#0969da", "#7dcfff"), // blue / soft cyan
		Action:     hexA("#0550ae", "#7aa2f7"), // blue
		Primary:    hexA("#8250df", "#bb9af7"), // purple (headline actions)
		Text:       hexA("#1f2328", "#c0caf5"), // near-black / soft lavender-white
		Muted:      hexA("#6e7781", "#828bb8"), // secondary gray
		Faint:      hexA("#d0d7de", "#3b4261"), // dim lines
		SelectedBg: hexA("#eaeef2", "#2e3c64"), // gentle selection bg
		Success:    hexA("#1a7f37", "#9ece6a"), // green
		Warning:    hexA("#9a6700", "#e0af68"), // amber
		Danger:     hexA("#cf222e", "#f7768e"), // soft red
	}
}
