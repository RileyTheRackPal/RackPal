---
type: Playbook
title: A deferred action needs a frame, and a gesture outlives its own handler
description: Two defects one phase apart — addPostFrameCallback queues but does not schedule, and TabBarView settles the page under a tab switch made mid-click. Both were invisible to every unit test at both ends.
tags: [practice, flutter, gestures, debugging, m2-f]
timestamp: 2026-08-01T00:00:00Z
status: adopted
---

M2-F Phase 5 wired CR-105's elevation chip to the schematic. Both ends were
built, unit-tested and correct. Neither worked, for two different reasons, and
**every test at both ends stayed green**, which is the whole reason this is
written down.

# One: `addPostFrameCallback` queues, it does not schedule

`SchematicCanvasScreen` defers its reveal by one frame; it has to, because the
selection controller notifies synchronously and the shell is mid-`setState`.
The deferral was written as a bare `addPostFrameCallback`.

**Reveals driven through the controller did nothing at all** (no selection, no
scroll, no status line) while the identical code path reached from `initState`
worked perfectly. The difference is that `initState` runs INSIDE a frame, so a
callback queued there is drained at the end of that same frame. A callback
queued from a listener, with no `setState` anywhere and no frame pending, waits
for whatever happens to schedule one next.

In production something usually does. That is the trap: the code appears to
work, intermittently, for reasons unrelated to itself.

**The fix is `ensureVisualUpdate()` beside the callback**, so the deferral is
self-sufficient rather than dependent on a stranger's `setState`.

# Two: a `TabBarView` settles the page under a switch made mid-click

The shell answers the chip by switching tabs. Done inside the click handler,
`TabController.index` read 1 the instant `switchToTab` returned and **0 once the
frame settled**.

`TabBarView` is a `PageView`, and a `PageView` settles to the nearest page when
the pointer it is watching goes up. The click on the chip IS that pointer: the
index moved while the page position was still at 0, and the settle put 0 back.
A user would have seen the Schematic flash and the Rack come back.

**The fix is one post-frame hop**, so the switch lands after the gesture has
resolved. The reveal request is parked FIRST and unconditionally, so the
destination screen still gets it whichever frame it is built on.

# The shape

Both are the same class as the
[salvage post-mortem](/practices/diagnose-before-fixing.md)'s finding: **a
mechanism that reads as working because one of its invocations does.** The unit
tests at each end were true and the composition was false, which is what
`apps/rackpal/test/session/signposting_test.dart` exists for; it is the only
place that can observe the two halves being wired to each other.

# How to catch it next time

* When a widget defers work it did not itself schedule a frame for, pair
  `addPostFrameCallback` with `ensureVisualUpdate`.
* When an action taken during a pointer event changes something a scrollable
  owns (a page, a scroll offset, a route) defer it past the gesture.
* **Drive the composition, not just the ends.** A test that asserts a callback
  fires and a test that asserts a request is honoured can both pass while
  nothing connects them.
* Neither defect was found by reading. Both were found by printing the value at
  two moments and noticing it changed between them.
