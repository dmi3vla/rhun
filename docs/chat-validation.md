# Chat validation and remaining gates

Validation date: 2026-10-07. Local repository, no Git remotes. The implementation
has reached phase 8's Linux validation milestone. This is not a claim that every
Claudian feature or every platform acceptance gate is complete.

## Providers

| Provider | Adapter | Deterministic coverage | Installed CLI workflow |
| --- | --- | --- | --- |
| Codex | Native app-server stdio | 19 scenarios, plus shared persistence/context/edit/hardening | 0.160.1: actual short reply, process restart and native resume passed |
| OpenCode | ACP stdio | 12 scenarios, plus shared persistence/context | 2.0.24: actual short reply, process restart and native resume passed |
| Grok | Shared ACP, x.ai aliases and mirror filtering | Common permissions/models/cancel scenarios | CLI absent; real-version compatibility unverified |
| Pi | Native JSONL RPC | Streaming/models/resume/dialogs/tool results/cancellation/correlation | Temporary official CLI 1.0.4: create + native resume passed without a model turn |
| Claude | Optional per user direction | Existing history reader only | Interactive adapter not enabled |

The Grok/Pi test module has 27 scenarios. Pi requires a version exposing
`agent_settled`; intermediate `agent_end` never marks the session idle. Built-in
A temporary official Pi 1.0.4 npm installation was used for the native
initialization/resume check; no global Pi installation was made. Built-in
Pi tools are restricted to `read,grep,find,ls`. Provider extensions retain their
own policy; rhun does not implement a general Pi tool approval hook.

Real smoke prompts requested only `RHUN_SMOKE_OK`, in an empty temporary project,
without tools or file access. No credential files were read by the probes.
Codex cannot resume a never-used thread after its process exits because no native
rollout exists. Only a locally empty chat may recover with a new native ID and its
existing draft. Conversations containing user/assistant messages never fall back
to a fresh thread on resume errors.

## Platforms

| Platform | Result | Outstanding gate |
| --- | --- | --- |
| Linux x86-64 | Native build, headless UI regression tests and installed CLI workflows | Remaining feature parity below |
| macOS / AArch64 | Translation checks for affected assembly sources | Native assembler/linker, AppKit execution and real CLI tests require a macOS host |
| Windows x64 | Interactive transport returns unsupported (`ENOSYS`) | Implement nonblocking native transport, then build and execute the same acceptance suite |

The Linux host has no `llvm-mc`/`lld-link` toolchain and no native Windows/macOS
runtime. Translation is not presented as native execution or a platform release.

## Regression inventory

The registered transport/chat modules contain 100 deterministic scenarios:
5 transport, 19 Codex, 12 OpenCode, 10 persistence, 10 context, 6 editing,
27 additional providers and 11 hardening. History-browser, palette, settings,
editor, Git, files, resource/fault and other application suites remain registered
in `tests/run.sh`.

Final full-suite result: PASS (`tests/run.sh`, exit 0). The history suite has
one expected macOS-only skip on Linux. The final palette-focus change also passed
all 10 palette scenarios and the context cancellation regression.

```sh
./tests/run.sh
python3 tools/probe-codex-chat.py
python3 tools/probe-opencode-chat.py --new-session
python3 tools/probe-live-chat.py --provider codex
python3 tools/probe-live-chat.py --provider opencode
# When Pi is installed, or supply its executable with --cli:
python3 tools/probe-live-chat.py --provider pi
# Explicitly sends one small real model prompt, then verifies native resume:
python3 tools/probe-live-chat.py --provider codex --prompt-turn
python3 tools/probe-live-chat.py --provider opencode --prompt-turn
```

Visual checks covered assistant headings/fenced code and both normal/compact
composers. The transcript retains Markdown markers. Editing uses an explicit
read-only original/replacement comparison with stale-buffer protection and one
Undo group; it does not auto-apply a model answer or save the source file.

## Remaining parity and acceptance work

- Native Windows interactive transport and native macOS runtime validation.
- Installed Grok execution, Pi real model/extension workflows and additional
  provider-version compatibility; OpenCode v1 installed-version testing.
- Rich inline Markdown, links/tables, word-level edit diff and editor-bottom Zen
  placement. Current compact mode stays inside the Agents panel.
- User/global prompt and skill catalogs, native skill blocks and provider command
  discovery. Current `/` and `$` pick project templates/SKILL.md as text context.
- OpenCode HTTP-specific question forms and secret/masked answers. Unknown
  interactions are explicitly rejected. Codex supports plain native questions;
  Pi supports confirmation, text and bounded native-option selection.
- Native MCP tool/elicitation acceptance tests. MCP configuration stays with the
  installed provider CLI; no separate MCP settings UI has been implemented.

These gates remain visible rather than being counted as completed phases or
full Claudian parity. Linux implementation milestones have a commit per phase.
