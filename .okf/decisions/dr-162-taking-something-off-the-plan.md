---
type: Design Ruling
title: DR-162 — Taking something off the plan, and putting the pages in order
description: >-
  ClearPlanPinCommand and ReorderPlanUnderlayCommand shipped at PLAN-C with real
  reverts and no caller, while the two commands beside them that PLACE things
  both had one. Delete and Backspace now clear the selection's pins and the rail
  reorders by a dedicated grip. Building it found that this canvas never took
  focus, so Esc had never worked on it either.
tags: [ruling, plan-view, pins, keymap, focus, dr-162, dr-011, dr-143, cr-102]
timestamp: 2026-09-13T00:00:00Z
ruling_id: DR-162
canon_section: "11.161"
status: built
---

Settled by the user on 2026-09-13, closing `#878`. Found by `#872`'s
reachability gate.

# Every gesture that placed something was wired; neither that took it back was

`ClearPlanPinCommand` and `ReorderPlanUnderlayCommand` had real reverts, their
own `LabelKey` values and six test constructions between them, and no caller.
`SetPlanPinCommand` and `RemovePlanUnderlayCommand` live in the same file and
both had callers. So a rack pinned to the wrong room could only be fixed by
pinning it somewhere else, and docs/15 §6's gesture table has a row for every way
to create a pin and none for removing one.

# One key, three canvases

`Delete` and `Backspace`, chosen by the user over a visible control. The cost is
stated rather than discovered: `KeymapConflictKind.meaningDrift` forces one label
per key across scopes, so this reads *"Delete the selection"* while the rack's
`Delete` removes a device from the project, and DR-011.6 had already refused to
widen that rule because *"a keyboard-only user cannot see a scope boundary"*.

**It is right anyway because the label names the SELECTION**, and the selection
is a different kind of thing on each canvas: devices on the rack, cables on the
schematic, pins here.

**What makes it SAFE is the strip.** A cleared pin puts its carrier straight back
into the unpinned rail along the bottom, which docs/15 §6 calls *"the difference
between a plan that is trusted and a plan that is 80% complete without saying
so"*. The answer to *"did I just delete my rack"* appears three inches below the
pointer in the same frame.

A marquee clear is one undo step, and a selection holding no pin DISABLES the
action rather than building a transaction whose only child declines, which is
`#863`.

# Pages reorder by a grip, and the row's width history decided it

Whole-row drag was refused because tap-to-open and two buttons live inside what
it would claim. **Up/down buttons were refused on a measurement**: that row
overflowed by 126 pixels at 240 wide holding ONE button. A reorder is a single
`orderBetween` field write and never a renumber; where it cannot mint a value the
gesture is refused in words.

# What building it found

**This canvas never called `requestFocus`.** `rack_canvas_screen.dart` calls it in
eight places; this one relied on `autofocus: true`, which wins only while nothing
else has claimed focus. `Shortcuts` sits above the focus node, so **`Esc` has
been dead on this surface since `PLAN-E/5`** with green cases all along.

**And no pointer gesture reaches the Plan tab at the app mounting.** A tap does
not select a pin, a drag does not move one, a drag on the rail's grip does not
reorder, while all three work in `rackpal_ui`'s own suites and
`signposting_test.dart` taps the RACK canvas in the same harness. Whether that is
the product or the harness is **not settled here and not guessed at**: `#882`
carries the measurement and the check that tells them apart. The two gestures are
proved at the widget level, and the app-level proof is recorded as owed.

# Related

* [autofocus is not a focus
  policy](/practices/autofocus-is-not-a-focus-policy.md) is the general form of
  the focus finding.
* [A surface tested alone has never met its
  host](/practices/a-surface-tested-alone-has-no-host.md) is `#877`'s, one ticket
  earlier, and the Plan tab is the second instance: `shell_tabs_test.dart`
  asserts `Plan` is in the strip and never switches to it.
