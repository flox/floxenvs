package tui

import (
	"sort"
	"strings"

	"charm.land/bubbles/v2/help"
	"charm.land/bubbles/v2/spinner"
	"charm.land/bubbles/v2/viewport"
	tea "charm.land/bubbletea/v2"

	"flox.dev/flox-ai/internal/catalog"
)

type catalogItem = catalog.Item

type action int

const (
	actionInstall action = iota + 1
	actionUninstall
)

type mode int

const (
	modeSearch mode = iota // editing the query (default on start)
	modeNormal             // navigating results / detail
)

type focusPane int

const (
	focusList focusPane = iota
	focusDetail
)

type tag int

const (
	tagNone tag = iota
	tagInstalled
	tagInstall
	tagUninstall
)

type model struct {
	items     []catalogItem
	installed map[string]bool
	pending   map[string]action

	agents   []string
	agentIdx int

	query string

	mode   mode
	focus  focusPane
	cursor int

	agentPick     int // cursor in the agent-picker popup
	confirmCursor int // cursor in the apply/confirm modal
	suggestCursor int // selected #tag completion suggestion

	showDetail bool
	detailVP   viewport.Model

	modal modalState

	keys     keyMap
	help     help.Model
	showHelp bool
	spin     spinner.Model

	streamDone    bool
	applyInstalls int // planned counts for the apply progress header
	applyRemoves  int
	applySteps    []applyStep

	theme         Theme
	styles        Styles
	tintIDs       []string
	tintIdx       int
	tintOrig      int  // tint before opening the picker (for revert)
	themeUserSet  bool // user picked a theme; don't auto-switch on bg change
	tintPick      int  // cursor in the (filtered) picker list
	tintQuery     string
	tintSearching bool
	tintFilter    int // 0 all, 1 dark, 2 light

	installer   Installer
	uninstaller Uninstaller
	reviewer    Auditor
	doctor      DoctorRunner
	upgrader    Upgrader

	upgrades    []Upgrade // available upgrades (from background check)
	hasIncludes bool

	shareDir   string
	configDir  string
	projectDir string

	streamCh  chan tea.Msg
	streamLog string

	// Review report (modalReview): structured audit results + tool doctor.
	reviewResults    []auditResult
	reviewTools      []toolStatus
	reviewFocus      int    // 0 skills · 1 checks · 2 findings · 3 raw
	reviewCur        [4]int // cursor within each pane
	reviewErr        string
	reviewBusy       bool   // doctor / install / audit in flight
	reviewBusyLabel  string // spinner caption while busy
	reviewNeedsSetup bool   // missing tools — show the install prompt

	errs   []string
	launch bool

	phase   int // phaseReady (default) or phaseSplash
	splashN int // animation frame counter

	width  int
	height int
}

func newModel(items []catalogItem, installed map[string]bool,
	agents []string, inst Installer, unin Uninstaller,
	rev Auditor, doc DoctorRunner, shareDir, configDir, projectDir string) model {
	if installed == nil {
		installed = map[string]bool{}
	}
	m := model{
		items:       items,
		installed:   installed,
		pending:     map[string]action{},
		agents:      agents,
		query:       "",
		mode:        modeSearch,
		focus:       focusList,
		showDetail:  true,
		detailVP:    viewport.New(),
		keys:        defaultKeyMap(),
		help:        help.New(),
		spin:        spinner.New(spinner.WithSpinner(spinner.Dot)),
		installer:   inst,
		uninstaller: unin,
		reviewer:    rev,
		doctor:      doc,
		shareDir:    shareDir,
		configDir:   configDir,
		projectDir:  projectDir,
	}
	m.tintIDs = sortedTintIDs()
	cfg := loadConfig(projectDir)
	idx := defaultTintIndex(m.tintIDs)
	if cfg.Theme != "" {
		for i, id := range m.tintIDs {
			if id == cfg.Theme {
				idx = i
				break
			}
		}
	}
	m.applyTint(idx)
	m.showDetail = cfg.Preview
	m.themeUserSet = cfg.Theme != "" // respect a saved choice
	m.upgrader = FloxUpgrader{ProjectDir: projectDir}
	// Default to claude when available; the agent list is sorted, so index 0
	// would otherwise land on agent-deck.
	for i, a := range agents {
		if a == "claude" {
			m.agentIdx = i
			break
		}
	}
	return m
}

// Init requests the terminal background color (for theming), checks for
// upgrades in the background (held back until the splash finishes), and — when
// started with the splash enabled — kicks off the startup animation.
func (m model) Init() tea.Cmd {
	cmds := []tea.Cmd{tea.RequestBackgroundColor, m.checkUpgradesCmd()}
	if m.phase == phaseSplash {
		cmds = append(cmds, splashTick())
	}
	return tea.Batch(cmds...)
}

func (m model) checkUpgradesCmd() tea.Cmd {
	up := m.upgrader
	if up == nil {
		return nil
	}
	return func() tea.Msg {
		ups, inc, _ := up.Check()
		return upgradeCheckMsg{ups: ups, includes: inc}
	}
}

func (m model) currentAgent() string {
	if m.agentIdx < 0 || m.agentIdx >= len(m.agents) {
		return ""
	}
	return m.agents[m.agentIdx]
}

func (m model) matchesAgent(it catalogItem) bool {
	if it.For == "" {
		return true
	}
	return it.For == agentFor(m.currentAgent())
}

// parseQuery splits the raw query into free text and #tag tokens.
func parseQuery(q string) (text string, tags []string) {
	var words []string
	for _, tok := range strings.Fields(q) {
		if len(tok) > 1 && tok[0] == '#' {
			tags = append(tags, strings.ToLower(tok[1:]))
		} else {
			words = append(words, tok)
		}
	}
	return strings.Join(words, " "), tags
}

func hasAllTags(it catalogItem, tags []string) bool {
	if len(tags) == 0 {
		return true
	}
	have := map[string]bool{}
	for _, t := range it.Tags {
		have[strings.ToLower(t)] = true
	}
	for _, t := range tags {
		if !have[t] {
			return false
		}
	}
	return true
}

// results returns the search matches for the current query.
func (m model) results() []catalogItem {
	text, tags := parseQuery(m.query)
	var out []catalogItem
	for _, it := range m.items {
		if !m.matchesAgent(it) || !it.Match(text) || !hasAllTags(it, tags) {
			continue
		}
		out = append(out, it)
	}
	return out
}

// isTopPicks reports whether the list is showing the default recommendations
// (no query typed yet) rather than search results.
func (m model) isTopPicks() bool {
	text, tags := parseQuery(m.query)
	return text == "" && len(tags) == 0
}

// visibleItems is what the list renders: the idle set when there is no query,
// else search results.
func (m model) visibleItems() []catalogItem {
	if m.isTopPicks() {
		return m.idleItems()
	}
	return m.results()
}

// idleItems is the default list: currently-installed packages if any are
// installed, otherwise the curated top picks.
func (m model) idleItems() []catalogItem {
	if inst := m.installedPicks(); len(inst) > 0 {
		return inst
	}
	return m.topPicks()
}

// installedPicks returns the installed catalog packages for the agent, by name.
func (m model) installedPicks() []catalogItem {
	var out []catalogItem
	for _, it := range m.items {
		if m.matchesAgent(it) && m.installed[it.ID] {
			out = append(out, it)
		}
	}
	sort.Slice(out, func(i, j int) bool { return out[i].Name < out[j].Name })
	return out
}

const topPicksLimit = 8

// topPicks returns a curated default set for the current agent: featured
// first, then by title.
func (m model) topPicks() []catalogItem {
	var out []catalogItem
	for _, it := range m.items {
		if m.matchesAgent(it) {
			out = append(out, it)
		}
	}
	sort.Slice(out, func(i, j int) bool {
		a, b := out[i], out[j]
		if a.Featured != b.Featured {
			return a.Featured
		}
		return a.Name < b.Name
	})
	if len(out) > topPicksLimit {
		out = out[:topPicksLimit]
	}
	return out
}

// structuralTags are tags that just restate the type or target agent; they
// appear on nearly every item and make poor discovery filters.
var structuralTags = map[string]bool{
	"plugin": true, "skill": true, "agent": true, "rule": true,
	"claude-code": true, "claude": true,
}

// popularTags returns the n most common meaningful tags for the current
// agent (structural tags excluded).
func (m model) popularTags(n int) []string {
	freq := map[string]int{}
	for _, it := range m.items {
		if !m.matchesAgent(it) {
			continue
		}
		for _, t := range it.Tags {
			lt := strings.ToLower(t)
			if structuralTags[lt] {
				continue
			}
			freq[lt]++
		}
	}
	tags := make([]string, 0, len(freq))
	for t := range freq {
		tags = append(tags, t)
	}
	sort.Slice(tags, func(i, j int) bool {
		if freq[tags[i]] != freq[tags[j]] {
			return freq[tags[i]] > freq[tags[j]]
		}
		return tags[i] < tags[j]
	})
	if len(tags) > n {
		tags = tags[:n]
	}
	return tags
}

// activeTokenTag returns the in-progress "#prefix" token at the end of the
// query (without the #), or "", false if the query doesn't end in one.
func (m model) activeTokenTag() (string, bool) {
	if m.query == "" || m.query[len(m.query)-1] == ' ' {
		return "", false
	}
	fields := strings.Fields(m.query)
	last := fields[len(fields)-1]
	if len(last) >= 1 && last[0] == '#' {
		return strings.ToLower(last[1:]), true
	}
	return "", false
}

// tagSuggestions returns up to n tags (for the current agent) that start
// with prefix, most common first.
func (m model) tagSuggestions(prefix string, n int) []string {
	freq := map[string]int{}
	for _, it := range m.items {
		if !m.matchesAgent(it) {
			continue
		}
		for _, t := range it.Tags {
			lt := strings.ToLower(t)
			if strings.HasPrefix(lt, prefix) {
				freq[lt]++
			}
		}
	}
	out := make([]string, 0, len(freq))
	for t := range freq {
		out = append(out, t)
	}
	sort.Slice(out, func(i, j int) bool {
		if freq[out[i]] != freq[out[j]] {
			return freq[out[i]] > freq[out[j]]
		}
		return out[i] < out[j]
	})
	if len(out) > n {
		out = out[:n]
	}
	return out
}

// tagSuggestLimit is how many #tag completions the popup shows.
const tagSuggestLimit = 6

// completeTag replaces the trailing #prefix token with the selected matching
// tag suggestion, if any.
func (m *model) completeTag() {
	prefix, ok := m.activeTokenTag()
	if !ok {
		return
	}
	sugg := m.tagSuggestions(prefix, tagSuggestLimit)
	if len(sugg) == 0 {
		return
	}
	sel := clamp(m.suggestCursor, 0, len(sugg)-1)
	i := strings.LastIndex(m.query, "#")
	m.query = m.query[:i] + "#" + sugg[sel] + " "
	m.cursor = 0
	m.suggestCursor = 0
}

// counts returns installed, staged-install and staged-remove totals for
// the current agent.
func (m model) counts() (installed, toInstall, toRemove int) {
	for _, it := range m.items {
		if !m.matchesAgent(it) {
			continue
		}
		switch m.tagFor(it.ID) {
		case tagInstalled:
			installed++
		case tagInstall:
			toInstall++
		case tagUninstall:
			toRemove++
		}
	}
	return installed, toInstall, toRemove
}

// panelItems returns installed ∪ staged items for the current agent,
// staged-first. Used for counts and the apply diff.
func (m model) panelItems() []catalogItem {
	var out []catalogItem
	for _, it := range m.items {
		if !m.matchesAgent(it) {
			continue
		}
		if m.installed[it.ID] || m.pending[it.ID] != 0 {
			out = append(out, it)
		}
	}
	sort.Slice(out, func(i, j int) bool {
		pi, pj := m.pending[out[i].ID] != 0, m.pending[out[j].ID] != 0
		if pi != pj {
			return pi
		}
		return out[i].ID < out[j].ID
	})
	return out
}

func (m model) tagFor(id string) tag {
	switch m.pending[id] {
	case actionInstall:
		return tagInstall
	case actionUninstall:
		return tagUninstall
	default:
		if m.installed[id] {
			return tagInstalled
		}
		return tagNone
	}
}

// selected returns the item under the list cursor, or nil.
func (m model) selected() *catalogItem {
	list := m.visibleItems()
	if m.cursor < 0 || m.cursor >= len(list) {
		return nil
	}
	it := list[m.cursor]
	return &it
}

// stageInstall stages an install for id unless already installed/staged.
func (m *model) stageInstall(id string) {
	if id == "" || m.installed[id] || m.pending[id] == actionInstall {
		return
	}
	m.pending[id] = actionInstall
}

// remove unstages a pending change, or stages an uninstall for an
// installed item.
func (m *model) remove(id string) {
	if id == "" {
		return
	}
	if m.pending[id] != 0 {
		delete(m.pending, id)
	} else if m.installed[id] {
		m.pending[id] = actionUninstall
	}
}

func (m *model) clampCursor() {
	if n := len(m.visibleItems()); m.cursor >= n {
		m.cursor = max(0, n-1)
	}
	if m.cursor < 0 {
		m.cursor = 0
	}
}

// confirmItems returns the items shown in the apply modal, ordered
// staged-installs, staged-removes, then currently installed; each group
// sorted by id.
func (m model) confirmItems() []catalogItem {
	var ins, rem, inst []catalogItem
	for _, it := range m.items {
		if !m.matchesAgent(it) {
			continue
		}
		switch m.tagFor(it.ID) {
		case tagInstall:
			ins = append(ins, it)
		case tagUninstall:
			rem = append(rem, it)
		case tagInstalled:
			inst = append(inst, it)
		}
	}
	byID := func(a, b catalogItem) bool { return a.ID < b.ID }
	sort.Slice(ins, func(i, j int) bool { return byID(ins[i], ins[j]) })
	sort.Slice(rem, func(i, j int) bool { return byID(rem[i], rem[j]) })
	sort.Slice(inst, func(i, j int) bool { return byID(inst[i], inst[j]) })
	out := append(ins, rem...)
	return append(out, inst...)
}

// pendingOps returns install pkg-paths and uninstall install-ids.
func (m model) pendingOps() (installs, uninstalls []string) {
	byID := map[string]catalogItem{}
	for _, it := range m.items {
		byID[it.ID] = it
	}
	var ids []string
	for id := range m.pending {
		ids = append(ids, id)
	}
	sort.Strings(ids)
	for _, id := range ids {
		it, ok := byID[id]
		if !ok {
			continue
		}
		switch m.pending[id] {
		case actionInstall:
			installs = append(installs, it.InstallPkg)
		case actionUninstall:
			uninstalls = append(uninstalls, installIDOf(it))
		}
	}
	return installs, uninstalls
}

// managedSet is the set of install-ids flox-ai manages: the catalog
// fragments plus the agent runtime (claude-code). Upgrades for anything
// else (dev-env packages) are ignored.
func (m model) managedSet() map[string]bool {
	s := map[string]bool{"claude-code": true}
	for _, it := range m.items {
		s[installIDOf(it)] = true
	}
	return s
}

func installIDOf(it catalogItem) string {
	const p = "flox/"
	if len(it.InstallPkg) > len(p) && it.InstallPkg[:len(p)] == p {
		return it.InstallPkg[len(p):]
	}
	return it.InstallPkg
}
