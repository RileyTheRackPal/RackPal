---
type: Design Ruling
title: DR-172 · The undo depth is a per-machine preference
description: >-
  Canon §10.12(a) made the undo depth a setting in August, and nothing could set it: both stacks were
  built at a default of 200 and the oldest step dropped silently. It is now a per-machine preference
  in Edit > Preferences, 50 to 1000, applied at once, with a full-history notice once per document.
tags: [ruling, undo, preferences, ac-058, scope-addition, dr-172]
timestamp: 2026-09-15T00:00:00Z
ruling_id: DR-172
canon_section: "11.171"
status: built
---

Ruled by the user on 2026-09-15 and built as `#560`.

# A setting nothing could set

Canon §10.12(a) answered *"keep 200, and make it a setting"* on 2026-08-03. The 200 was a constructor
default that neither the document's stack nor the Device Builder's ever passed, and the oldest entry
dropped with no signal, which AC-058 D5 had ruled out.

# What was ruled

- **Per machine**, in `prefs.json`, edited in a new **Edit > Preferences**. File > Project settings
  keeps what travels in the file.
- **A whole number from 50 to 1000**, default 200. A hand-edited value outside the range reads as
  absent, not clamped.
- **Immediately**, on the open document and an open builder window; lowering it drops the oldest steps
  and says how many.
- **The full notice once per document**, because the status line never clears itself.
- **One setting for both stacks.**

# What building it found

- The field commits on Enter or Close, never on clicking away, because a half-typed depth would drop
  history.
- A resize goes through the controller, so `editsSinceSave` stays honest when the save point ages out.
- The first document is built after the preferences load, not before.

# Where it lives

- `packages/rackpal_core/lib/src/commands/undo_stack.dart`: the bounds, `resize`, `droppedCount`.
- `apps/rackpal/lib/src/session/document_session.dart`: the notice and `applyUndoDepth`.
- `packages/rackpal_ui/lib/src/settings/preferences_dialog.dart`: the dialog.

A §8.3 scope addition: the app's first per-machine settings surface.
