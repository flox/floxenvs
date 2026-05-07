package doctor_test

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"flox.dev/claude-managed/internal/discover"
	"flox.dev/claude-managed/internal/doctor"
)

func TestCheck_ValidFixtures(t *testing.T) {
	frags := &discover.Result{
		Rules: []discover.Fragment{{Name: "alpha", Path: filepath.Join("..", "testdata", "share", "claude-code", "rules", "alpha.md")}},
	}
	result := doctor.Check(frags)
	if len(result.Errors()) != 0 {
		t.Errorf("expected no errors, got: %v", result.Errors())
	}
	if len(result.Checked) != 1 {
		t.Errorf("expected 1 checked fragment, got %d", len(result.Checked))
	}
}

func TestCheck_MissingFile(t *testing.T) {
	frags := &discover.Result{
		Rules: []discover.Fragment{{Name: "missing", Path: "/nonexistent/file.md"}},
	}
	result := doctor.Check(frags)
	if len(result.Errors()) == 0 {
		t.Error("expected error for missing file")
	}
	if len(result.Checked) != 1 || result.Checked[0].OK {
		t.Error("expected checked fragment marked as not OK")
	}
}

func TestCheck_MissingSkill(t *testing.T) {
	dir := t.TempDir()
	frags := &discover.Result{
		Skills: []discover.Fragment{{Name: "broken", Path: filepath.Join(dir, "SKILL.md")}},
	}
	result := doctor.Check(frags)
	if len(result.Errors()) == 0 {
		t.Error("expected error for missing SKILL.md")
	}
}

func TestCheck_SkillRequiresNameAndDescription(t *testing.T) {
	dir := t.TempDir()
	skillFile := filepath.Join(dir, "SKILL.md")
	// Frontmatter present but missing both name and description.
	os.WriteFile(skillFile, []byte("---\nlicense: MIT\n---\n# Skill\n"), 0644)

	frags := &discover.Result{
		Skills: []discover.Fragment{{Name: "incomplete", Path: skillFile}},
	}
	result := doctor.Check(frags)
	wantMissing := []string{`"name"`, `"description"`}
	for _, want := range wantMissing {
		found := false
		for _, issue := range result.Errors() {
			if strings.Contains(issue.Message, "missing required frontmatter key") &&
				strings.Contains(issue.Message, want) {
				found = true
			}
		}
		if !found {
			t.Errorf("expected error about missing required key %s, got: %v", want, result.Errors())
		}
	}
}

func TestCheck_SkillNoFrontmatterIsLenient(t *testing.T) {
	dir := t.TempDir()
	skillFile := filepath.Join(dir, "SKILL.md")
	os.WriteFile(skillFile, []byte("# Skill\nDo things.\n"), 0644)

	frags := &discover.Result{
		Skills: []discover.Fragment{{Name: "good", Path: skillFile}},
	}
	result := doctor.Check(frags)
	if len(result.Issues) != 0 {
		t.Errorf("expected no issues for skill without frontmatter, got: %v", result.Issues)
	}
	if !result.Checked[0].OK {
		t.Error("expected checked fragment marked as OK")
	}
}

func TestCheck_SkillSpecConformant(t *testing.T) {
	dir := t.TempDir()
	skillFile := filepath.Join(dir, "SKILL.md")
	os.WriteFile(skillFile, []byte("---\nname: my-skill\ndescription: does things\nlicense: MIT\ncompatibility: claude-code opencode\nmetadata:\n  version: \"1.0\"\n---\n# Skill\n"), 0644)

	frags := &discover.Result{
		Skills: []discover.Fragment{{Name: "my-skill", Path: skillFile}},
	}
	result := doctor.Check(frags)
	if len(result.Issues) != 0 {
		t.Errorf("expected no issues for spec-conformant skill, got: %v", result.Issues)
	}
}

func TestCheck_SkillHumanizerStyle(t *testing.T) {
	// Reproduces blader/humanizer's frontmatter: block-scalar description,
	// top-level version (non-spec), license, compatibility, allowed-tools list.
	skillBody := `---
name: humanizer
version: 2.5.1
description: |
  Remove signs of AI-generated writing from text. Use when editing or reviewing
  text to make it sound more natural and human-written. Based on Wikipedia's
  comprehensive "Signs of AI writing" guide. Detects and fixes patterns including:
  inflated symbolism, promotional language, superficial -ing analyses, vague
  attributions, em dash overuse, rule of three, AI vocabulary words, passive
  voice, negative parallelisms, and filler phrases.
license: MIT
compatibility: claude-code opencode
allowed-tools:
  - Read
  - Write
  - Edit
---
# Humanizer
`
	dir := t.TempDir()
	skillFile := filepath.Join(dir, "SKILL.md")
	os.WriteFile(skillFile, []byte(skillBody), 0644)

	frags := &discover.Result{
		Skills: []discover.Fragment{{Name: "humanizer", Path: skillFile}},
	}
	result := doctor.Check(frags)

	if len(result.Errors()) != 0 {
		t.Errorf("expected no errors for humanizer-style skill, got: %v", result.Errors())
	}
	if !result.Checked[0].OK {
		t.Error("expected humanizer to be marked OK (warnings only)")
	}

	// Exactly one warning, about the non-spec top-level "version" key.
	warnings := result.Warnings()
	if len(warnings) != 1 {
		t.Fatalf("expected exactly 1 warning, got %d: %v", len(warnings), warnings)
	}
	if !strings.Contains(warnings[0].Message, `"version"`) ||
		!strings.Contains(warnings[0].Message, "metadata") {
		t.Errorf("expected pedagogical warning about version+metadata, got: %q", warnings[0].Message)
	}
}

func TestCheck_SkillNameTooLong(t *testing.T) {
	dir := t.TempDir()
	skillFile := filepath.Join(dir, "SKILL.md")
	longName := "a-very-long-skill-name-that-exceeds-the-sixty-four-character-limit-by-far"
	os.WriteFile(skillFile, []byte("---\nname: "+longName+"\ndescription: x\n---\n# Skill\n"), 0644)

	frags := &discover.Result{
		Skills: []discover.Fragment{{Name: "long", Path: skillFile}},
	}
	result := doctor.Check(frags)
	found := false
	for _, issue := range result.Errors() {
		if strings.Contains(issue.Message, "exceeds 64") {
			found = true
		}
	}
	if !found {
		t.Errorf("expected error for skill name exceeding 64 chars, got: %v", result.Issues)
	}
}

func TestCheck_SkillNameNotKebab(t *testing.T) {
	dir := t.TempDir()
	skillFile := filepath.Join(dir, "SKILL.md")
	os.WriteFile(skillFile, []byte("---\nname: MySkill\ndescription: x\n---\n# Skill\n"), 0644)

	frags := &discover.Result{
		Skills: []discover.Fragment{{Name: "bad-name", Path: skillFile}},
	}
	result := doctor.Check(frags)
	found := false
	for _, issue := range result.Errors() {
		if strings.Contains(issue.Message, "kebab-case") {
			found = true
		}
	}
	if !found {
		t.Error("expected error for non-kebab-case name")
	}
}

func TestCheck_SkillUnknownKeyIsWarning(t *testing.T) {
	dir := t.TempDir()
	skillFile := filepath.Join(dir, "SKILL.md")
	os.WriteFile(skillFile, []byte("---\nname: ok\ndescription: x\nfoo: bar\n---\n# Skill\n"), 0644)

	frags := &discover.Result{
		Skills: []discover.Fragment{{Name: "unknown-key", Path: skillFile}},
	}
	result := doctor.Check(frags)
	if len(result.Errors()) != 0 {
		t.Errorf("unknown skill key should not be an error, got: %v", result.Errors())
	}
	found := false
	for _, issue := range result.Warnings() {
		if strings.Contains(issue.Message, "unknown frontmatter key") {
			found = true
		}
	}
	if !found {
		t.Error("expected warning for unknown frontmatter key")
	}
	if !result.Checked[0].OK {
		t.Error("warnings alone should not flip OK to false")
	}
}

func TestCheck_SkillDescriptionTooLong(t *testing.T) {
	dir := t.TempDir()
	skillFile := filepath.Join(dir, "SKILL.md")
	longDesc := strings.Repeat("a", 1500)
	os.WriteFile(skillFile, []byte("---\nname: ok\ndescription: "+longDesc+"\n---\n# Skill\n"), 0644)

	frags := &discover.Result{
		Skills: []discover.Fragment{{Name: "long-desc", Path: skillFile}},
	}
	result := doctor.Check(frags)
	if len(result.Errors()) != 0 {
		t.Errorf("description over 1024 chars should be a warning, not an error, got: %v", result.Errors())
	}
	found := false
	for _, issue := range result.Warnings() {
		if strings.Contains(issue.Message, "description") && strings.Contains(issue.Message, "1024") {
			found = true
		}
	}
	if !found {
		t.Error("expected warning about description length")
	}
}

func TestCheck_RuleWithPaths(t *testing.T) {
	dir := t.TempDir()
	ruleFile := filepath.Join(dir, "style.md")
	os.WriteFile(ruleFile, []byte("---\npaths:\n  - \"src/**/*.ts\"\n---\n# Rules\n"), 0644)

	frags := &discover.Result{
		Rules: []discover.Fragment{{Name: "style", Path: ruleFile}},
	}
	result := doctor.Check(frags)
	if len(result.Issues) != 0 {
		t.Errorf("expected no issues, got: %v", result.Issues)
	}
}

func TestCheck_RuleUnknownKeyIsWarning(t *testing.T) {
	dir := t.TempDir()
	ruleFile := filepath.Join(dir, "bad.md")
	os.WriteFile(ruleFile, []byte("---\nfoo: bar\n---\n# Rules\n"), 0644)

	frags := &discover.Result{
		Rules: []discover.Fragment{{Name: "bad", Path: ruleFile}},
	}
	result := doctor.Check(frags)
	if len(result.Errors()) != 0 {
		t.Errorf("unknown rule key should be a warning, got errors: %v", result.Errors())
	}
	found := false
	for _, issue := range result.Warnings() {
		if strings.Contains(issue.Message, "unknown frontmatter key") {
			found = true
		}
	}
	if !found {
		t.Error("expected warning for unknown frontmatter key in rule")
	}
}

func TestCheck_AgentForbiddenKey(t *testing.T) {
	dir := t.TempDir()
	agentFile := filepath.Join(dir, "bad.md")
	os.WriteFile(agentFile, []byte("---\nname: bad\nhooks: something\n---\n# Agent\n"), 0644)

	frags := &discover.Result{
		Agents: []discover.Fragment{{Name: "bad", Path: agentFile}},
	}
	result := doctor.Check(frags)
	found := false
	for _, issue := range result.Errors() {
		if strings.Contains(issue.Message, "forbidden") {
			found = true
		}
	}
	if !found {
		t.Error("expected error for forbidden agent key")
	}
}

func TestCheck_AgentValidEffort(t *testing.T) {
	dir := t.TempDir()
	agentFile := filepath.Join(dir, "good.md")
	os.WriteFile(agentFile, []byte("---\nname: good\neffort: high\n---\n# Agent\n"), 0644)

	frags := &discover.Result{
		Agents: []discover.Fragment{{Name: "good", Path: agentFile}},
	}
	result := doctor.Check(frags)
	if len(result.Issues) != 0 {
		t.Errorf("expected no issues, got: %v", result.Issues)
	}
}

func TestCheck_AgentInvalidEffort(t *testing.T) {
	dir := t.TempDir()
	agentFile := filepath.Join(dir, "bad.md")
	os.WriteFile(agentFile, []byte("---\neffort: turbo\n---\n# Agent\n"), 0644)

	frags := &discover.Result{
		Agents: []discover.Fragment{{Name: "bad", Path: agentFile}},
	}
	result := doctor.Check(frags)
	found := false
	for _, issue := range result.Errors() {
		if strings.Contains(issue.Message, "effort") {
			found = true
		}
	}
	if !found {
		t.Error("expected error for invalid effort value")
	}
}

func TestCheck_AgentInvalidIsolation(t *testing.T) {
	dir := t.TempDir()
	agentFile := filepath.Join(dir, "bad.md")
	os.WriteFile(agentFile, []byte("---\nisolation: sandbox\n---\n# Agent\n"), 0644)

	frags := &discover.Result{
		Agents: []discover.Fragment{{Name: "bad", Path: agentFile}},
	}
	result := doctor.Check(frags)
	found := false
	for _, issue := range result.Errors() {
		if strings.Contains(issue.Message, "isolation") {
			found = true
		}
	}
	if !found {
		t.Error("expected error for invalid isolation value")
	}
}

func TestCheck_NoFrontmatter(t *testing.T) {
	dir := t.TempDir()
	ruleFile := filepath.Join(dir, "plain.md")
	os.WriteFile(ruleFile, []byte("# Just a rule\nNo frontmatter here.\n"), 0644)

	frags := &discover.Result{
		Rules: []discover.Fragment{{Name: "plain", Path: ruleFile}},
	}
	result := doctor.Check(frags)
	if len(result.Issues) != 0 {
		t.Errorf("expected no issues for rule without frontmatter, got: %v", result.Issues)
	}
}

func TestCheck_SkillInvalidYAML(t *testing.T) {
	dir := t.TempDir()
	skillFile := filepath.Join(dir, "SKILL.md")
	// Tab in frontmatter is illegal YAML indentation.
	os.WriteFile(skillFile, []byte("---\nname: foo\n\tbroken: indent\n---\n"), 0644)

	frags := &discover.Result{
		Skills: []discover.Fragment{{Name: "broken", Path: skillFile}},
	}
	result := doctor.Check(frags)
	found := false
	for _, issue := range result.Errors() {
		if strings.Contains(issue.Message, "invalid YAML") {
			found = true
		}
	}
	if !found {
		t.Errorf("expected error about invalid YAML, got: %v", result.Issues)
	}
}

func TestParseFrontmatter(t *testing.T) {
	tests := []struct {
		name      string
		input     string
		wantNil   bool
		wantErr   bool
		wantKeys  []string
		notExpect []string // keys that must NOT appear (regression tests)
	}{
		{
			name:    "no frontmatter",
			input:   "# Hello\nWorld",
			wantNil: true,
		},
		{
			name:     "simple frontmatter",
			input:    "---\nname: test\n---\n# Hello",
			wantKeys: []string{"name"},
		},
		{
			name:     "quoted value with colon",
			input:    "---\nname: \"foo: bar\"\n---\n# Hello",
			wantKeys: []string{"name"},
		},
		{
			name:    "unclosed frontmatter",
			input:   "---\nname: test\n# Hello",
			wantNil: true,
		},
		{
			name: "block scalar description",
			input: `---
name: humanizer
description: |
  Multi-line text.
  More text including: a colon mid-line.
  Yet more text.
---
# Body`,
			wantKeys:  []string{"name", "description"},
			notExpect: []string{"More text including"},
		},
		{
			name: "folded scalar",
			input: `---
description: >
  Folded text spans
  multiple lines.
---`,
			wantKeys: []string{"description"},
		},
		{
			name: "list value",
			input: `---
allowed-tools:
  - Read
  - Write
---`,
			wantKeys:  []string{"allowed-tools"},
			notExpect: []string{"Read", "Write"},
		},
		{
			name: "nested mapping",
			input: `---
metadata:
  version: "1.0"
  author: someone
---`,
			wantKeys:  []string{"metadata"},
			notExpect: []string{"version", "author"},
		},
		{
			name:    "tab indent invalid",
			input:   "---\nname: foo\n\tbroken: 1\n---",
			wantErr: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result, err := doctor.ParseFrontmatterForTest(tt.input)
			if tt.wantErr {
				if err == nil {
					t.Errorf("expected error, got nil")
				}
				return
			}
			if err != nil {
				t.Fatalf("unexpected error: %v", err)
			}
			if tt.wantNil {
				if result != nil {
					t.Errorf("expected nil, got %v", result)
				}
				return
			}
			if result == nil {
				t.Fatal("expected non-nil result")
			}
			for _, key := range tt.wantKeys {
				if _, ok := result[key]; !ok {
					t.Errorf("expected key %q, got keys %v", key, mapKeys(result))
				}
			}
			for _, key := range tt.notExpect {
				if _, ok := result[key]; ok {
					t.Errorf("unexpected key %q (block scalar / list / nested leaked into top-level)", key)
				}
			}
		})
	}
}

func mapKeys(m map[string]any) []string {
	keys := make([]string, 0, len(m))
	for k := range m {
		keys = append(keys, k)
	}
	return keys
}

func TestValidatePlugin_Valid(t *testing.T) {
	dir := t.TempDir()
	pluginDir := filepath.Join(dir, "my-plugin")
	os.MkdirAll(pluginDir, 0755)
	os.WriteFile(filepath.Join(pluginDir, ".lsp.json"), []byte(`{"name":"my-lsp"}`), 0644)
	os.MkdirAll(filepath.Join(pluginDir, ".claude-plugin"), 0755)
	os.WriteFile(filepath.Join(pluginDir, ".claude-plugin", "plugin.json"),
		[]byte(`{"name":"my-plugin","version":"1.0.0"}`), 0644)

	frags := &discover.Result{
		Plugins: []discover.Fragment{{Name: "my-plugin", Path: pluginDir}},
	}
	result := doctor.Check(frags)
	for _, issue := range result.Issues {
		if issue.Type == "plugins" {
			t.Errorf("unexpected issue: %s", issue.Message)
		}
	}
}

func TestValidatePlugin_NoComponents(t *testing.T) {
	dir := t.TempDir()
	pluginDir := filepath.Join(dir, "empty-plugin")
	os.MkdirAll(pluginDir, 0755)

	frags := &discover.Result{
		Plugins: []discover.Fragment{{Name: "empty-plugin", Path: pluginDir}},
	}
	result := doctor.Check(frags)
	found := false
	for _, issue := range result.Issues {
		if issue.Type == "plugins" && strings.Contains(issue.Message, "no recognized components") {
			found = true
		}
	}
	if !found {
		t.Error("expected 'no recognized components' issue")
	}
}

func TestValidatePlugin_BadPluginJSON(t *testing.T) {
	dir := t.TempDir()
	pluginDir := filepath.Join(dir, "bad-json")
	os.MkdirAll(filepath.Join(pluginDir, ".claude-plugin"), 0755)
	os.WriteFile(filepath.Join(pluginDir, ".claude-plugin", "plugin.json"),
		[]byte(`not json`), 0644)
	os.WriteFile(filepath.Join(pluginDir, ".lsp.json"), []byte(`{}`), 0644)

	frags := &discover.Result{
		Plugins: []discover.Fragment{{Name: "bad-json", Path: pluginDir}},
	}
	result := doctor.Check(frags)
	found := false
	for _, issue := range result.Issues {
		if issue.Type == "plugins" && strings.Contains(issue.Message, "invalid JSON") {
			found = true
		}
	}
	if !found {
		t.Error("expected 'invalid JSON' issue")
	}
}

func TestValidatePlugin_MissingName(t *testing.T) {
	dir := t.TempDir()
	pluginDir := filepath.Join(dir, "no-name")
	os.MkdirAll(filepath.Join(pluginDir, ".claude-plugin"), 0755)
	os.WriteFile(filepath.Join(pluginDir, ".claude-plugin", "plugin.json"),
		[]byte(`{"version":"1.0.0"}`), 0644)
	os.WriteFile(filepath.Join(pluginDir, ".lsp.json"), []byte(`{}`), 0644)

	frags := &discover.Result{
		Plugins: []discover.Fragment{{Name: "no-name", Path: pluginDir}},
	}
	result := doctor.Check(frags)
	found := false
	for _, issue := range result.Issues {
		if issue.Type == "plugins" && strings.Contains(issue.Message, "missing \"name\"") {
			found = true
		}
	}
	if !found {
		t.Error("expected missing name issue")
	}
}

func TestValidatePlugin_BadInstalledPluginsJSON(t *testing.T) {
	dir := t.TempDir()
	pluginDir := filepath.Join(dir, "bad-ip")
	os.MkdirAll(pluginDir, 0755)
	os.WriteFile(filepath.Join(pluginDir, ".lsp.json"), []byte(`{}`), 0644)
	os.WriteFile(filepath.Join(pluginDir, "installed_plugins.json"),
		[]byte(`not json`), 0644)

	frags := &discover.Result{
		Plugins: []discover.Fragment{{Name: "bad-ip", Path: pluginDir}},
	}
	result := doctor.Check(frags)
	found := false
	for _, issue := range result.Issues {
		if issue.Type == "plugins" &&
			strings.Contains(issue.Message, "installed_plugins.json") &&
			strings.Contains(issue.Message, "invalid JSON") {
			found = true
		}
	}
	if !found {
		t.Error("expected invalid JSON issue for installed_plugins.json")
	}
}
