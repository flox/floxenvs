package tui

import (
	"fmt"
	"sort"
	"time"

	tea "charm.land/bubbletea/v2"

	"flox.dev/flox-ai/internal/catalog"
	"flox.dev/flox-ai/internal/launch"
	"flox.dev/flox-ai/internal/manifest"
)

// Options are the resolved inputs for Run.
type Options struct {
	ShareDir   string
	ConfigDir  string
	ProjectDir string // holds .flox/env/manifest.lock
	CatalogURL string // overridable; defaults to catalog.DefaultURL
}

// agentNames returns the supported launch agents, sorted.
func agentNames() []string {
	names := make([]string, 0, len(launch.Supported))
	for n := range launch.Supported {
		names = append(names, n)
	}
	sort.Strings(names)
	return names
}

// Run loads the catalog + installed set, runs the TUI, and (on user
// request) execs the agent via launch.Run.
func Run(opts Options) error {
	url := opts.CatalogURL
	if url == "" {
		url = catalog.DefaultURL
	}
	items, _, err := catalog.Load(catalog.Config{
		URL:      url,
		CacheDir: catalog.CacheDir(),
		Timeout:  3 * time.Second,
	})
	if err != nil {
		return fmt.Errorf("load catalog: %w", err)
	}

	installed, err := manifest.Installed(opts.ProjectDir)
	if err != nil {
		return fmt.Errorf("read manifest: %w", err)
	}

	m := newModel(items, installed, agentNames(),
		FloxInstaller{}, FloxUninstaller{}, ReviewSkills{}, FloxDoctor{},
		opts.ShareDir, opts.ConfigDir, opts.ProjectDir)
	m.phase = phaseSplash // play the startup animation

	prog := tea.NewProgram(m)
	final, err := prog.Run()
	if err != nil {
		return err
	}

	fm, ok := final.(model)
	if !ok || !fm.launch {
		return nil
	}
	return launch.Run(launch.Options{
		AgentName: fm.currentAgent(),
		ShareDir:  opts.ShareDir,
		ConfigDir: opts.ConfigDir,
	})
}
