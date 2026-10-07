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
