---
type: Design Ruling
title: DR-141 — A pin arms one drop at a time, and the fast path is the strip rather than the table
description: docs/15 gives the fast path as "click a drop, then click the plan" and stops there. One arm, one pin, and the mode stays on with nothing armed. Auto-advance was declined on the failure mode, not the ergonomics. And a gate then moved the chapter boundary, because the drop-table producer is unreachable until the Plan view has a home.
tags: [ruling, plan-view, pins, mode, ux, dr-141, dr-140, plan-e, cr-105]
timestamp: 2026-09-08T00:00:00Z
ruling_id: DR-141
canon_section: "11.140"
status: ruled
---

Settled by the user on 2026-09-08, on a question `PLAN-E/3`'s brief leaves open
and which decides whether that chapter is worth building.

# The unspecified moment

docs/15 §6: *"Click an outlet in the Structure editor's drop table, then click
the plan. Pins that outlet. This is the fast path for a 60-drop rough-in."*
**What happens after that click is not stated**, and sixty drops means sixty
pins.

**The ruling: one arm, one pin, and the mode stays on with nothing armed.** The
chip stays up saying so and `Esc` dismisses it. Nothing is ever armed that the
user did not explicitly choose.

# Auto-advance was declined for the failure mode

The more obvious design: pin, advance to the next unpinned outlet in table
order, chip reads *"Next: D-014"*, sixty drops in sixty clicks with no view
change.

> A mis-click pins the wrong drop **and** advances the queue, so the recovery is
> an undo plus a re-arm, and the person going fast is exactly the person who
> will not notice which subject the chip had moved to. **An auto-advancing queue
> is a machine for producing confidently wrong pins on a drawing an installer
> will trust.**

# The cost is real and is paid by another ruling

Two acts per drop. Across a tab boundary this **is** the sixty round trips
`PLAN-E/3`'s own brief cites AC-048 and the as-built tally surface as already
refusing, and the chapter's claim to be *"the reason the feature is usable"*
would have been false.

It is not, because [DR-140](dr-140-the-rack-is-pinned-from-the-unpinned-strip.md)
already put the picker in the plan view. The unpinned strip is right there, so
the loop is **pick from the strip, click the plan**: two acts, no view change,
every pin deliberate, and the strip's shrinking count is the progress indicator
an auto-advancing chip would have had to invent.

**So `PLAN-E/4`'s strip is THE pinning workflow and `PLAN-E/3` is the secondary
entry point**, for somebody already in the Structure editor. The brief's own
framing is superseded, and the chapter shrinks: no queue, no ordering rule, no
next-subject indicator.

# A mode is not a request

`SchematicRevealController` is the existing cross-tab mechanism (CR-105's
*"clicking it switches to the schematic with that device selected"*) and it is
**one-shot**: `take()` empties it so one click reveals once. This outlives the
pin, because *"on with nothing armed"* is what keeps the chip telling the user
where to go, and a mode that ended silently after each pin would be
indistinguishable from one that had failed.

Mutation-tested by ending the mode inside `pinned()`, which is exactly the
one-shot design: **five cases fail**. A suite that only ever pinned once could
not have told the two apart.

# A gate then moved the chapter boundary

The drop table's half was built: `StructureEditorActions.onPinOnPlan`, threaded
to a row, opened by a secondary tap, two cases green.
[actions-have-callers](/gates/callbacks-have-callers.md) refused it, because
**nothing in `lib/` supplies one**.

That gate exists for M3-H/5, where `OutletsActions.onRemoveGang` had a command,
an app-side implementation, tests for both and no caller. It had just caught the
same shape again.

**The cheat was available and is worth naming.** The call site was
`pin(row.linkId)` through a local alias, so the scanner's `\.name\s*\(` never
matched; rewording it until the regex matched would have satisfied the letter
and left the gesture unreachable. A menu item that arms a mode whose only
surface is a view the shell does not mount is a control that does nothing, which
is DR-091's rule one level down. **The producer moves to `PLAN-E/5`.**

# The general point, which is about the decomposition

`PLAN-E/2`, `/3` and `/4` all build behaviour for a view that `PLAN-E/5` mounts,
so **each ends with code the product cannot reach**. That is legal and each
chapter says so in its own files. What it means is that **`PLAN-E/5` is not a
small wiring chapter**: it is the one that makes three chapters' work true, and
it should be scheduled as that rather than as a tab and a keymap.

# Not ruled

The chip's appearance or wording, which is UI/UX and is the user's. Whether the
strip is orderable. The tab switch itself, which arrives with `PLAN-E/5`.
