---
type: Design Ruling
title: DR-166 — A 0U occupant has a span, and it draws as a bar on its rail
description: >-
  AC-044 keeps an inspector editing channel, start U and span in v1, and a plain
  bar in the elevation. Neither could be finished, because the model had no
  extent for a 0U occupant and the scene builder dropped every non-rail
  placement, which is why such a device could never be selected.
tags: [ruling, zero-u, elevation, ac-044, g4, plc-003, dr-166, m5]
timestamp: 2026-09-13T00:00:00Z
ruling_id: DR-166
canon_section: "11.165"
status: ruled
---

Settled by the user on 2026-09-13, closing `#883`.

# One line made half a ruling unreachable

`scene_builder.dart` read `if (placement is! RailPlacement) continue;`, so a 0U
device was never drawn, never hit-tested and **never selectable**. That is why
[DR-163](/decisions/dr-163-zero-u-from-the-inspector.md) had to put AC-044's
occupant fields on the rack panel rather than on the device inspector that
ruling names, and an installer reading the elevation could not see the PDU at
all.

# The model field came first

AC-044 has named *"channel, start U, span"* since the critique and `#876`
shipped two of the three. `ZeroUPlacement` carried a channel, an offset and an
orientation; `TemplateBody` has no physical length for a body whose `frontU` and
`rearU` are both 0; and `PLC-003` treated the occupant as a POINT.

Both alternatives invent a length the file does not hold. Running the bar to the
channel's end is honest only while one occupant is in a channel, and `#884` puts
every new one at offset 0. Spanning the whole channel makes `#876`'s **Start U**
field change nothing visible.

**Absent is unknown, not zero.** Every document written before this has no span,
so it is the ordinary case: an absent key, an empty field hinted `unknown`, and
a one-U **hollow** stub rather than a filled bar. G4's rule, given a shape
instead of a number.

# What building it found

`planSetZeroUPosition` rebuilds the placement to move it, so it erased the new
field on every move, silently: [a new field is erased by every
rebuilder](/practices/a-new-field-is-erased-by-every-rebuilder.md).

And a comment claimed a bar needed no scene fragment, *"one absolute rect with
no local origin worth having"*. The canvas builds a leaf per entry in
`RackScene.devices` and `fragmentFor` throws on an id it has no range for, so
the first run painted an error where the elevation should have been.

# Related

* [DR-163](/decisions/dr-163-zero-u-from-the-inspector.md) is what this
  completes: §11.162.1's reason for the rack panel is now spent.
* [Assert the artifact, not the
  mechanism](/practices/assert-the-artifact-not-the-mechanism.md) is what the
  closing case obeys: clicking the bar selects the device, which the inspector
  shows by swapping panels.
