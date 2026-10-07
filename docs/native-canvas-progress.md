# Native canvas progress

Preparation: archived the untracked task transcript outside the repository at
../rhun-task-archive/2026-10-07; preserved user inputs in commit 441b49f. Local
branch codex/native-canvas; no Git remotes. Build outputs are retained for use.

## Phase 0: research and contracts

Followed DOC/TAB ownership, input/drawing routing, save/close prompts and session
path restoration. Design recorded in native-canvas-design.md. The existing chat
transport is interactive; phase 6 can reuse it after validating offline patches.
No browser/JS runtime or upstream implementation code was added.

Baseline: `./build.sh test` passed; `python3 tests/chat-drop.py` passed 6 scenarios.
`python3 tests/editor-matrix.py` passed all 18 scenarios. Broad prior
regression coverage is in chat-validation.md; it is not a substitute for canvas
acceptance tests. Linux x86-64 is the primary target. Native Windows/macOS and
full Excalidraw external validation are not available at this phase.

Next: phase 1 viewport/tab lifecycle, then phase 2 editing/persistence. Later
phase entries must distinguish implemented behavior from planned acceptance.

## Phase 1 — native tab and viewport

Implemented owned `DOC_canvas`, a distinct canvas tab and `Canvas: New Draft`
palette command, two fixture shapes, world-aligned grid, clipped rendering,
independent pan/zoom, middle-button capture and pointer-anchored zoom (25–400%).
Canvas typing is consumed without entering text editor commands. Closing frees
owned vectors/text. Changes to included ASM contracts now invalidate object files.

Acceptance:
- `./build.sh test` — PASS (build including the new native test).
- `build/canvas_transform_test` — PASS; 6,200 negative/positive coordinate pairs
  across 31 zoom values, bounded quantization and owned scene lifecycle.
- `python3 tests/canvas-viewport.py` — 4 PASS: independent tabs, pan/zoom bounds,
  input isolation, resize and shell clipping.
- `python3 tests/editor-matrix.py` — 18 PASS (37.441 s), log
  `/tmp/rhun-canvas-phase1-editor-final.log`.
- `python3 tests/chat-drop.py` — 6 PASS.
- `git diff --check` — PASS.

The phase-1 fixture is intentionally read-only and untitled; editing, dirty state
and scene persistence are phase 2. No canvas content is claimed to survive restart.
Integer transforms quantize by at most one screen pixel (four world units at 25%).
The headless control protocol accepts `down 2` / `up 2` for middle-button tests;
plain `down` / `up` retains its existing left-button behavior.

## Phase 2 — draft editor, bindings, history and persistence

New drafts start empty (the phase-1 fixtures are now in the owned example file).
Implemented all seven drawing tools, geometric reverse-order hit testing,
zoom-dependent line/stroke tolerance, Shift and marquee selection, move/resize
previews, native UTF-8 multiline text and paste, bound arrows, selected-node plus
and role choice, whole-gesture cancellation and transactions. Arrow bindings keep
center coordinates in IR and render at rectangle/ellipse boundaries.

Owned deep snapshots retain strings and stroke points. IDs never recycle; content
checkpoints determine dirty state and revisions increase through undo/redo. The
combined history is capped at 32 entries / 16 MiB. Native JSON validates complete
schema, integer ranges, IDs, duplicate IDs, references, UTF-8 and limits into a
new owned scene. The same validator rejects an invalid content transaction before
history publication. Save uses atomic file replacement. Watch/reload has a canvas
path, rejects unstable/invalid or unsaved documents, and preserves live content.
Close/quit/project-switch prompts, dirty tab dots and saved session paths include
canvases. Pending text cannot be silently discarded by a mouse close.

Acceptance:
- `./build.sh test` — PASS.
- `python3 tests/canvas-edit.py` — 18 PASS: drawing, one-step history,
  cancellation, bound movement/deletion, resize, Cyrillic/newlines/paste, strokes,
  save/open, 12 corrupt-field cases, invalid live reload, session restoration,
  history limit, pending-text close and image Save As isolation.
- `python3 tests/canvas-viewport.py` — 4 PASS (updated empty-draft expectation).
- `build/canvas_scene_test` — PASS: parser-arena independence, owned Cyrillic,
  revision checkpoints, undo/redo branch and non-reused IDs.
- `build/canvas_transform_test`, `build/canvas_boundary_test` and
  `build/textarea_test` — PASS.
- `python3 tests/editor-matrix.py` — 18 PASS (40.503 s), log
  `/tmp/rhun-canvas-phase2-editor.log`.
- `sh tests/session.sh` — 8 PASS, log `/tmp/rhun-canvas-phase2-session.log`.
- `python3 tests/chat-drop.py` — 6 PASS.
- `python3 tests/chat-clipboard.py` — 13 PASS on isolated full rerun (10.655 s).
  A concurrent run timed out waiting for the question fixture's reply; that case
  separately passed and the isolated entire group passed without code changes.
- `build/image_test tests/data/images/palette-trns.png tests/data/images/exif-rotated.jpg`
  — decoded PNG 13x9 and EXIF-oriented JPEG 16x24; pixel hashes b311c4f5/d10b36ae.
- Native headless screenshot `/tmp/rhun-frame-arrow.png` visually inspected;
  reopened and selected bound arrows were checked, with a pixel test for visible
  arrowheads and a native unit test for rectangle/ellipse boundary coordinates.
- `git diff --check` — PASS.

Usage and current limits: `docs/native-canvas.md`. Frame membership and external
interchange are phase 3; no IME or desktop-platform acceptance is claimed yet.
