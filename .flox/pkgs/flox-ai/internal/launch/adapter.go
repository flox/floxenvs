package launch

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
