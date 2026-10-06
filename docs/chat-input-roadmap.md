# Chat drag/drop and clipboard

Implementation phases, each recorded in a local commit:

0. Define behavior and limits (this document).
1. Shared attachment ingestion: absolute paths, directories as references, bounded
   UTF-8 text context, PNG/JPEG native image markers, binary/audio/video path
   references. URI lists decode local file URLs; web links remain literal text.
2. Internal project-tree drag/drop: copied selection ownership, Ctrl toggles,
   Shift ranges, threshold before drag, release into the Agents panel, visible
   target feedback. Single file click retains existing opening behavior. Tree
   refresh clears stale selection; no files are moved on disk.
3. Linux clipboard MIME negotiation: prefer file URI lists and PNG/JPEG in chat,
   otherwise UTF-8 text. Private persistent image copies survive chat restart.
   Clipboard objects are routed to attachments, question replies remain text.
4. Regression validation, user guide, and honest platform/provider limits.

Files are added to the unsent draft, never sent automatically. Up to 64 selected
items; draft 64 KiB; text context 32 KiB/file; up to eight images / 1 MiB total. Other objects retain
local file references so the provider can inspect them with its own tools.
Links are inserted without fetching their contents. Media references are not a
claim of native audio/video model input support. External desktop drag/drop and
Windows/macOS binary clipboard integration are separate follow-ups; this scope
implements drag/drop from rhun's own tree and Linux clipboard objects.


## Completion and validation (2026-10-07)

- Phase 0: `5f32148`, specification.
- Phase 1: `83f9051`, shared path and URI ingestion; atomic Linux executable replacement.
- Phase 2: `1ed5884`, tree selection and internal drag/drop.
- Phase 3: `c27fd5c`, Linux typed clipboard, bounded INCR and multiple images.
- Phase 4: regression registration, final UI polish and this acceptance record.

New coverage: six real pointer scenarios, thirteen typed clipboard scenarios, and
six real X11 clipboard scenarios on an isolated Xvfb display. X11 coverage uses
Ctrl+V through the ordinary application event loop: URI and GNOME file preference over text,
PNG, JPEG, UTF-8 and a valid 600x600 PNG through incremental transfer (larger than
the previous X11 receive buffer). Existing ten chat-context scenarios pass.
The Xvfb package is unpacked only under `/tmp`, not installed globally, and its
clipboard/display are isolated from the user's desktop.

Wayland offer negotiation, exact offered MIME selection, nonblocking bounded
reads and five-second inactivity cleanup are implemented and assemble on Linux.
An actual Wayland compositor clipboard test remains unverified. macOS/Windows
retain text clipboard support; binary/object MIME handling is Linux-specific.

Protocol references: [X11 core protocol](https://www.x.org/releases/X11R7.7/doc/xproto/x11protocol.html),
[Wayland data offers](https://wayland.freedesktop.org/docs/html/apa.html#protocol-spec-wl_data_offer).


Final acceptance: all registered regression groups passed across the long run
and focused completion runs. The long `tests/run.sh` process exited 143 during
the stress group; stress, file-fault injection and the UI script suite were then
rerun independently and each exited 0. Earlier groups had no failures. Final
focused runs passed all 13 clipboard, 6 X11 clipboard, 6 pointer and 10 existing
context cases. The textarea assembly check also passed. Seven changed shared
assembly sources translated to AArch64; this is not native macOS execution.
The drag target was visually inspected with a headless screenshot.

Phase-4 polish preserves tabs when pasting code, accounts for replaced selection
bytes in the draft limit, supports literal HTTP(S) URI-list links and GNOME
`copy`/`cut` file lists, and draws the target outline without covering the chat.
