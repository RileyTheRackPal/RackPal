---
type: Design Ruling
title: DR-193 · The validation keys work from every view and go where the fix is
description: >-
  F7, F8 and Shift+F8 were declared global and handled only by the Rack view. The shell now handles them, and F8 switches to the view that can fix the finding and selects its subject. The drawer stays on the Rack view.
tags: [ruling, validation, keymap, f8, shell, dr-193]
timestamp: 2026-09-23T00:00:00Z
ruling_id: DR-193
canon_section: "11.192"
status: built
---

Settled by the user on 2026-09-23, choosing the recommended option of three, each put with a price.
The reasoning is the author's as offered; the user accepted it and added none of their own.

# What was ruled

| The finding points at | `F8` goes to |
|---|---|
| A device in a rack, or a rack | Rack, with that rack showing |
| A device not in a rack, or a cable | Schematic |
| A floorplan | Site, with that plan open |
| A net or a circuit | Rack, saying there is no single item to show |

One cursor over `evaluateDocument`'s own order, wrapping at both ends. `F7` re-checks from any view.
**The drawer stays on the Rack view**: putting it under every view was offered and not chosen.

# How it was found

Writing the user guide, which repeated the old guide's claim that the keys work anywhere. The keymap
declared them global and the generated reference printed that, and only one view's `Actions` map
held a handler. A declared scope is a claim; the handler is the fact.
