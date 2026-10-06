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
items; draft 64 KiB; text context 32 KiB/file; images 1 MiB. Other objects retain
local file references so the provider can inspect them with its own tools.
Links are inserted without fetching their contents. Media references are not a
claim of native audio/video model input support. External desktop drag/drop and
Windows/macOS binary clipboard integration are separate follow-ups; this scope
implements drag/drop from rhun's own tree and Linux clipboard objects.
