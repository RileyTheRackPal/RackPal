---
type: Practice
title: Hiding a widget is a structural change, not a visual one
description: >-
  One afternoon produced three bugs with one cause: a column that appeared on
  two tabs broke every tab switch, destroyed every tab's State, and stopped a
  saved template reaching the palette. Flutter reconciles by position and
  identity, so "show this sometimes" rearranges the tree.
tags: [practice, flutter, layout, reconciliation, dr-165, m5]
timestamp: 2026-09-13T00:00:00Z
---

`#885` moved the device palette out of one screen so two views could share it.
The palette column shows on the Rack tab and the Plan tab and on no other, which
reads like a visual decision and is not one. Three bugs came out of it in an
afternoon, and **they are the same bug three times**.

# 1. A hidden column changed a `PageView`'s page width

The column was drawn as a sibling of the shell's `TabBarView`, with a flag for
the tabs that have no palette. **A `TabBarView` is a `PageView`, and a
`PageView` positions by PIXEL OFFSET**: `index * viewportWidth`. Hiding a 280px
column widens the viewport by 280, so an offset animated for the old width lands
between pages.

Tapping `Schematic` from the Rack tab showed `Structured Wiring`, one page
short, every single time. Nothing threw. The failing assertion was
`findsNothing` for a screen that should have been there.

# 2. A conditional child in a `Row` moved its siblings

`if (showColumn) ...[column, divider]` emits **one** child on the tabs with no
palette and **three** on the two that have one. Multi-child elements are matched
BY POSITION, so the canvas moved from slot 2 to slot 0 and its entire subtree
was destroyed and rebuilt on every tab change, taking every tab's `State` with
it.

The fix is that the children count must not depend on the condition, or better,
that the thing being hidden is not a sibling at all.

# 3. An `InheritedWidget` carrying a `State` never notified

`updateShouldNotify` was written as `state != old.state`. That asks **"was this
widget replaced"** and never **"did anything change"**: a `State` instance is the
same object for the life of its element, so the comparison is false forever. The
column stopped rebuilding, and a template saved while the canvas was open never
appeared in the palette.

# What to check

**When a widget's presence depends on a condition, ask what its absence does to
its NEIGHBOURS.** Not how it looks: what slot the siblings occupy, what width is
left for them, and whether anything downstream measures that width. A scrollable
that positions by offset (`PageView`, `ListView` with an extent) is the loud
case; any `Expanded` beside a conditional child is the quiet one.

**Prefer "the view places it" over "the host hides it".** The fix here was to
stop passing a `showColumn` flag down and let each view put a column in its own
layout. The page width then never changes, nothing is conditional in a shared
`Row`, and *which views have a palette* becomes a fact about those views rather
than a flag that travels.

**And an `InheritedWidget` over mutable state notifies on every rebuild.**
Comparing the carried object is only correct when that object is itself the
value. If it is a handle to something that mutates, the comparison is asking the
wrong question and will answer it consistently.

# Related

* [A surface tested alone has never met its
  host](a-surface-tested-alone-has-no-host.md): all three of these were invisible
  to the package's own suite and visible the moment the real shell was pumped.
* [Assert the artifact, not the
  mechanism](assert-the-artifact-not-the-mechanism.md) is the habit that caught
  the third one, via a case about a saved template rather than about a notifier.
