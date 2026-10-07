# Radare2 native frames: phases and acceptance

User scope: native Radare2 tab analogous to canvas, trace decomposition into
frames, review, phase commits. Base e233bfa. Runtime remains ASM, no WebKit.

## Architecture review / phase 0

Reuse the owned DOC_canvas shell and TAB_CANVAS rendering/lifecycle as a Radare2
canvas subtype: dedicated title and commands, normal save/reopen/close/undo.
Do not copy terminal ASCII screenshots into an image. Function frames own block
geometry; local numeric scene IDs are separate from source binary addresses.
Block raw JSON and disassembly are copied, never retained in the parser arena.
Native format v6 adds an owned analysis string; read v1–v5 unchanged. Analysis
records source identity and imported trace; cursor is ephemeral view state.

Radare2 is an optional external read-only analyzer, not an embedded library.
Use fixed argv and bounded nonblocking output, deadline and cancellation. No
shell, debugger target execution or user-supplied radare command strings.
Stale project results are discarded. Missing executable must explain the remedy.
CFG is static possible control flow. A separately imported address sequence is
trace evidence; never call CFG node visitation an observed execution.

Sources: https://book.rada.re/analysis/graphs.html (agfj),
https://book.rada.re/analysis/code_analysis.html (functions/blocks),
https://book.rada.re/scripting/r2pipe.html (external process integration).
No upstream runtime source copied. External r2 version is recorded by tests.

Commit: docs(radare2): review native integration and define phased contracts

## Phase 1: owned CFG, dedicated tab and demo

Stages: validate agfj function arrays; import function frames, block rectangles,
owned assembly text, bound colored jump/fail arrows; stable address metadata;
source limits; palette demo/import; persistence/undo integration.
Limits: 64 functions, 512 blocks total, 32 instructions/block in display (source
retained), 8 MiB input, 4096 scene elements; JS-safe integer addresses required.
Unknown external branch destinations remain source metadata, not invented blocks.
Layout is deterministic bounded grid, not an optimal cyclic graph layout.
Acceptance: valid/invalid fixtures, branches, Cyrillic/name quoting, save/reopen,
parser ownership, frame collapse, rendering and no code-editor input leakage.
Commit: feat(radare2): render owned function and block frames natively

## Phase 2: asynchronous analyzer

Stages: executable discovery PATH / RHUN_RADARE2 override; choose binary;
fixed non-debug analysis; JSON-line normalization; output/deadline cap; cancel;
stale project handling; ready output opens an independent Radare2 tab.
Acceptance: argv-injection filenames, missing/failure/oversized/timeout fixtures,
responsive commands during analysis, cancellation; actual r2 on a local fixture.
Commit: feat(radare2): analyze binaries asynchronously with bounded jobs

## Phase 3: imported trace and review

Stages: closed address-sequence trace import; resolve to source block intervals;
coverage highlighting and ordered previous/next; repeated addresses stay ordered;
unmatched addresses explicit; frame collapse retains trace; add selected-block
review note in one undo; export Markdown addresses/assembly/notes/evidence;
selected context uses existing canvas chat request transport by explicit action.
Acceptance: invalid trace leaves scene intact, loops/unmapped events, timeline
without content edits, imported trace undo/redo/save, note undo, escaped export.
No debugger launch, live tracing, decompiler or automatic vulnerability verdict.
Commit: feat(radare2): add trace navigation and source-linked review notes

## Phase 4: review, integration and documentation

Stages: review ownership and external process teardown; mixed tab regressions;
actual native screenshot; actual r2 smoke; user walkthrough and limitations.
Acceptance: all new checks, relevant existing canvas/editor/chat checks, clean
Git tree after commit. Linux x86-64 primary; report unavailable platform checks.
Commit: test(radare2): verify native analysis trace and review workflows

### Phase 1 acceptance

Native demo contains one function frame, four blocks and four bound green/red
edges. Function labels and assembly are native text; display shows up to 32
instructions while full block JSON stays owned in source metadata. The importer
accepts addr/legacy offset, rejects duplicate block addresses, malformed values
and input limits, and keeps missing external edge targets only in source JSON.
Function layout uses two columns with height derived from the largest displayed
block. Initial zoom 75%; native glyph line spacing is bounded by font metrics.

`./build.sh test`, `build/radare_model_test`, `tests/radare-frames.py` (5), canvas
edit (18), graph (6), proposals (7), UI (7), exchange (7) passed. Screenshot
/tmp/rhun-radare2-demo.png inspected. A snapshot clone now copies next-ID and
revision as well as owned content; undo restore still retains monotonic live IDs.
Native v6 saves analysis and reads previous versions. Excalidraw export of analysis
scenes is refused rather than losing analysis/producing colliding external IDs.
