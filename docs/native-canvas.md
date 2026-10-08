# Native drafts in rhun

Runtime is native ASM using rhun's rasterizer; there is no browser engine.
[Radare2 function frames, imported traces and review](radare2.md) use this same
owned canvas model with a dedicated toolbar and analysis metadata.
Open the command palette and choose **Canvas: New Draft**, or open a saved
`.rhun-canvas` file (for example `examples/canvas/native-draft.rhun-canvas`).

The toolbar and single-letter keys select tools: **S** selection, **R** rectangle,
**E** ellipse, **A** arrow, **T** text, **F** frame, **L** line, **P** freehand.
Draw with the left mouse button. Middle drag pans; the wheel zooms around the
pointer between 25% and 400%. Each canvas keeps its own viewport.

Click to select; Shift toggles additional elements. Drag on empty space makes a
selection rectangle. Drag selected elements to move them; the bottom-right handle
resizes them. Delete removes selected elements. Arrows bind to shapes under their
start/end points. Bound endpoints follow centers in IR and are painted on shape
boundaries. Deleting an anchor detaches the endpoint at its last position.

A selected shape exposes **+** at its right edge. Drag it to empty space or another
shape, then choose **1 Шаг / 2 Вопрос / 3 Решение / 4 Ограничение** from the overlay
(or press the digit). Node creation and connection are one undo transaction.
Escape cancels the complete proposal before choosing a type.

Text uses the native UTF-8 text area: Enter inserts a newline; **Ctrl+Enter**
applies the text; Escape cancels. Select existing text and press Enter to edit.
Copy, cut, paste, cursor movement and deletion use rhun's native text controls.
Pending text also participates in the close/save prompt. IME has not been tested.

Save / Save As uses the existing file prompt. Use the `.rhun-canvas` suffix so
opening the file recognizes a native draft. Saved paths restore with the project
session; unnamed drafts need Save As. Undo/redo has 32 snapshots and a combined
16 MiB budget. Redo is discarded by a new edit. Cancelled previews are not history.
Viewport/selection changes do not dirty saved content.

Native JSON v7 (with v1–v6 backward reads) validates IDs, references, integer geometry, strict UTF-8, schema
and limits before publishing owned content: 4,096 elements, 8,192 references,
8,192 stroke points per element, 64 KiB text per element, 8 MiB serialized content.
World coordinates and element extents are bounded to +/-1,000,000. Edits outside
these limits are rejected as a whole. Stable IDs are positive integers below
2^53; deleted or undone IDs are not reused. Nested frames are not supported.
Writes use rhun's existing atomic sibling-file replacement. Invalid reloads keep
the live scene; reload refuses unsaved or pending edits.

Phases 0–8 provide drafting, interchange, semantic UI, model proposals and a
native distributed-state demonstration. This is a native editor with a documented
Excalidraw subset, not the complete upstream application. Linux x86-64 is verified;
Windows and macOS gates are listed below. IME remains untested.

### Groups, frames and export (phase 3)

The command palette exposes Canvas: Group/Ungroup Selection, Bring Selection Forward/Send Selection Back, Rotate Selection 15 Degrees (rectangle/ellipse), Toggle Seeded Sketch, Attach Contained Elements to Frame, Select Frame Contents, Insert Local Image, Export Frame SVG and Export Excalidraw. Click a frame's empty area before attaching/exporting its contents. Group and frame selection moves members together; these edits are undoable. Local image paths must remain available on reopening; SVG embeds PNG/JPEG for portability.

Native v2 reads v1 documents. Supported Excalidraw v2 primitives round-trip geometry, text, groups, frames, seeds, colors and two-point arrow bindings, retaining unknown metadata. Unsupported primitives appear as placeholders with retained original JSON. Imported embedded assets remain retained source data. A scene with native local images cannot export Excalidraw; use SVG or the native format. Native fonts, rough outlines and SVG typography differ from Excalidraw. Frames cannot nest; rotation editing covers rectangles/ellipses. External Excalidraw UI validation remains unperformed.

### Semantic UI and HTML (phase 4)

Attach shapes to a frame, select a shape, then use Canvas: Assign Button/Input/Text/Card/Row/Column/List. Assignments are separate from geometry and undoable. Canvas: Import UI JSON accepts the documented closed schema; its revision must equal the next scene revision. Canvas: Export UI HTML exports the selected assigned subtree (or UI root), opens the generated code tab, and includes `data-scene-id` and `rhun-component-ID` for navigation. Use Go to Generated Component Code and Go to Source Figure from the component's code line.

After geometry changes, use Refresh UI Source Revision to revalidate the mapping. Clear UI Assignments before deleting referenced source figures. Width/height zero means automatic sizing; padding/gap are integer pixels. Only the seven listed types/properties are accepted; actions remain identifiers. Existing differing HTML is kept separately from newly generated output, and an already-existing alternate is also kept. There is no HTML-to-scene parser.

### Native UI preview (phase 5)

Canvas: Toggle Native UI Preview switches between drawing tools and the semantic projection. Preview clicks select source components; input fields show values without executing actions or editing the sketch. Use the palette command again to return to drawing. Stale UI needs Refresh UI Source Revision before preview/export.

Columns stack auto heights with gap; rows share available width among auto children after explicit widths. Padding belongs to each component. Frame roots clip to their bounds; all containers clip descendants. Width/height zero selects auto sizing, positive values select explicit size. Text measurement uses 8 logical pixels per Unicode scalar and 20 per line; native glyphs remain the IDE font, so HTML and native typography can differ.

### Model proposals and detail (phase 6)

Open `examples/canvas/proposal-source.rhun-canvas`, then Load Model Proposal with `detail-proposal.json`. Proposed shapes appear at 50% opacity. Select Next Proposal Change (or click a proposed figure), then Accept Selected Proposal Change: a proposed arrow also accepts any required new endpoint/frame. Accept All applies the full set. Reject leaves the document unchanged; acceptance is one undo. Any content edit makes a pending proposal stale.

Export Selected Context Request creates bounded JSON; Send Selected Context to Ready Chat sends it through the chosen existing chat provider after the chat is ready. Ask the agent to save the `rhun-proposal` response as a JSON file, then load that file. The request carries no project-wide context automatically. add/replace records use the complete current native element schema; delete has `id`; ui has `value` with the closed UI IR. UI source revision must describe the accepted next scene revision.

Steps have progress 0/1/2 (pending/done/blocked), changed by the palette commands. Expand/Collapse Selected Frame hides/restores direct members without deleting/recreating them. The folded summary counts direct `role=1` steps, completed steps and blocked steps. All semantic content stays saved in native v4; collapse is a view choice.

Proposal image add/replace operations are rejected in this first version; use the explicit local image insertion command. UI proposals must carry the next accepted scene revision. Alpha compositing uses at most 16 MiB of viewport backup; larger viewports fall back to the distinct tinted overlay.

### Distributed state demo (phase 7)

Canvas: Open Distributed State Demo opens the native graph. The top controls switch 2D/3D, fold/unfold the selected segment and move through events. V switches projection, F folds, [ and ] select events; middle-button drag orbits and the wheel zooms. Click markers for the inspector. Demo event 4 shows DB v8/cache v7; event 5 makes all four replicas v8. The object `order#42` and schema v1 remain distinct from state versions.

Standalone `.rhun-graph` uses `nodes`, `edges`, `segments`, `events`; fields are a closed schema with bounded integer coordinates/versions and copied string IDs. Folded boundary links expose original `sourceIds` in `print-graph`; unfolding restores the source graph. Saving through rhun embeds graph JSON in native v5. Rotation, folds and timeline are view state, so reopening uses default camera/event. This is a demonstration trace, not a live profiler or JavaScript execution.

### Reproducible walkthrough

Build locally with `./build.sh test`, then run `build/rhun . --wait`. Open the
palette (Ctrl+Shift+P), choose **Canvas: New Draft**, draw a frame (**F**), two
shapes (**R**, **E**) and an arrow (**A**). Add Russian text with **T**, finish
with Ctrl+Enter. Select the frame and use Attach Contained Elements to Frame.
Save as `draft.rhun-canvas`, then reopen it.

Assign Button/Input/Text to selected members. Refresh UI Source Revision, export
UI HTML and toggle Native UI Preview. To try proposals reproducibly, open
`examples/canvas/proposal-source.rhun-canvas`, load
`examples/canvas/detail-proposal.json`, choose Next Proposal Change and Accept
Selected; undo/redo should remove/restore the accepted dependency set together.
Use **Canvas: Open Distributed State Demo** for the supplied trace (the palette
may match by “Distributed”). **V** toggles 2D/3D, **F** folds the selected segment,
**[ / ]** move through events; middle drag rotates and wheel zooms.

The automated walkthrough is `python3 tests/canvas-integration.py`; run the full
regression set with `sh tests/run.sh`. Ownership tests include 100 repeated
scene/proposal/graph/undo lifecycles with zero retained owned-byte growth after
warm-up. See native-canvas-progress.md for acceptance evidence and
native-canvas-measurements.json for measured samples.

### Platform and compatibility status

| Area | Implemented / checked | Limit |
| --- | --- | --- |
| Linux x86-64 | Headless acceptance plus Wayland/X11 live event-loop smoke | IME, native clipboard ownership on private Xvfb and live AI providers untested |
| Windows | Build attempted | LLVM `llvm-mc` absent; no binary/runtime acceptance |
| macOS ARM64 | 24 of 30 new module translations pass | Six translator blockers; assembly/AppKit runtime untested; feature currently unavailable |
| Excalidraw v2 | Supported primitive round trips and retained opaque metadata | Complex shapes/embedded assets are placeholders; external editor validation unperformed |
| UI IR | Seven component types, HTML/CSS and native read-only projection | No browser execution, reverse HTML parsing or business-action execution |
| Model proposals | Strict JSON, preview, dependency-aware acceptance, undo; existing ACP test transport | Results loaded explicitly from JSON files; no automatic chat-response extraction |
| Graph | Supplied 11-node trace, 2D/3D, events, replica/schema inspector, lossless folds | Demo data, no code analysis or live telemetry |

Native image cache limits apply after decoding: 16 MiB per cached image / 64 MiB
per scene. The existing decoder can allocate larger transient pixel buffers before
that cache admission check. Performance samples measure basic rectangle painting,
not whole UI frame latency or an FPS guarantee.

Memory evidence uses a separate read-only native profile: see [entry/stack/heap projection](radare2-memory.md).
