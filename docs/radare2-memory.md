# Native entry, stack and memory projection

The Linux ASM build has a dedicated **Radare2 Memory** canvas. It renders owned,
bounded evidence in native 2D and 3D, without a browser engine. This is a static
analysis / imported snapshot viewer, not a live debugger or an original-source
AST recovery tool. Import never launches the target binary.

## Start

Build with `./build.sh`, then launch `./build/rhun .`. Use the command palette
(`Ctrl+Shift+P`):

- **Radare2: Open Entry Stack Heap Demo**: synthetic teaching lifecycle from
  loading and initialization through calls, allocation, free, address reuse and
  exit. All addresses and frames in this example are illustrative.
- **Radare2: Analyze Binary Entry CFG**, then **Radare2: Project CFG to Entry
  Stack Heap**: project the current Radare2 tab's functions, instructions and
  control-flow branches. Drawn annotation arrows are excluded unless their
  endpoints match retained agfj jump/fail evidence. The memory projection keeps
  branch endpoints; jump/fallthrough labels remain in the original CFG view.
  Radare2 must be installed or set through `RHUN_RADARE2`.
  Imported `agfj` files work too. Stack and heap lanes stay empty when unobserved;
  the static snapshot's PC/SP/BP are `0x0` with an explicit “not observed” label.
  Radare's explicit `entry0` is classified as entry; ordinary symbols remain
  function candidates. No startup order or stack frame is invented from names.
- **Radare2: Import Memory Snapshots**: choose a `rhun-memory` JSON file or the
  captured header format below. `.rhun-memory` snapshot files also open directly
  from the explorer. Bad imports preserve existing tabs and evidence.

Code, per-thread stack frames/pointer slots, and memory mappings/allocations have
separate frames. Cards expose addresses, size/capacity, state and certainty;
long text is clipped to its card. The 3D inspector exposes the source address.
Blue links are control/call relations, green are declared live pointers, amber
are candidates, red are dangling pointers to historical allocations.

`[` / `]` or Previous/Next navigate ordered snapshots. `V` toggles 2D/3D. Middle
mouse pans 2D or rotates 3D; the wheel zooms. **Select Next Object** provides
keyboard/palette selection. Click a card/node to select it; selection maps to the
same source ID when switching views. Snapshot changes clear selection and retain
camera; folds reset. `N` / Entry restores default cameras. In **2D and 3D**,
`F` / **Fold Selected Segment** folds code, stack or memory. Select a node or
click a 2D segment header/summary first. A collapsed 2D card shows its node count;
external arrows bind to that card. Parallel links with the same directed endpoints
and kind are aggregated while retaining every original source index; different
link kinds remain separate. Internal links are hidden in the folded view and stay
in the evidence. Folds and selected segments survive mode switches. Unfolding
restores original geometry and the last node focused in that segment. Keyboard
selection skips hidden cards and includes collapsed summaries. Empty summaries
create no source nodes. The common Canvas graph commands delegate to these same
Memory controls when this tab is active, including snapshot previous/next.
Folding is not a runtime event.

Save As `.rhun-canvas` persists the full evidence in native v7. Reopening resets
view state (snapshot, camera, selection and folds), not evidence. Native v1–v6
still read. Imported Memory and editable drafts/CFG are separate profiles;
Excalidraw export refuses memory evidence because it cannot preserve this model.

## Evidence contract

Root `rhun-memory` v1 fields are exactly `type`, `version`, `binary`, `provenance`,
`allocator`, `entrypoints`, `snapshots`. See
[`rhun-lifecycle.rhun-memory`](../examples/memory/rhun-lifecycle.rhun-memory)
for a complete example. Each snapshot records `id`, `thread`, `pc`, `sp`, `bp`,
`label`, `nodes`, `links`; these are imported declarations, not measurements
performed by rhun. Capture/unwind must be supplied by a separate debugger or
adapter. A snapshot describes one thread; additional threads require separate
snapshot records with their own thread identity. There is no simultaneous
multi-thread replay or cross-thread unwinder in this version.

| Field | Values |
| --- | --- |
| provenance | 0 static, 1 imported declarations, 2 teaching demo |
| allocator | `generic` or `rhun-v1` |
| entry kind | 0 entry, 1 init, 2 main, 3 function candidate |
| node kind | 0 code, 1 call frame instance, 2 mapping, 3 allocation generation, 4 variable/pointer slot |
| node state | 0 declared live, 1 freed/historical, 2 unknown |
| node certainty | 0 declared fact, 1 inferred, 2 candidate, 3 teaching |
| link kind | 0 control, 1 declared live pointer, 2 candidate, 3 dangling pointer, 4 call |

Node fields: `id`, `label`, `address`, `parent`, `thread`, `source`, `kind`, `size`,
`capacity`, `state`, `certainty`. Link fields: `from`, `to`, `kind`. Entry fields:
`id`, `address`, `kind`. IDs are nonempty, unique in their vector and at most
128 bytes. Node parent chains must resolve and be acyclic. Frame thread IDs must
match their snapshot. A live pointer must target a declared live allocation;
a dangling pointer must target a historical allocation. Candidate links retain
uncertainty. Addresses/source/PC/SP/BP use **exact uint64 hex strings**, including
values above 2^53. The existing Radare2 agfj reader still limits numeric source
addresses to 2^53−1; the CFG adapter inherits that limit. Full-width addresses
are supported through the memory import contract. Unknown register values may use `0x0` with an explicit label;
zero is not silently interpreted as measured. Size/capacity are bytes (at most
1 GiB), and address ranges cannot overflow uint64. Rhun capacity is the entire
allocator slot/mapping, including its 16-byte header, not usable payload size.

Allocation IDs identify generations. Reusing an address requires a new ID in
the supplied evidence; rhun does not discover allocation/free events itself.
Historical and current allocations may share addresses, as in demo H1/H2.
No cross-snapshot event recorder verifies identity declarations automatically.

Limits: 3 MiB raw input, 64 entrypoints, 64 snapshots, 256 nodes per snapshot /
4096 total, 1024 links per snapshot / 8192 total; text fields up to 4096 bytes.
Projection of a larger CFG is rejected, not silently truncated. View geometry is
deterministic from ordered records and lane membership; it carries no physical
memory-distance meaning. Static CFG covers only functions analyzed/imported into
the current tab, not every reachable function in the entire binary.

## Captured rhun allocation header

Import Memory Snapshots also accepts this closed five-field object:

```json
{"type":"rhun-heap-header","version":1,"binary":"capture:rhun","address":"0x7f1200001010","header":"02000000000000004000000000000000"}
```

`address` is the payload address. `header` is exactly 16 captured bytes at
`address - 16`, encoded as 32 hex characters, with little-endian uint64 words:
class/mapping size and requested size. Classes 0–11 give slots `32 << class`;
large allocations have a page-aligned mapping size. The decoder checks these
against `requested + 16`, power-of-two rounding through 64 KiB and 4096-byte
page rounding above that. This layout is specific to `src/mem.s`; it is not a
glibc allocator decoder. It does not dereference the address or read a process.

The resulting allocation is always **unknown state / inferred layout**, with
imported provenance. A valid header cannot establish liveness: rhun's free lists
retain header fields after freeing. No free-list traversal or arena enumeration
is implied. The supplied header fixture is synthetic and demonstrates the byte
layout; it is not a capture of this running editor. See [`captured-header.json`](../examples/memory/captured-header.json).

## Review and checks

Select an individual node and choose **Radare2 Memory: Export Selected Review
JSON**, or start a chat, wait until ready and use **Send Selected Evidence to Ready
Chat**. The explicit request includes that node, its direct neighbors, incident
links, snapshot registers, allocator, binary and provenance. It rejects more
than 64 context nodes or 48 KiB and leaves an existing export untouched on failure.
The request asks for source-linked review prose distinguishing facts, candidates
and missing evidence. `allowed` is empty; no memory mutation is accepted from a
review response. Existing Radare2 CFG source-note workflows remain separate.

Control/script diagnostics: `print-memory` exposes the current owned snapshot
and its camera-independent logical 2D `view` (`fold`, card IDs/geometry, typed
links and zero-based numeric `sourceIds`). Source link indices refer to the
snapshot's original ordered `links` array. Individual visual IDs are 1-based
snapshot node indices; segment summaries are 257 code, 258 stack, 259 memory.
These derived IDs are not allocation addresses or persistent source node IDs;
`print-graph` exposes projected nodes, typed edges and folded `sourceIds`.
Memory graphs have an empty `versions` array: replica versions from the separate
distributed-state demo have no memory-analysis meaning.

`sh tests/run.sh` includes memory contracts, native save/reopen, invalid input,
2D/3D identity/camera/folding, static/header adapters, bounded review and ACP chat
transport. `RHUN_REAL_RADARE2=/path/to/r2 python3 tests/memory-adapter.py` enables
actual `/bin/true` static projection. `RHUN_CANVAS_NATIVE_SMOKE=1 python3
tests/canvas-native-smoke.py` enables live Wayland/X11 checks when displays exist.
macOS/Windows execution is unverified; translation checks alone are not runtime
or full platform acceptance. See [phases and acceptance](radare2-memory-plan.md).

## Fork updates

Automatic update checks default to **off**. Built-in release installers,
manual update checks and Issues links point to `dmi3vla/rhun`, never the parent
repository. An existing explicit `updates.check = true` is still honored against
the fork; set it false in Settings to stop checks. Explicit `RHUN_RELEASES_URL`
overrides remain supported for custom mirrors and tests. Restart using the freshly
built binary to use these changes.
