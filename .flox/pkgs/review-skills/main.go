package main

import (
	"flag"
	"fmt"
	"os"
)

const version = "0.1.0"

func ansi(code, s string) string { return "\033[" + code + "m" + s + "\033[0m" }
func red(s string) string        { return ansi("31", s) }

func printUsage() {
	fmt.Fprintln(os.Stderr, "Usage: review-skills <audit|review|lint|report|doctor|version> [opts] <path>")
}

func main() {
	if len(os.Args) >= 2 && (os.Args[1] == "version" || os.Args[1] == "--version") {
		fmt.Println(version)
		return
	}
	flag.Usage = printUsage
	flag.Parse()
	cmd := flag.Arg(0)
	if cmd == "" {
		printUsage()
		os.Exit(1)
	}
	switch cmd {
	case "audit", "review", "lint", "report", "doctor":
		fmt.Fprintln(os.Stderr, red("not implemented yet: ")+cmd)
		os.Exit(1)
	default:
		fmt.Fprintln(os.Stderr, red("unknown command: ")+cmd)
		printUsage()
		os.Exit(1)
	}
}
