package tui

import (
	"bufio"
	"fmt"
	"io"
	"os/exec"
)

// LineFunc receives one line of command output.
type LineFunc func(string)

// Installer installs a flox package by pkg-path (e.g.
// "flox/skills-caveman"), streaming output lines to out.
type Installer interface {
	Install(pkg string, out LineFunc) error
}

// InstallerFunc adapts a function to the Installer interface.
type InstallerFunc func(pkg string, out LineFunc) error

func (f InstallerFunc) Install(pkg string, out LineFunc) error { return f(pkg, out) }

// FloxInstaller shells out to `flox install <pkg>`.
type FloxInstaller struct{}

func (FloxInstaller) Install(pkg string, out LineFunc) error {
	return streamExec(out, "flox", "install", pkg)
}

// Uninstaller removes a flox package by its install id (the manifest
// key, e.g. "skills-caveman"), streaming output lines.
type Uninstaller interface {
	Uninstall(id string, out LineFunc) error
}

// UninstallerFunc adapts a function to the Uninstaller interface.
type UninstallerFunc func(id string, out LineFunc) error

func (f UninstallerFunc) Uninstall(id string, out LineFunc) error { return f(id, out) }

// FloxUninstaller shells out to `flox uninstall <id>`.
type FloxUninstaller struct{}

func (FloxUninstaller) Uninstall(id string, out LineFunc) error {
	return streamExec(out, "flox", "uninstall", id)
}

// streamExec runs a command, forwarding each combined stdout/stderr line
// to out (if non-nil), and returns the command's exit error.
func streamExec(out LineFunc, name string, args ...string) error {
	cmd := exec.Command(name, args...)
	pr, pw := io.Pipe()
	cmd.Stdout = pw
	cmd.Stderr = pw
	if err := cmd.Start(); err != nil {
		return fmt.Errorf("%s: %w", name, err)
	}
	done := make(chan struct{})
	go func() {
		sc := bufio.NewScanner(pr)
		for sc.Scan() {
			if out != nil {
				out(sc.Text())
			}
		}
		close(done)
	}()
	werr := cmd.Wait()
	pw.Close()
	<-done
	if werr != nil {
		return fmt.Errorf("%s %v: %w", name, args, werr)
	}
	return nil
}
