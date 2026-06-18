package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"text/tabwriter"

	"flox.dev/flox-ai/internal/audit/audit"
	"flox.dev/flox-ai/internal/audit/detect"
	"flox.dev/flox-ai/internal/discover"
	"flox.dev/flox-ai/internal/doctor"
	"flox.dev/flox-ai/internal/emit"
	"flox.dev/flox-ai/internal/launch"
	"flox.dev/flox-ai/internal/plugins"
	"flox.dev/flox-ai/internal/symlinks"
	"flox.dev/flox-ai/internal/tui"
)

const version = "0.9.0"

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
	flag.StringVar(&flagConfigDir, "config-dir", "", "config directory (default: $FLOX_ENV_PROJECT/.flox/cache/flox-ai)")
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
	configDir := resolveConfigDir(flagConfigDir, os.Getenv("FLOX_AI_DIR"), projectDir)
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
		passthrough := agentPassthrough(flag.Args())
		if err := launch.Run(launch.Options{
			AgentName:   agentName,
			ShareDir:    shareDir,
			ConfigDir:   configDir,
			Passthrough: passthrough,
		}); err != nil {
			fmt.Fprintf(os.Stderr, red("ERROR:")+" %v\n", err)
			os.Exit(1)
		}
	case "audit":
		os.Exit(runAudit(flag.Args()[1:], os.Stdout, os.Stderr))
	case "tui":
		if floxEnv == "" {
			fmt.Fprintln(os.Stderr, red("ERROR:")+" flox-ai tui must run inside a Flox environment.")
			fmt.Fprintln(os.Stderr)
			fmt.Fprintln(os.Stderr, "It installs plugins, skills, agents & rules into the active")
			fmt.Fprintln(os.Stderr, "environment's manifest, so a Flox environment must be active.")
			fmt.Fprintln(os.Stderr)
			fmt.Fprintln(os.Stderr, "  Activate one, then run it again:")
			fmt.Fprintln(os.Stderr, "    flox activate")
			fmt.Fprintln(os.Stderr, "    flox-ai tui")
			os.Exit(1)
		}
		requireShareDir()
		if err := tui.Run(tui.Options{
			ShareDir:   shareDir,
			ConfigDir:  configDir,
			ProjectDir: projectDir,
		}); err != nil {
			fmt.Fprintf(os.Stderr, red("ERROR:")+" %v\n", err)
			os.Exit(1)
		}
	default:
		printUsage()
		os.Exit(1)
	}
}

// agentPassthrough returns the args after `flox-ai launch <agent>` that
// should be forwarded verbatim to the agent. A single leading "--" is
// dropped: it is the conventional delimiter between the flox-ai launch
// command and the agent's own args (and is baked into agent-deck's
// `command = "flox-ai launch claude --"`). flox-ai's flag parser already
// stops at the subcommand, so the "--" is purely a delimiter — forwarding
// it would make the agent treat its own flags (e.g. --session-id) as
// positional args.
func agentPassthrough(args []string) []string {
	if len(args) <= 2 {
		return nil
	}
	rest := args[2:]
	if len(rest) > 0 && rest[0] == "--" {
		rest = rest[1:]
	}
	return rest
}

// resolveConfigDir picks the flox-ai config directory: an explicit
// --config-dir flag wins, then FLOX_AI_DIR, then the default under the
// project's flox cache.
func resolveConfigDir(flagConfigDir, floxAIDir, projectDir string) string {
	if flagConfigDir != "" {
		return flagConfigDir
	}
	if floxAIDir != "" {
		return floxAIDir
	}
	return filepath.Join(projectDir, ".flox", "cache", "flox-ai")
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
  audit <path>                   Score a skill/agent (--json --findings --report --threshold N --kind)
  tui                            Browse, install, and launch fragments
  version          Print version

Flags:
  --dir          Fragment source dir (default: $FLOX_ENV/share/claude-code)
  --config-dir   Config dir (default: $FLOX_ENV_PROJECT/.flox/cache/flox-ai)`)
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

	// Audit tools: availability of the external quality/security binaries.
	fmt.Fprintln(os.Stdout, bold("Audit tools"))
	rows := doctor.Probe()
	tw := tabwriter.NewWriter(os.Stdout, 0, 2, 2, ' ', 0)
	fmt.Fprintln(tw, "TOOL\tSTATE\tVERSION\tSMOKE")
	for _, r := range rows {
		v := r.Version
		if v == "" {
			v = "-"
		}
		fmt.Fprintf(tw, "%s\t%s\t%s\t%s\n", r.Tool, r.State, v, r.Smoke)
	}
	tw.Flush()
	avail := map[string]bool{}
	for _, r := range rows {
		avail[r.Tool] = r.State == "ok"
	}
	for _, kind := range []detect.Kind{detect.KindSkill, detect.KindAgent} {
		res := doctor.Resolve(kind, avail)
		fmt.Fprintf(os.Stdout, "%s audit → uses: %s\n", kind, strings.Join(res.Tools, ", "))
		if res.Warning != "" {
			fmt.Fprintln(os.Stdout, red("  WARNING:")+" "+res.Warning)
		}
	}

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

// runAudit implements `flox-ai audit <path> [--json --findings --report
// --threshold N --kind skill|agent --tools list --disable list]`.
func runAudit(args []string, out, errw io.Writer) int {
	fs := flag.NewFlagSet("audit", flag.ContinueOnError)
	fs.SetOutput(errw)
	jsonOut := fs.Bool("json", false, "machine-readable JSON")
	withFindings := fs.Bool("findings", false, "include findings")
	withReport := fs.Bool("report", false, "include raw per-tool output")
	threshold := fs.Int("threshold", -1, "exit nonzero if overall < N")
	kindFlag := fs.String("kind", "", "skill|agent")
	toolsFlag := fs.String("tools", "", "comma list: use exactly these tools")
	disableFlag := fs.String("disable", "", "comma list: drop these tools")
	// Go's flag package stops at the first positional, so parse in a loop to
	// allow flags on either side of the <path> argument.
	var positionals []string
	rest := args
	for {
		if err := fs.Parse(rest); err != nil {
			return 2
		}
		if fs.NArg() == 0 {
			break
		}
		positionals = append(positionals, fs.Arg(0))
		rest = fs.Args()[1:]
	}
	if len(positionals) < 1 {
		fmt.Fprintln(errw, red("ERROR:")+" usage: flox-ai audit <path> [flags]")
		return 1
	}
	path := positionals[0]
	var kind detect.Kind
	switch *kindFlag {
	case "", "skill", "agent":
		kind = detect.Kind(*kindFlag)
	default:
		fmt.Fprintln(errw, red("ERROR:")+" --kind must be skill or agent")
		return 1
	}
	res, err := audit.Run(audit.Options{
		Path:       path,
		Kind:       kind,
		Tools:      *toolsFlag,
		Disable:    *disableFlag,
		Findings:   *withFindings || *withReport,
		IncludeRaw: *withReport,
	})
	if err != nil {
		fmt.Fprintln(errw, red("ERROR:")+" "+err.Error())
		return 1
	}
	if *jsonOut {
		enc := json.NewEncoder(out)
		enc.SetIndent("", "  ")
		_ = enc.Encode(res)
	} else {
		printAuditText(out, res, *withFindings, *withReport)
	}
	if *threshold >= 0 && res.Overall < *threshold {
		return 1
	}
	return 0
}

// printAuditText renders the human summary.
func printAuditText(out io.Writer, res audit.Result, withFindings, withReport bool) {
	fmt.Fprintf(out, "%s  %s  overall %d (%s)\n",
		res.Identity.Kind, res.Identity.Name, res.Overall, res.Status)
	fmt.Fprintf(out, "  quality %d  reliability %d  security %d  impact %d\n",
		res.Quality.Score, res.Reliability.Score, res.Security.Score, res.Impact.Score)
	for _, c := range res.Quality.Checks {
		mark := "pass"
		if !c.Pass {
			mark = "FAIL"
		}
		fmt.Fprintf(out, "    %-16s w%-3d %s  %s\n", c.ID, c.Weight, mark, c.Note)
	}
	if withFindings || withReport {
		for _, f := range res.Findings {
			loc := f.File
			if f.Line > 0 {
				loc = fmt.Sprintf("%s:%d", f.File, f.Line)
			}
			fmt.Fprintf(out, "  [%s] %s %s — %s (%s)\n", f.Severity, f.Tool, f.Rule, f.Message, loc)
		}
	}
	if withReport {
		toolNames := make([]string, 0, len(res.RawByTool))
		for tool := range res.RawByTool {
			toolNames = append(toolNames, tool)
		}
		sort.Strings(toolNames)
		for _, tool := range toolNames {
			fmt.Fprintf(out, "\n=== %s ===\n%s\n", tool, res.RawByTool[tool])
		}
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
