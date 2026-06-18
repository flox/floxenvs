// opencode.go: runs opencode with flox fragments injected through a
// merged inline config (OPENCODE_CONFIG_CONTENT). opencode merges this
// with the user's own config, so nothing is clobbered. Skills are pointed
// at a staged skill root (opencode follows symlinks); rules become
// instruction file paths; Claude-format plugins are passed as local
// plugin specs.
package launch

import (
	"encoding/json"
	"fmt"

	"flox.dev/flox-ai/internal/discover"
)

// EnvOpencodeConfigContent is opencode's inline-config env var; its value
// is merged with the user's opencode config.
const EnvOpencodeConfigContent = "OPENCODE_CONFIG_CONTENT"

type opencodeAdapter struct{}

var _ Adapter = opencodeAdapter{}

func (opencodeAdapter) Name() string        { return "opencode" }
func (opencodeAdapter) InstallPkg() string  { return "opencode" }
func (opencodeAdapter) Check(string) Status { return Status{Level: OK} }

func (opencodeAdapter) Build(ctx Context) (Spec, error) {
	frags, err := discover.Scan(ctx.ShareDir)
	if err != nil {
		return Spec{}, fmt.Errorf("discover: %w", err)
	}
	// Reuse the codex skill-root staging: a dir of <name>/SKILL.md, which
	// opencode discovers via its **/SKILL.md glob (it follows symlinks).
	skillRoot, _, err := PrepareCodex(ctx.LaunchDir, frags)
	if err != nil {
		return Spec{}, err
	}

	cfg := map[string]any{}
	if skillRoot != "" {
		cfg["skills"] = map[string]any{"paths": []string{skillRoot}}
	}
	if len(frags.Rules) > 0 {
		paths := make([]string, 0, len(frags.Rules))
		for _, r := range frags.Rules {
			paths = append(paths, r.Path)
		}
		cfg["instructions"] = paths
	}
	if len(frags.Plugins) > 0 {
		specs := make([]string, 0, len(frags.Plugins))
		for _, p := range frags.Plugins {
			specs = append(specs, p.Path)
		}
		cfg["plugin"] = specs
	}

	blob, err := json.Marshal(cfg)
	if err != nil {
		return Spec{}, fmt.Errorf("marshal opencode config: %w", err)
	}
	env := setEnvVar(ctx.BaseEnv, "FLOX_AI", "1")
	env = setEnvVar(env, EnvOpencodeConfigContent, string(blob))
	argv := append([]string{ctx.Bin}, ctx.Passthrough...)
	return Spec{Argv: argv, Env: env}, nil
}
