package tui

import (
	"fmt"
	"strings"

	"charm.land/bubbles/v2/spinner"
	tea "charm.land/bubbletea/v2"

	"flox.dev/flox-ai/internal/manifest"
)

// upgradeCheckMsg carries the result of the background upgrade check.
type upgradeCheckMsg struct {
	ups      []Upgrade
	includes bool
}

// apply step states.
const (
	stepPending = iota
	stepRunning
	stepDone
	stepFailed
)

// applyStep is one install/uninstall shown as a single, in-place line.
type applyStep struct {
	name  string
	verb  string // "install" or "uninstall"
	pkg   string // pkg-path (install) or install-id (uninstall)
	state int
}

// applyStepMsg updates a step's state during apply.
type applyStepMsg struct{ idx, state int }

// streamLineMsg is one line of output from a streaming action.
type streamLineMsg string

// streamDoneMsg ends a streaming action. installed is non-nil only for
// apply (which reloads the manifest).
type streamDoneMsg struct {
	errs      []string
	installed map[string]bool
}

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.width, m.height = msg.Width, msg.Height
		m.help.SetWidth(msg.Width)
		m.syncDetail()
		if m.modal.kind == modalStream {
			m.modal.vp = newModalViewport(m.width, m.height)
			m.modal.vp.SetContent(m.streamLog)
			m.modal.vp.GotoBottom()
		}
		return m, nil
	case applyStepMsg:
		if msg.idx >= 0 && msg.idx < len(m.applySteps) {
			m.applySteps[msg.idx].state = msg.state
		}
		return m, m.waitStreamCmd()
	case streamLineMsg:
		m.streamLog += string(msg) + "\n"
		if m.modal.kind == modalStream {
			m.modal.vp.SetContent(m.streamLog)
			m.modal.vp.GotoBottom()
		}
		return m, m.waitStreamCmd()
	case spinner.TickMsg:
		spinning := (m.modal.kind == modalStream || m.modal.kind == modalApply) && !m.streamDone
		spinning = spinning || (m.modal.kind == modalReview && m.reviewBusy)
		if spinning {
			var cmd tea.Cmd
			m.spin, cmd = m.spin.Update(msg)
			return m, cmd
		}
		return m, nil
	case reviewDoctorMsg:
		m.reviewBusy = false
		m.reviewTools = msg.tools
		switch {
		case msg.err != nil:
			m.reviewErr = msg.err.Error()
			return m, nil
		}
		if len(missingTools(msg.tools)) > 0 {
			m.reviewNeedsSetup = true // prompt before the report
			return m, nil
		}
		return m.beginReviewAudit()
	case reviewInstalledMsg:
		if msg.installed != nil {
			m.installed = msg.installed
			m.clampCursor()
			m.syncDetail()
		}
		if len(msg.errs) > 0 {
			m.reviewBusy = false
			m.reviewErr = "install failed: " + strings.Join(msg.errs, "; ")
			return m, nil
		}
		return m.beginReviewAudit()
	case reviewDoneMsg:
		m.reviewBusy = false
		m.reviewResults = msg.results
		if msg.tools != nil {
			m.reviewTools = msg.tools
		}
		m.reviewFocus = 0
		m.reviewCur = [4]int{}
		switch {
		case msg.err != nil:
			m.reviewErr = msg.err.Error()
		default:
			m.reviewErr = ""
		}
		return m, nil
	case streamDoneMsg:
		m.streamDone = true
		if msg.installed != nil {
			m.installed = msg.installed
			m.pending = map[string]action{}
			m.clampCursor()
			m.syncDetail()
		}
		m.errs = msg.errs
		if m.modal.kind == modalStream {
			if len(msg.errs) > 0 {
				m.streamLog += fmt.Sprintf("\n%d error(s). [esc] close\n", len(msg.errs))
			} else {
				m.streamLog += "\nDone. [esc] close\n"
			}
			m.modal.vp.SetContent(m.streamLog)
			m.modal.vp.GotoBottom()
		}
		return m, nil
	case splashTickMsg:
		if m.phase != phaseSplash {
			return m, nil
		}
		m.splashN++
		if m.splashN >= splashTotal {
			m.finishSplash()
			return m, nil
		}
		return m, splashTick()
	case tea.KeyPressMsg:
		if m.phase == phaseSplash { // any key skips the animation
			m.finishSplash()
			return m, nil
		}
		return m.handleKey(msg)
	case tea.MouseClickMsg:
		if m.phase == phaseSplash {
			m.finishSplash()
			return m, nil
		}
		return m.handleMouse(msg)
	case tea.BackgroundColorMsg:
		// Terminal reported (or changed) its background. Match the theme to
		// the new appearance.
		dark := msg.IsDark()
		if !m.themeUserSet {
			// No explicit choice: use the default for this appearance.
			m.applyTint(defaultTintIndexFor(m.tintIDs, dark))
			m.syncDetail()
		} else if sib := siblingFor(m.tintIDs[m.tintIdx], dark); sib != "" {
			// A chosen theme flips to its light/dark sibling when one exists.
			if i := m.tintIndexOf(sib); i >= 0 {
				m.applyTint(i)
				m.syncDetail()
			}
		}
		return m, nil
	case upgradeCheckMsg:
		// Only surface upgrades for packages we manage (AI fragments + the
		// agent runtime), not arbitrary dev-env packages.
		managed := m.managedSet()
		m.upgrades = nil
		for _, u := range msg.ups {
			if managed[u.Pkg] {
				m.upgrades = append(m.upgrades, u)
			}
		}
		m.hasIncludes = msg.includes
		// Don't interrupt the startup animation; finishSplash opens it.
		if m.phase == phaseReady && len(m.upgrades) > 0 && !m.modal.open() && m.query == "" {
			m.modal = modalState{kind: modalUpgrade, title: "upgrade"}
		}
		return m, nil
	}
	return m, nil
}

// syncDetail refreshes the detail viewport with the selected item.
func (m *model) syncDetail() {
	w, h := m.detailDims()
	if w <= 0 || h <= 0 {
		return
	}
	m.detailVP.SetWidth(w)
	m.detailVP.SetHeight(h)
	body := ""
	if it := m.selected(); it != nil {
		body = m.detailBody(*it)
	}
	m.detailVP.SetContent(body)
	m.detailVP.GotoTop()
}

func (m model) handleKey(msg tea.KeyPressMsg) (tea.Model, tea.Cmd) {
	if m.modal.open() {
		return m.handleModalKey(msg)
	}
	if m.mode == modeSearch {
		return m.handleSearchKey(msg)
	}
	return m.handleNormalKey(msg)
}

func (m model) handleModalKey(msg tea.KeyPressMsg) (tea.Model, tea.Cmd) {
	switch msg.String() {
	case "ctrl+c":
		return m, tea.Quit
	}
	if m.modal.kind == modalConfirm {
		switch msg.String() {
		case "j", "down":
			m.confirmCursor = clamp(m.confirmCursor+1, 0, max(0, len(m.confirmItems())-1))
		case "k", "up":
			m.confirmCursor = clamp(m.confirmCursor-1, 0, max(0, len(m.confirmItems())-1))
		case "u":
			// Undo the staged change for the selected item (unstage only —
			// never stages a new removal).
			if items := m.confirmItems(); len(items) > 0 {
				it := items[clamp(m.confirmCursor, 0, len(items)-1)]
				if m.pending[it.ID] != 0 {
					delete(m.pending, it.ID)
					m.confirmCursor = clamp(m.confirmCursor, 0, max(0, len(m.confirmItems())-1))
				}
			}
		case "A", "y", "enter":
			if len(m.pending) > 0 {
				return m.startApply()
			}
			m.modal = modalState{} // nothing to apply — just close
		case "L":
			m.modal = modalState{kind: modalLaunch, title: "launch"}
		case "esc", "q", "n":
			m.modal = modalState{}
		}
		return m, nil
	}
	if m.modal.kind == modalUpgrade {
		switch msg.String() {
		case "U", "y", "enter":
			if len(m.upgrades) > 0 {
				return m.startUpgrade()
			}
		case "esc", "q", "n":
			m.modal = modalState{}
		}
		return m, nil
	}
	if m.modal.kind == modalApply {
		// Actionable only once the apply has finished.
		if m.streamDone {
			switch msg.String() {
			case "L":
				m.modal = modalState{kind: modalLaunch, title: "launch"}
			case "a":
				m.agentPick = m.agentIdx
				m.modal = modalState{kind: modalAgents, title: "Switch agent"}
			case "esc", "q", "enter":
				m.modal = modalState{}
			}
		}
		return m, nil
	}
	if m.modal.kind == modalLaunch {
		switch msg.String() {
		case "enter", "L", "y":
			m.launch = true
			m.persist()
			return m, tea.Quit
		case "a":
			m.agentPick = m.agentIdx
			m.modal = modalState{kind: modalAgents, title: "Switch agent"}
		case "esc", "q", "n":
			m.modal = modalState{}
		}
		return m, nil
	}
	if m.modal.kind == modalAgents {
		switch msg.String() {
		case "j", "down":
			if m.agentPick < len(m.agents)-1 {
				m.agentPick++
			}
		case "k", "up":
			if m.agentPick > 0 {
				m.agentPick--
			}
		case "enter", " ", "l":
			m.setAgent(m.agentPick)
			m.modal = modalState{}
			m.syncDetail()
		case "esc", "q", "a", "h":
			m.modal = modalState{}
		}
		return m, nil
	}
	if m.modal.kind == modalThemes {
		if m.tintSearching {
			switch msg.String() {
			case "esc", "enter", "down":
				m.tintSearching = false
			case "backspace":
				if m.tintQuery != "" {
					m.tintQuery = m.tintQuery[:len(m.tintQuery)-1]
					m.tintPick = 0
					m.previewTintAt()
				}
			default:
				if t := msg.Key().Text; t != "" {
					m.tintQuery += t
					m.tintPick = 0
					m.previewTintAt()
				}
			}
			return m, nil
		}
		const page = 11
		switch msg.String() {
		case "j", "down":
			m.tintPick++
			m.previewTintAt()
		case "k", "up":
			m.tintPick--
			m.previewTintAt()
		case "J", "shift+down", "pgdown", "ctrl+d":
			m.tintPick += page
			m.previewTintAt()
		case "K", "shift+up", "pgup", "ctrl+u":
			m.tintPick -= page
			m.previewTintAt()
		case "g", "home":
			m.tintPick = 0
			m.previewTintAt()
		case "G", "end":
			m.tintPick = len(m.filteredTints())
			m.previewTintAt()
		case "/":
			m.tintSearching = true
		case "f":
			m.tintFilter = (m.tintFilter + 1) % 3
			m.tintPick = 0
			m.previewTintAt()
		case "enter":
			m.modal = modalState{} // keep
			m.themeUserSet = true
			m.syncDetail()
			m.persist()
		case "esc", "q", "T":
			m.applyTint(m.tintOrig) // revert
			m.modal = modalState{}
			m.syncDetail()
		}
		return m, nil
	}
	if m.modal.kind == modalReview {
		switch {
		case m.reviewBusy:
			if s := msg.String(); s == "esc" || s == "q" {
				m.modal = modalState{}
			}
			return m, nil
		case m.reviewNeedsSetup:
			switch msg.String() {
			case "enter", "y", "i":
				pkgs := missingToolPkgs(m.reviewTools)
				m.reviewNeedsSetup = false
				m.reviewBusy = true
				m.reviewBusyLabel = "Installing review tools…"
				return m, tea.Batch(m.runInstallToolsCmd(pkgs), m.spin.Tick)
			case "s":
				return m.beginReviewAudit()
			case "esc", "q", "n":
				m.modal = modalState{}
			}
			return m, nil
		}
		switch msg.String() {
		case "l", "right", "enter":
			if m.reviewFocus < 3 {
				m.reviewFocus++
			}
		case "h", "left":
			if m.reviewFocus > 0 {
				m.reviewFocus--
			}
		case "j", "down":
			n := m.reviewPaneLen(m.reviewFocus)
			m.reviewCur[m.reviewFocus] = clamp(m.reviewCur[m.reviewFocus]+1, 0, max(0, n-1))
			for d := m.reviewFocus + 1; d < 4; d++ {
				m.reviewCur[d] = 0
			}
		case "k", "up":
			n := m.reviewPaneLen(m.reviewFocus)
			m.reviewCur[m.reviewFocus] = clamp(m.reviewCur[m.reviewFocus]-1, 0, max(0, n-1))
			for d := m.reviewFocus + 1; d < 4; d++ {
				m.reviewCur[d] = 0
			}
		case "g", "home":
			m.reviewCur[m.reviewFocus] = 0
		case "G", "end":
			m.reviewCur[m.reviewFocus] = max(0, m.reviewPaneLen(m.reviewFocus)-1)
		case "esc", "q":
			m.modal = modalState{}
		}
		return m, nil
	}
	// stream modal
	switch msg.String() {
	case "esc", "q":
		m.modal = modalState{}
		return m, nil
	default:
		var cmd tea.Cmd
		m.modal.vp, cmd = m.modal.vp.Update(msg)
		return m, cmd
	}
}

// review flow messages.
type (
	// reviewDoctorMsg carries the tool-availability check that precedes the
	// audit (and the optional install prompt).
	reviewDoctorMsg struct {
		tools []toolStatus
		err   error
	}
	// reviewInstalledMsg ends the "install missing tools" step.
	reviewInstalledMsg struct {
		errs      []string
		installed map[string]bool
	}
	// reviewDoneMsg carries the structured audit report back to the UI.
	reviewDoneMsg struct {
		results []auditResult
		tools   []toolStatus
		err     error
	}
)

// startReview opens the review flow: check tools first, prompt to install any
// missing ones, then audit.
func (m model) startReview() (tea.Model, tea.Cmd) {
	m.reviewResults, m.reviewTools, m.reviewErr = nil, nil, ""
	m.reviewFocus = 0
	m.reviewCur = [4]int{}
	m.reviewNeedsSetup = false
	m.reviewBusy = true
	m.reviewBusyLabel = "Checking review tools…"
	m.modal = modalState{kind: modalReview, title: "review skills"}
	return m, tea.Batch(m.runDoctorCheckCmd(m.reviewer), m.spin.Tick)
}

// beginReviewAudit runs the per-skill/agent audit and shows the report.
func (m model) beginReviewAudit() (tea.Model, tea.Cmd) {
	m.reviewNeedsSetup = false
	m.reviewBusy = true
	m.reviewBusyLabel = "Reviewing skills & agents…"
	return m, tea.Batch(m.runAuditCmd(m.reviewer), m.spin.Tick)
}

func (m model) runDoctorCheckCmd(a Auditor) tea.Cmd {
	share := m.shareDir
	return func() tea.Msg {
		tools, err := a.DoctorTools(share)
		return reviewDoctorMsg{tools: tools, err: err}
	}
}

func (m model) runAuditCmd(a Auditor) tea.Cmd {
	share := m.shareDir
	return func() tea.Msg {
		tools, _ := a.DoctorTools(share)
		results, err := a.Audit(share)
		return reviewDoneMsg{results: results, tools: tools, err: err}
	}
}

// runInstallToolsCmd installs the missing review-tool packages into the
// active environment, then reloads the installed set.
func (m model) runInstallToolsCmd(pkgs []string) tea.Cmd {
	inst := m.installer
	projectDir := m.projectDir
	return func() tea.Msg {
		discard := func(string) {}
		var errs []string
		for _, p := range pkgs {
			if err := inst.Install(p, discard); err != nil {
				errs = append(errs, err.Error())
			}
		}
		installed, _ := manifest.Installed(projectDir)
		return reviewInstalledMsg{errs: errs, installed: installed}
	}
}

func (m model) handleSearchKey(msg tea.KeyPressMsg) (tea.Model, tea.Cmd) {
	switch msg.String() {
	case "ctrl+c":
		return m, tea.Quit
	case "esc", "enter":
		m.mode = modeNormal
		m.focus = focusList
		return m, nil
	case "ctrl+n":
		m.moveSuggest(1)
		return m, nil
	case "ctrl+p":
		m.moveSuggest(-1)
		return m, nil
	case "tab":
		m.completeTag()
		m.syncDetail()
		return m, nil
	case "down":
		// Drop out of the search box into the list (gh-dash behavior).
		m.mode = modeNormal
		m.focus = focusList
		return m, nil
	case "backspace":
		if m.query != "" {
			m.query = m.query[:len(m.query)-1]
			m.cursor = 0
			m.suggestCursor = 0
			m.syncDetail()
		}
		return m, nil
	case "space":
		m.query += " "
		m.cursor = 0
		m.suggestCursor = 0
		m.syncDetail()
		return m, nil
	}
	if t := msg.Key().Text; t != "" {
		m.query += t
		m.cursor = 0
		m.suggestCursor = 0
		m.syncDetail()
	}
	return m, nil
}

// moveSuggest moves the #tag completion selection, clamped to the current
// suggestion count.
func (m *model) moveSuggest(d int) {
	prefix, ok := m.activeTokenTag()
	if !ok {
		return
	}
	n := len(m.tagSuggestions(prefix, tagSuggestLimit))
	if n == 0 {
		return
	}
	m.suggestCursor = clamp(m.suggestCursor+d, 0, n-1)
}

func (m model) handleNormalKey(msg tea.KeyPressMsg) (tea.Model, tea.Cmd) {
	if m.showHelp {
		m.showHelp = false
		m.help.ShowAll = false
		return m, nil
	}

	// Keys handled the same in either focus.
	switch msg.String() {
	case "ctrl+c", "q":
		m.persist()
		return m, tea.Quit
	case "?":
		m.showHelp = true
		m.help.ShowAll = true
		return m, nil
	case "/":
		m.mode = modeSearch
		return m, nil
	case "p":
		m.showDetail = !m.showDetail
		if !m.showDetail {
			m.focus = focusList
		}
		m.syncDetail()
		m.persist()
		return m, nil
	case "i", "+":
		if it := m.selected(); it != nil {
			m.stageInstall(it.ID)
			m.syncDetail()
		}
		return m, nil
	case "x", "-":
		if it := m.selected(); it != nil {
			m.remove(it.ID)
			m.syncDetail()
		}
		return m, nil
	case "A":
		// Always open — shows installed state even with nothing staged.
		m.confirmCursor = 0
		m.modal = modalState{kind: modalConfirm, title: "apply changes"}
		return m, nil
	case "a":
		m.agentPick = m.agentIdx
		m.modal = modalState{kind: modalAgents, title: "Switch agent"}
		return m, nil
	case "U":
		m.modal = modalState{kind: modalUpgrade, title: "upgrade"}
		return m, nil
	case "T":
		m.tintOrig = m.tintIdx
		m.tintQuery, m.tintSearching = "", false
		m.tintFilter = defaultTintFilter() // match current appearance
		m.tintPick = 0
		if m.tintIdx < len(m.tintIDs) {
			for i, id := range m.filteredTints() {
				if id == m.tintIDs[m.tintIdx] {
					m.tintPick = i
					break
				}
			}
		}
		m.modal = modalState{kind: modalThemes, title: "Theme"}
		return m, nil
	case "R":
		return m.startReview()
	case "D":
		return m.startStream("doctor", m.runDoctorCmd)
	case "L":
		m.modal = modalState{kind: modalLaunch, title: "launch"}
		return m, nil
	case "[":
		m.prevAgent()
		m.syncDetail()
		return m, nil
	case "]":
		m.nextAgent()
		m.syncDetail()
		return m, nil
	}

	if m.focus == focusDetail {
		return m.handleDetailKey(msg)
	}
	return m.handleListKey(msg)
}

func (m model) handleListKey(msg tea.KeyPressMsg) (tea.Model, tea.Cmd) {
	switch msg.String() {
	case "j", "down":
		m.moveCursor(1)
	case "k", "up":
		m.moveCursor(-1)
	case "g", "home":
		m.cursor = 0
		m.syncDetail()
	case "G", "end":
		m.cursor = max(0, len(m.visibleItems())-1)
		m.syncDetail()
	case "l", "right", "enter":
		if m.showDetail && m.selected() != nil {
			m.focus = focusDetail
		}
	}
	return m, nil
}

func (m model) handleDetailKey(msg tea.KeyPressMsg) (tea.Model, tea.Cmd) {
	switch msg.String() {
	case "h", "left", "esc":
		m.focus = focusList
	case "j", "down":
		m.detailVP.ScrollDown(1)
	case "k", "up":
		m.detailVP.ScrollUp(1)
	case "ctrl+d":
		m.detailVP.HalfPageDown()
	case "ctrl+u":
		m.detailVP.HalfPageUp()
	}
	return m, nil
}

func (m *model) moveCursor(d int) {
	n := len(m.visibleItems())
	m.cursor = clamp(m.cursor+d, 0, n-1)
	m.syncDetail()
}

func clamp(v, lo, hi int) int {
	if hi < lo {
		return lo
	}
	if v < lo {
		return lo
	}
	if v > hi {
		return hi
	}
	return v
}

// startStream opens a stream modal and kicks off a producer cmd.
func (m model) startStream(title string, factory func(chan tea.Msg) tea.Cmd) (tea.Model, tea.Cmd) {
	m.streamLog = ""
	m.streamDone = false
	ch := make(chan tea.Msg, 256)
	m.streamCh = ch
	vp := newModalViewport(m.width, m.height)
	m.modal = modalState{kind: modalStream, title: title, vp: vp}
	return m, tea.Batch(factory(ch), m.waitStreamCmd(), m.spin.Tick)
}

func (m model) waitStreamCmd() tea.Cmd {
	ch := m.streamCh
	return func() tea.Msg { return <-ch }
}

// startApply runs the staged changes, showing one in-place line per change.
func (m model) startApply() (tea.Model, tea.Cmd) {
	installs, uninstalls := m.pendingOps()
	nameByPkg, nameByID := map[string]string{}, map[string]string{}
	for _, it := range m.items {
		nameByPkg[it.InstallPkg] = it.Name
		nameByID[installIDOf(it)] = it.Name
	}
	name := func(mp map[string]string, k string) string {
		if n := mp[k]; n != "" {
			return n
		}
		return k
	}
	var steps []applyStep
	for _, p := range installs {
		steps = append(steps, applyStep{name: name(nameByPkg, p), verb: "install", pkg: p})
	}
	for _, id := range uninstalls {
		steps = append(steps, applyStep{name: name(nameByID, id), verb: "uninstall", pkg: id})
	}
	m.applySteps = steps
	m.applyInstalls, m.applyRemoves = len(installs), len(uninstalls)
	m.streamDone = false
	m.errs = nil
	ch := make(chan tea.Msg, 256)
	m.streamCh = ch
	m.modal = modalState{kind: modalApply, title: "apply"}
	return m, tea.Batch(m.runApplyCmd(ch), m.waitStreamCmd())
}

// startUpgrade runs the available upgrades, streaming output into the modal.
func (m model) startUpgrade() (tea.Model, tea.Cmd) {
	m.streamLog = ""
	m.streamDone = false
	m.errs = nil
	m.upgrades = nil // optimistic; re-checked on next launch
	ch := make(chan tea.Msg, 256)
	m.streamCh = ch
	m.modal = modalState{kind: modalStream, title: "upgrade", vp: newModalViewport(m.width, m.height)}
	return m, tea.Batch(m.runUpgradeCmd(ch), m.waitStreamCmd(), m.spin.Tick)
}

func (m model) runUpgradeCmd(ch chan tea.Msg) tea.Cmd {
	up := m.upgrader
	projectDir := m.projectDir
	return func() tea.Msg {
		emit := func(s string) { ch <- streamLineMsg(s) }
		var errs []string
		if up != nil {
			if err := up.Run(emit); err != nil {
				errs = append(errs, err.Error())
				emit("error: " + err.Error())
			}
		}
		installed, _ := manifest.Installed(projectDir)
		ch <- streamDoneMsg{errs: errs, installed: installed}
		return nil
	}
}

func (m model) runApplyCmd(ch chan tea.Msg) tea.Cmd {
	steps := m.applySteps
	inst, unin := m.installer, m.uninstaller
	projectDir := m.projectDir
	return func() tea.Msg {
		discard := func(string) {}
		var errs []string
		for i, s := range steps {
			ch <- applyStepMsg{i, stepRunning}
			var err error
			if s.verb == "install" {
				err = inst.Install(s.pkg, discard)
			} else {
				err = unin.Uninstall(s.pkg, discard)
			}
			if err != nil {
				errs = append(errs, err.Error())
				ch <- applyStepMsg{i, stepFailed}
			} else {
				ch <- applyStepMsg{i, stepDone}
			}
		}
		installed, err := manifest.Installed(projectDir)
		if err != nil {
			errs = append(errs, "reload installed: "+err.Error())
		}
		ch <- streamDoneMsg{errs: errs, installed: installed}
		return nil
	}
}

func (m model) runDoctorCmd(ch chan tea.Msg) tea.Cmd {
	doc := m.doctor
	share, cfg := m.shareDir, m.configDir
	return func() tea.Msg {
		emit := func(s string) { ch <- streamLineMsg(s) }
		var errs []string
		if err := doc.Run(share, cfg, emit); err != nil {
			errs = append(errs, err.Error())
			emit("error: " + err.Error())
		}
		ch <- streamDoneMsg{errs: errs}
		return nil
	}
}
