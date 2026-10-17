---
type: Design Ruling
title: DR-143 — The floorplan importer had no caller, so the Plan view had nothing to open
description: >-
  PLAN-D built the whole import path with tests and nothing in lib/ calls any of
  it. AddPlanUnderlayCommand has no producer, the starters carry no underlays,
  and the session has no way to add a container member. The reachability gate
  could not see it, because its name is broader than its scan.
tags: [ruling, plan-view, import, reachability, gates, dr-143, dr-091, plan-e]
timestamp: 2026-09-08T00:00:00Z
ruling_id: DR-143
canon_section: "11.142"
status: built
---

Settled by the user on 2026-09-08 at `PLAN-E/5`'s census, before a line of the
shell was written.

`PLAN-E/5` was scheduled as the chapter that makes three chapters' work
reachable ([DR-141](dr-141-one-arm-one-pin.md)), then four
([DR-142](dr-142-what-the-unpinned-strip-lists.md)). **The census found a fifth,
and it sits upstream of all of them.**

# Nothing in the product can put a floorplan in a project

`PLAN-D` built the import sequence, the format allowlist, the byte and pixel
caps, the PDF page lifter and the page picker, each with tests. Censused by call
site rather than by name, in `lib/` only:

| Built by PLAN-D | Call sites outside its own file |
|---|---|
| `pickAndImportFloorplan` | **0** |
| `importFloorplanFrom` | **0** |
| `importFloorplanBytes` | **0** |
| `readPdfPages` | **0** |
| `importLiftedPdfPage` | **0** |
| `PdfPagePickerDialog` | **0**, exported from the barrel and imported by nothing |

`AddPlanUnderlayCommand` therefore has no producer, the four starters carry no
`underlays` key, and `PlanCanvasScreen.underlay` is required and non-null.

> Mounting the Plan tab on this tree would have mounted a fully built view onto
> content the product cannot create. That is DR-091's rule arriving from the one
> direction it did not anticipate: not a tab onto an unbuilt view, but a finished
> view onto an impossible document.

# And the producer is two pieces

`DocumentSession._members` carries the container's binary members from open to
save. It is written in exactly one place, `adopt`, wholesale, when a different
document replaces this one. **There is no way to add a member to an open
session**, so a menu item calling the importer would have had bytes and nowhere
to put them, and the save would have written a `PlanUnderlay` naming a member the
container does not hold.

# Why the reachability gate did not fire

[callbacks-have-callers](/gates/callbacks-have-callers.md) exists for exactly
this defect and had just caught it again one chapter earlier. It scans
**function-typed fields on `*Actions` records** in **`packages/rackpal_ui/lib`**.
`plan_import_actions.dart` holds **free functions** in **`apps/rackpal/lib`**,
failing both predicates, and its filename ends in `_actions.dart`, which makes
the gap easy to miss at a glance.

**A gate's scope is part of its claim.** The gate is not wrong and is not
weakened by this; what is recorded is that its name is broader than its scan, and
reading "actions have callers" as "reachable code has callers" is how a green
board coexists with a feature nothing can start. See
[a-gate-can-move-a-chapter-boundary](/practices/a-gate-can-move-a-chapter-boundary.md),
which is the same gate in the case where it *did* fire.

# What was ruled

**The producer folds into `PLAN-E/5`**, rather than a new chapter or reopening
`PLAN-D`. That chapter is already the reachability chapter, the ordering is
forced (DR-091 wants a tab onto something that can exist), and reopening a closed
epic moves a mark under §8.9 for a defect cheaper to pay forward. **Not a §8.3
amendment**: roadmap §2 gains nothing, and this work was always inside *"Import:
PNG and JPEG, a PDF page LIFTED at import with a page picker"*. Only the carrying
chapter moved.

**`File ▸ Import floorplan…`**, beside `Import Template` and `Import Library`.
`plan_import_actions.dart`'s header says `Plan ▸ Import floorplan…` and no `Plan`
menu exists; a second top-level menu holding one item was rejected as premature.

# The near-miss this ruling also records

The first reading had `PLAN-E/5` renumbering the `Ctrl+n` map, on a paraphrase
saying the mapping was deferred *"until Plan lands"*. **DR-091 §11.90.4 defers it
past M6**, not until Plan lands. So the Plan view gets a tab and **no
accelerator**, joining Locations, Device Manager and Structured Wiring;
`Ctrl+3` stays reserved for CR-071's Rear Panel.

Reading the ruling rather than the paraphrase is what caught it. See
[a-confident-paragraph-is-a-tell](/practices/a-confident-paragraph-is-a-tell.md).

# Not ruled

The Plan view's layout beyond docs/15 §6's three regions plus `PLAN-E/4`'s strip.
What the underlay list looks like, or whether it is orderable. The empty state's
wording. **And whether the reachability gate should widen its scan**, which is a
real question deliberately left open rather than answered inside a chapter about
a floorplan.
