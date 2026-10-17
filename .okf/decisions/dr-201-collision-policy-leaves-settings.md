---
type: Design Ruling
title: DR-201 · The collision policy leaves Project Settings, because it governs nothing
description: >-
  Project Settings offered a collision policy that no code read: allocation cannot collide, and a
  typed duplicate is not checked against it. The row is removed; the stored value stays on the
  wire untouched, so existing projects save back byte for byte.
tags: [ruling, settings, designators, cr-045, dr-201]
timestamp: 2026-09-29T00:00:00Z
ruling_id: DR-201
canon_section: "11.200"
status: built
---

Settled by the user on 2026-09-29, choosing the recommended option of three, each put with a price.
The reasoning is the author's as offered; the user accepted it and added none of their own.

# What was ruled

The collision policy row leaves Project Settings. `ProjectSettings.collisionPolicy` stays in the model
and in the file, read and written as before (CR-117), so nothing migrates. `resolveDesignatorCollision`,
its only reader and itself uncalled, is deleted. A typed duplicate designator is unchanged: allowed at
entry, flagged by validation. Wiring a policy to typed entry was offered and not chosen.

# How it was found

`#945` triaged the public declarations nothing in `lib/` calls. Most were leftovers or test handles.
This one was the only reader of a setting the user could change, so its having no caller meant the
setting did nothing at all. The same triage found `allocateStructureDesignator` uncalled while two
sites named every new Structure `'STR-1'`, the literal its own doc comment warned against: an unused
helper can be the evidence that a rule is not being followed, not only that code is dead.
