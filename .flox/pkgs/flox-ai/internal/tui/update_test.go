package tui

import (
	"errors"
	"strings"
	"testing"
	"time"

	"charm.land/bubbles/v2/spinner"
	tea "charm.land/bubbletea/v2"
)

// fakeAuditor is a test double for the Auditor interface.
type fakeAuditor struct {
	tools   []toolStatus
	results []auditResult
}

func (f fakeAuditor) DoctorTools(string) ([]toolStatus, error) { return f.tools, nil }
func (f fakeAuditor) Audit(string) ([]auditResult, error)      { return f.results, nil }

// drainStream runs a producer cmd against m.streamCh and returns the
// terminal streamDoneMsg plus all streamed lines.
func drainStream(m model, producer tea.Cmd) (streamDoneMsg, []string) {
	go producer()
	var lines []string
	for {
		switch msg := (<-m.streamCh).(type) {
		case streamLineMsg:
			lines = append(lines, string(msg))
		case streamDoneMsg:
			return msg, lines
		}
	}
}

func TestApplyStreamsAndReloads(t *testing.T) {
	var installed, uninstalled []string
	m := newModel(testItems(), map[string]bool{"skills-graphify": true},
		[]string{"claude"},
		InstallerFunc(func(p string, out LineFunc) error { installed = append(installed, p); out("ok " + p); return nil }),
		UninstallerFunc(func(id string, out LineFunc) error { uninstalled = append(uninstalled, id); return nil }),
		nil, nil, "share", "cfg", "proj")
	m.applySteps = []applyStep{
		{name: "Caveman", verb: "install", pkg: "flox/claude-code-plugin-caveman"},
		{name: "Graphify", verb: "uninstall", pkg: "skills-graphify"},
	}
	ch := make(chan tea.Msg, 256)
	m.streamCh = ch
	done, _ := drainStream(m, m.runApplyCmd(ch))
	if len(installed) != 1 || installed[0] != "flox/claude-code-plugin-caveman" {
		t.Errorf("installed %v", installed)
	}
	if len(uninstalled) != 1 || uninstalled[0] != "skills-graphify" {
		t.Errorf("uninstalled %v", uninstalled)
	}
	if done.installed == nil {
		t.Error("apply must reload installed set")
	}
}

func TestDoctorStreams(t *testing.T) {
	m := newModel(testItems(), nil, []string{"claude"}, nil, nil, nil,
		DoctorFunc(func(s, c string, out LineFunc) error { out("all valid"); return nil }),
		"share", "cfg", "proj")
	ch := make(chan tea.Msg, 256)
	m.streamCh = ch
	_, lines := drainStream(m, m.runDoctorCmd(ch))
	if !strings.Contains(strings.Join(lines, "\n"), "all valid") {
		t.Errorf("missing doctor line: %v", lines)
	}
}

func TestApplyCollectsErrors(t *testing.T) {
	m := newModel(testItems(), map[string]bool{}, []string{"claude"},
		InstallerFunc(func(p string, out LineFunc) error { return errors.New("boom") }),
		UninstallerFunc(func(id string, out LineFunc) error { return nil }),
		nil, nil, "s", "c", "p")
	m.applySteps = []applyStep{{name: "Foo", verb: "install", pkg: "flox/skills-foo"}}
	ch := make(chan tea.Msg, 256)
	m.streamCh = ch
	done, _ := drainStream(m, m.runApplyCmd(ch))
	if len(done.errs) != 1 {
		t.Fatalf("expected 1 error, got %v", done.errs)
	}
}

// key feeds a KeyPressMsg, returning the updated model.
func pressKey(m model, s string) model {
	var km tea.KeyPressMsg
	switch s {
	case "enter":
		km = tea.KeyPressMsg{Code: tea.KeyEnter}
	case "esc":
		km = tea.KeyPressMsg{Code: tea.KeyEsc}
	default:
		km = tea.KeyPressMsg{Text: s}
	}
	mm, _ := m.Update(km)
	return mm.(model)
}

func TestSearchStageThenView(t *testing.T) {
	m := newModel(testItems(), map[string]bool{}, []string{"claude"},
		InstallerFunc(func(p string, out LineFunc) error { return nil }),
		UninstallerFunc(func(id string, out LineFunc) error { return nil }),
		fakeAuditor{},
		DoctorFunc(func(s, c string, out LineFunc) error { return nil }),
		"share", "cfg", "proj")
	mm, _ := m.Update(tea.WindowSizeMsg{Width: 100, Height: 30})
	m = mm.(model)
	m = pressKey(m, "c") // search "c"
	m = pressKey(m, "a")
	m = pressKey(m, "v")
	m = pressKey(m, "e")
	m = pressKey(m, "enter") // -> normal
	m = pressKey(m, "i")     // stage install hovered
	if m.pending["claude-code-plugin-caveman"] != actionInstall {
		t.Fatalf("expected caveman staged install; pending=%v", m.pending)
	}
	view := m.View().Content
	if !strings.Contains(view, "staged") || !strings.Contains(view, "Caveman") {
		t.Errorf("view should show the staged item; got:\n%s", view)
	}
}

func TestApplyViaKeysStreams(t *testing.T) {
	var called int
	m := newModel(testItems(), map[string]bool{}, []string{"claude"},
		InstallerFunc(func(p string, out LineFunc) error { called++; out("ok"); return nil }),
		UninstallerFunc(func(id string, out LineFunc) error { return nil }),
		fakeAuditor{},
		DoctorFunc(func(s, c string, out LineFunc) error { return nil }),
		"share", "cfg", "proj")
	mm, _ := m.Update(tea.WindowSizeMsg{Width: 100, Height: 30})
	m = mm.(model)
	m.mode = modeNormal // leave search mode so "A" triggers apply, not query input
	m.pending = map[string]action{"claude-code-plugin-caveman": actionInstall}
	// "A" opens the confirm modal; it must not stream yet.
	mm, _ = m.Update(tea.KeyPressMsg{Text: "A"})
	m = mm.(model)
	if m.modal.kind != modalConfirm {
		t.Fatalf("A must open the apply confirm modal; kind=%v", m.modal.kind)
	}
	if m.streamCh != nil {
		t.Fatal("confirm modal must not start the stream yet")
	}
	// Confirming with "A" starts the stream.
	mm, cmd := m.Update(tea.KeyPressMsg{Text: "A"})
	m = mm.(model)
	if m.streamCh == nil {
		t.Fatal("apply must create the stream channel")
	}
	if cmd == nil {
		t.Fatal("apply must return a command")
	}
	// drain the producer synchronously (it was started by startStream's batch;
	// run it directly against the same channel to assert the installer ran)
	go m.runApplyCmd(m.streamCh)()
	deadline := time.After(2 * time.Second)
	for {
		select {
		case msg := <-m.streamCh:
			if _, ok := msg.(streamDoneMsg); ok {
				if called < 1 {
					t.Fatalf("installer not called")
				}
				return
			}
		case <-deadline:
			t.Fatal("timed out waiting for stream done")
		}
	}
}

// TestSearchDownExitsToList covers the gh-dash behavior: pressing Down
// while editing the search drops focus into the result list.
func TestSearchDownExitsToList(t *testing.T) {
	m := newTestModel(nil)
	m.mode = modeSearch
	mm, _ := m.Update(tea.KeyPressMsg{Code: tea.KeyDown})
	m = mm.(model)
	if m.mode != modeNormal || m.focus != focusList {
		t.Fatalf("Down in search must enter the list; mode=%v focus=%v", m.mode, m.focus)
	}
}

// TestSearchHashTagFilters covers typing a #tag token in the search box.
func TestSearchHashTagFilters(t *testing.T) {
	m := newTestModel(nil)
	m.mode = modeSearch
	for _, r := range "#ai" {
		mm, _ := m.Update(tea.KeyPressMsg{Text: string(r)})
		m = mm.(model)
	}
	if m.query != "#ai" {
		t.Fatalf("query = %q, want #ai", m.query)
	}
	if !has(m.results(), "claude-code-plugin-caveman") {
		t.Errorf("#ai must filter to ai-tagged items: %v", m.results())
	}
}

func TestAgentPickerOpens(t *testing.T) {
	m := newTestModel(nil)
	m.mode = modeNormal
	mm, _ := m.Update(tea.KeyPressMsg{Text: "a"})
	m = mm.(model)
	if m.modal.kind != modalAgents {
		t.Fatalf("a must open the agent picker; kind=%v", m.modal.kind)
	}
	// esc closes it
	mm, _ = m.Update(tea.KeyPressMsg{Code: tea.KeyEscape})
	m = mm.(model)
	if m.modal.open() {
		t.Error("esc must close the agent picker")
	}
}

func TestTabCompletesTag(t *testing.T) {
	m := newTestModel(nil)
	m.mode = modeSearch
	m.query = "#a" // testItems have an "ai" tag
	mm, _ := m.Update(tea.KeyPressMsg{Code: tea.KeyTab})
	m = mm.(model)
	if m.query != "#ai " {
		t.Fatalf("tab must complete #a -> %q, got %q", "#ai ", m.query)
	}
}

func TestSpinnerStopsWhenStreamDone(t *testing.T) {
	m := newTestModel(nil)
	m.modal = modalState{kind: modalStream, title: "apply"}
	m.streamDone = true
	_, cmd := m.Update(spinner.TickMsg{})
	if cmd != nil {
		t.Error("spinner must not re-tick after the stream finished")
	}
}
