---
type: Design Ruling
title: DR-165 — The device palette is the shell's, so the Plan view can place a device
description: >-
  docs/15 section 6's first gesture row had a command, a public arming method
  and no palette on screen to start one. The palette moved out of the rack
  screen; the Plan view gained it; and the move found a defect in a parameter
  that had never been given the value its own name promised.
tags: [ruling, palette, plan-view, reachability, dr-143, dr-165, m5]
timestamp: 2026-09-13T00:00:00Z
ruling_id: DR-165
canon_section: "11.164"
status: built
---

Settled by the user on 2026-09-13, from their own report: *"Device templates are
only pulled in from the rack view ... field devices need to be accessible from
the plan view; it improves the UX workflow significantly."*

# Ruled in, built, tested, unmounted

docs/15 §6's gesture table opens with *"drag from the device palette or staging
bin onto the plan: places the device and sets its pin in one command"*.
`buildPlaceOnPlanCommand` carries the pin ON the placement so one undo restores
both. `PlanCanvasScreenState.armPaletteDrag` is public with a comment saying why:
*"the host that owns a palette hands the armed pointer down, and `PLAN-E/5` wires
the real one."*

**`armPaletteDrag` had three call sites and all three were tests.**
`DevicePalettePanel` had exactly one mount, inside `RackCanvasScreen`, so the
palette was not on screen when the Plan tab was. `PLAN-E/5` shipped the tab and
the layout and did not bring it: the chapter scheduled to make three chapters'
work reachable is the one that left this.

# The hoist, and the sub-question it answered structurally

`PaletteHost` owns the row list, its memo, the index that resolves a `rowKey`,
the search controller and the `/` handler. `RackCanvasScreen` loses all of it,
plus three parameters that existed only to feed it.

Which views show a column was left open by the ticket and is answered by the
layout rather than by a flag: **a view has a palette because its own `Row` puts
one in**. The Structure editor places outlets and plates from surfaces of its
own and simply does not.

# A parameter that had never been given a real value

The host hands over a resolved `PlaceableTemplate`. A `rowKey` is
`source/id@version` and a template id is not, and `_placeFromPalette` took a
rowKey and passed it to `buildPlaceOnPlanCommand` as a **`catalogId`**, which
resolves nothing for any real row. Its three tests all passed a bare id. The
type makes the wrong call unrepresentable now.

# And three findings about hiding a widget

Recorded at §11.164.5 and generalised in
[hiding a widget is a structural change](/practices/hiding-a-widget-is-a-structural-change.md):
a hidden column changed a `PageView`'s page width and broke every tab switch; a
conditional child in a `Row` shifted its siblings and destroyed every tab's
`State`; and an `InheritedWidget` comparing a `State` object never notified, so
a saved template never reached the palette.

# Related

* [DR-143](/decisions/dr-143-the-importer-had-no-caller.md) is the precedent for
  the scope call: an unbuilt clause reaching its producer is not an amendment.
* [A deferral reads as a decision](/practices/each-surface-deferred-to-the-other.md)
  is the neighbouring habit from `#884`, one ticket earlier.
