# Native Visual Diff implementation

The comparison is read-only. Base means the supplied analysis, not complete truth
about an ELF. Unsupported properties remain unknown. Model confidence is metadata,
never correctness. No source, registers, target process or Memory evidence is edited.

## Phases and acceptance

0. Contract: closed bounded Agent Claims IR, scoped completeness, fingerprint and
snapshot binding; source versus assertion versus confidence remain distinct.
Commit: docs(diff): define scoped native claims and acceptance phases.
1. Core: native owned adapter/parser/comparator and JSON report. Wrong/stale input
is atomic; complete answers alone produce missing nodes/edges. Numeric uint64
addresses are exact; memory generation identity is the node ID in one snapshot.
Commit: feat(diff): compare bounded CFG and memory claims natively.
2. 2D: read-only contours, ghost cards, navigation, inspector, structure/claims
filters, report export. Toggling never changes saved evidence.
Commit: feat(diff): render native visual discrepancies and source navigation.
3. Memory/3D: overlay projects onto existing nodes, respects folded segments;
phantoms have a separate labelled screen layer. Snapshot changes invalidate Diff.
Commit: feat(diff): share discrepancy identities across memory projections.
4. Chat: export agent contract and explicitly import a chosen structured response;
ordinary prose is rejected. No automatic acceptance or memory mutation.
Commit: feat(diff): connect explicit structured agent responses to comparison.
5. Properties: only known facts are compared; code allocation sizes and unknown
liveness stay unknown; confidence is displayed separately. Negative and lifecycle
cases, bounded parser/lifetime tests.
Commit: test(diff): verify uncertainty scope and native overlay lifecycles.
6. Supplied rhun ELF: reproducible good/bad claims, reports and native screenshots;
Russian walkthrough, regression checks and platform limits.
Commit: docs(diff): demonstrate supplied binary comparison and controls.

## Agent Claims v1

Root exact fields: type="rhun-agent-claims", version=1, base (source binding),
profile (0 CFG / 1 Memory), snapshot (empty for CFG), complete (0 partial / 1 full
within scope), scope (unique existing node IDs), nodes, links.
Node exact fields: id,address,label,kind,size,capacity,state,confidence.
Addresses are 0x uint64 strings. kind/size/capacity/state = -1 means no assertion.
confidence = -1 (not supplied) or 0..100, with no bearing on comparison status.
Link exact fields: from,to,kind. CFG kind 0 jump / 1 fall-through; Memory kind uses
rhun-memory v1. Endpoint IDs resolve to scope or explicitly proposed ghost nodes.
An empty scope is rejected. A node ID outside scope must be new in Base.
Caps: 1 MiB import, 512 nodes/scope IDs, 1024 links; strings <=4096, IDs <=128.
Base is a non-security source binding over native serialized content and snapshot;
revision is also checked during the live comparison. Reports explain that it is
not an ELF authenticity hash. Scope is immutable for a loaded comparison.

Statuses: 0 structural match, 1 unsupported/ghost, 2 contradiction, 3 omitted in a
complete scoped answer, 4 insufficient evidence. Unknown edges and indirect targets
are not automatically classified as proven model hallucinations. No semantic
assembly equivalence or automatic Markdown-to-proof extraction is promised.

## Implementation acceptance

Phases 0–5 are committed as a1bac12, 76aa40e, 1f0cf1d, 39d07a2,
c242800 and d653124. Phase 6 adds the supplied-ELF workshop, reproducible
synthetic claims, native screenshots and the Russian control guide.

The demonstration checks the original ELF SHA256 and leaves it and source
scenes unchanged. CFG main reports [41,1,2,5,1]; static mem_alloc Memory reports
[12,1,2,4,1]. Correct structured answers match the supplied graph. Live
Wayland/X11 checks cover both profiles, navigation, hiding, Memory 3D and
folding without changed result identities. Twelve structural tests, two ACP
chat tests and 100 allocation-lifecycle cycles cover the native implementation.

The expanded palette inventory is tested in bounded batches without dropping
commands. The idle stress assertion still requires zero frames over 1100 ms,
after 3000 ms of settling deferred UI work. ARM64 translation passes; macOS
and Windows runtime acceptance remains outstanding.

The complete `sh tests/run.sh` regression suite passed on Linux x86-64 after
these acceptance adjustments (platform-specific skips are reported by the suite).
