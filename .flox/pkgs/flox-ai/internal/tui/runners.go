package tui

import (
	"os"
)

// DoctorRunner runs flox-ai doctor, streaming output lines to out.
type DoctorRunner interface {
	Run(shareDir, configDir string, out LineFunc) error
}

// DoctorFunc adapts a function to DoctorRunner.
type DoctorFunc func(shareDir, configDir string, out LineFunc) error

func (f DoctorFunc) Run(s, c string, out LineFunc) error { return f(s, c, out) }

// FloxDoctor streams the running binary's own `doctor` subcommand.
type FloxDoctor struct{}

func (FloxDoctor) Run(shareDir, configDir string, out LineFunc) error {
	self, err := os.Executable()
	if err != nil {
		return err
	}
	var args []string
	if shareDir != "" {
		args = append(args, "--dir", shareDir)
	}
	if configDir != "" {
		args = append(args, "--config-dir", configDir)
	}
	args = append(args, "doctor")
	return streamExec(out, self, args...)
}

// ReviewSkills implements Auditor using the in-process audit engine.
type ReviewSkills struct{}
