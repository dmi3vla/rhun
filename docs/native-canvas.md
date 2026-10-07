# Native drafts in rhun

Runtime is native ASM using rhun's rasterizer; there is no browser engine.
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

Native JSON v1 validates IDs, references, integer geometry, strict UTF-8, schema
and limits before publishing owned content: 4,096 elements, 8,192 references,
8,192 stroke points per element, 64 KiB text per element, 8 MiB serialized content.
World coordinates and element extents are bounded to +/-1,000,000. Edits outside
these limits are rejected as a whole. Stable IDs are positive integers below
2^53; deleted or undone IDs are not reused. Nested frames are not supported in v1.
Writes use rhun's existing atomic sibling-file replacement. Invalid reloads keep
the live scene; reload refuses unsaved or pending edits.

Current implementation covers phases 0–2. Frame membership, groups, rotation,
images, sketch styling, Excalidraw exchange, SVG export, UI semantics and exports,
AI proposals and the 3D projection remain subsequent phases. A frame is currently
an outline drawing tool. This is not a claim of complete Excalidraw compatibility.
Linux x86-64 headless acceptance is tested; real platform/IME gates remain open.
