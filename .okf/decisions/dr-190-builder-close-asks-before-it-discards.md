---
type: Design Ruling
title: DR-190 · Close in the Device Builder asks before it discards
description: >-
  Close on a dirty template draft shows the project's own Save / Don't Save / Cancel prompt instead of silently destroying the in-memory draft. DR-099's refusal stands for its own case.
tags: [ruling, builder, undo, unsaved, dr-190, dr-099]
timestamp: 2026-09-23T00:00:00Z
ruling_id: DR-190
canon_section: "11.189"
status: built
---

Settled by the user on 2026-09-23, choosing the recommended option of three, each put with a price.
The reasoning is the author's as offered; the user accepted it and added none of their own.

# What was ruled

- **A dirty draft gets `UnsavedChangesDialog`**, the prompt docs/03 §9.5 already requires for closing
  a project, with its four rules: `Save` default, `Esc` is Cancel, no key reaches `Don't Save`, a
  click outside is not an answer. A clean draft closes with no prompt.
- **`Save` obeys AC-049.** A draft with no name, prefix or height saves nothing, stays open, and says
  why.

# Why DR-099 is not contradicted

[DR-099](/decisions/dr-099-door-2-moves-the-device-it-was-opened-from.md) §11.98.4 refuses rather than prompts when a draft
would be REPLACED on the way to another template, because a discard prompt met on the way to
something else is dismissed by reflex. Pressing Close is not on the way to anything: leaving is the
act, so the standard question is the honest one.

# How it was found

Writing the user guide (`#924`). The shell's own comment called a discard-and-return route *"a gap
rather than a decision"*, and `Close` was that route with no guard. See
[a modelled field is not a reachable one](/practices/a-modelled-field-is-not-a-reachable-one.md) for
the general shape: the comment described the state of the code one change ago.
