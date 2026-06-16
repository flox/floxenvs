package main

import (
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"flox.dev/flox-ai/internal/discover"
	"flox.dev/flox-ai/internal/doctor"
	"flox.dev/flox-ai/internal/emit"
	"flox.dev/flox-ai/internal/launch"
	"flox.dev/flox-ai/internal/plugins"
	"flox.dev/flox-ai/internal/symlinks"
)

const version = "0.5.0"

// ANSI color helpers
func ansi(code, s string) string { return "\033[" + code + "m" + s + "\033[0m" }
func bold(s string) string       { return ansi("1", s) }
func red(s string) string        { return ansi("31", s) }
func green(s string) string      { return ansi("32", s) }
func yellow(s string) string     { return ansi("33", s) }
func dim(s string) string        { return ansi("2", s) }

func main() {
	// Handle version before flag.Parse() to avoid flag errors.
	if len(os.Args) >= 2 && (os.Args[1] == "version" || os.Args[1] == "--version") {
		fmt.Println(version)
		return
	}

	var flagDir, flagConfigDir string
	flag.StringVar(&flagDir, "dir", "", "fragment source directory (default: $FLOX_ENV/share/claude-code)")
	flag.StringVar(&flagConfigDir, "config-dir", "", "config directory (default: $FLOX_ENV_PROJECT/.flox-ai)")
	flag.Usage = printUsage
	flag.Parse()

	cmd := flag.Arg(0)
	if cmd == "" {
		printUsage()
		os.Exit(1)
	}

	floxEnv := os.Getenv("FLOX_ENV")
	projectDir := os.Getenv("FLOX_ENV_PROJECT")

	shareDir := flagDir
	if shareDir == "" && floxEnv != "" {
		shareDir = filepath.Join(floxEnv, "share", "claude-code")
	}

	if projectDir == "" {
		projectDir, _ = os.Getwd()
	}
	configDir := flagConfigDir
	if configDir == "" {
		configDir = os.Getenv("FLOX_AI_DIR")
	}
	if configDir == "" {
		configDir = filepath.Join(projectDir, ".flox-ai")
	}
	managed := os.Getenv("FLOX_AI") == "1"

	requireShareDir := func() {
		if shareDir == "" {
			fmt.Fprintln(os.Stderr, red("ERROR:")+" --dir is required or run flox-ai inside Flox environment")
			os.Exit(1)
		}
	}

	switch cmd {
	case "setup-hook":
		requireShareDir()
		if err := runSetup(shareDir, configDir, "hook"); err != nil {
			fmt.Fprintf(os.Stderr, red("ERROR:")+" %v\n", err)
			os.Exit(1)
		}
	case "setup-profile", "setup-profile-bash", "setup-profile-zsh":
		requireShareDir()
		if err := runSetup(shareDir, configDir, "profile"); err != nil {
			fmt.Fprintf(os.Stderr, red("ERROR:")+" %v\n", err)
			os.Exit(1)
		}
	case "setup-profile-fish":
		requireShareDir()
		if err := runSetup(shareDir, configDir, "profile-fish"); err != nil {
			fmt.Fprintf(os.Stderr, red("ERROR:")+" %v\n", err)
			os.Exit(1)
		}
	case "doctor":
		requireShareDir()
		if err := runDoctor(shareDir, configDir, projectDir, managed); err != nil {
			fmt.Fprintf(os.Stderr, red("ERROR:")+" %v\n", err)
			os.Exit(1)
		}
	case "plugins":
		subcmd := flag.Arg(1)
		switch subcmd {
		case "add":
			pluginPath := flag.Arg(2)
			if pluginPath == "" {
				fmt.Fprintln(os.Stderr, red("ERROR:")+" usage: flox-ai plugins add <path>")
				os.Exit(1)
			}
			if err := plugins.Add(pluginPath, configDir); err != nil {
				fmt.Fprintf(os.Stderr, red("ERROR:")+" %v\n", err)
				os.Exit(1)
			}
		case "remove":
			name := flag.Arg(2)
			if name == "" {
				fmt.Fprintln(os.Stderr, red("ERROR:")+" usage: flox-ai plugins remove <name>")
				os.Exit(1)
			}
			if err := plugins.Remove(name, configDir); err != nil {
				fmt.Fprintf(os.Stderr, red("ERROR:")+" %v\n", err)
				os.Exit(1)
			}
		case "list":
			if err := runPluginsList(configDir); err != nil {
				fmt.Fprintf(os.Stderr, red("ERROR:")+" %v\n", err)
				os.Exit(1)
			}
		case "clean":
			requireShareDir()
			if err := plugins.Clean(configDir, shareDir); err != nil {
				fmt.Fprintf(os.Stderr, red("ERROR:")+" %v\n", err)
				os.Exit(1)
			}
		default:
			fmt.Fprintln(os.Stderr, red("ERROR:")+" unknown plugins command: "+subcmd)
			printUsage()
			os.Exit(1)
		}
	case "rules":
		runFragmentSubcmd("rules", flag.Arg(1), flag.Arg(2), configDir, shareDir)
	case "skills":
		runFragmentSubcmd("skills", flag.Arg(1), flag.Arg(2), configDir, shareDir)
	case "agents":
		runFragmentSubcmd("agents", flag.Arg(1), flag.Arg(2), configDir, shareDir)
	case "launch":
		agentName := flag.Arg(1)
		if agentName == "" {
			fmt.Fprintln(os.Stderr, red("ERROR:")+" usage: flox-ai launch <agent> [-- <agent args>]")
			os.Exit(1)
		}
		requireShareDir()
		var passthrough []string
		if flag.NArg() > 2 {
			passthrough = flag.Args()[2:]
		}
		if err := launch.Run(launch.Options{
			AgentName:   agentName,
			FloxEnv:     floxEnv,
			ShareDir:    shareDir,
			ConfigDir:   configDir,
			Passthrough: passthrough,
		}); err != nil {
			fmt.Fprintf(os.Stderr, red("ERROR:")+" %v\n", err)
			os.Exit(1)
		}
	default:
		printUsage()
		os.Exit(1)
	}
}

func printUsage() {
	fmt.Fprintln(os.Stderr, `Usage: flox-ai [flags] <command>

Commands:
  setup-hook            Emit shell code for on-activate hook
  setup-profile         Emit POSIX profile code (bash/zsh default)
  setup-profile-bash    Emit profile code for [profile.bash]
  setup-profile-zsh     Emit profile code for [profile.zsh]
  setup-profile-fish    Emit profile code for [profile.fish]
  doctor           Show config status, symlink health, and validation
  rules add|remove|list|clean    Manage rule symlinks
  skills add|remove|list|clean   Manage skill symlinks
  agents add|remove|list|clean   Manage agent symlinks
  plugins add|remove|list|clean  Manage plugins (symlinks + JSON)
  launch <agent> [-- <args>]     Run an AI agent with flox fragments injected
  version          Print version

Flags:
  --dir          Fragment source dir (default: $FLOX_ENV/share/claude-code)
  --config-dir   Config dir (default: $FLOX_ENV_PROJECT/.flox-ai)`)
}

// runSetup emits the shell code for the requested setup phase. Fragment
// validation is intentionally NOT performed here: surfacing frontmatter
// warnings on every environment activation is noisy. Those checks now live
// solely in `flox-ai doctor`, which users run on demand.
func runSetup(shareDir, configDir, mode string) error {
	frags, err := discover.Scan(shareDir)
	if err != nil {
		return fmt.Errorf("discover: %w", err)
	}

	params := &emit.Params{
		Frags:     frags,
		ShareDir:  shareDir,
		ConfigDir: configDir,
	}

	switch mode {
	case "hook":
		fmt.Print(emit.HookCode(params))
	case "profile":
		fmt.Print(emit.ProfileCode(params))
	case "profile-fish":
		fmt.Print(emit.ProfileCodeFish(params))
	}

	return nil
}

func runDoctor(shareDir, configDir, projectDir string, managed bool) error {
	frags, err := discover.Scan(shareDir)
	if err != nil {
		return err
	}

	rel := func(p string) string {
		if r, err := filepath.Rel(projectDir, p); err == nil {
			return r
		}
		return p
	}

	fmt.Println(bold("Claude managed config diagnostics"))
	fmt.Println()

	if managed {
		fmt.Printf("  %s %s %s\n", dim("config:"), rel(configDir), green("(active)"))
	} else {
		fmt.Printf("  %s %s %s\n", dim("config:"), rel(configDir), yellow("(not activated)"))
	}

	if _, err := os.Stat(filepath.Join(configDir, ".claude.json")); err == nil {
		fmt.Printf("  %s %s\n", dim("  auth:"), green("bridged"))
	} else if managed {
		fmt.Printf("  %s %s\n", dim("  auth:"), yellow("not bridged"))
	}

	result := doctor.Check(frags)
	issuesByKey := make(map[string][]doctor.Issue)
	for _, issue := range result.Issues {
		key := issue.Type + "/" + issue.Name
		issuesByKey[key] = append(issuesByKey[key], issue)
	}

	// installed-symlink lookup: subdir/<name> -> entry
	installedByKey := make(map[string]symlinks.Entry)
	for _, subdir := range []string{"rules", "skills", "agents", "plugins"} {
		entries, _ := symlinks.List(filepath.Join(configDir, subdir))
		for _, e := range entries {
			installedByKey[subdir+"/"+e.Name] = e
		}
	}

	printSection := func(label, subdir string, items []discover.Fragment) {
		fmt.Println()
		fmt.Printf("  %s\n", bold(label))
		if len(items) == 0 {
			fmt.Printf("    %s\n", dim("No "+strings.ToLower(label)+" found."))
			return
		}
		for _, f := range items {
			issues := issuesByKey[subdir+"/"+f.Name]

			symlinkKey := subdir + "/" + f.Name
			if subdir == "rules" || subdir == "agents" {
				symlinkKey = subdir + "/" + filepath.Base(f.Path)
			}
			entry, hasSymlink := installedByKey[symlinkKey]

			marker := dim("·")
			switch {
			case hasIssueError(issues):
				marker = red("✗")
			case hasSymlink && entry.Broken:
				marker = yellow("→ broken")
			case hasSymlink:
				marker = green("✓")
			}

			fmt.Printf("    %s %s\n", marker, f.Name)
			for _, issue := range issues {
				if issue.IsError() {
					fmt.Printf("      %s\n", red(issue.Message))
				} else {
					fmt.Printf("      %s %s\n", yellow("⚠"), issue.Message)
				}
			}
		}
	}

	printSection("Rules", "rules", frags.Rules)
	printSection("Skills", "skills", frags.Skills)
	printSection("Agents", "agents", frags.Agents)
	printSection("Plugins", "plugins", frags.Plugins)

	fmt.Println()

	errCount := len(result.Errors())
	warnCount := len(result.Warnings())

	switch {
	case errCount == 0 && warnCount == 0:
		fmt.Println(green("All valid."))
		return nil
	case errCount == 0:
		fmt.Println(yellow(fmt.Sprintf("%d warning(s), no errors.", warnCount)))
		return nil
	default:
		return fmt.Errorf("%d error(s), %d warning(s)", errCount, warnCount)
	}
}

func hasIssueError(issues []doctor.Issue) bool {
	for _, i := range issues {
		if i.IsError() {
			return true
		}
	}
	return false
}

func runSymlinkList(label, configDir, subdir string) error {
	entries, err := symlinks.List(filepath.Join(configDir, subdir))
	if err != nil {
		return err
	}

	fmt.Println(bold("Installed " + label))
	fmt.Println()

	if len(entries) == 0 {
		fmt.Printf("  %s\n", dim("No "+label+" found."))
		return nil
	}

	for _, e := range entries {
		status := green("✓")
		if e.Broken {
			status = yellow("→ broken")
		}
		fmt.Printf("  %s %s\n", status, e.Name)
		if e.Target != "" {
			fmt.Printf("    %s\n", dim(e.Target))
		}
	}

	return nil
}

func runFragmentSubcmd(typeName, subcmd, arg, configDir, shareDir string) {
	subdir := typeName
	switch subcmd {
	case "add":
		if arg == "" {
			fmt.Fprintf(os.Stderr, red("ERROR:")+" usage: flox-ai %s add <path>\n", typeName)
			os.Exit(1)
		}
		if err := symlinks.Add(arg, filepath.Join(configDir, subdir)); err != nil {
			fmt.Fprintf(os.Stderr, red("ERROR:")+" %v\n", err)
			os.Exit(1)
		}
	case "remove":
		if arg == "" {
			fmt.Fprintf(os.Stderr, red("ERROR:")+" usage: flox-ai %s remove <name>\n", typeName)
			os.Exit(1)
		}
		if err := symlinks.Remove(arg, filepath.Join(configDir, subdir)); err != nil {
			fmt.Fprintf(os.Stderr, red("ERROR:")+" %v\n", err)
			os.Exit(1)
		}
	case "list":
		if err := runSymlinkList(typeName, configDir, subdir); err != nil {
			fmt.Fprintf(os.Stderr, red("ERROR:")+" %v\n", err)
			os.Exit(1)
		}
	case "clean":
		if shareDir == "" {
			fmt.Fprintln(os.Stderr, red("ERROR:")+" --dir is required or run inside Flox environment")
			os.Exit(1)
		}
		if _, err := symlinks.Clean(filepath.Join(configDir, subdir), shareDir); err != nil {
			fmt.Fprintf(os.Stderr, red("ERROR:")+" %v\n", err)
			os.Exit(1)
		}
	default:
		fmt.Fprintf(os.Stderr, red("ERROR:")+" unknown %s command: %s\n", typeName, subcmd)
		printUsage()
		os.Exit(1)
	}
}

func runPluginsList(configDir string) error {
	entries, err := plugins.List(configDir)
	if err != nil {
		return err
	}

	fmt.Println(bold("Installed plugins"))
	fmt.Println()

	if len(entries) == 0 {
		fmt.Printf("  %s\n", dim("No plugins found."))
		return nil
	}

	for _, e := range entries {
		status := green("✓")
		if e.Broken {
			status = yellow("→ broken")
		}
		fmt.Printf("  %s %s\n", status, e.Name)
		if e.Target != "" {
			fmt.Printf("    %s\n", dim(e.Target))
		}
	}

	return nil
}
