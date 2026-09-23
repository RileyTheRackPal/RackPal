---
type: Design Ruling
title: DR-187 · The schematic holds its layout, and a symbol drags, nudges and pins
description: >-
  Adding a device re-flowed the schematic and moved every symbol on it. The sheet keeps its layout
  now and the positions go in the file, written on the first edit that would re-flow rather than on
  view, which overrules DR-011.4's rejection of a SheetItem per device. A drag or a nudge moves a
  symbol and pins it, and Tidy sheet re-flows the unpinned ones.
tags: [ruling, schematic, layout, sheet-item, keymap, dr-187, dr-011, cr-068, cr-117]
timestamp: 2026-09-18T00:00:00Z
ruling_id: DR-187
canon_section: "11.186"
status: ruled
---

Ruled by the user on 2026-09-18 on board `#914`.

# Three measurements, and the third changed the plan

Probed on `schematic_scene_test.dart`'s fixture:

- **Adding two devices re-flows the sheet** and moves the symbols already on it. The report,
  reproduced.
- **Pinning a symbol where it already stands moves nothing**; pinning it 24 by 8 grid units away
  **moves all five of its neighbours**, because a fixed node stops relaxing.
- **With every existing symbol fixed, a newly added device lands exactly on top of one of them.**
  Freezing the sheet works; placing the newcomer does not come free.

# What was ruled

- **The sheet keeps its layout and the positions are in the file**, which overrules
  [DR-011.4](/decisions/dr-011-connect-gesture.md)'s rejection of a `SheetItem` per device (canon
  §12.38). A session-only freeze was offered and declined: it loses the arrangement when the project
  is reopened.
- **Written on the first edit that would re-flow**, never on view. Writing at save time was declined
  because it mutates the document outside a command; writing on first layout because it would prompt
  "save changes?" for a project nobody edited.
- **A stored position is honoured whether or not it is pinned.** Pinned is what `Tidy sheet` spares.
- **A drag or a nudge moves a symbol and pins it** (CR-068), and the arrows nudge whenever no connect
  is in flight, with the keymap row relabelled to carry both meanings.


# The clause that said "its own undo entry", and the measurement that killed it

Canon §11.186.2 said the freeze lands as its own undo entry beside the edit. **Built that way it
did, and two tests older than the ruling went red on it**: `schematic_remedy_test.dart` asserts
*"ONE undo takes back the device AND the cable"* and `schematic_remedy_dr128_test.dart` asserts
*"one undo takes back the converter and both cables"*, which is the Edit menu's standing promise.

**The behaviour it produced is the one this ruling exists to abolish.** The first `Ctrl+Z` after any
edit took back the ARRANGEMENT and left the edit, so the sheet visibly scrambled, the device stayed
deleted, and undoing one delete cost two presses.

**Ruled instead (§11.186.2.1): the freeze is a CHILD of the edit's own undo entry.** One undo
reverts both and lands on exactly the document that existed before either, which re-flows to the
layout that was frozen, so the arrangement is right either way. The entry is still named by the
edit, because `_commit` names a transaction after its first child ([DR-156](/decisions/dr-156-a-command-reports-whether-it-applied.md)
§11.155.2).

The mechanism is `DocumentController.addConsequence`: a hook that runs at the tail of a transaction
that changed something, with the entry still open. **An epoch listener cannot do this**, because by
the time an epoch bumps the entry is sealed and the only way in is a second one.

**The sentence was the option author's and not the user's**, which is the failure
[record-the-choice-not-a-reason-they-did-not-give](/practices/record-the-choice-not-a-manufactured-reason.md)
already records once: a manufactured reason gets reasoned from.


# The drag, priced before it was offered

One frame is 16.7 ms. Measured on `schematic_perf_test.dart`, best of five:

| Path | 300 links | 3,600 links |
|---|---|---|
| Wires re-routed, symbol tier reused | 0.72 ms | **8.8 ms** |
| Layout reused, wires re-routed | — | **36.3 ms** |
| Cold scene build | 7.7 ms | **76.9 ms** |

Live re-routing is affordable on a house and not on a campus, **and a campus sheet is exactly the
one somebody needs to drag symbols around on**, so the expensive case decided it. A dashed ghost
follows the cursor and the sheet lands on release, at one rectangle per frame at any size. The cost
is that the wires are not seen until the drop, and one `Ctrl+Z` is the way out.

**`Ctrl+Shift+U` ships with the drag** and not later. A drag pins (CR-068) and `Tidy sheet` spares a
pinned symbol, so without an unpin the act of arranging a sheet by hand is what puts it beyond the
reach of the command that lays it out again. That is a trap somebody falls into by doing exactly
what the feature invites.


# The nudge, and the clause its own build refuted

§11.186.4 said the arrows nudge *"when no connect is in flight"*. **The arrows are also how a pin is
REACHED before anything is armed**, so that condition is true for half of the connect route itself,
and sixteen tests said so on the first build.

**§11.186.10: a caret on screen is the mode.** With one, the arrows move it and `Esc` hands them
back; with no caret and a symbol selected they nudge it; with no caret and nothing selected they seed
one, which is the old behaviour. `W` seeds a caret and arms in a single press, so the connect route
kept its entry.

**A run of presses is one undo entry**, through a `mergeKey` on the set of symbols. A pin and an
unpin never merge, because those are decisions rather than adjustments.

**And a gate corrected the relabelling.** ↑/↓ carry a union label shared with the rack, where the
nudge is real; ←/→ cannot, because `Arrow Right` is shared with the builder and `meaningDrift`
refused the pair. **A shared label may state only what is true in every scope that shares the
chord**, so those two carry the nudge in a note instead.

# What this does not rule

`Tidy sheet`'s host, which is settled when it is built: the schematic's only chrome is its domain
filter bar, and docs/05's context menu is specified and unbuilt. Multi-select drag.
