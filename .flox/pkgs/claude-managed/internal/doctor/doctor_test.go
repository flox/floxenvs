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
	if len(result.Issues) != 0 {
		t.Errorf("expected no issues, got: %v", result.Issues)
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
	if len(result.Issues) == 0 {
		t.Error("expected issue for missing file")
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
	if len(result.Issues) == 0 {
		t.Error("expected issue for missing SKILL.md")
	}
}

func TestCheck_ValidSkill(t *testing.T) {
	dir := t.TempDir()
	skillFile := filepath.Join(dir, "SKILL.md")
	os.WriteFile(skillFile, []byte("# Skill\nDo things.\n"), 0644)

	frags := &discover.Result{
		Skills: []discover.Fragment{{Name: "good", Path: skillFile}},
	}
	result := doctor.Check(frags)
	if len(result.Issues) != 0 {
		t.Errorf("expected no issues, got: %v", result.Issues)
	}
	if len(result.Checked) != 1 || !result.Checked[0].OK {
		t.Error("expected checked fragment marked as OK")
	}
}

func TestCheck_SkillWithValidFrontmatter(t *testing.T) {
	dir := t.TempDir()
	skillFile := filepath.Join(dir, "SKILL.md")
	os.WriteFile(skillFile, []byte("---\nname: my-skill\ndescription: does things\n---\n# Skill\n"), 0644)

	frags := &discover.Result{
		Skills: []discover.Fragment{{Name: "my-skill", Path: skillFile}},
	}
	result := doctor.Check(frags)
	if len(result.Issues) != 0 {
		t.Errorf("expected no issues, got: %v", result.Issues)
	}
}

func TestCheck_SkillNameTooLong(t *testing.T) {
	dir := t.TempDir()
	skillFile := filepath.Join(dir, "SKILL.md")
	longName := "a-very-long-skill-name-that-exceeds-the-sixty-four-character-limit-by-far"
	os.WriteFile(skillFile, []byte("---\nname: "+longName+"\n---\n# Skill\n"), 0644)

	frags := &discover.Result{
		Skills: []discover.Fragment{{Name: "long", Path: skillFile}},
	}
	result := doctor.Check(frags)
	found := false
	for _, issue := range result.Issues {
		if issue.Message != "" && len(longName) > 64 {
			found = true
		}
	}
	if !found {
		t.Error("expected issue for skill name exceeding 64 chars")
	}
}

func TestCheck_SkillNameNotKebab(t *testing.T) {
	dir := t.TempDir()
	skillFile := filepath.Join(dir, "SKILL.md")
	os.WriteFile(skillFile, []byte("---\nname: MySkill\n---\n# Skill\n"), 0644)

	frags := &discover.Result{
		Skills: []discover.Fragment{{Name: "bad-name", Path: skillFile}},
	}
	result := doctor.Check(frags)
	found := false
	for _, issue := range result.Issues {
		if contains(issue.Message, "kebab-case") {
			found = true
		}
	}
	if !found {
		t.Error("expected issue for non-kebab-case name")
	}
}

func TestCheck_SkillUnknownKey(t *testing.T) {
	dir := t.TempDir()
	skillFile := filepath.Join(dir, "SKILL.md")
	os.WriteFile(skillFile, []byte("---\nname: ok\nfoo: bar\n---\n# Skill\n"), 0644)

	frags := &discover.Result{
		Skills: []discover.Fragment{{Name: "unknown-key", Path: skillFile}},
	}
	result := doctor.Check(frags)
	found := false
	for _, issue := range result.Issues {
		if contains(issue.Message, "unknown frontmatter key") {
			found = true
		}
	}
	if !found {
		t.Error("expected issue for unknown frontmatter key")
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

func TestCheck_RuleUnknownKey(t *testing.T) {
	dir := t.TempDir()
	ruleFile := filepath.Join(dir, "bad.md")
	os.WriteFile(ruleFile, []byte("---\nfoo: bar\n---\n# Rules\n"), 0644)

	frags := &discover.Result{
		Rules: []discover.Fragment{{Name: "bad", Path: ruleFile}},
	}
	result := doctor.Check(frags)
	found := false
	for _, issue := range result.Issues {
		if contains(issue.Message, "unknown frontmatter key") {
			found = true
		}
	}
	if !found {
		t.Error("expected issue for unknown frontmatter key in rule")
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
	for _, issue := range result.Issues {
		if contains(issue.Message, "forbidden") {
			found = true
		}
	}
	if !found {
		t.Error("expected issue for forbidden agent key")
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
	for _, issue := range result.Issues {
		if contains(issue.Message, "effort") {
			found = true
		}
	}
	if !found {
		t.Error("expected issue for invalid effort value")
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
	for _, issue := range result.Issues {
		if contains(issue.Message, "isolation") {
			found = true
		}
	}
	if !found {
		t.Error("expected issue for invalid isolation value")
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

func TestParseFrontmatter(t *testing.T) {
	tests := []struct {
		name    string
		input   string
		wantNil bool
		wantKey string
		wantVal string
	}{
		{
			name:    "no frontmatter",
			input:   "# Hello\nWorld",
			wantNil: true,
		},
		{
			name:    "simple frontmatter",
			input:   "---\nname: test\n---\n# Hello",
			wantKey: "name",
			wantVal: "test",
		},
		{
			name:    "quoted value",
			input:   "---\nname: \"my-skill\"\n---\n# Hello",
			wantKey: "name",
			wantVal: "my-skill",
		},
		{
			name:    "unclosed frontmatter",
			input:   "---\nname: test\n# Hello",
			wantNil: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := doctor.ParseFrontmatterForTest(tt.input)
			if tt.wantNil {
				if result != nil {
					t.Errorf("expected nil, got %v", result)
				}
				return
			}
			if result == nil {
				t.Fatal("expected non-nil result")
			}
			if result[tt.wantKey] != tt.wantVal {
				t.Errorf("expected %s=%q, got %q", tt.wantKey, tt.wantVal, result[tt.wantKey])
			}
		})
	}
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

func contains(s, sub string) bool {
	return len(s) >= len(sub) && (s == sub || len(s) > 0 && containsStr(s, sub))
}

func containsStr(s, sub string) bool {
	for i := 0; i <= len(s)-len(sub); i++ {
		if s[i:i+len(sub)] == sub {
			return true
		}
	}
	return false
}
