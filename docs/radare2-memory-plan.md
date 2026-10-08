# Binary projection and memory analysis: implementation phases

Scope: native ASM runtime, owned deterministic data, no browser engine. Existing
Radare2 CFG/trace/review remains usable. No target process is launched by importing
memory evidence. Static facts, imported snapshots, and teaching examples carry
explicit provenance; addresses are 64-bit hex strings in the memory contract.

0. Fork updates and contracts. Disable automatic checks by default; point all
   built-in release/install/Issues paths at dmi3vla/rhun. Document phases.
1. Owned memory IR. Strict bounded import with source, entrypoints, snapshots,
   per-thread frames, memory regions, allocations and pointer evidence; native
   persistence and lifecycle validation. Rejected input is atomic.
2. Native 2D analysis. Dedicated entry/stack/heap frames, source addresses,
   lifetime distinctions and ordered snapshot navigation. Derived scene geometry
   and timeline/camera are view state, not edits to imported evidence.
3. Shared 2D/3D projection. Native graph projection from the same owned memory
   snapshot, linked identifiers and typed pointer/call relations; deterministic
   placement and explicit display limits. No replica versions presented as memory.
4. Radare2 static adapter and rhun allocator. Selected CFG projection/entry
   discovery, read-only snapshot import, rhun size-class decoding; clearly mark
   inferred stack facts and unverified pointer candidates. Custom heap is not glibc.
5. Integration/review/docs. Timeline, save/reopen, bad inputs, actual analysis,
   memory ownership, native rendering and existing canvas/chat regressions.

Each phase ends with checks and a separate commit. Live debugger recording,
arbitrary-architecture unwinding and recovered original source AST are outside
this implementation; imported evidence is the supported runtime boundary.

Phase 1 acceptance: native v7 owns a memory JSON field and reads v1–v6. Closed
rhun-memory v1 supports 64 snapshots, 256 nodes/snapshot (4096 total), exact
64-bit hex addresses, typed links and allocation generations. Source, observed,
and demo provenance is explicit. Cycles/dangling IDs, wrong thread frames,
range overflow and live pointers to freed allocations are rejected. Rhun slot
capacity matches the allocator's header/classes/page rounding. Native analysis
and memory profiles cannot be mixed; Excalidraw export refuses metadata loss.
7 contract checks, 100 owned lifecycle cycles, 6 Radare frame checks and 7 canvas
exchange checks passed after ./build.sh test. Imported memory has no live debugger.

Phase 2 acceptance: dedicated native Memory tab draws code/entry, thread stack,
and mappings/allocations as derived frames. Typed colors separate pointer,
candidate and dangling links; freed allocations retain historical identity.
Previous/next and [ ] preserve ordered snapshots; model/camera navigation does
not change saved evidence. Teaching provenance is visible. Palette import/demo,
raw .rhun-memory open, native save/reopen and print-memory are available.
6 memory view checks, 4 viewport checks and owned model lifecycle passed.
Screenshot /tmp/rhun-memory-2d.png inspected. 3D rendering follows in phase 3.

Phase 3 acceptance: shared source IDs map to native 2D cards and 3D nodes;
selection survives mode switches. 3D code/stack/memory segments fold with retained
boundary edge source IDs. Typed colors and inspector addresses replace replica
versions. Camera survives snapshot changes; navigation never edits evidence.
3 memory graph, 6 existing graph and 6 memory view checks passed; 100 lifecycle
cycles now include derived scene, graph and projection with zero allocation growth.
Native screenshot /tmp/rhun-memory-3d.png inspected. F folds in the 3D view.

Phase 4 acceptance: Project CFG to Entry Stack Heap converts the current owned
Radare2 function/block/branch records into static memory IR with exact hex source
addresses, instruction text, function membership and original branch endpoints.
Only Radare's explicit entry0 flag is classified as binary entry; function names
are not treated as startup execution evidence. Static PC/SP/BP and stack/heap
are unknown, never fabricated. Projection rejects excess limits atomically.
Import Memory Snapshots also accepts a closed rhun-heap-header capture: exactly
16 little-endian header bytes, validated class/page size and request capacity.
The result always has unknown liveness, inferred layout and imported provenance.
4 adapter checks passed including actual Radare2 6.2.4 /bin/true entry analysis
(official release SHA256 checked, extracted under /tmp; no system installation).
7 contract checks and 100 lifecycle cycles including header conversion passed.

Phase 5 acceptance: selected-node review JSON and ready-chat ACP transport carry
source addresses, snapshot registers, provenance, allocator, directly connected
nodes and incident typed links. Read-only prose review is requested with no
allowed scene operations. No selection, >64 context nodes or >48 KiB fails without
sending or replacing an existing export. Static projection checks retained agfj
jump/fail evidence so drawn annotation arrows do not become branch facts.
Card text is clipped; addresses/state precede potentially long instruction text.
Entry resets both cameras. Documentation covers exact contracts, unknown states,
allocation generations, reset-on-reopen view state, source limits and runtime
capture boundaries. The synthetic header fixture is explicitly not a live capture.
25 memory checks including actual Radare2 /bin/true passed; 100 lifecycle cycles
include scene/graph projection, native clone/validation and header conversion
with zero allocation growth. Live Wayland and X11 smoke passed; final native
2D/3D screenshots inspected. All 9 memory modules and 2 unit modules translate to
ARM64 after equivalent-instruction fixes. Existing canvas still has 5 translator
blockers; macOS/Windows runtime acceptance is not claimed. Windows LLVM tools are
unavailable on this host. Build dependency tracking includes memory headers/demo.
Update tests now explicitly cover default-off/no-background-state and opt-in;
desktop link expectations use the fork Issues URL.
Final `sh tests/run.sh` completed with exit 0 on the final Linux build. Actual-r2
and live-display checks above were run separately because they are opt-in.
