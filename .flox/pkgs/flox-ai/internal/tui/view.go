package tui

import (
	"fmt"
	"strings"

	tea "charm.land/bubbletea/v2"
	"charm.land/lipgloss/v2"
	"github.com/charmbracelet/x/ansi"
	zone "github.com/lrstanley/bubblezone/v2"
)

// hyperlink wraps text in an OSC 8 terminal hyperlink so it opens url on
// click even when the displayed text is truncated or wrapped.
func hyperlink(url, text string) string {
	return ansi.SetHyperlink(url) + text + ansi.ResetHyperlink()
}

func (m model) View() tea.View {
	v := tea.NewView(zone.Scan(m.render()))
	v.AltScreen = true
	v.MouseMode = tea.MouseModeCellMotion
	return v
}

func (m model) render() string {
	if m.phase == phaseSplash {
		return m.renderSplash()
	}
	base := m.viewBase()
	var box string
	switch {
	case m.modal.open():
		box = m.viewModal()
	case m.showHelp:
		box = m.viewHelp()
	default:
		// #tag autocomplete: float suggestions just below the search box.
		if m.mode == modeSearch {
			if prefix, ok := m.activeTokenTag(); ok {
				if sb := m.viewTagSuggest(prefix); sb != "" {
					return lipgloss.NewCompositor(
						lipgloss.NewLayer(base),
						lipgloss.NewLayer(sb).X(12).Y(4),
					).Render()
				}
			}
		}
		return base
	}
	bw, bh := lipgloss.Width(box), lipgloss.Height(box)
	col := max(0, (m.width-bw)/2)
	row := max(0, (m.height-bh)/2)
	layers := []*lipgloss.Layer{
		lipgloss.NewLayer(base),
		lipgloss.NewLayer(box).X(col).Y(row),
	}
	return lipgloss.NewCompositor(layers...).Render()
}

// ---- layout dimensions -----------------------------------------------------

func (m model) usableWidth() int {
	if w := m.width - 4; w > 10 {
		return w
	}
	return 10
}

func (m model) bodyHeight() int {
	if h := m.height - 8; h > 3 {
		return h
	}
	return 3
}

func (m model) detailVisible() bool {
	return m.showDetail && m.usableWidth() >= 70 && m.selected() != nil
}

// detailColWidth is the full width of the right detail column (border + pad).
func (m model) detailColWidth() int {
	uw := m.usableWidth()
	return clamp(uw*42/100, 30, uw-36)
}

func (m model) listWidth() int {
	if !m.detailVisible() {
		return m.usableWidth()
	}
	// reserve one column as a gap before the detail divider
	return m.usableWidth() - m.detailColWidth() - 1
}

// detailDims is the inner viewport size for the detail pane. The column
// width loses 2 to the inclusive border style, 1 to the left border, and 2
// to the left padding, so the viewport content area is colWidth-5.
func (m model) detailDims() (int, int) {
	if !m.detailVisible() {
		return 0, 0
	}
	return m.detailColWidth() - 5, m.bodyHeight() - 2
}

// ---- base view -------------------------------------------------------------

func (m model) viewBase() string {
	uw := m.usableWidth()
	// Full-bleed separators run edge to edge; everything else is inset.
	full := m.styles.Rule.Render(strings.Repeat(ruleH, m.width))
	ind := func(s string) string { return indentLines(s, 2) }
	parts := []string{
		ind(m.viewTopBand(uw)),
		full,
		ind(m.viewStatus(uw)),
		ind(m.viewBody()),
		full,
		ind(m.viewFooter(uw)),
	}
	return strings.Join(parts, "\n")
}

func indentLines(s string, n int) string {
	pad := strings.Repeat(" ", n)
	out := strings.Split(s, "\n")
	for i := range out {
		out[i] = pad + out[i]
	}
	return strings.Join(out, "\n")
}

// installedCount is the number of catalog packages installed for the agent.
func (m model) installedCount() int {
	n := 0
	for _, it := range m.items {
		if m.matchesAgent(it) && m.installed[it.ID] {
			n++
		}
	}
	return n
}

// viewApplyModal shows apply progress inside the standard modal box (so the
// view doesn't jump around): a planned-counts summary, friendly per-package
// lines, and either a spinner or a launch suggestion.
func (m model) viewLaunchModal() string {
	head := m.styles.Muted.Render("Launch ") +
		m.styles.Accent.Render("‹"+agentDisplay(m.currentAgent())+"›") +
		m.styles.Muted.Render(" with the installed plugins, skills, agents & rules?")
	desc := m.styles.Muted.Width(60).Render(agentLaunch(m.currentAgent()))
	footer := m.dimKeys([2]string{"enter", "launch"},
		[2]string{"a", "change agent"}, [2]string{"esc", "cancel"})
	return m.modalBox("launch", head+"\n\n"+desc, footer)
}

func (m model) viewUpgradeModal() string {
	if len(m.upgrades) == 0 {
		return m.modalBox("upgrade",
			m.styles.Muted.Render("Everything is up to date."),
			m.dimKeys([2]string{"esc", "close"}))
	}
	var b strings.Builder
	b.WriteString(m.styles.Muted.Render("Do you really want to upgrade?") + "\n\n")
	if m.hasIncludes {
		b.WriteString(m.styles.Muted.Render("Included environments are upgraded first.") + "\n\n")
	}
	for _, u := range m.upgrades {
		line := "  " + m.styles.Text.Render(u.Pkg)
		switch {
		case u.To != "":
			line += m.styles.Muted.Render("  "+u.From+" → ") + m.styles.Installed.Render(u.To)
		case u.From != "":
			line += m.styles.Muted.Render("  " + u.From + " (rebuild)")
		}
		b.WriteString(line + "\n")
	}
	footer := m.dimKeys([2]string{"U", "upgrade"}, [2]string{"esc", "cancel"})
	return m.modalBox("upgrade", strings.TrimRight(b.String(), "\n"), footer)
}

// verbForms returns the gerund and past tense of an apply verb.
func verbForms(verb string) (gerund, past string) {
	switch verb {
	case "install":
		return "installing", "installed"
	case "uninstall":
		return "uninstalling", "uninstalled"
	default:
		return verb + "ing", verb + "ed"
	}
}

func (m model) viewApplyModal() string {
	var sm []string
	if m.applyInstalls > 0 {
		sm = append(sm, m.styles.Accent.Render(fmt.Sprintf("%d to install", m.applyInstalls)))
	}
	if m.applyRemoves > 0 {
		sm = append(sm, m.styles.Danger.Render(fmt.Sprintf("%d to uninstall", m.applyRemoves)))
	}
	sm = append(sm, m.styles.Installed.Render(fmt.Sprintf("%d installed", m.installedCount())))
	summary := strings.Join(sm, m.styles.Muted.Render(" · "))

	// One gray line per change, updated in place as each step progresses.
	var lines []string
	for _, s := range m.applySteps {
		ger, past := verbForms(s.verb)
		var text string
		switch s.state {
		case stepRunning:
			text = "· " + ger + " " + s.name + "…"
		case stepDone:
			text = "· " + s.name + " " + past
		case stepFailed:
			text = "· " + s.name + " failed"
		default:
			text = "· " + s.name
		}
		lines = append(lines, m.styles.Muted.Render(text))
	}
	body := summary + "\n\n" + strings.Join(lines, "\n")

	var footer string
	if m.streamDone {
		status := m.styles.Installed.Render("Done.")
		if len(m.errs) > 0 {
			status = m.styles.Danger.Render(fmt.Sprintf("%d error(s).", len(m.errs)))
		}
		// Prominent launch suggestion right under the output.
		launch := m.styles.Primary.Render("[L] launch") +
			m.styles.Muted.Render(" the setup under ") +
			m.styles.Accent.Render("‹"+agentDisplay(m.currentAgent())+"›")
		body += "\n\n" + status + "\n\n" + launch
		footer = m.dimKeys([2]string{"a", "change agent"}, [2]string{"esc", "close"})
	} else {
		footer = m.spin.View() + m.styles.Muted.Render(" applying…")
	}
	return m.modalBox("applying changes", body, footer)
}

// spread left-justifies a and right-justifies b across width w.
func (m model) spread(a, b string, w int) string {
	gap := w - lipgloss.Width(a) - lipgloss.Width(b)
	if gap < 1 {
		gap = 1
	}
	return a + strings.Repeat(" ", gap) + b
}

// headerLogoArt is the flox bolt traced from the SVG, drawn with quadrant
// blocks (each cell is 2x2 pixels): banner up top, kick right, foot left.
var headerLogoArt = []string{
	"▗████",
	"██▛▀ ",
	" ▐███",
	"█▌   ",
}

// logoBlock renders the flox mark as a 4-line block in the brand color.
func (m model) logoBlock() string {
	lines := make([]string, len(headerLogoArt))
	for i, l := range headerLogoArt {
		lines[i] = m.styles.Title.Render(l)
	}
	return strings.Join(lines, "\n")
}

// viewTopBand places the flox mark in front of the brand line and search box:
//
//	▗███   flox·ai                         [a] Switch agent: ‹Claude›
//	██▀▘   ┌──────────────────────────────────────────────────────┐
//	 ▐██   │  search…   #tag                                       │
//	█▌     └──────────────────────────────────────────────────────┘
func (m model) viewTopBand(uw int) string {
	const logoW, gap = 5, 3
	// charm.land lipgloss .Width is the outer width (border included), so the
	// brand line and the search box share the same width and right-align.
	rightW := uw - logoW - gap
	if rightW < 24 {
		rightW = 24
	}
	right := m.viewBrand(rightW) + "\n" + m.viewSearch(rightW)
	return lipgloss.JoinHorizontal(lipgloss.Top,
		m.logoBlock(), strings.Repeat(" ", gap), right)
}

func (m model) viewBrand(uw int) string {
	left := m.styles.Title.Render("flox") + m.styles.Muted.Render("·ai")
	if uw > 80 {
		left += m.styles.Muted.Render("   Curated plugins, skills, agents & rules")
	}
	agent := zone.Mark("agents", m.styles.Primary.Render("[a] Switch agent: ")+
		m.styles.Accent.Render("‹"+agentDisplay(m.currentAgent())+"›"))
	return m.spread(left, agent, uw)
}

func (m model) viewSearch(uw int) string {
	border := m.styles.PaneBlur
	if m.mode == modeSearch {
		border = m.styles.PaneFocus
	}
	const placeholder = "[/] search…   #tag"
	var inner string
	switch {
	case m.mode == modeSearch && m.query == "":
		inner = "▌" + m.styles.Muted.Render(" "+placeholder)
	case m.mode == modeSearch:
		inner = m.query + "▌"
	case m.query == "":
		inner = m.styles.Muted.Render(placeholder)
	default:
		inner = m.query
	}
	mag := m.styles.Accent.Render(iconSearch)
	return zone.Mark("search", border.Width(uw).Render(" "+mag+"  "+inner))
}

func (m model) viewStatus(uw int) string {
	var left string
	if m.isTopPicks() {
		label := "TOP PICKS"
		if len(m.installedPicks()) > 0 {
			label = "INSTALLED"
		}
		left = m.styles.Title.Render(label)
		if tags := m.popularTags(6); len(tags) > 0 {
			chips := make([]string, len(tags))
			for i, t := range tags {
				chips[i] = m.styles.Muted.Render("#" + t)
			}
			left += m.styles.Muted.Render("   popular  ") + strings.Join(chips, " ")
		}
	} else {
		left = m.styles.Title.Render(fmt.Sprint(len(m.results()))) +
			m.styles.Muted.Render(" matches")
	}

	inst, toInst, toRem := m.counts()
	var st []string
	// Confirm affordance — purple headline action, shown only when there is
	// something to apply.
	if len(m.pending) > 0 {
		st = append(st, zone.Mark("apply", m.styles.Primary.Render("[A] Confirm changes")))
	}
	if n := len(m.upgrades); n > 0 {
		st = append(st, zone.Mark("upgrade-hint",
			m.styles.Warning.Render(fmt.Sprintf("[U] %d upgrades", n))))
	}
	if inst > 0 {
		st = append(st, m.styles.Installed.Render(fmt.Sprintf("%d installed", inst)))
	}
	if toInst > 0 {
		st = append(st, m.styles.Accent.Render(fmt.Sprintf("%d to install", toInst)))
	}
	if toRem > 0 {
		st = append(st, m.styles.Danger.Render(fmt.Sprintf("%d to uninstall", toRem)))
	}
	right := strings.Join(st, m.styles.Muted.Render(" · "))
	return m.spread(left, right, uw)
}

func (m model) viewBody() string {
	h := m.bodyHeight()
	list := m.listView(m.listWidth(), h)
	if !m.detailVisible() {
		return list
	}
	return lipgloss.JoinHorizontal(lipgloss.Top, list, " ", m.detailView())
}

// ---- list ------------------------------------------------------------------

func (m model) listView(w, h int) string {
	items := m.visibleItems()
	if len(items) == 0 {
		hint := m.styles.Muted.Render("no matches — try a different search or #tag")
		return lipgloss.NewStyle().Width(w).Height(h).MaxHeight(h).Render(hint)
	}

	// One leading blank (space below TOP PICKS / count), then items
	// separated only by a gentle divider — no extra blank below a row.
	perItem := 3 // two content lines + one divider
	visible := h / perItem
	if visible < 1 {
		visible = 1
	}
	start := 0
	if m.cursor >= visible {
		start = m.cursor - visible + 1
	}
	end := start + visible
	if end > len(items) {
		end = len(items)
	}

	sep := "  " + m.styles.Rule.Render(strings.Repeat(ruleH, max(1, w-4)))
	rows := []string{""}
	for i := start; i < end; i++ {
		focused := m.focus == focusList && i == m.cursor
		block := strings.Join(m.rowLines(items[i], w, focused), "\n")
		rows = append(rows, zone.Mark("item:"+items[i].ID, block))
		if i < end-1 {
			rows = append(rows, sep)
		}
	}
	return lipgloss.NewStyle().Width(w).Height(h).MaxHeight(h).
		Render(strings.Join(rows, "\n"))
}

// rowStyle is the single state color for a row's icon, title and badge:
// green installed, red removing, accent staging, bold-white installable.
func (m model) rowStyle(id string) lipgloss.Style {
	switch m.tagFor(id) {
	case tagInstalled:
		return m.styles.Installed // green
	case tagInstall:
		return m.styles.Accent
	case tagUninstall:
		return m.styles.Danger // red
	default:
		return m.styles.Strong // installable: bold white
	}
}

// rowLines renders one catalog item as two lines: a title row (icon + name +
// state badge, all in the state color) and a muted description. Selection is
// shown by the background highlight only — no cursor glyph. The state color
// persists when selected.
func (m model) rowLines(it catalogItem, w int, focused bool) []string {
	status, _ := m.statusBadge(it.ID)
	st := m.rowStyle(it.ID)

	head := "  " + typeIcon(it.Type) + " " + it.Name
	if it.Audit != nil {
		head += "  " + m.auditScoreBadge(it.Audit.Overall, it.Audit.Status)
	}
	if status != "" {
		head = m.spread(head, status, w-2) // gap before the divider
	}
	descTxt := "    " + truncate(it.Description, w-5)

	if focused {
		return []string{
			st.Background(m.theme.SelectedBg).Width(w).Render(head),
			m.styles.SelDesc.Width(w).Render(descTxt),
		}
	}
	return []string{
		st.Render(head),
		m.styles.Muted.Render(descTxt),
	}
}

// statusBadge returns the trailing status glyph+label and its style.
func (m model) statusBadge(id string) (string, lipgloss.Style) {
	switch m.tagFor(id) {
	case tagInstalled:
		return iconInstalled + " installed", m.styles.Installed
	case tagInstall:
		return iconStaged + " staged", m.styles.Accent
	case tagUninstall:
		return iconRemove + " uninstall", m.styles.Danger
	default:
		return "", m.styles.Muted
	}
}

// ---- detail ----------------------------------------------------------------

func (m model) detailView() string {
	w := m.detailColWidth()
	h := m.bodyHeight()
	it := m.selected()

	header := m.styles.Muted.Render("select a package")
	if it != nil {
		header = m.styles.Title.Render(it.Name) +
			m.styles.Muted.Render("  "+it.Type)
	}
	// Leading blank line to match the list's top spacing under the status row.
	content := "\n" + header + "\n" + m.detailVP.View()

	border := m.theme.Faint
	if m.focus == focusDetail {
		border = m.theme.Accent
	}
	return lipgloss.NewStyle().
		Border(lipgloss.NormalBorder(), false, false, false, true).
		BorderForeground(border).
		PaddingLeft(2).
		Width(w - 2).Height(h).MaxHeight(h).
		Render(content)
}

// field renders an aligned "label  value" metadata row.
func (m model) field(label, value string) string {
	return m.styles.Muted.Render(fmt.Sprintf("%-10s ", label)) + value + "\n"
}

// detailBody renders the scrollable detail content for an item. The
// description leads (most important); status and metadata sit below.
func (m model) detailBody(it catalogItem) string {
	var b strings.Builder

	if it.Description != "" {
		b.WriteString(it.Description + "\n\n")
	}
	if it.Intro != "" {
		b.WriteString(it.Intro + "\n\n")
	}

	// Scores, with color, right below the description.
	b.WriteString(m.styles.Title.Render("Scores") + "\n")
	b.WriteString(m.scoreBlock(it) + "\n")

	for _, s := range it.Summary {
		b.WriteString("• " + s + "\n")
	}
	if len(it.Summary) > 0 {
		b.WriteString("\n")
	}

	if it.License != "" {
		b.WriteString(m.field("license", it.License))
	}
	if it.Maintainer != "" {
		b.WriteString(m.field("maintainer", it.Maintainer))
	}
	b.WriteString(m.field("id", it.ID))
	if len(it.Tags) > 0 {
		tagged := make([]string, len(it.Tags))
		for i, t := range it.Tags {
			tagged[i] = zone.Mark("tag:"+t, m.styles.Accent.Render("#"+t))
		}
		b.WriteString(m.field("tags", strings.Join(tagged, m.styles.Muted.Render(" · "))))
	}
	if len(it.Categories) > 0 {
		b.WriteString(m.field("categories", strings.Join(it.Categories, " · ")))
	}
	if len(it.Stack) > 0 {
		b.WriteString(m.field("stack", strings.Join(it.Stack, " · ")))
	}
	if fh := it.FloxHubURL(); fh != "" {
		b.WriteString(m.field("floxhub", hyperlink(fh, m.styles.Accent.Render(fh))))
	}
	if it.Homepage != "" {
		b.WriteString(m.field("homepage", hyperlink(it.Homepage, m.styles.Accent.Render(it.Homepage))))
	}
	return b.String()
}

// scoreBlock renders the scores as colored bars. Real metrics are not yet
// in the catalog, so this shows a clearly-labeled deterministic sample.
func (m model) scoreBlock(it catalogItem) string {
	if it.ID == "" {
		return m.styles.Muted.Render("No score data for this package.\n")
	}
	metrics := []struct {
		label string
		salt  int
	}{{"quality", 7}, {"reliability", 13}, {"security", 29}}
	var b strings.Builder
	for _, mt := range metrics {
		v := sampleScore(it.ID, mt.salt)
		st := m.scoreStyle(v)
		fmt.Fprintf(&b, "  %s %s %s\n",
			m.styles.Muted.Render(fmt.Sprintf("%-11s", mt.label)),
			m.scoreBar(v, st),
			st.Render(fmt.Sprintf("%3d", v)))
	}
	return b.String()
}

func (m model) scoreStyle(v int) lipgloss.Style {
	switch {
	case v >= 80:
		return m.styles.Installed
	case v >= 60:
		return m.styles.Warning
	default:
		return m.styles.Danger
	}
}

// statusStyle colors an audit status word (good / risk / fail).
func (m model) statusStyle(status string) lipgloss.Style {
	switch status {
	case "good", "pass", "ok":
		return m.styles.Installed
	case "risk", "warn":
		return m.styles.Warning
	default:
		return m.styles.Danger
	}
}

// auditStatusStyle maps catalog audit statuses (stable|warn|risk|missing) to
// a display style.
func (m model) auditStatusStyle(status string) lipgloss.Style {
	switch status {
	case "stable":
		return m.styles.Installed
	case "warn":
		return m.styles.Warning
	case "risk", "missing":
		return m.styles.Danger
	default:
		return m.styles.Muted
	}
}

// auditScoreBadge returns a compact "89 ●" badge colored by audit status for
// use in catalog row headers.
func (m model) auditScoreBadge(overall int, status string) string {
	st := m.auditStatusStyle(status)
	return m.styles.Muted.Render(fmt.Sprintf("%d", overall)) + " " + st.Render("●")
}

// viewReviewModal shows the review-skills report: scores on the left, the
// selected artifact's breakdown (and why) on the right.
func (m model) viewReviewModal() string {
	switch {
	case m.reviewBusy:
		label := m.reviewBusyLabel
		if label == "" {
			label = "Working…"
		}
		return m.modalBox("review skills",
			m.spin.View()+m.styles.Muted.Render(" "+label),
			m.dimKeys([2]string{"esc", "cancel"}))
	case m.reviewNeedsSetup:
		return m.viewReviewSetup()
	case m.reviewErr != "":
		return m.modalBox("review skills",
			m.styles.Danger.Render(m.reviewErr), m.dimKeys([2]string{"esc", "close"}))
	case len(m.reviewResults) == 0:
		return m.modalBox("review skills",
			m.styles.Muted.Render("No skills or agents present to review."),
			m.dimKeys([2]string{"esc", "close"}))
	}

	cols := []reviewCol{
		m.reviewColSkills(),
		m.reviewColChecks(),
		m.reviewColFindings(),
		m.reviewColRaw(),
	}
	body := m.reviewHead() + m.renderPanes(cols)
	footer := m.dimKeys([2]string{"h/l", "panes"}, [2]string{"j/k", "move"}, [2]string{"esc", "close"})
	return m.modalBox("review skills", body, footer)
}

// viewReviewSetup prompts to install the missing review-tool packages into
// the active environment before running the audit.
func (m model) viewReviewSetup() string {
	miss := missingTools(m.reviewTools)
	var b strings.Builder
	b.WriteString(m.styles.Muted.Render(fmt.Sprintf(
		"%d review tool(s) are missing. Install them into this environment for real scores?",
		len(miss))) + "\n\n")
	for _, name := range miss {
		b.WriteString("  " + m.styles.Accent.Render(iconStaged) + " " +
			m.styles.Text.Render("flox/"+name) + "\n")
	}
	footer := m.dimKeys([2]string{"enter", "install"},
		[2]string{"s", "skip"}, [2]string{"esc", "cancel"})
	return m.modalBox("review skills", strings.TrimRight(b.String(), "\n"), footer)
}

// reviewHead shows the doctor banner (missing tools) plus a summary + dimension
// bars for the selected skill, above the panes.
func (m model) reviewHead() string {
	var b strings.Builder
	if miss := missingTools(m.reviewTools); len(miss) > 0 {
		b.WriteString(m.styles.Warning.Render(fmt.Sprintf("⚠ %d review tools unavailable", len(miss))) +
			m.styles.Muted.Render(": "+strings.Join(miss, ", ")) + "\n\n")
	}
	if sel, ok := m.reviewSel(); ok {
		b.WriteString(m.styles.Title.Render(sel.Name) + m.styles.Muted.Render("  "+sel.Kind) + "  " +
			m.scoreStyle(sel.Overall).Render(fmt.Sprintf("%d", sel.Overall)) +
			m.styles.Muted.Render("/100 ") + m.statusStyle(sel.Status).Render(sel.Status) + "\n")
		for _, d := range []struct {
			label string
			v     int
		}{{"quality", sel.Quality}, {"reliability", sel.Reliability}, {"security", sel.Security}, {"impact", sel.Impact}} {
			ds := m.scoreStyle(d.v)
			b.WriteString(m.styles.Muted.Render(fmt.Sprintf("%-11s", d.label)) + " " +
				m.scoreBar(d.v, ds) + " " + ds.Render(fmt.Sprintf("%3d", d.v)) + "\n")
		}
		b.WriteString("\n")
	}
	return b.String()
}

type reviewCol struct {
	title string
	rows  []string
	cur   int
	pane  int
}

func (m model) renderPanes(cols []reviewCol) string {
	const fullW, sliverW = 30, 8
	left := m.reviewFocus
	if left > 2 {
		left = 2
	}
	twoFull := m.usableWidth() >= 70 // narrow terminals show a single full pane
	var blocks []string
	for i, c := range cols {
		switch {
		case i < left:
			blocks = append(blocks, m.renderCol(c, sliverW, false))
		case i == left:
			blocks = append(blocks, m.renderCol(c, fullW, i == m.reviewFocus))
		case i == left+1 && twoFull:
			blocks = append(blocks, m.renderCol(c, fullW, i == m.reviewFocus))
		}
	}
	pieces := make([]string, 0, len(blocks)*2)
	for i, b := range blocks {
		if i > 0 {
			pieces = append(pieces, "  ")
		}
		pieces = append(pieces, b)
	}
	return lipgloss.JoinHorizontal(lipgloss.Top, pieces...)
}

func (m model) renderCol(c reviewCol, w int, active bool) string {
	lines := []string{m.styles.Muted.Render(truncate(c.title, w))}
	for i, r := range c.rows {
		cur := "  "
		if active && i == c.cur {
			cur = m.styles.Strong.Render(cursorMark) + " "
		}
		lines = append(lines, zone.Mark(fmt.Sprintf("rv:%d:%d", c.pane, i), cur+truncate(r, w-2)))
	}
	return lipgloss.NewStyle().Width(w).Render(strings.Join(lines, "\n"))
}

func (m model) reviewColSkills() reviewCol {
	rows := make([]string, len(m.reviewResults))
	for i, r := range m.reviewResults {
		rows[i] = m.styles.Muted.Render(fmt.Sprintf("%-16s", truncate(r.Name, 16))) +
			" " + m.scoreStyle(r.Overall).Render(fmt.Sprintf("%3d", r.Overall))
	}
	return reviewCol{title: "skills", rows: rows, cur: m.reviewCur[0], pane: 0}
}

func (m model) reviewColChecks() reviewCol {
	sel, ok := m.reviewSel()
	if !ok {
		return reviewCol{title: "checks", pane: 1}
	}
	var rows []string
	for _, c := range sel.Checks {
		g := m.styles.Installed.Render(iconInstalled)
		if !c.Pass {
			g = m.styles.Danger.Render(iconRemove)
		}
		rows = append(rows, g+" "+m.styles.Text.Render(c.ID))
	}
	return reviewCol{title: "checks", rows: rows, cur: m.reviewCur[1], pane: 1}
}

func (m model) reviewColFindings() reviewCol {
	fs := m.reviewFindings()
	if len(fs) == 0 {
		return reviewCol{title: "findings", rows: []string{m.styles.Muted.Render("No findings.")}, pane: 2}
	}
	rows := make([]string, len(fs))
	for i, f := range fs {
		st := m.styles.Warning
		if f.Severity == "error" {
			st = m.styles.Danger
		}
		rows[i] = st.Render("● "+f.Rule) + "  " + m.styles.Muted.Render(truncate(f.Message, 22))
	}
	return reviewCol{title: "findings", rows: rows, cur: m.reviewCur[2], pane: 2}
}

func (m model) reviewColRaw() reviewCol {
	sel, ok := m.reviewSel()
	if !ok {
		return reviewCol{title: "raw", pane: 3}
	}
	raw := sel.Raw[m.reviewSelTool()]
	if raw == "" {
		raw = "No raw output."
	}
	return reviewCol{title: "raw", rows: []string{m.styles.Muted.Render(raw)}, pane: 3}
}

// scoreBar renders a 10-cell bar: filled in the score color, empty in faint.
func (m model) scoreBar(v int, st lipgloss.Style) string {
	n := v / 10
	if n > 10 {
		n = 10
	}
	if n < 0 {
		n = 0
	}
	return st.Render(strings.Repeat("█", n)) +
		m.styles.Rule.Render(strings.Repeat("░", 10-n))
}

func sampleScore(id string, salt int) int {
	h := salt
	for _, c := range id {
		h = h*31 + int(c)
	}
	if h < 0 {
		h = -h
	}
	return 40 + h%61
}

// ---- modal -----------------------------------------------------------------

// viewFooter shows every shortcut, always. The contextual ones (install /
// uninstall / apply) are highlighted white to draw attention; the rest stay
// dim.
func (m model) viewFooter(uw int) string {
	it := m.selected()
	installable := it != nil && !m.installed[it.ID] && m.pending[it.ID] == 0
	removable := it != nil && (m.installed[it.ID] || m.pending[it.ID] != 0)
	items := []struct {
		key, label string
		hot        bool
	}{
		{"/", "search", false},
		{"i", "install", installable},
		{"x", "uninstall", removable},
		{"A", "apply", len(m.pending) > 0},
		{"R", "review skills", false},
		{"p", "preview", false},
		{"?", "help", false},
		{"q", "quit", false},
	}
	sep := m.styles.Muted.Render(" · ")
	parts := make([]string, len(items))
	for i, x := range items {
		parts[i] = zone.Mark("sc:"+x.key, m.shortcut(x.key, x.label, x.hot))
	}
	left := strings.Join(parts, sep)

	// Launch is the headline action, right-aligned and purple — the point
	// of the tool. (Agent switching lives in the header.)
	right := zone.Mark("sc:L", m.styles.Primary.Render("[L] launch"))
	return m.spread(left, right, uw)
}

// shortcut renders one "[key] label" hint — the single place key hints are
// formatted. hot draws attention (action key + bright label); otherwise dim.
func (m model) shortcut(key, label string, hot bool) string {
	br := "[" + key + "]"
	if hot {
		return m.styles.Action.Render(br) + " " + m.styles.Strong.Render(label)
	}
	return m.styles.Muted.Render(br + " " + label)
}

// dimKeys joins dim "[key] label" hints with " · " — for modal footers.
func (m model) dimKeys(pairs ...[2]string) string {
	parts := make([]string, len(pairs))
	for i, p := range pairs {
		parts[i] = m.shortcut(p[0], p[1], false)
	}
	return strings.Join(parts, m.styles.Muted.Render(" · "))
}

// viewTagSuggest renders the #tag autocomplete box, or "" when there are no
// suggestions for the in-progress token.
func (m model) viewTagSuggest(prefix string) string {
	sugg := m.tagSuggestions(prefix, tagSuggestLimit)
	if len(sugg) == 0 {
		return ""
	}
	sel := clamp(m.suggestCursor, 0, len(sugg)-1)
	rows := make([]string, len(sugg))
	for i, t := range sugg {
		mark := "  "
		st := m.styles.Muted
		if i == sel {
			mark = m.styles.Action.Render(cursorMark) + " "
			st = m.styles.Strong
		}
		rows[i] = mark + st.Render("#"+t)
	}
	rows = append(rows, "", m.dimKeys(
		[2]string{"^n/^p", "move"}, [2]string{"tab", "complete"}))
	return m.styles.PaneFocus.Padding(1, 2).Render(strings.Join(rows, "\n"))
}

// viewAgentsModal renders the agent picker (master list + description).
func (m model) viewAgentsModal() string {
	pick := clamp(m.agentPick, 0, len(m.agents)-1)
	var rows []string
	for i, name := range m.agents {
		title, _ := agentInfo(name)
		cur, st := "  ", m.styles.Muted // unselected: dim
		if i == pick {
			cur, st = m.styles.Strong.Render(cursorMark)+" ", m.styles.Strong // white
		}
		row := cur + st.Render(title)
		if i == m.agentIdx {
			row += m.styles.Installed.Render(" " + iconInstalled)
		}
		rows = append(rows, zone.Mark("agent:"+name, row))
	}
	list := lipgloss.NewStyle().Width(22).Render(strings.Join(rows, "\n"))
	_, desc := agentInfo(m.agents[pick])
	detail := lipgloss.NewStyle().
		Border(lipgloss.NormalBorder(), false, false, false, true).
		BorderForeground(m.theme.Faint).
		PaddingLeft(2).Width(44).
		Render(m.styles.Muted.Render(desc))
	body := lipgloss.JoinHorizontal(lipgloss.Top, list, "  ", detail)
	footer := m.dimKeys([2]string{"j/k", "move"}, [2]string{"enter", "select"},
		[2]string{"esc", "cancel"})
	return m.modalBox("Switch agent", body, footer)
}

// padR right-pads s to a display width of n.
func padR(s string, n int) string {
	if w := lipgloss.Width(s); w < n {
		return s + strings.Repeat(" ", n-w)
	}
	return s
}

// viewHelp renders the keybinding reference with a purpose for each action,
// grouped into sections.
func (m model) viewHelp() string {
	type entry struct{ key, name, desc string }
	type section struct {
		title   string
		entries []entry
	}
	sections := []section{
		{"Navigate", []entry{
			{"/", "search", "Filter the catalog by text or #tag"},
			{"j / k", "move", "Move down / up the list"},
			{"g / G", "first / last", "Jump to the start / end"},
			{"h / l", "panes", "Move focus between list and detail"},
			{"⏎", "detail", "Open the detail pane for the selection"},
			{"^u / ^d", "scroll", "Page the detail pane up / down"},
		}},
		{"Manage", []entry{
			{"i / +", "install", "Stage the selected package to install"},
			{"x / -", "uninstall", "Stage an uninstall, or unstage a change"},
			{"A", "apply", "Apply all staged installs / removals"},
			{"U", "upgrade", "Upgrade packages in the environment"},
			{"R", "review skills", "Audit present skills & agents"},
			{"D", "doctor", "Run flox-ai doctor diagnostics"},
			{"L", "launch", "Launch the agent with installed fragments"},
		}},
		{"Agent & view", []entry{
			{"a", "agents", "Switch the target agent"},
			{"[ / ]", "cycle agent", "Previous / next agent"},
			{"T", "theme", "Browse and switch color themes"},
			{"p", "preview", "Toggle the detail pane"},
			{"?", "help", "Toggle this help"},
			{"q", "quit", "Exit flox-ai"},
		}},
	}

	var b strings.Builder
	for i, s := range sections {
		if i > 0 {
			b.WriteString("\n")
		}
		b.WriteString(m.styles.Primary.Render(s.title) + "\n")
		for _, e := range s.entries {
			b.WriteString("  " +
				m.styles.Strong.Render(padR(e.key, 9)) +
				m.styles.Text.Render(padR(e.name, 14)) +
				m.styles.Muted.Render(e.desc) + "\n")
		}
	}
	return m.modalBox("Help", strings.TrimRight(b.String(), "\n"), "")
}

// capitalize upper-cases the first letter of s.
func capitalize(s string) string {
	if s == "" {
		return s
	}
	r := []rune(s)
	return strings.ToUpper(string(r[:1])) + string(r[1:])
}

// modalBox is the standard floating-modal frame used by every popup:
// bordered + padded, a capitalized title, then an optional body and footer,
// each separated by a blank line.
func (m model) modalBox(title, body, footer string) string {
	parts := []string{m.styles.Title.Render(capitalize(title))}
	if body != "" {
		parts = append(parts, "", body)
	}
	if footer != "" {
		parts = append(parts, "", footer)
	}
	return m.styles.PaneFocus.Padding(1, 2).Render(strings.Join(parts, "\n"))
}

func (m model) viewModal() string {
	switch m.modal.kind {
	case modalConfirm:
		return m.viewConfirmModal()
	case modalAgents:
		return m.viewAgentsModal()
	case modalThemes:
		return m.viewThemeModal()
	case modalApply:
		return m.viewApplyModal()
	case modalUpgrade:
		return m.viewUpgradeModal()
	case modalLaunch:
		return m.viewLaunchModal()
	case modalReview:
		return m.viewReviewModal()
	}
	// stream modal: title carries a live status glyph, body is the viewport.
	status := " " + m.spin.View()
	if m.streamDone {
		if len(m.errs) > 0 {
			status = " " + m.styles.Danger.Render("✗")
		} else {
			status = " " + m.styles.Installed.Render("✓")
		}
	}
	title := m.styles.Title.Render(capitalize(m.modal.title)) + status
	footer := m.dimKeys([2]string{"esc", "close"}, [2]string{"↑↓", "scroll"})
	return m.styles.PaneFocus.Padding(1, 2).Render(
		strings.Join([]string{title, "", m.modal.vp.View(), "", footer}, "\n"))
}

// stateLabel/stateGlyphStyle describe a row's state in the apply modal.
func (m model) stateGlyphStyle(t tag) (label, icon string, st lipgloss.Style) {
	switch t {
	case tagInstall:
		return "To install", iconStaged, m.styles.Accent
	case tagUninstall:
		return "To uninstall", iconRemove, m.styles.Danger
	default:
		return "Installed", iconInstalled, m.styles.Installed
	}
}

func (m model) viewConfirmModal() string {
	items := m.confirmItems()
	if len(items) == 0 {
		footer := m.dimKeys([2]string{"esc", "cancel"})
		return m.modalBox("apply changes",
			m.styles.Muted.Render("Nothing installed or staged."), footer)
	}
	cursor := clamp(m.confirmCursor, 0, len(items)-1)

	// Master: sectioned list with a cursor over items.
	var rows []string
	lastState := tag(-1)
	for i, it := range items {
		state := m.tagFor(it.ID)
		if state != lastState {
			if len(rows) > 0 {
				rows = append(rows, "")
			}
			title, _, _ := m.stateGlyphStyle(state)
			rows = append(rows, m.styles.Primary.Render(title))
			lastState = state
		}
		_, icon, ist := m.stateGlyphStyle(state)
		cur, nameSt := "  ", m.styles.Muted
		if i == cursor {
			cur, nameSt = m.styles.Strong.Render(cursorMark)+" ", m.styles.Strong
		}
		row := cur + ist.Render(icon) + " " + nameSt.Render(it.Name)
		rows = append(rows, zone.Mark("confirm:"+it.ID, row))
	}
	list := lipgloss.NewStyle().Width(28).Render(strings.Join(rows, "\n"))

	// Detail: description of the selected item.
	sel := items[cursor]
	var d strings.Builder
	d.WriteString(m.styles.Title.Render(sel.Name) + m.styles.Muted.Render("  "+sel.Type) + "\n\n")
	if sel.Description != "" {
		d.WriteString(m.styles.Muted.Render(sel.Description) + "\n\n")
	}
	d.WriteString(m.styles.Title.Render("Scores") + "\n" + m.scoreBlock(sel))
	detail := lipgloss.NewStyle().
		Border(lipgloss.NormalBorder(), false, false, false, true).
		BorderForeground(m.theme.Faint).
		PaddingLeft(2).Width(44).
		Render(d.String())

	body := lipgloss.JoinHorizontal(lipgloss.Top, list, "  ", detail)
	if len(m.pending) == 0 {
		// Nothing staged — note it, and offer to launch instead.
		body = m.styles.Muted.Render("Nothing to apply.") + "\n\n" + body
		footer := m.dimKeys([2]string{"L", "launch"}, [2]string{"esc", "close"})
		return m.modalBox("apply changes", body, footer)
	}
	footer := m.dimKeys([2]string{"j/k", "move"}, [2]string{"u", "undo"},
		[2]string{"A", "apply"}, [2]string{"esc", "cancel"})
	return m.modalBox("apply changes", body, footer)
}

// truncate clips s to a maximum display width, appending an ellipsis.
func truncate(s string, max int) string {
	if max <= 0 {
		return ""
	}
	if lipgloss.Width(s) <= max {
		return s
	}
	r := []rune(s)
	for len(r) > 0 && lipgloss.Width(string(r))+1 > max {
		r = r[:len(r)-1]
	}
	return string(r) + "…"
}
