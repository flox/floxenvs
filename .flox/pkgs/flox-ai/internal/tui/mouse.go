package tui

import (
	"fmt"
	"strings"

	tea "charm.land/bubbletea/v2"
	zone "github.com/lrstanley/bubblezone/v2"
)

// The TUI uses a single global bubblezone manager; Mark wraps clickable
// regions and Scan (called in View) records their screen bounds.
func init() { zone.NewGlobal() }

// footerKeys are the clickable footer shortcuts. Clicking one runs the same
// action as pressing the key.
var footerKeys = []string{"/", "i", "x", "A", "D", "p", "?", "q", "L"}

// handleMouse routes a left click to whatever zone it landed in.
func (m model) handleMouse(msg tea.MouseClickMsg) (tea.Model, tea.Cmd) {
	if msg.Mouse().Button != tea.MouseLeft {
		return m, nil
	}

	switch m.modal.kind {
	case modalThemes:
		for i, id := range m.filteredTints() {
			if zone.Get("tint:" + id).InBounds(msg) {
				m.tintPick = i
				m.previewTintAt()
				return m, nil
			}
		}
		return m, nil
	case modalAgents:
		for i, name := range m.agents {
			if zone.Get("agent:" + name).InBounds(msg) {
				m.setAgent(i)
				m.modal = modalState{}
				m.syncDetail()
				return m, nil
			}
		}
		return m, nil
	case modalConfirm:
		for i, it := range m.confirmItems() {
			if zone.Get("confirm:" + it.ID).InBounds(msg) {
				m.confirmCursor = i
				return m, nil
			}
		}
		return m, nil
	case modalReview:
		for p := 0; p < 4; p++ {
			for i := 0; i < m.reviewPaneLen(p); i++ {
				if zone.Get(fmt.Sprintf("rv:%d:%d", p, i)).InBounds(msg) {
					m.reviewFocus = p
					m.reviewCur[p] = i
					return m, nil
				}
			}
		}
		return m, nil
	case modalNone:
		// handled below
	default:
		return m, nil // confirm / stream modals: ignore clicks
	}

	if zone.Get("search").InBounds(msg) {
		m.mode = modeSearch
		return m, nil
	}
	if zone.Get("agents").InBounds(msg) {
		m.agentPick = m.agentIdx
		m.modal = modalState{kind: modalAgents, title: "Switch agent"}
		return m, nil
	}
	if zone.Get("apply").InBounds(msg) {
		m.confirmCursor = 0
		m.modal = modalState{kind: modalConfirm, title: "apply changes"}
		return m, nil
	}
	if zone.Get("upgrade-hint").InBounds(msg) {
		m.modal = modalState{kind: modalUpgrade, title: "upgrade"}
		return m, nil
	}

	items := m.visibleItems()
	for i, it := range items {
		if zone.Get("item:" + it.ID).InBounds(msg) {
			m.cursor = i
			m.focus = focusList
			m.syncDetail()
			return m, nil
		}
	}

	if it := m.selected(); it != nil {
		for _, t := range it.Tags {
			if zone.Get("tag:" + t).InBounds(msg) {
				if m.query != "" && !strings.HasSuffix(m.query, " ") {
					m.query += " "
				}
				m.query += "#" + t
				m.cursor = 0
				m.syncDetail()
				return m, nil
			}
		}
	}

	for _, k := range footerKeys {
		if zone.Get("sc:" + k).InBounds(msg) {
			return m.handleNormalKey(tea.KeyPressMsg{Text: k})
		}
	}
	return m, nil
}
