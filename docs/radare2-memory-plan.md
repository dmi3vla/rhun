# Binary projection and memory analysis: implementation phases

Scope: native ASM runtime, owned deterministic data, no browser engine. Existing
Radare2 CFG/trace/review remains usable. No target process is launched by importing
memory evidence. Static facts, imported snapshots, and teaching examples carry
explicit provenance; addresses are 64-bit hex strings in the memory contract.

0. Fork updates and contracts. Disable automatic checks by default; point all
   built-in release/install/feedback paths at dmi3vla/rhun. Document phases.
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
