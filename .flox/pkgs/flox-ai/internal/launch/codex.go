// codex.go: runs OpenAI Codex with flox-managed fragments injected via the
// env-var hooks added by the flox codex patch (flox-fragments.patch). Unlike
// the claude path, Codex takes no --plugin-dir / --append-system-prompt-file
// flags: it discovers skills from skill-root directories and rules from
// project instructions. The patch lets us point Codex at flox-staged copies
// through CODEX_FLOX_SKILL_ROOTS and CODEX_FLOX_INSTRUCTIONS_FILE, so nothing
// in ~/.codex or the working tree is mutated.

package launch

import (
	"bytes"
	"fmt"
	"io"
	"os"
	"path/filepath"

	"flox.dev/flox-ai/internal/discover"
)

const (
	// EnvCodexSkillRoots is the colon-separated list of extra skill-root
	// directories the flox codex patch appends to Codex's skill discovery.
	EnvCodexSkillRoots = "CODEX_FLOX_SKILL_ROOTS"
	// EnvCodexInstructionsFile is the extra project-instructions file the
	// flox codex patch appends to Codex's loaded instructions.
	EnvCodexInstructionsFile = "CODEX_FLOX_INSTRUCTIONS_FILE"
)

// codexAdapter launches OpenAI Codex with skills and rules injected via
// the env-var seams added by the flox codex patch. Plugins are not
// mapped (Codex's plugin format differs from Claude's).
type codexAdapter struct{}

var _ Adapter = codexAdapter{}

func (codexAdapter) Name() string       { return "codex" }
func (codexAdapter) InstallPkg() string { return "codex" }

// Check reports OK when the codex binary carries the flox patch, and
// Degraded otherwise: an unpatched codex still runs but ignores the
// CODEX_FLOX_* env vars, so no fragments are injected.
func (codexAdapter) Check(bin string) Status {
	if codexIsPatched(bin) {
		return Status{Level: OK}
	}
	return Status{
		Level:  Degraded,
		Reason: "codex is not the flox-patched build; skills and rules will not be injected",
	}
}

// codexIsPatched reports whether the codex binary carries the flox patch,
// detected by the presence of the patch's env-var symbol. It streams the
// file in chunks (the binary is large) with an overlap so a match across
// a chunk boundary is still found.
func codexIsPatched(bin string) bool {
	f, err := os.Open(bin)
	if err != nil {
		return false
	}
	defer f.Close()

	needle := []byte(EnvCodexSkillRoots)
	overlap := len(needle) - 1
	buf := make([]byte, 1<<20)
	var tail []byte
	for {
		n, err := f.Read(buf)
		if n > 0 {
			chunk := append(tail, buf[:n]...)
			if bytes.Contains(chunk, needle) {
				return true
			}
			if len(chunk) > overlap {
				tail = append([]byte(nil), chunk[len(chunk)-overlap:]...)
			} else {
				tail = chunk
			}
		}
		if err == io.EOF {
			return false
		}
		if err != nil {
			return false
		}
	}
}

func (codexAdapter) Build(ctx Context) (Spec, error) {
	frags, err := discover.Scan(ctx.ShareDir)
	if err != nil {
		return Spec{}, fmt.Errorf("discover: %w", err)
	}
	skillRoot, rulesFile, err := PrepareCodex(ctx.LaunchDir, frags)
	if err != nil {
		return Spec{}, err
	}
	env := setEnvVar(ctx.BaseEnv, "FLOX_AI", "1")
	if skillRoot != "" {
		env = setEnvVar(env, EnvCodexSkillRoots, skillRoot)
	}
	if rulesFile != "" {
		env = setEnvVar(env, EnvCodexInstructionsFile, rulesFile)
	}
	argv := append([]string{ctx.Bin}, ctx.Passthrough...)
	return Spec{Argv: argv, Env: env}, nil
}

// BuildCodexSkillRoot creates a Codex skill-root directory under
// launchDir/skills containing the given skills and agents as skill
// subdirectories, and returns the root path. Each skill is linked as its
// SKILL.md-holding directory; each standalone agent is wrapped as
// <name>/SKILL.md (Codex discovers it as a skill). Codex follows symlinked
// skill folders when scanning. Returns "" (and writes nothing) when there
// are no skills or agents.
func BuildCodexSkillRoot(launchDir string, skills, agents []discover.Fragment) (string, error) {
	if len(skills) == 0 && len(agents) == 0 {
		return "", nil
	}
	root := filepath.Join(launchDir, "skills")
	if err := os.MkdirAll(root, 0755); err != nil {
		return "", err
	}
	for _, s := range skills {
		// s.Path is the SKILL.md file; link its directory as a skill.
		target := filepath.Dir(s.Path)
		if err := os.Symlink(target, filepath.Join(root, s.Name)); err != nil {
			return "", err
		}
	}
	for _, a := range agents {
		// Standalone agents have no skill directory; synthesize one whose
		// SKILL.md is the agent file so Codex surfaces it as a skill.
		dir := filepath.Join(root, a.Name)
		if err := os.MkdirAll(dir, 0755); err != nil {
			return "", err
		}
		if err := os.Symlink(a.Path, filepath.Join(dir, "SKILL.md")); err != nil {
			return "", err
		}
	}
	return root, nil
}

// PrepareCodex wipes launchDir and rebuilds the synth skill root and merged
// rules file from the discovered fragments. Like Prepare, wiping each run
// keeps the tree free of stale entries. Returns the skill-root path ("" if
// none) and the rules file path ("" if none).
func PrepareCodex(launchDir string, frags *discover.Result) (skillRoot, rulesFile string, err error) {
	if err := os.RemoveAll(launchDir); err != nil {
		return "", "", err
	}
	if err := os.MkdirAll(launchDir, 0755); err != nil {
		return "", "", err
	}
	skillRoot, err = BuildCodexSkillRoot(launchDir, frags.Skills, frags.Agents)
	if err != nil {
		return "", "", err
	}
	rulesFile, err = MergeRules(launchDir, frags.Rules)
	if err != nil {
		return "", "", err
	}
	return skillRoot, rulesFile, nil
}
