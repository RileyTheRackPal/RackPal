---
type: Design Ruling
title: DR-103 — Placing a library row copies the template into the project, and the palette says which shelf every row came from
description: >-
  DR-102 put library rows in the palette and never ruled what a double-click
  does; the census found that `buildPlaceFromCatalogCommand` resolves out of
  `doc.templates`, so every library row would list with a badge and then refuse.
  Copy-on-place is AC-041's standing promise, not a new idea. Six clauses:
  placement, ordering, the id already taken, once-per-template announcement,
  category-with-a-badge, and a disabled chip for a library that will not open.
tags: [ruling, palette, library, rmda, copy-on-place, ac-041, ac-042, dr-102, dr-101, dr-077, m4]
timestamp: 2026-08-30T00:00:00Z
ruling_id: DR-103
canon_section: "11.102"
status: built
---

# DR-103 · A library row copies itself in

Board `#242`, under `#170` (M4-N). Settled by the user 2026-08-30, before any
code, on the precedent this milestone set five times.

## The finding: DR-102's palette would list rows it cannot place

`buildPlaceFromCatalogCommand` opens with `resolveLatestTemplate(doc,
catalogId)` and returns `CatalogPlacementFailed('Unknown catalog template
"$catalogId".')` when that answers null. It has resolved out of
`RackDocument.templates` since M0, and DR-077 §11.76.3 made that its **property**
rather than an implementation detail.

A library template is by definition not in the document. So every library row
[DR-102](dr-102-the-palette-answers-for-every-shelf.md) adds would list with a
badge, take a double-click, and answer with a refusal naming an id the user can
see on screen. DR-102 says the merged list *"keeps placement a single gesture"*,
and that sentence is a **consequence, not a mechanism**.

## Placement: the copy happens, and it is AC-041

Placing a library row writes the snapshot into `RackDocument.templates` and then
places the device, **in one transaction**.

Neither an invention nor a compromise. AC-041 already rules v1 as copy-on-place,
and docs/02's rejected-alternatives table is blunter: the alternative to embedded
snapshots is *"a live library reference"*, costing *"non-reproducible
deliverables; drawings that change silently across machines"*. **A device
resolving out of a `.rmda` on one person's shelf IS that alternative.**

**Nothing was built for the transaction.** `DocumentController.transact` already
groups any number of commands into one undo entry and applies each on `add`, so
the placement sees the template the copy just wrote. Sixth time in one milestone
the hardest-looking item was already in the tree.

## The ordering, which is the one real constraint

The placement is **built before the copy is committed**.
`buildPlaceFromCatalogCommand` takes the resolved snapshot as an argument on this
path, so a rack with no room refuses **without** having copied anything. Adding
the save first and discovering the refusal second leaves a template in the
project for a device that was never placed: `transact` rolls back on a throw, and
**a refusal is not a throw**.

## The id that is already taken, which is the common case

| The document at that exact key | What happens |
|---|---|
| Nothing | Copy the library's own `templateId@version` verbatim, version preserved |
| A body that hashes identically | **No copy at all**, and nothing announced |
| A body that hashes differently | Mint a fresh id via `templateIdFor` at v1 |

Row three is not hypothetical:
[DR-101](dr-101-an-id-collision-on-import-is-a-question.md) is why. Two people who
both typed `HDMI Matrix 16x16` have `tpl.hdmi_matrix_16x16` in both libraries,
both at v1. Overwriting was never available (the key is what placed devices
resolve against); placing the document's version instead would silently hand the
user the other library's device under the name they clicked.

**The comparison is a recomputed hash, not the claimed one.** Comparing the two
`contentHash` strings answers "unknown" for everything written before `#795`, and
there is no user to ask mid-gesture. What is **written** is still the claim, or
AC-042's mismatch warning becomes unreachable.

## The three surface clauses

**Announcement is once per template**, triggered by the copy having happened
rather than by a counter, so it carries no state and cannot drift from what the
document did. Silence was declined; announcing on every placement was declined
for spending the warning's value before the day it matters.

**Grouping is the category with a badge, not a pinned group per library.**
Mirroring DR-077 §11.76.2 loses on arithmetic: the pinned region sits above the
categories in a panel legal down to 220px, and four libraries put the nine
categories below the fold. The success case would break the panel.

**A library that will not decode is a disabled chip carrying its file name.**
This is the case AC-042 does **not** cover, and the distinction lets both rules
stand: a hash mismatch loads and its templates are badged; a malformed file
yields no templates at all and there is nothing to badge.

## What building it found

**A click on a palette row had been announcing a refusal for a gesture nobody
made.** Every pointer-down arms a drag (AC-016 #23); the pointer-up found `phase
!= dragging` and said *"Released outside the rack — HDMI Matrix 4x4 was not
placed."* `DragPreviewPhase.armed`'s own comment says what it is: *"might still
just be a click/double-click"*. The second half of every double-click reached it
too, landing after the placement and overwriting it. Found because it was eating
this ruling's own announcement, and **no test anywhere named that string, in
either direction**. See
[a string no test names](../practices/a-string-no-test-names.md).

## What it does not rule

Which libraries load (all of them; the shelf is the state), favourites and smart
folders (M4-O's), and **any way to remove a library from inside the app**: the
file manager stays the only other reader of the shelf, which is a real gap named
rather than closed.
