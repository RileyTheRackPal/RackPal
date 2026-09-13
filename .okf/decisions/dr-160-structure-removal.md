---
type: Design Ruling
title: DR-160 — Removing a Structure body or an outlet, and what each takes with it
description: >-
  RemoveOutletCommand and RemoveStructureCommand shipped at M3-A/1 with real
  reverts and no caller, so the Structured Wiring tab could create a panel and a
  wall plate and take back neither. Both are reachable now, behind confirmations
  counting plates, cables and pins. The cascade is asymmetric: a plate takes its
  home runs because nothing in the product can re-home one, and a panel takes its
  plates because they name it in a field that is not nullable.
tags: [ruling, structure, outlets, deletion, undo, confirmation, dr-160, dr-013, dr-021, dr-158, cr-016]
timestamp: 2026-09-13T00:00:00Z
ruling_id: DR-160
canon_section: "11.159"
status: ruled
---

Settled by the user on 2026-09-13, closing `#877`. Found by `#872`'s reachability
gate, which is now the source of six findings in five days.

`RemoveOutletCommand` and `RemoveStructureCommand` were declared in
`structure_commands.dart` with real reverts and eight and nine test constructions
between them, and **nothing in `lib/` constructed either.** Add was wired for
both, so a wrong drop or a duplicate panel was permanent for the life of the
project unless somebody noticed in time to press `Ctrl+Z`.

# The half that was a decision, and the half that was not

**The plate's cascade was the user's to make.** `RemoveOutletCommand`'s own
comment argues for leaving the cables and asks for a `Transaction` from any
caller that means both. Both halves of that stand: this supplies the caller, and
the confirmation is what makes the larger edit legitimate rather than silent.

Blanking the box was the tempting alternative and it is a trap.
`StructureOrigin.outletId` is nullable and DR-046 gives the null a ruled meaning,
so the document would say something true. It would also be **unrepairable**:
`StructureOriginField` lists seven editable properties and `outletId` is not one
of them, `AddHomeRunCommand` sets it at creation, and no surface in the product
can move a drop onto a different plate. The cable would sit on the Structure
table with an empty box column forever.

**The panel's cascade had no decision in it.** `Outlet.structureBodyId` and
`StructureOrigin.structureBodyId` are both non-nullable and `final`, so neither
an outlet nor a home run can be repaired to point at a surviving panel or at
none. Leaving them behind does not produce a true document; it produces two
classes of entity naming a body that is not there.

So the cascade is asymmetric, and §11.159.4 exists to say which clause a later
reader may reopen: make `outletId` editable and §11.159.2 is back open, and
§11.159.3 is not.

# What the confirmations count

Plates, cables and **pins**, in three units and never summed. `Outlet.planPin` is
walked-site work: somebody stood in the room and dotted the floorplan,
`plan_length.dart` derives a cable length from that dot, and it travels inside
the outlet when the outlet goes.

A bare plate is removed with no prompt (DR-013 §11.13.2). **An empty panel is
still asked about**, which is where the two dialogs part: it is the container the
tab is named for, and re-creating one is a different order of work from re-typing
a drop.

# The plan is taken twice, and that bend was measured

`delete_location_dialog.dart`'s rule is that the number the person answers and
the set the edit removes are ONE object. The edit re-plans after the await, which
technically breaks it, and `#877` measured why that is still right: **`Ctrl+Z`
reaches `undoFromShell` from inside a modal route**, because DR-159 put undo on
`KeyScope.global` with its `Shortcuts` above the `Navigator`. Probed on the plate
dialog, the document went from two links to three with the confirmation still up
and still saying one.

So the stale count is the cost, and it is the smaller one: running the answered
plan would leave the restored drop naming a plate that is gone. A dialog that
dismissed itself when the document moved would be better than both and is not
ruled here.

# Where the controls live

A **trash icon on the plate's row in the left rail**, the shape the user chose
for DR-158's template removal the day before, and an **overflow menu in the
editor header** for the panel.

A trash icon beside the body picker was refused on a defect found while writing
the question: `_EditorHeader` builds that picker only when
`doc.structures.length > 1`, so a one-panel project would have had no control at
all, and a one-panel project is both the ordinary case and exactly where somebody
wants a wrongly-created panel gone.

# Related

* [A template is removed as a whole](dr-158-a-template-is-removed-as-a-whole.md)
  is the plan-plus-transaction-plus-dialog shape this follows, one ticket older.
* [Undo is document-global](dr-159-undo-is-document-global.md) is what makes the
  re-plan above reachable.
* [A surface tested alone has never met its
  host](/practices/a-surface-tested-alone-has-no-host.md) is what building this
  found on the way.
