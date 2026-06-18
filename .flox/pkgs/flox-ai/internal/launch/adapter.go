package launch

import (
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strings"
	"syscall"
)

// Level is the severity of an agent preflight result.
type Level int

const (
	// OK means the agent can launch with fragments injected.
	OK Level = iota
	// Degraded means the agent runs but fragments will not inject.
	Degraded
	// Fail means the agent cannot launch.
	Fail
)

// Status is the result of an agent preflight Check. The zero value is
// OK with no reason.
type Status struct {
	Level  Level
	Reason string // shown by launch (warn/error) and, later, doctor
}

// Context is everything an adapter needs to stage and launch.
type Context struct {
	Bin         string   // resolved absolute binary path (argv[0])
	ShareDir    string   // $FLOX_ENV/share/claude-code (fragment source)
	LaunchDir   string   // per-agent writable cache (ConfigDir/launch/<agent>)
	ConfigDir   string   // $FLOX_ENV_PROJECT/.flox/cache/flox-ai
	Passthrough []string // verbatim args after the agent name
	BaseEnv     []string // os.Environ()
}

// Spec is the resolved process to exec.
type Spec struct {
	Argv []string // Argv[0] == Bin
	Env  []string // full child environment
}

// Adapter knows how to preflight-check and launch one agent with flox
// fragments injected.
type Adapter interface {
	Name() string       // CLI / PATH lookup name, e.g. "claude"
	InstallPkg() string // flox package to suggest when the binary is missing
	Check(bin string) Status
	Build(ctx Context) (Spec, error)
}

// registry maps agent name to its launch Adapter.
var registry = map[string]Adapter{
	"claude":     claudeAdapter{},
	"agent-deck": deckAdapter{},
	"codex":      codexAdapter{},
}

// RegisteredNames returns the registered agent names, sorted. It is the
// single source of truth for the TUI agent picker and SupportedNames.
func RegisteredNames() []string {
	names := make([]string, 0, len(registry))
	for n := range registry {
		names = append(names, n)
	}
	sort.Strings(names)
	return names
}

// SupportedNames returns the supported agent names, sorted and
// comma-joined, for error messages.
func SupportedNames() string {
	return strings.Join(RegisteredNames(), ", ")
}

// Run resolves the agent, verifies its binary, runs the preflight Check,
// builds the launch spec, and execs the agent process (replacing the
// current process). It only returns when something fails before exec.
func Run(opts Options) error {
	ad, ok := registry[opts.AgentName]
	if !ok {
		return fmt.Errorf("unknown agent %q (supported: %s)", opts.AgentName, SupportedNames())
	}
	bin, err := exec.LookPath(ad.Name())
	if err != nil {
		return fmt.Errorf("%s not found on PATH.\nInstall it with: flox install flox/%s",
			ad.Name(), ad.InstallPkg())
	}
	switch st := ad.Check(bin); st.Level {
	case Fail:
		return errors.New(st.Reason)
	case Degraded:
		fmt.Fprintln(os.Stderr, "warning: "+st.Reason)
	}
	ctx := Context{
		Bin:         bin,
		ShareDir:    opts.ShareDir,
		LaunchDir:   filepath.Join(opts.ConfigDir, "launch", opts.AgentName),
		ConfigDir:   opts.ConfigDir,
		Passthrough: opts.Passthrough,
		BaseEnv:     os.Environ(),
	}
	spec, err := ad.Build(ctx)
	if err != nil {
		return err
	}
	return syscall.Exec(spec.Argv[0], spec.Argv, spec.Env)
}
