---
type: Design Ruling
title: DR-013 — deleting a wired device cascades, after a warning that counts the cost
description: A TODO that was inert until DR-011.1 made it live — removing a device left Links naming ports that no longer exist. Cascade, with a confirmation that states the count, and an undo that puts the cables back.
tags: [ruling, m2, delete, undo, schedule, dr-013]
timestamp: 2026-08-01T00:00:00Z
ruling_id: DR-013
canon_section: "11.13"
status: ruled
---

Settled by the user on 2026-08-01, closing the one item on the post-M3 review
that needed a decision rather than a patch.

# The defect, and why it was harmless until it was not

`RemoveDeviceCommand.apply` carries a `TODO(post-M0)`: it removes the
`DeviceInstance` and *"does not yet decrement any TemplateSnapshot refcount, nor
clean up orphaned `Port`/`Link` references to this device"*.

**Nothing in the application ever wrote `doc.ports`** — the finding
[DR-011](/decisions/dr-011-connect-gesture.md) opens with — so for every
milestone up to M2-F there were no ports to orphan and no links to strand. §11.11.1
makes the connect command materialise ports inside `apply()`. From that commit
the note stopped describing deferred work and started describing a live defect:
delete a wired device and the schedule prints a row citing a device that is not
in the document.

That is the one thing **CR-017** forbids: *the gesture may hesitate; the
document may not lie.*

# The ruling

**Cascade.** Removing a device removes every `Link` terminating on it and its
materialised `Port`s, in ONE undoable command.

**With a confirmation that names the count**, in the shape docs/04 §4.1's
shrink dialog already uses. This is the second place in the product where one
gesture destroys work the user cannot see all of, and
[G1](/getting-started.md) makes the cost specific: the schedule is the
deliverable, so a delete that silently drops a dozen rows off it is the
expensive failure. A bare "Are you sure?" does not discharge the clause. A
device carrying nothing prompts not at all.

**And an undo that restores the cables with the same ids**, not just the
device — the discipline `ConnectPortsCommand` already holds for the ports it
materialises.

# The option that was recommended and rejected

**Demote the far end to `OpenEndpoint`.** AC-018 models "a cable whose far end
is unbound" as first-class, `endpoint_resolution.dart` already returns null for
it, and demotion would have kept every row and every `W` number on the pull
sheet.

The rejection is not a disagreement about the model. It is that demotion also
keeps a pull sheet full of half-cables nobody asked for, on a document the user
believes they simplified — and M5's validation, where *"this run ends
nowhere"* becomes a visible finding, does not exist yet. **A cable to a device
that has been deleted is not a design intent; it is debris.**

**Refusal** — *"unwire it first"* — was also rejected. It would be the only
place in the product where an ordinary edit is blocked by a condition the user
can see and disagree with, and CR-017 reserves refusal for the five tier-1
topology rules, whose escape docs/02 §5 gives as *"None. There is nothing to
escape to."* Wanting a device gone is not that.

# What it leaves unruled

**The `TemplateSnapshot` refcount half of the same TODO.** `RemoveDeviceCommand`
still does not drop a snapshot nothing references any more. An unreferenced
snapshot is inert and AC-006's lazy design means files already carry snapshots
for devices that were never placed, so this is file size rather than
correctness — deferred, not forgotten.

# Citations

[1] canonical-decisions.md §11.13 (`docs/canonical-decisions.md`)
[2] `packages/rackmate_core/lib/src/commands/device_commands.dart` — the TODO
[3] `packages/rackmate_core/lib/src/derived/endpoint_resolution.dart` — the five
    situations a null rack answer already covers, including "a port whose device
    is missing"
[4] docs/04-rack-editor.md §4.1 — the shrink dialog, the shape §11.13.2 reuses
