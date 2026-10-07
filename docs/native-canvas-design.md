# Native canvas design and acceptance contracts

Research baseline: local HEAD b56c5fa (chat/input work), preparation commit 441b49f.
The historical rhun SHA in the input plan is not the current implementation.
No remote is configured. Runtime remains assembly with the existing static
rasterizer, UTF-8 font renderer, JSON parser, file helpers and process adapters.

## Document and tab ownership

Add TAB_CANVAS and DOC_canvas (owned pointer). Keep a normal DOC shell so names,
paths, tab selection, close/save prompts and session paths reuse their existing
lifecycle. g_file points at the shell; g_doc remains null so code editor commands
cannot change the scene. doc_free frees the scene. Canvas input is dispatched
before code editor/Vim input when the active tab is a canvas. Phase 1 has only a
read-only fixture plus viewport; it does not claim scene persistence.

The shell's save/dirty callbacks delegate to the canvas only after phase 2 adds
validated transactional serialization. Plain text/image/Git/settings routing
must remain unchanged. File suffix .rhun-canvas identifies the native format;
invalid files must not replace an existing scene. Saved paths participate in the
existing session list. Untitled drafts require Save As and are not silently
invented on restore.

## Scene IR v1

A scene owns an ordered vector of elements, copied text and external IDs,
revision, next numeric ID, viewport, selection and gesture preview. Internal IDs
are nonzero uint64 and never reused. Exchange IDs are a separate copied mapping.
Geometry uses bounded signed integer world units (initial range +/-1,000,000);
zoom is unsigned 16.16, clamped to 0.25..4.0. Pixel coordinates never overwrite
world geometry. Importing fractional geometry needs an explicit conversion and
compatibility diagnostic. Scene origin is independent of tab/window layout.

Screen = viewport origin + (world + pan) * zoom / 65536. Zoom preserves the world
point under the mouse, modulo at most one world unit of integer rounding. Pan
uses middle mouse; scroll zooms. Clip stack is balanced for every draw path.

Elements: id, kind, x/y/w/h, seed, stroke/fill, owned UTF-8 text, frame/group IDs,
angle, source/target bindings and owned point vector. Arrow endpoints are derived
from bound objects. Deletion unbinds endpoints at their last world positions.
Max 4096 elements, 8192 references, 64 KiB text per element, 8 MiB serialized scene.
No long-lived pointers into the JSON arena. Read -> validate temporary owned IR
-> atomically swap. Unknown native versions/kinds fail with a diagnostic.

A gesture previews separately; release commits one patch, Escape commits none.
History contains at most 32 owned snapshots with a total 16 MiB budget. Revision
is monotonic, including undo/redo, so a stale model proposal cannot accidentally
become valid again. A saved content checkpoint determines dirty state; viewport
and selection do not dirty scene content.

## UI IR v1

Separate owned tree: component ID, source scene ID/revision, type, child IDs,
text, action ID and a closed style vocabulary. Initial components: row, column,
card, list, text, button and input. Initial layout: width/height, padding, gap,
color/background/border/radius. Max 512 components, depth 32, no cycles, no
unknown child/source IDs or duplicate IDs. Styles and actions are declarative.
HTML/CSS export escapes text/attributes, produces stable component IDs and a
source map. Existing generated files are compared before replacement; manually
edited outputs require a new filename. Native preview consumes this IR, never
executes generated HTML/JS. Arbitrary HTML reverse import is outside this contract.

## Graph/State IR v1

Separate nodes, edges, segments and event trace with stable owned string IDs.
A logical object's replicas and schema version are distinct. Folding builds a
projection and aggregates original edge IDs without mutating source vectors.
Selected/collapsed IDs are shared by 2D and 3D views. Orbit and timeline are view
state, not graph edits. 3D projection clamps near-plane depth and guards overflow;
visible nodes are depth sorted for this demonstrator, not a general 3D engine.

The supplied example has 11 nodes, 14 edges, three segments and six events.
Extract it as a deterministic fixture; preserve the single shared schema node.
This is a demo trace, not production telemetry or hidden reasoning inspection.

## Model proposal contract v1

Request: source scene revision, selected IDs, bounded context, allowed operations
and task. Response: copied explanation plus a closed set of element/UI patches.
Validate IDs, bounds, dependencies and revision before preview; user acceptance
is one undoable transaction. Partial acceptance includes dependency closure.
Reject leaves content untouched. Existing Codex/OpenCode transport is available;
first prove the full flow with local fixtures, then attach it to chat.

## Initial compatibility matrix

| Feature | Native milestone | Excalidraw interchange |
| --- | --- | --- |
| Rectangle/ellipse/line/arrow/text/free stroke/frame | Phases 1-2 | Phase 3 subset only |
| Groups/angle/z-order/images/seeded sketch | Phase 3 | Explicit supported fields/metrics |
| Embedded images and unknown fields | Phase 3 gate | No silent loss; preserve or diagnose |
| Collaboration/library/complete browser behavior | Not planned | Not claimed |
| UI semantics and HTML export | Phase 4 | rhun extension, not Excalidraw semantics |
| Native UI IR preview | Phase 5 | No arbitrary HTML execution |
| Model patches and progressive detail | Phase 6 | No direct ASM execution |
| Folded 3D demo graph | Phase 7 | Separate Graph/State IR |

Provenance: supplied plan and HTML live in docs/native-canvas-agent-plan.md and
examples/reference/distributed-state-3d.html. The upstream editor is studied at
https://github.com/excalidraw/excalidraw; its MIT license is at
https://github.com/excalidraw/excalidraw/blob/master/LICENSE. No upstream runtime
code is copied in phase 0. A future algorithm port must record its exact source
revision and required notices. Native platform execution is separately gated.
