package tui

import (
	"image/color"
	"sort"
	"strings"

	"charm.land/lipgloss/v2"
	"charm.land/lipgloss/v2/compat"
	bt "github.com/lrstanley/bubbletint/v2"
	zone "github.com/lrstanley/bubblezone/v2"
)

// bubbletint's default registry is empty until NewDefaultRegistry populates
// it with all built-in tints; do that once at package load.
func init() {
	if bt.DefaultRegistry == nil {
		bt.NewDefaultRegistry()
	}
}

// tintColor adapts a bubbletint color (which may be nil) to a color.Color.
func tintColor(c *bt.Color) color.Color {
	if c == nil {
		return lipgloss.NoColor{}
	}
	return c
}

func firstColor(cs ...*bt.Color) color.Color {
	for _, c := range cs {
		if c != nil {
			return c
		}
	}
	return lipgloss.NoColor{}
}

// themeFromTint maps a bubbletint palette onto our semantic roles.
func themeFromTint(t *bt.Tint) Theme {
	return Theme{
		// Accent uses blue rather than cyan — many tints' cyan reads too
		// close to green.
		Accent:     firstColor(t.Blue, t.BrightBlue),
		Action:     firstColor(t.BrightBlue, t.Blue),
		Primary:    firstColor(t.BrightPurple, t.Purple, t.BrightBlue),
		Text:       firstColor(t.Fg, t.BrightWhite, t.White),
		Muted:      firstColor(t.BrightBlack, t.White),
		Faint:      firstColor(t.BrightBlack, t.Black),
		SelectedBg: firstColor(t.SelectionBg, t.BrightBlack),
		Success:    firstColor(t.BrightGreen, t.Green),
		Warning:    firstColor(t.BrightYellow, t.Yellow),
		Danger:     firstColor(t.BrightRed, t.Red),
	}
}

// sortedTintIDs returns all registered tint IDs, alphabetically.
func sortedTintIDs() []string {
	ids := bt.TintIDs()
	sort.Strings(ids)
	return ids
}

// defaultTintIndex picks a pleasant default for the background detected at
// startup. Runtime changes are handled via defaultTintIndexFor.
func defaultTintIndex(ids []string) int {
	return defaultTintIndexFor(ids, compat.HasDarkBackground)
}

// defaultTintIndexFor picks a pleasant default tint for a dark or light
// background, falling back to the first registered tint.
func defaultTintIndexFor(ids []string, dark bool) int {
	prefs := []string{"catppuccin_macchiato", "tokyo_night", "catppuccin_mocha", "dracula", "nord"}
	if !dark {
		prefs = []string{"catppuccin_latte", "catppuccin_frappe"}
	}
	for _, want := range prefs {
		for i, id := range ids {
			if id == want {
				return i
			}
		}
	}
	return 0
}

// themePairs map a dark tint to its light sibling within the same family, so
// a chosen theme can flip with the terminal's appearance.
var themePairs = []struct{ dark, light string }{
	{"catppuccin_macchiato", "catppuccin_latte"},
	{"catppuccin_mocha", "catppuccin_latte"},
	{"catppuccin_frappe", "catppuccin_latte"},
	{"tokyo_night", "tokyo_night_light"},
	{"tokyo_night_storm", "tokyo_night_light"},
	{"tokyonight", "tokyonight_day"},
	{"tokyonight_storm", "tokyonight_day"},
	{"gruvbox_dark", "gruvbox_light"},
	{"gruvbox_dark_hard", "gruvbox_light"},
	{"rose_pine", "rose_pine_dawn"},
	{"rose_pine_moon", "rose_pine_dawn"},
	{"ayu", "ayu_light"},
	{"ayu_mirage", "ayu_light"},
	{"nord", "nord_light"},
	{"one_dark", "atom_one_light"},
	{"one_half_dark", "one_half_light"},
	{"builtin_solarized_dark", "builtin_solarized_light"},
	{"i_term_2_solarized_dark", "i_term_2_solarized_light"},
}

// siblingFor returns the same-family variant of id for the requested
// darkness, or "" if id has no known light/dark pair.
func siblingFor(id string, dark bool) string {
	for _, p := range themePairs {
		if p.dark == id || p.light == id {
			if dark {
				return p.dark
			}
			return p.light
		}
	}
	return ""
}

// tintIndexOf returns the index of a tint id, or -1.
func (m model) tintIndexOf(id string) int {
	for i, t := range m.tintIDs {
		if t == id {
			return i
		}
	}
	return -1
}

// applyTint switches the active tint and rebuilds styles.
func (m *model) applyTint(i int) {
	if len(m.tintIDs) == 0 {
		return
	}
	i = clamp(i, 0, len(m.tintIDs)-1)
	m.tintIdx = i
	if t, ok := bt.GetTint(m.tintIDs[i]); ok {
		m.theme = themeFromTint(t)
		m.styles = newStyledTheme(m.theme)
	}
}

// defaultTintFilter selects the picker's dark/light filter to match the
// current terminal appearance (1 dark, 2 light).
func defaultTintFilter() int {
	if compat.HasDarkBackground {
		return 1
	}
	return 2
}

// tintIsDark reports whether a tint has a dark background.
func tintIsDark(id string) bool {
	t, ok := bt.GetTint(id)
	if !ok || t.Bg == nil {
		return true
	}
	r, g, b, _ := t.Bg.RGBA()
	lum := 0.2126*float64(r>>8) + 0.7152*float64(g>>8) + 0.0722*float64(b>>8)
	return lum < 128
}

// filteredTints applies the picker's dark/light filter and search query.
func (m model) filteredTints() []string {
	q := strings.ToLower(m.tintQuery)
	var out []string
	for _, id := range m.tintIDs {
		switch m.tintFilter {
		case 1:
			if !tintIsDark(id) {
				continue
			}
		case 2:
			if tintIsDark(id) {
				continue
			}
		}
		if q != "" && !strings.Contains(strings.ToLower(id), q) &&
			!strings.Contains(strings.ToLower(tintName(id)), q) {
			continue
		}
		out = append(out, id)
	}
	return out
}

// previewTintAt applies the tint at the picker cursor (over the filtered set)
// for live preview, if any match.
func (m *model) previewTintAt() {
	f := m.filteredTints()
	if len(f) == 0 {
		return
	}
	m.tintPick = clamp(m.tintPick, 0, len(f)-1)
	if i := m.tintIndexOf(f[m.tintPick]); i >= 0 {
		m.applyTint(i)
	}
}

// tintName returns a display name for a tint id.
func tintName(id string) string {
	if t, ok := bt.GetTint(id); ok && t.DisplayName != "" {
		return t.DisplayName
	}
	return id
}

// tintSwatch renders a short row of color blocks from the tint's palette.
func tintSwatch(id string) string {
	t, ok := bt.GetTint(id)
	if !ok {
		return ""
	}
	var b strings.Builder
	for _, c := range []*bt.Color{t.BrightRed, t.BrightYellow, t.BrightGreen,
		t.BrightCyan, t.BrightBlue, t.BrightPurple} {
		b.WriteString(lipgloss.NewStyle().Foreground(tintColor(c)).Render("█"))
	}
	return b.String()
}

// viewThemeModal renders the tint picker: a search box, a dark/light filter,
// and a windowed list. Moving the cursor live-applies the tint so the whole
// UI behind the modal previews the selection.
func (m model) viewThemeModal() string {
	const visible = 12
	f := m.filteredTints()
	pick := clamp(m.tintPick, 0, max(0, len(f)-1))

	// search + filter header
	var search string
	switch {
	case m.tintSearching && m.tintQuery == "":
		search = m.styles.Accent.Render(iconSearch+" ") + "▌"
	case m.tintSearching:
		search = m.styles.Accent.Render(iconSearch+" ") + m.tintQuery + "▌"
	case m.tintQuery != "":
		search = m.styles.Muted.Render(iconSearch+" ") + m.tintQuery
	default:
		search = m.styles.Muted.Render(iconSearch + " type / to search")
	}
	filterLabel := []string{"all", "dark", "light"}[m.tintFilter]
	head := m.spread(search,
		m.styles.Muted.Render("filter: ")+m.styles.Accent.Render(filterLabel), 48)

	var rows []string
	if len(f) == 0 {
		rows = []string{m.styles.Muted.Render("no themes match")}
	} else {
		start := clamp(pick-visible/2, 0, max(0, len(f)-visible))
		end := min(start+visible, len(f))
		for i := start; i < end; i++ {
			id := f[i]
			name := truncate(tintName(id), 22)
			var row string
			if i == pick {
				row = m.styles.Strong.Render(cursorMark+" ") +
					m.styles.Strong.Render(name) + "  " + tintSwatch(id)
			} else {
				row = "  " + m.styles.Muted.Render(name) + "  " + tintSwatch(id)
			}
			if m.tintOrig < len(m.tintIDs) && id == m.tintIDs[m.tintOrig] {
				row += m.styles.Muted.Render("  · original")
			}
			rows = append(rows, zone.Mark("tint:"+id, row))
		}
	}
	orig := ""
	if m.tintOrig < len(m.tintIDs) {
		orig = m.styles.Muted.Render("original  ") +
			m.styles.Muted.Render(tintName(m.tintIDs[m.tintOrig])) + "\n\n"
	}
	body := orig + head + "\n\n" + strings.Join(rows, "\n")
	footer := m.dimKeys([2]string{"j/k", "move"}, [2]string{"/", "search"},
		[2]string{"f", "dark/light"}, [2]string{"enter", "keep"}, [2]string{"esc", "revert"})
	return m.modalBox("Theme", body, footer)
}
