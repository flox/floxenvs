package tui

import (
	"math"
	"strings"
	"time"

	tea "charm.land/bubbletea/v2"
)

// splashTickMsg advances the startup animation.
type splashTickMsg struct{}

// splashTick schedules the next animation frame (~30ms).
func splashTick() tea.Cmd {
	return tea.Tick(30*time.Millisecond, func(time.Time) tea.Msg { return splashTickMsg{} })
}

// finishSplash ends the animation and opens any pending upgrade prompt that
// was held back until startup completed.
func (m *model) finishSplash() {
	m.phase = phaseReady
	if len(m.upgrades) > 0 && !m.modal.open() && m.query == "" {
		m.modal = modalState{kind: modalUpgrade, title: "upgrade"}
	}
}

// Startup phases.
const (
	phaseReady = iota // normal UI (default — tests never enter splash)
	phaseSplash
)

// Splash timing, in ~30ms ticks: show the mark, wink it, then blow it apart.
const (
	splashShow  = 14 // hold the solid mark (~0.4s)
	splashHold  = 28 // wink (eyelids close to a slit and reopen) finishes here
	splashTotal = 64 // explode the blocks outward and clear (~1.9s)
)

// logoArt is the flox mark in block characters (no gradient — single color).
var logoArt = []string{
	"         ███████████████████████",
	"      ██████████████████████████",
	"   █████████████████████████████",
	"████████████████████████████████",
	"█████████████████████████████",
	"███████████████████████",
	"█████████████████",
	"███████████",
	"           █████████████████████",
	"           █████████████████████",
	"           █████████████████████",
	"           █████████████████████",
	"███████████",
	"███████████",
	"███████████",
	"███████████",
}

// splashCell is one block of the mark, with a per-block seed for varied
// explosion velocity and lifetime.
type splashCell struct {
	x, y int
	seed float64
}

// hash01 maps a cell coordinate to a stable pseudo-random value in [0,1).
func hash01(a, b int) float64 {
	h := uint32(a)*73856093 ^ uint32(b)*19349663
	h = h*2654435761 + 2246822519
	return float64(h%1000) / 1000.0
}

// logoCells returns the centered screen positions of every block, plus the
// center point the explosion radiates from.
func (m model) logoCells() (cells []splashCell, cx, cy int) {
	w := 0
	for _, l := range logoArt {
		if r := len([]rune(l)); r > w {
			w = r
		}
	}
	h := len(logoArt)
	ox := max(0, (m.width-w)/2)
	oy := max(0, (m.height-h)/2)
	for r, line := range logoArt {
		for c, ch := range []rune(line) {
			if ch == ' ' {
				continue
			}
			cells = append(cells, splashCell{x: ox + c, y: oy + r, seed: hash01(c, r)})
		}
	}
	return cells, ox + w/2, oy + h/2
}

// renderSplash draws the flox mark held at center, then exploding into
// dissolving particles that fly outward under a little gravity.
func (m model) renderSplash() string {
	if m.width <= 0 || m.height <= 0 {
		return ""
	}
	cells, cx, cy := m.logoCells()

	rows, cols := m.height, m.width
	grid := make([][]rune, rows)
	for i := range grid {
		grid[i] = make([]rune, cols)
		for j := range grid[i] {
			grid[i][j] = ' '
		}
	}
	put := func(x, y int, ch rune) {
		if y >= 0 && y < rows && x >= 0 && x < cols {
			grid[y][x] = ch
		}
	}

	if m.splashN < splashHold {
		// Hold the solid mark, then wink once: eyelids close from top and
		// bottom to a thin slit at the center row, then reopen.
		half := float64(len(logoArt)) / 2
		openHalf := half
		if m.splashN >= splashShow {
			t := float64(m.splashN-splashShow) / float64(splashHold-splashShow)
			openHalf = math.Abs(2*t-1) * half // 1→0→1: open, shut, open
		}
		for _, c := range cells {
			if math.Abs(float64(c.y-cy)) <= openHalf+0.5 {
				put(c.x, c.y, '█')
			}
		}
	} else {
		// Explode: every block bursts outward in all directions, dissolving
		// as it ages.
		p := float64(m.splashN-splashHold) / float64(splashTotal-splashHold)
		if p > 1 {
			p = 1
		}
		glyphs := []rune("█▓▒░")
		for _, c := range cells {
			s2 := hash01(c.y*31+7, c.x*17+3) // second, independent seed
			life := 0.45 + c.seed*0.55       // each block winks out at its own time
			if p >= life {
				continue
			}
			// Aspect-correct outward direction; blocks near the center pick a
			// fully random heading so the burst covers every side.
			dx := float64(c.x - cx)
			dy := float64(c.y-cy) * 2
			d := math.Hypot(dx, dy)
			var ux, uy float64
			if d < 1 {
				a := c.seed * 2 * math.Pi
				ux, uy = math.Cos(a), math.Sin(a)
			} else {
				ux, uy = dx/d, dy/d
			}
			// Rotate by a chaotic angle so it scatters instead of zooming.
			ja := (c.seed - 0.5) * 2.4
			ca, sa := math.Cos(ja), math.Sin(ja)
			rx := ux*ca - uy*sa
			ry := ux*sa + uy*ca
			speed := 16 + d*0.6 + s2*22 // bigger, more varied blast radius
			nx := float64(c.x) + rx*speed*p
			// Undo the aspect stretch on the vertical, plus a little gravity.
			ny := float64(c.y) + ry*speed*p*0.5 + p*p*float64(rows)*0.12
			gi := int(p / life * float64(len(glyphs)))
			if gi >= len(glyphs) {
				gi = len(glyphs) - 1
			}
			put(int(math.Round(nx)), int(math.Round(ny)), glyphs[gi])
		}
	}

	style := m.styles.Title
	var b strings.Builder
	for i, row := range grid {
		if line := strings.TrimRight(string(row), " "); line != "" {
			b.WriteString(style.Render(line))
		}
		if i < rows-1 {
			b.WriteByte('\n')
		}
	}
	return b.String()
}
