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
