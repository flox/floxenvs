package tui

import "charm.land/lipgloss/v2"

// Styles holds the Lipgloss styles used across the TUI, derived from a Theme.
type Styles struct {
	Accent      lipgloss.Style // cyan emphasis
	Danger      lipgloss.Style
	Muted       lipgloss.Style
	Text        lipgloss.Style
	Selected    lipgloss.Style // bold accent (search label, tag cursor)
	Installed   lipgloss.Style // success
	Warning     lipgloss.Style
	Action      lipgloss.Style // call-to-action key (bright blue)
	Primary     lipgloss.Style // headline actions (agents, launch) — purple
	Strong      lipgloss.Style // bright primary text (installable name)
	Title       lipgloss.Style
	Rule        lipgloss.Style // horizontal/vertical divider lines
	PaneFocus   lipgloss.Style // modal / overlay frame, focused
	PaneBlur    lipgloss.Style
	SelectedRow lipgloss.Style // hovered row
	SelName     lipgloss.Style // selected row, title line (bright)
	SelDesc     lipgloss.Style // selected row, description line (muted)
}

func newStyles() Styles { return newStyledTheme(DefaultTheme()) }

func newStyledTheme(t Theme) Styles {
	return Styles{
		Accent:    lipgloss.NewStyle().Foreground(t.Accent),
		Danger:    lipgloss.NewStyle().Foreground(t.Danger),
		Muted:     lipgloss.NewStyle().Foreground(t.Muted),
		Text:      lipgloss.NewStyle().Foreground(t.Text),
		Selected:  lipgloss.NewStyle().Foreground(t.Accent).Bold(true),
		Installed: lipgloss.NewStyle().Foreground(t.Success),
		Warning:   lipgloss.NewStyle().Foreground(t.Warning),
		Action:    lipgloss.NewStyle().Foreground(t.Action).Bold(true),
		Primary:   lipgloss.NewStyle().Foreground(t.Primary).Bold(true),
		Strong:    lipgloss.NewStyle().Foreground(t.Text).Bold(true),
		Title:     lipgloss.NewStyle().Foreground(t.Accent).Bold(true),
		Rule:      lipgloss.NewStyle().Foreground(t.Faint),
		PaneFocus: lipgloss.NewStyle().
			Border(lipgloss.RoundedBorder()).
			BorderForeground(t.Accent),
		PaneBlur: lipgloss.NewStyle().
			Border(lipgloss.RoundedBorder()).
			BorderForeground(t.Faint),
		SelectedRow: lipgloss.NewStyle().
			Background(t.SelectedBg).Foreground(t.Text),
		SelName: lipgloss.NewStyle().
			Background(t.SelectedBg).Foreground(t.Text),
		SelDesc: lipgloss.NewStyle().
			// Muted matches the selection bg too closely; lift it toward the
			// foreground for contrast while staying dimmer than the title.
			Background(t.SelectedBg).Foreground(blend(t.Muted, t.Text, 0.5)),
	}
}
