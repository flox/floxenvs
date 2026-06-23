package main

import (
	"reflect"
	"testing"
)

func TestAgentPassthrough(t *testing.T) {
	cases := []struct {
		name string
		args []string
		want []string
	}{
		{"no args", []string{"launch", "claude"}, nil},
		{"plain flag", []string{"launch", "claude", "-c"}, []string{"-c"}},
		{"strips delimiter", []string{"launch", "claude", "--", "--session-id", "X"}, []string{"--session-id", "X"}},
		{"deck path", []string{"launch", "agent-deck", "--", "status"}, []string{"status"}},
		{"only first dash-dash stripped", []string{"launch", "claude", "--", "--"}, []string{"--"}},
		{"none", []string{"launch"}, nil},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			if got := agentPassthrough(c.args); !reflect.DeepEqual(got, c.want) {
				t.Fatalf("got %#v want %#v", got, c.want)
			}
		})
	}
}

func TestResolveConfigDir(t *testing.T) {
	cases := []struct {
		name      string
		flag, env string
		project   string
		want      string
	}{
		{"flag wins", "/explicit", "/envdir", "/proj", "/explicit"},
		{"env over default", "", "/envdir", "/proj", "/envdir"},
		{"default", "", "", "/proj", "/proj/.flox/cache/flox-ai"},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			if got := resolveConfigDir(c.flag, c.env, c.project); got != c.want {
				t.Fatalf("got %q want %q", got, c.want)
			}
		})
	}
}
