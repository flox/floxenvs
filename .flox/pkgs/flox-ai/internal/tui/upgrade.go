package tui

import (
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

// Upgrade is one available package upgrade.
type Upgrade struct {
	Pkg  string
	From string
	To   string // empty when the version is unchanged (rebuild/dep change)
}

// Upgrader checks for and applies environment upgrades.
type Upgrader interface {
	// Check returns the available upgrades and whether the environment uses
	// includes (which must be upgraded first).
	Check() (ups []Upgrade, includes bool, err error)
	// Run applies the upgrades, streaming output lines to out.
	Run(out LineFunc) error
}

// FloxUpgrader shells out to `flox upgrade` (and `flox include upgrade`).
type FloxUpgrader struct{ ProjectDir string }

func (u FloxUpgrader) dirArgs() []string {
	if u.ProjectDir == "" {
		return nil
	}
	return []string{"-d", u.ProjectDir}
}

func (u FloxUpgrader) Check() ([]Upgrade, bool, error) {
	includes := hasIncludes(u.ProjectDir)
	args := append([]string{"upgrade", "--dry-run"}, u.dirArgs()...)
	out, err := exec.Command("flox", args...).CombinedOutput()
	// Parse whatever output we got even on a non-zero exit.
	return parseUpgrades(string(out)), includes, err
}

func (u FloxUpgrader) Run(out LineFunc) error {
	if hasIncludes(u.ProjectDir) {
		args := append([]string{"include", "upgrade"}, u.dirArgs()...)
		if err := streamExec(out, "flox", args...); err != nil {
			return err
		}
	}
	return streamExec(out, "flox", append([]string{"upgrade"}, u.dirArgs()...)...)
}

// hasIncludes reports whether the environment manifest declares includes.
func hasIncludes(projectDir string) bool {
	data, err := os.ReadFile(filepath.Join(projectDir, ".flox", "env", "manifest.toml"))
	if err != nil {
		return false
	}
	return strings.Contains(string(data), "[include]")
}

// parseUpgrades parses `flox upgrade --dry-run` output lines of the form
// "- pkg: from -> to" or "- pkg: version".
func parseUpgrades(out string) []Upgrade {
	var ups []Upgrade
	for _, line := range strings.Split(out, "\n") {
		line = strings.TrimSpace(line)
		if !strings.HasPrefix(line, "- ") {
			continue
		}
		pkg, rest, ok := strings.Cut(strings.TrimPrefix(line, "- "), ":")
		if !ok {
			continue
		}
		pkg, rest = strings.TrimSpace(pkg), strings.TrimSpace(rest)
		if from, to, ok := strings.Cut(rest, "->"); ok {
			ups = append(ups, Upgrade{Pkg: pkg, From: strings.TrimSpace(from), To: strings.TrimSpace(to)})
		} else {
			ups = append(ups, Upgrade{Pkg: pkg, From: rest})
		}
	}
	return ups
}
