package tui

import "charm.land/bubbles/v2/key"

// keyMap is the full set of TUI key bindings; it also feeds the
// context-aware help footer.
type keyMap struct {
	Search      key.Binding
	Up          key.Binding
	Down        key.Binding
	First       key.Binding
	Last        key.Binding
	FocusList   key.Binding
	Detail      key.Binding
	PageUp      key.Binding
	PageDown    key.Binding
	Install     key.Binding
	Remove      key.Binding
	Apply       key.Binding
	Review      key.Binding
	Doctor      key.Binding
	Launch      key.Binding
	Agents      key.Binding
	Theme       key.Binding
	PrevAgent   key.Binding
	NextAgent   key.Binding
	Preview     key.Binding
	AuditDetail key.Binding
	Close       key.Binding
	Help        key.Binding
	Quit        key.Binding
}

func defaultKeyMap() keyMap {
	return keyMap{
		Search:      key.NewBinding(key.WithKeys("/"), key.WithHelp("/", "search")),
		Up:          key.NewBinding(key.WithKeys("k", "up"), key.WithHelp("k", "up")),
		Down:        key.NewBinding(key.WithKeys("j", "down"), key.WithHelp("j", "down")),
		First:       key.NewBinding(key.WithKeys("g", "home"), key.WithHelp("g", "first")),
		Last:        key.NewBinding(key.WithKeys("G", "end"), key.WithHelp("G", "last")),
		FocusList:   key.NewBinding(key.WithKeys("h", "left"), key.WithHelp("h", "list")),
		Detail:      key.NewBinding(key.WithKeys("l", "right", "enter"), key.WithHelp("l", "detail")),
		PageUp:      key.NewBinding(key.WithKeys("ctrl+u"), key.WithHelp("^u", "page up")),
		PageDown:    key.NewBinding(key.WithKeys("ctrl+d"), key.WithHelp("^d", "page down")),
		Install:     key.NewBinding(key.WithKeys("i"), key.WithHelp("i", "install")),
		Remove:      key.NewBinding(key.WithKeys("x"), key.WithHelp("x", "remove")),
		Apply:       key.NewBinding(key.WithKeys("A"), key.WithHelp("A", "apply")),
		Review:      key.NewBinding(key.WithKeys("R"), key.WithHelp("R", "review skills")),
		Doctor:      key.NewBinding(key.WithKeys("D"), key.WithHelp("D", "doctor")),
		Launch:      key.NewBinding(key.WithKeys("L"), key.WithHelp("L", "launch")),
		Agents:      key.NewBinding(key.WithKeys("a"), key.WithHelp("a", "agents")),
		Theme:       key.NewBinding(key.WithKeys("T"), key.WithHelp("T", "theme")),
		PrevAgent:   key.NewBinding(key.WithKeys("["), key.WithHelp("[", "prev agent")),
		NextAgent:   key.NewBinding(key.WithKeys("]"), key.WithHelp("]", "next agent")),
		Preview:     key.NewBinding(key.WithKeys("p"), key.WithHelp("p", "preview")),
		AuditDetail: key.NewBinding(key.WithKeys("V"), key.WithHelp("V", "view audit")),
		Close:       key.NewBinding(key.WithKeys("esc"), key.WithHelp("esc", "close")),
		Help:        key.NewBinding(key.WithKeys("?"), key.WithHelp("?", "help")),
		Quit:        key.NewBinding(key.WithKeys("q", "ctrl+c"), key.WithHelp("q", "quit")),
	}
}

// shortHelp returns the compact footer bindings for the current context.
func (k keyMap) shortHelp(m model) []key.Binding {
	if m.modal.open() {
		if m.modal.kind == modalConfirm {
			return []key.Binding{k.Apply, k.Close, k.Quit}
		}
		return []key.Binding{k.PageUp, k.PageDown, k.Close, k.Quit}
	}
	switch m.mode {
	case modeSearch:
		return []key.Binding{k.Down, k.Close, k.Quit}
	default:
		if m.focus == focusDetail {
			return []key.Binding{k.Up, k.Down, k.PageDown, k.FocusList,
				k.Install, k.Remove, k.Help, k.Quit}
		}
		return []key.Binding{k.Down, k.Up, k.Search, k.Detail, k.Install,
			k.Remove, k.Apply, k.Launch, k.Preview, k.Help, k.Quit}
	}
}

// fullHelp returns the grouped bindings for the `?` help overlay.
func (k keyMap) fullHelp(m model) [][]key.Binding {
	return [][]key.Binding{
		{k.Search, k.Up, k.Down, k.First, k.Last},
		{k.FocusList, k.Detail, k.Preview, k.PageUp, k.PageDown},
		{k.Install, k.Remove, k.Apply, k.Review, k.Doctor},
		{k.Launch, k.Agents, k.Theme, k.PrevAgent, k.NextAgent},
		{k.AuditDetail},
		{k.Help, k.Quit},
	}
}
