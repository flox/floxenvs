package tui

import "strings"

// agentFor maps a launchable agent name to the meta.yaml "for" value.
func agentFor(agent string) string {
	switch agent {
	case "claude":
		return "claude-code"
	default:
		return agent
	}
}

// agentDisplay is the short, brand-style title for an agent (e.g. "Claude"),
// distinct from the CLI name ("claude").
func agentDisplay(name string) string {
	switch name {
	case "claude":
		return "Claude"
	case "":
		return ""
	default:
		return strings.ToUpper(name[:1]) + name[1:]
	}
}

// agentInfo returns a display title and description for an agent, shown in
// the agent-picker popup.
func agentInfo(name string) (title, desc string) {
	switch name {
	case "claude":
		return "Claude Code",
			"Anthropic's Claude Code CLI. Injects the fragments present in " +
				"this environment — rules, skills, agents and plugins — then " +
				"launches claude."
	default:
		return name, "AI coding agent."
	}
}

// agentLaunch explains what launching an agent does, its limitations, and
// what to expect — shown on the launch confirmation.
func agentLaunch(name string) string {
	switch name {
	case "claude":
		return "Starts Claude Code with this environment's plugins, skills, " +
			"agents and rules injected into its config.\n\n" +
			"Only Claude Code is supported for now — more agents are planned.\n\n" +
			"You can install or remove fragments and relaunch any time."
	default:
		return "Starts the agent with the installed plugins, skills, agents and rules."
	}
}

func (m *model) setAgent(i int) {
	if i < 0 || i >= len(m.agents) {
		return
	}
	m.agentIdx = i
	m.onAgentChange()
}

func (m *model) nextAgent() {
	if m.agentIdx < len(m.agents)-1 {
		m.agentIdx++
		m.onAgentChange()
	}
}

func (m *model) prevAgent() {
	if m.agentIdx > 0 {
		m.agentIdx--
		m.onAgentChange()
	}
}

func (m *model) onAgentChange() {
	m.cursor = 0
	m.focus = focusList
}
