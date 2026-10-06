# Interactive agents in rhun

Implementation baseline: 2026-10-07. Each completed phase gets a separate local
Git commit. The upstream Git remote has been removed; existing history is kept.

## Architecture and scope

The application, provider adapters, transport and UI remain assembly. Installed
agent CLIs are external runtimes; no application-side JavaScript SDK is required.
The existing Agents session reader must remain usable throughout development.

Providers targeted: Codex and OpenCode first; Grok Build and Pi later. Claude Code
is optional, per the user's updated priority. Features are capability-driven; changing provider
must never silently continue a conversation under a different runtime.

Sources:
- https://github.com/YishenTu/claudian (chat, context, inline edits and providers)
- https://learn.chatgpt.com/docs/app-server (Codex protocol)
- https://code.claude.com/docs/en/cli-reference (Claude CLI flags)
- https://github.com/YishenTu/claudian/blob/main/src/providers/opencode/execution/OpencodeSessionKernel.ts (OpenCode version-specific transport)

## Protocol decisions

| Provider | Proposed transport | Local validation | Remaining validation |
| --- | --- | --- | --- |
| Codex | app-server, newline-delimited JSON RPC over stdio | Installed 0.160.1; handshake probe | Turns, approvals, resume, cancellation |
| Claude | CLI stream-json input/output | CLI absent | Control/permission protocol must be verified before enabling tools |
| Grok Build | ACP | CLI absent | Version, handshake and capability matrix |
| OpenCode | ACP stdio, verified against installed v2 | v2.0.24 initialize and session/new passed | Real model turns, saved-session resume, model selection and native forms |
| Pi | RPC | CLI absent | Version, handshake and capability matrix |

Codex initialization precedes initialized, thread/start and turn/start. Store the
returned thread ID, use item/agentMessage/delta for streaming, and distinguish
completed, interrupted and failed turns. Do not use exec as the interactive
transport. Auth stays with the CLI; rhun does not read or copy credential files.

Claude stream-json flags are documented, but that alone does not establish the
permission handshake. Do not ship a bypass-permissions fallback to cover a
missing interactive permission implementation.

## Phases and acceptance gates

0. **Specification and probes.** Record protocols and local availability. Probe
   Codex initialization without creating a turn or sending project content.
   Other providers remain explicitly unverified until installed.
1. **Transport foundation.** Bounded queues, partial writes, separate stderr,
   newline framing, EOF/error handling and child cleanup. Test fragmentation,
   backpressure, closed input and oversized frames. Unix first; native Windows
   transport and macOS runtime validation are explicit follow-up gates.
2. **Interactive MVP.** New chat, provider discovery, multiline composer, send,
   streamed response, follow-up and stop. First enable Codex, then OpenCode v2.
   Keep the existing history browser. GUI and deterministic mock CLI tests.
3. **Interactions.** Permission cards, questions, model selection, turn states.
   Unknown requests receive an explicit unsupported response, never an approval.
4. **Persistence.** Tabs, native session resume, local metadata, drafts, crash
   recovery and deduplication between native history and live events.
5. **Context and rendering.** File/selection attachments, @mentions, images where
   supported, Markdown, code blocks, slash commands, skills and native MCP.
6. **Editing workflows.** Inline changes with diff/undo, project diffs, side chat,
   compact composer. Detect stale buffers before applying edits.
7. **Other providers.** Shared ACP, Grok adapter and Pi RPC; optional Claude and
   OpenCode v1 compatibility. Run the same
   acceptance scenarios for each provider.
8. **Release validation.** Linux, Windows and macOS; real CLI workflows, resource
   limits, compatibility documentation and regression suite.

## Assembly invariants

- JSON arena pointers expire on the next json_parse. Copy all retained strings.
- Child argv is built as an array; prompts must never be shell source text.
- Keep stdin, protocol stdout and diagnostic stderr separate.
- UI ticks perform bounded I/O work. No blocking writes or waits in the UI path.
- Queues and individual protocol records have documented limits.
- Project changes close owned sessions before releasing project strings.
- Continue external sessions only through the provider's native resume protocol.

## Progress

- Phase 0: specification recorded; Codex 0.160.1 initialize/initialized probe
  passed without a model turn. Uninstalled provider probes remain explicit gates.
- Phase 1: Unix nonblocking transport implemented; 5 deterministic transport
  tests pass. Windows intentionally returns ENOSYS rather than blocking the UI.
  AArch64 translation passes; native macOS execution remains unverified.
- Phase 2: initial Codex chat implemented on Linux, with composer, streamed text,
  follow-up turns and stop/reconnect via a new conversation. Eight mock-runtime
  UI/protocol tests passed at the initial milestone. OpenCode is next; Claude is optional.
- Phase 3, Codex milestone: explicit command/file approvals, queued requests,
  sequential questions with a separate draft, native turn interruption, optional
  executable/model/effort settings, model catalog and recoverable turn errors.
  Seventeen mock-runtime tests cover these interactions. Secret input, tool/diff
  rendering and equivalent OpenCode behavior remain acceptance gates.
- OpenCode MVP milestone: owned `opencode acp` runtime; explicit new-chat
  command; session creation, fragmented text streaming, follow-up, native cancel,
  once-only permission options and queued cancellation outcomes. Model catalog
  handles both legacy models and configOptions with grouped values. Eleven mock CLI
  scenarios pass. Installed v2.0.24 initialize/session/new probes pass without a
  model turn. Codex regression: 17 tests; settings: 11 tests. Windows transport,
  native macOS execution, paid model turns, native question forms, model selection
  and persistence remain unverified or pending.
- Phases 4–8: pending. This is not yet full Claudian parity.
- Updated next-provider sequence: OpenCode v2 runtime lifecycle and HTTP/event
  transport was the initial candidate. The installed v2.0.24 also supports ACP;
  use its verified ACP stdio endpoint for the first adapter, then add native
  forms and model selection. Reuse the existing assembly composer and owned
  interaction queue; preserve Codex behavior. Claudian selects HTTP for OpenCode
  v2 and ACP for v1. rhun currently uses the locally verified v2 ACP endpoint;
  HTTP-specific features are not yet reproduced.
- Local Git author was resolved through gh: dmi3vla, with GitHub's ID-based
  noreply address. No remote is configured. Specification, Unix transport and
  the initial Codex interface are recorded as separate commits; remaining gates
  above must be completed before declaring the full phases finished.
