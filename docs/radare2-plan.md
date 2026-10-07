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

### Phase 2 acceptance

Analyze Binary Entry CFG runs fixed `aa;agfj @ entry0`; Analyze Function Address
accepts only decimal/0x numeric input and builds `aa;af @ ADDR;agfj @ ADDR` for the
same saved source path. Each result opens a separate tab. Import also normalizes
`agfj @@F` JSON-lines arrays into copied function objects within the same caps.
No shell or `-d`, no write mode; absolute regular-file arguments are required.
User r2 startup scripts are disabled (`-N`), plugins disabled by R2_NOPLUGINS=1,
and inherited R2_ARGS cleared (real r2 otherwise replaces fixed argv with it).

Nonblocking output has an 8 MiB limit, 30-second deadline, 20-ms pending-job
poll, explicit cancellation and shutdown reaping. EOF and child exit are separate
states; UI never waits synchronously for an ordinarily running analyzer. A
changed project or source mtime discards the result. RHUN_RADARE_TIMEOUT_MS permits
50–30000 ms for testing; RHUN_RADARE2 overrides executable discovery.

`./build.sh test`, frame tests (5 including JSON-lines), analyzer tests (7),
unchanged explorer-create checks (6) passed. Real radare2 6.2.4 release 485e5e2,
verified official package SHA256 7019eedc0e0e87d1f53d6b8f5fc62b898567679c5efdce7fbfc557c9e7655e90,
read-only /bin/true entry CFG passed. Fixture tests cover literal hostile filenames,
missing r2, nonzero exit, output cap, timeout, cancel while other tabs stay usable,
numeric command validation and changed source. Runtime dependency was extracted
outside this repo for testing; it is not bundled in rhun. Linux is verified.

### Phase 3 acceptance

Imported address sequences preserve loops and show unknown/ambiguous addresses
separately. An owned revision-keyed cache derives block visit counts; navigation
and collapse do not mutate content. One undo restores trace import or a complete
source-linked note frame. Native v6 preserves source links and trace on reopening.
CFG edges are labelled T/F/J; coverage and current-event overlays remain separate
from static branch colors. Review export uses indented assembly/note text, and
explicit selected-block chat requests carry review instructions and bounded trace
evidence through the existing proposal transport.

`./build.sh test`, trace/review checks (6), frame checks (5), proposals (7), canvas
chat transport (1), and the owned-model binary passed. Review caught borrowed
numeric JSON tokens: trace input now remains owned until serialization finishes.
Source reference validation permits only typed review-to-function/note-to-block
links in analysis scenes; old native formats retain their prior validation.

### Phase 4 acceptance

Review corrected function navigation to skip annotation frames and restricted
reuse to typed source-review frames. Native screenshot review exposed a generic
step label overlapping assembly; analysis blocks now suppress that label, with
a pixel regression check. Native rendering inspected in docs/radare2-native.png.

`sh tests/run.sh` completed successfully, including all new Radare2 suites and
existing editor/chat/canvas regressions (environment-dependent checks skip with
reasons). Frame checks: 6; trace/review checks: 7, including explicit proposal
preview/accept/undo retaining source/evidence; ACP review transport: 1. Analyzer
checks: 8 with the actual backend enabled. Real Radare2 6.2.4 analyzes /bin/true,
then its CFG saves/reopens, accepts repeated-address evidence plus an unmapped
event and a source-linked note while preserving raw source. Cancel and shutdown
checks confirm the analyzer PID is gone. The native owned-model binary performs
100 trace/cache/clone/history cycles with zero live owned-byte growth.

Opt-in native Wayland and X11 window tests both passed with imported trace and
next-event navigation. All 7 new Radare2 modules translate to ARM64. Existing
canvas translator blockers still prevent claiming macOS runtime support; Windows
runtime/toolchain verification remains unavailable. Mac build dependency tracking
now includes the Radare2 schema and embedded demo. User guide: docs/radare2.md.

Phase commits: phase 0 e159ac5, phase 1 d17c921, phase 2 ea55803,
phase 3 0ac0f42; phase 4 uses the final test/documentation commit below.
