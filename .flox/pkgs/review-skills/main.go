package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"os"

	"flox.dev/review-skills/internal/audit"
	"flox.dev/review-skills/internal/detect"
	"flox.dev/review-skills/internal/report"
)

const version = "0.1.0"

func ansi(code, s string) string { return "\033[" + code + "m" + s + "\033[0m" }
func red(s string) string        { return ansi("31", s) }
func bold(s string) string       { return ansi("1", s) }

func printUsage(w io.Writer) {
	fmt.Fprintln(w, "Usage: review-skills <audit|review|lint|report|doctor|version> [opts] <path>")
	fmt.Fprintln(w, "")
	fmt.Fprintln(w, "  audit   full 0-100 metrics (--json --findings --threshold N --tools --disable --with-behavioral)")
	fmt.Fprintln(w, "  review  quality score only (--json --threshold N --tools --disable)")
	fmt.Fprintln(w, "  lint    deterministic gate, exit 0/1 (--kind)")
	fmt.Fprintln(w, "  report  raw per-tool output (--json --tools --disable)")
	fmt.Fprintln(w, "  doctor  tool availability + smoke + resolved ensemble (--kind)")
	fmt.Fprintln(w, "")
	fmt.Fprintln(w, "  --kind skill|agent   override artifact detection")
}

func main() {
	os.Exit(run(os.Args[1:], os.Stdout, os.Stderr))
}

// run dispatches a command and returns the process exit code. It writes
// normal output to out and diagnostics to errw, never calling os.Exit, so it
// is unit-testable in-process.
func run(args []string, out, errw io.Writer) int {
	if len(args) >= 1 && (args[0] == "version" || args[0] == "--version") {
		fmt.Fprintln(out, version)
		return 0
	}
	if len(args) < 1 {
		printUsage(errw)
		return 1
	}
	cmd, rest := args[0], args[1:]
	switch cmd {
	case "audit":
		return runAudit(rest, out, errw)
	case "review":
		return runReview(rest, out, errw)
	case "lint":
		return runLint(rest, out, errw)
	case "report":
		return runReport(rest, out, errw)
	case "doctor":
		// Wired in a later phase.
		fmt.Fprintln(errw, red("not implemented yet: ")+cmd)
		return 1
	default:
		fmt.Fprintln(errw, red("unknown command: ")+cmd)
		printUsage(errw)
		return 1
	}
}

// kindFromFlag converts the --kind flag value to a detect.Kind.
func kindFromFlag(s string) (detect.Kind, error) {
	switch s {
	case "":
		return "", nil
	case "skill":
		return detect.KindSkill, nil
	case "agent":
		return detect.KindAgent, nil
	default:
		return "", fmt.Errorf("invalid --kind %q (want skill|agent)", s)
	}
}

// newFlagSet builds a command FlagSet that reports errors to errw instead of
// the global stderr (so tests stay quiet) and does not exit the process.
func newFlagSet(name string, errw io.Writer) *flag.FlagSet {
	fs := flag.NewFlagSet(name, flag.ContinueOnError)
	fs.SetOutput(errw)
	return fs
}

func runAudit(args []string, out, errw io.Writer) int {
	fs := newFlagSet("audit", errw)
	jsonOut := fs.Bool("json", false, "machine-readable JSON")
	withFindings := fs.Bool("findings", false, "include normalized findings")
	threshold := fs.Int("threshold", -1, "exit nonzero if overall < N")
	kindFlag := fs.String("kind", "", "skill|agent")
	toolsFlag := fs.String("tools", "", "comma list: use exactly these quality tools")
	disable := fs.String("disable", "", "comma list: drop these quality tools")
	behavioral := fs.Bool("with-behavioral", false, "run promptfoo behavioral eval")
	if err := fs.Parse(args); err != nil {
		return 2
	}
	kind, err := kindFromFlag(*kindFlag)
	if err != nil {
		fmt.Fprintln(errw, red("ERROR:")+" "+err.Error())
		return 2
	}
	if fs.NArg() < 1 {
		fmt.Fprintln(errw, red("ERROR:")+" missing <path>")
		return 2
	}
	r, err := audit.Run(audit.Options{
		Path: fs.Arg(0), Kind: kind, Tools: *toolsFlag, Disable: *disable,
		WithBehavioral: *behavioral, Findings: *withFindings,
	})
	if err != nil {
		fmt.Fprintln(errw, red("ERROR:")+" "+err.Error())
		return 2
	}
	if *jsonOut {
		b, _ := json.MarshalIndent(r, "", "  ")
		fmt.Fprintln(out, string(b))
	} else {
		fmt.Fprintf(out, "%s %s: %d (%s)\n", r.Identity.Kind, r.Identity.Name, r.Overall, r.Status)
	}
	if *threshold >= 0 && r.Overall < *threshold {
		return 1
	}
	return 0
}

func runReview(args []string, out, errw io.Writer) int {
	fs := newFlagSet("review", errw)
	jsonOut := fs.Bool("json", false, "machine-readable JSON")
	threshold := fs.Int("threshold", -1, "exit nonzero if quality < N")
	kindFlag := fs.String("kind", "", "skill|agent")
	toolsFlag := fs.String("tools", "", "comma list: use exactly these quality tools")
	disable := fs.String("disable", "", "comma list: drop these quality tools")
	if err := fs.Parse(args); err != nil {
		return 2
	}
	kind, err := kindFromFlag(*kindFlag)
	if err != nil {
		fmt.Fprintln(errw, red("ERROR:")+" "+err.Error())
		return 2
	}
	if fs.NArg() < 1 {
		fmt.Fprintln(errw, red("ERROR:")+" missing <path>")
		return 2
	}
	r, err := audit.Run(audit.Options{Path: fs.Arg(0), Kind: kind, Tools: *toolsFlag, Disable: *disable})
	if err != nil {
		fmt.Fprintln(errw, red("ERROR:")+" "+err.Error())
		return 2
	}
	if *jsonOut {
		b, _ := json.MarshalIndent(r.Quality, "", "  ")
		fmt.Fprintln(out, string(b))
	} else {
		fmt.Fprintf(out, "%s %s: quality %d\n", r.Identity.Kind, r.Identity.Name, r.Quality.Score)
	}
	if *threshold >= 0 && r.Quality.Score < *threshold {
		return 1
	}
	return 0
}

func runLint(args []string, out, errw io.Writer) int {
	fs := newFlagSet("lint", errw)
	kindFlag := fs.String("kind", "", "skill|agent")
	if err := fs.Parse(args); err != nil {
		return 2
	}
	kind, err := kindFromFlag(*kindFlag)
	if err != nil {
		fmt.Fprintln(errw, red("ERROR:")+" "+err.Error())
		return 2
	}
	if fs.NArg() < 1 {
		fmt.Fprintln(errw, red("ERROR:")+" missing <path>")
		return 2
	}
	ok, err := audit.Lint(audit.Options{Path: fs.Arg(0), Kind: kind})
	if err != nil {
		fmt.Fprintln(errw, red("ERROR:")+" "+err.Error())
		return 2
	}
	if ok {
		fmt.Fprintln(out, "lint: OK")
		return 0
	}
	fmt.Fprintln(errw, red("lint: FAILED gate"))
	return 1
}

func runReport(args []string, out, errw io.Writer) int {
	fs := newFlagSet("report", errw)
	jsonOut := fs.Bool("json", false, "machine-readable JSON")
	kindFlag := fs.String("kind", "", "skill|agent")
	toolsFlag := fs.String("tools", "", "comma list: use exactly these quality tools")
	disable := fs.String("disable", "", "comma list: drop these quality tools")
	if err := fs.Parse(args); err != nil {
		return 2
	}
	kind, err := kindFromFlag(*kindFlag)
	if err != nil {
		fmt.Fprintln(errw, red("ERROR:")+" "+err.Error())
		return 2
	}
	if fs.NArg() < 1 {
		fmt.Fprintln(errw, red("ERROR:")+" missing <path>")
		return 2
	}
	outs, err := report.Run(report.Options{Path: fs.Arg(0), Kind: kind, Tools: *toolsFlag, Disable: *disable})
	if err != nil {
		fmt.Fprintln(errw, red("ERROR:")+" "+err.Error())
		return 2
	}
	if *jsonOut {
		b, _ := json.MarshalIndent(outs, "", "  ")
		fmt.Fprintln(out, string(b))
		return 0
	}
	for _, o := range outs {
		fmt.Fprintln(out, bold("== "+o.Tool+" =="))
		fmt.Fprintln(out, o.Raw)
	}
	return 0
}
