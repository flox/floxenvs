package tui

import "charm.land/bubbles/v2/viewport"

type modalKind int

const (
	modalNone        modalKind = iota
	modalConfirm               // apply diff confirmation (static)
	modalStream                // live command output in a viewport (review/doctor)
	modalAgents                // agent picker (master/detail)
	modalThemes                // tint picker (live preview)
	modalApply                 // apply progress
	modalUpgrade               // upgrade confirmation
	modalLaunch                // launch confirmation
	modalReview                // review-skills audit report (master/detail)
	modalAuditDetail           // pre-computed audit from data.json for selected item
)

// modalState is the floating modal: a confirm prompt (static) or a stream
// view (live output in a viewport).
type modalState struct {
	kind  modalKind
	title string
	vp    viewport.Model
}

func (m modalState) open() bool { return m.kind != modalNone }

// modalDims returns the centered modal's content width/height, always
// fitting inside the screen with a margin so the box never runs off-screen.
func modalDims(w, h int) (int, int) {
	mw := w * 3 / 4
	if mw < 24 {
		mw = 24
	}
	if mw > w-6 {
		mw = w - 6
	}
	// Leave room for border (2) + title (1) + footer (1) + screen margin.
	mh := h - 8
	if mh < 4 {
		mh = 4
	}
	if mh > h-4 {
		mh = h - 4
	}
	return mw, mh
}

// newModalViewport builds a viewport sized to fit the screen.
func newModalViewport(w, h int) viewport.Model {
	vw, vh := modalDims(w, h)
	vp := viewport.New()
	vp.SetWidth(vw)
	vp.SetHeight(vh)
	return vp
}
