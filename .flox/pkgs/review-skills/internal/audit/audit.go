// Package audit orchestrates the review-skills scoring pipeline: it detects
// the artifact kind, runs the selected quality tools (real or, under
// REVIEW_SKILLS_DRY_RUN, fixed stubs), runs the reliability gate, the
// skillcheck security scan, and the optional behavioral stage, then fuses
// the four dimensions into a single 0-100 score. It is a faithful port of
// the bash skills-review runner.
package audit

import (
	"bufio"
	"bytes"
	"encoding/json"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"

	"flox.dev/review-skills/internal/detect"
	"flox.dev/review-skills/internal/findings"
	"flox.dev/review-skills/internal/score"
	"flox.dev/review-skills/internal/tools"
)

// Options configures a single audit run.
type Options struct {
	Path           string
	Kind           detect.Kind // "" = auto-detect
	Tools, Disable string
	WithBehavioral bool
	Findings       bool
}

// Check is one quality-ensemble member's breakdown.
type Check struct {
	ID     string `json:"id"`
	Weight int    `json:"weight"`
	Note   string `json:"note"`
	Pass   bool   `json:"pass"`
}

// Result is the fused metrics.json document.
type Result struct {
	Identity struct {
		Kind string `json:"kind"`
		Name string `json:"name"`
		Dir  string `json:"dir"`
	} `json:"identity"`
	Overall int    `json:"overall"`
	Status  string `json:"status"`
	Quality struct {
		Score  int     `json:"score"`
		Checks []Check `json:"checks"`
	} `json:"quality"`
	Reliability struct {
		Score int `json:"score"`
	} `json:"reliability"`
	Security struct {
		Score    int    `json:"score"`
		Cap      int    `json:"cap"`
		Severity string `json:"severity"`
	} `json:"security"`
	Impact struct {
		Score     int  `json:"score"`
		Estimated bool `json:"estimated"`
	} `json:"impact"`
	Findings []findings.Finding `json:"findings,omitempty"`
}

func dry() bool { return os.Getenv("REVIEW_SKILLS_DRY_RUN") == "1" }

// runner carries per-audit state: the resolved kind/path and a one-shot
// cache of the staged-project claudelint output, mirroring the bash cl_run
// cache so claudelint is never staged or executed twice per audit.
type runner struct {
	kind detect.Kind
	path string

	clDone bool
	clOut  []byte
	clOK   bool

	// outCache memoizes each tool's raw output by tool name so a tool is
	// executed at most once per audit even when both its score and its
	// findings are needed.
	outCache map[string][]byte

	// secDone caches the skillcheck SARIF so the security scan runs once
	// and its findings (which explain the security cap) can be collected.
	secDone bool
	secOut  []byte
}

// Run executes the full pipeline and returns the fused Result.
func Run(opts Options) (Result, error) {
	var r Result
	kind := opts.Kind
	if kind == "" {
		kind = detect.Detect(opts.Path)
	}
	r.Identity.Kind = string(kind)
	r.Identity.Name = filepath.Base(strings.TrimRight(opts.Path, "/"))
	r.Identity.Dir = opts.Path

	sel, err := tools.Select(kind, opts.Tools, opts.Disable)
	if err != nil {
		return r, err
	}

	rn := &runner{kind: kind, path: opts.Path, outCache: map[string][]byte{}}

	// --- quality ensemble ---------------------------------------------
	var members []score.Weighted
	for _, t := range sel {
		sc, ok := rn.scoreTool(t)
		w := t.Weight[kind]
		members = append(members, score.Weighted{Weight: w, Score: sc})
		r.Quality.Checks = append(r.Quality.Checks, Check{
			ID:     t.Name,
			Weight: w,
			Note:   note(t.Name, sc, ok),
			Pass:   ok && sc >= 60,
		})
		if opts.Findings && !dry() && t.Collect != nil {
			r.Findings = append(r.Findings, t.Collect(rn.runTool(t))...)
		}
	}
	r.Quality.Score = score.Ensemble(members)

	// --- reliability = gate pass/fail, floored by claudelint ----------
	if rn.runGate() {
		rel := rn.claudelintScore()
		if rel < 60 {
			rel = 60
		}
		r.Reliability.Score = rel
	} else {
		r.Reliability.Score = 0
	}

	// --- security = skillcheck severity + cap -------------------------
	sev := score.SevNone
	r.Security.Score = 100
	if !dry() {
		sev = rn.securitySeverity()
		r.Security.Score = securityScore(sev)
	}
	r.Security.Severity = string(sev)
	r.Security.Cap = score.ApplyCap(100, sev)

	// Security findings (e.g. leaked secrets) explain the security cap, so
	// include them alongside the quality findings when requested. Reuse the
	// cached skillcheck scan — no extra tool run.
	if opts.Findings && !dry() {
		if sc, found := tools.Find("skillcheck"); found && sc.Collect != nil {
			r.Findings = append(r.Findings, sc.Collect(rn.skillcheckOut())...)
		}
	}

	// --- impact -------------------------------------------------------
	if opts.WithBehavioral && !dry() {
		r.Impact.Score = rn.behavioral()
		r.Impact.Estimated = false
	} else {
		r.Impact.Score = 70
		r.Impact.Estimated = true
	}

	// --- fuse + cap ---------------------------------------------------
	overall := score.Fuse(r.Quality.Score, r.Reliability.Score, r.Security.Score, r.Impact.Score)
	overall = score.ApplyCap(overall, sev)
	r.Overall = overall
	r.Status = score.Pill(overall)

	if opts.Findings {
		findings.Sort(r.Findings)
	}
	return r, nil
}

// Lint runs only the reliability gate, returning whether it passed. It backs
// the `lint` command.
func Lint(opts Options) (bool, error) {
	kind := opts.Kind
	if kind == "" {
		kind = detect.Detect(opts.Path)
	}
	rn := &runner{kind: kind, path: opts.Path}
	return rn.runGate(), nil
}

// note renders a quality check's note: the failure marker when the tool
// crashed (fail closed), else the numeric score, mirroring quality_block.
func note(name string, sc int, ok bool) string {
	if !ok {
		return name + " failed to run"
	}
	return strconv.Itoa(sc)
}

// --- tool execution -------------------------------------------------------

// runTool returns a tool's combined output. Stage tools run inside a freshly
// staged temp .claude project (claudelint/cclint); claudelint reuses the
// cached staged run. A nonzero exit with valid output is not a crash — the
// Score's jsonOK guard handles fail-closed semantics.
func (rn *runner) runTool(t tools.Tool) []byte {
	if t.Name == "claudelint" {
		out, _ := rn.claudelint()
		return out
	}
	if cached, ok := rn.outCache[t.Name]; ok {
		return cached
	}
	args := t.RunArgs(rn.kind, rn.path)
	cmd := exec.Command(t.Bin, args...)
	if t.Stage {
		proj := rn.stageProject()
		cmd.Dir = proj
	}
	out, _ := cmd.CombinedOutput()
	if rn.outCache != nil {
		rn.outCache[t.Name] = out
	}
	return out
}

// scoreTool returns a quality tool's 0-100 score. Under dry-run it returns
// the per-tool stub the bash runner used; otherwise it runs the tool and
// applies its Score extractor (fail-closed when ok==false).
func (rn *runner) scoreTool(t tools.Tool) (int, bool) {
	if dry() {
		return dryStub(t.Name), true
	}
	if t.Score == nil {
		return 0, false
	}
	return t.Score(rn.runTool(t))
}

// dryStub returns the fixed per-tool score used in dry-run mode, matching the
// bash helpers' DRY echoes.
func dryStub(name string) int {
	switch name {
	case "skill-tools":
		return 82
	case "skill-validator":
		return 90
	case "claudelint":
		return 70
	case "agnix":
		return 80
	case "cclint":
		return 100
	default:
		return 70
	}
}

// --- claudelint cache -----------------------------------------------------

// claudelint runs `claudelint check-all --format json` against a staged
// project at most once per audit, caching the output. The bool reports
// whether the run produced parseable JSON (i.e. did not crash).
func (rn *runner) claudelint() ([]byte, bool) {
	if rn.clDone {
		return rn.clOut, rn.clOK
	}
	rn.clDone = true
	if dry() {
		rn.clOut, rn.clOK = nil, true
		return rn.clOut, rn.clOK
	}
	proj := rn.stageProject()
	cmd := exec.Command("claudelint", "check-all", "--format", "json")
	cmd.Dir = proj
	out, _ := cmd.CombinedOutput()
	rn.clOut = out
	rn.clOK = jsonOK(out)
	return rn.clOut, rn.clOK
}

// claudelintScore derives a 0-100 quality score from the cached claudelint
// run, used as the reliability floor input. Fails closed to 0 on a crash.
func (rn *runner) claudelintScore() int {
	if dry() {
		return dryStub("claudelint")
	}
	out, ok := rn.claudelint()
	if !ok {
		return 0
	}
	t, found := tools.Find("claudelint")
	if !found || t.Score == nil {
		return 0
	}
	sc, sok := t.Score(out)
	if !sok {
		return 0
	}
	return sc
}

// --- reliability gate -----------------------------------------------------

// runGate is the deterministic structural veto. Agents require a clean
// claudelint Agents-schema parse; skills require quick_validate (or, when it
// is unavailable, the inline frontmatter check). Dry-run always passes.
func (rn *runner) runGate() bool {
	if os.Getenv("REVIEW_SKILLS_FORCE_GATE_FAIL") != "" {
		return false
	}
	if dry() {
		return true
	}
	if rn.kind == detect.KindAgent {
		out, ok := rn.claudelint()
		if !ok {
			return false
		}
		return agentSchemaErrors(out) == 0
	}
	return quickValidate(rn.path)
}

// agentSchemaErrors counts the claudelint "Agents Validator" errors.
func agentSchemaErrors(out []byte) int {
	t, found := tools.Find("claudelint")
	if !found {
		return 1
	}
	// Reuse the collector to extract per-validator findings, then count the
	// agent-schema errors. The collector is tolerant of partial JSON.
	n := 0
	for _, f := range t.Collect(out) {
		if f.Severity == "error" {
			n++
		}
	}
	return n
}

// quickValidate prefers the vendored skill-creator quick_validate.py (needs
// PyYAML); REVIEW_SKILLS_QUICK_VALIDATE may pin its path, or it may be on
// PATH. When neither is usable it falls back to the inline frontmatter check
// so the gate stays offline and dependency-free.
func quickValidate(skillDir string) bool {
	qv := os.Getenv("REVIEW_SKILLS_QUICK_VALIDATE")
	if qv == "" {
		if p, err := exec.LookPath("quick_validate.py"); err == nil {
			qv = p
		}
	}
	if qv != "" && fileExists(qv) && pyYAMLAvailable() {
		cmd := exec.Command("python3", qv, skillDir)
		return cmd.Run() == nil
	}
	return inlineFrontmatterOK(skillDir)
}

func pyYAMLAvailable() bool {
	return exec.Command("python3", "-c", "import yaml").Run() == nil
}

// inlineFrontmatterOK is the minimal offline gate: SKILL.md exists, opens
// with `---`, closes with `---`, and the block carries name + description.
func inlineFrontmatterOK(skillDir string) bool {
	f, err := os.Open(filepath.Join(skillDir, "SKILL.md"))
	if err != nil {
		return false
	}
	defer f.Close()

	sc := bufio.NewScanner(f)
	first := true
	inBlock := false
	closed := false
	haveName := false
	haveDesc := false
	for sc.Scan() {
		line := sc.Text()
		trimmed := strings.TrimSpace(line)
		if first {
			first = false
			if trimmed == "---" {
				inBlock = true
				continue
			}
			break // no frontmatter fence on line 1
		}
		if !inBlock {
			break
		}
		if trimmed == "---" {
			closed = true
			break
		}
		switch {
		case strings.HasPrefix(trimmed, "name:"):
			haveName = true
		case strings.HasPrefix(trimmed, "description:"):
			haveDesc = true
		}
	}
	return closed && haveName && haveDesc
}

// --- security -------------------------------------------------------------

// skillcheckOut runs skillcheck once and caches its SARIF output, so the
// security severity and the security findings share a single scan.
func (rn *runner) skillcheckOut() []byte {
	if rn.secDone {
		return rn.secOut
	}
	rn.secDone = true
	cmd := exec.Command("skillcheck", "--format", "sarif", rn.path)
	rn.secOut, _ = cmd.CombinedOutput()
	return rn.secOut
}

// securitySeverity returns the highest SARIF severity from the cached
// skillcheck scan. A missing/garbage SARIF is treated as none, matching bash.
func (rn *runner) securitySeverity() score.Severity {
	out := rn.skillcheckOut()
	if !jsonOK(out) {
		return score.SevNone
	}
	return tools.SkillcheckSeverity(out)
}

// securityScore maps a severity to the ported 0-100 security score.
func securityScore(sev score.Severity) int {
	switch sev {
	case score.SevCritical:
		return 50
	case score.SevHigh:
		return 80
	case score.SevMedium:
		return 90
	case score.SevLow:
		return 95
	default:
		return 100
	}
}

// --- behavioral -----------------------------------------------------------

// behavioral runs the optional promptfoo stage; success scores 80, else 70.
func (rn *runner) behavioral() int {
	cmd := exec.Command("promptfoo", "eval", "-c", rn.path)
	if cmd.Run() == nil {
		return 80
	}
	return 70
}

// --- staging --------------------------------------------------------------

// stageProject mirrors the bash stage_project: it builds a temp .claude
// project, copies the artifact into .claude/skills/<name>/ or
// .claude/agents/, and returns the project root. Staging is best-effort;
// claudelint/cclint fail-close on a malformed stage via their jsonOK guard.
func (rn *runner) stageProject() string {
	proj, err := os.MkdirTemp("", "review-skills-proj-")
	if err != nil {
		return rn.path
	}
	if rn.kind == detect.KindAgent {
		dst := filepath.Join(proj, ".claude", "agents")
		_ = os.MkdirAll(dst, 0o755)
		if isDir(rn.path) {
			copyGlobMD(rn.path, dst)
		} else {
			_ = copyFile(rn.path, filepath.Join(dst, filepath.Base(rn.path)))
		}
	} else {
		name := filepath.Base(strings.TrimRight(rn.path, "/"))
		dst := filepath.Join(proj, ".claude", "skills", name)
		_ = os.MkdirAll(dst, 0o755)
		if isDir(rn.path) {
			_ = copyFile(filepath.Join(rn.path, "SKILL.md"), filepath.Join(dst, "SKILL.md"))
		} else {
			_ = copyFile(rn.path, filepath.Join(dst, "SKILL.md"))
		}
	}
	return proj
}

// --- small fs helpers -----------------------------------------------------

func fileExists(p string) bool {
	fi, err := os.Stat(p)
	return err == nil && !fi.IsDir()
}

func isDir(p string) bool {
	fi, err := os.Stat(p)
	return err == nil && fi.IsDir()
}

func copyFile(src, dst string) error {
	b, err := os.ReadFile(src)
	if err != nil {
		return err
	}
	return os.WriteFile(dst, b, 0o644)
}

// copyGlobMD copies every *.md file from src into dst (best-effort).
func copyGlobMD(src, dst string) {
	entries, err := os.ReadDir(src)
	if err != nil {
		return
	}
	for _, e := range entries {
		if e.IsDir() || !strings.HasSuffix(e.Name(), ".md") {
			continue
		}
		_ = copyFile(filepath.Join(src, e.Name()), filepath.Join(dst, e.Name()))
	}
}

// jsonOK reports whether b is non-empty and parses as JSON. Duplicated from
// the tools package (unexported there) to keep the fail-closed guard local.
func jsonOK(b []byte) bool {
	b = bytes.TrimSpace(b)
	if len(b) == 0 {
		return false
	}
	var v any
	return json.Unmarshal(b, &v) == nil
}
