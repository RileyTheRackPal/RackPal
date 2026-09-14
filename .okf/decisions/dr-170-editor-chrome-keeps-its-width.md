---
type: Design Ruling
title: DR-170 · Editor chrome is drawn at its authored screen width at every zoom, and a canvas is told the zoom its layer applies
description: >-
  The zoom sat in a transform layer the canvas's stroke rules could not see,
  so "screen-pixel" chrome grew with it: a 2-pixel selection outline painted
  at 24 pixels at 12x. Measured on the rack and the schematic before either
  width was ruled, and the flag that was supposed to prevent it was defeated
  by the layer.
tags: [ruling, rack, schematic, chrome, cr-082, stroke-width, dr-170]
timestamp: 2026-09-14T00:00:00Z
ruling_id: DR-170
canon_section: "11.169"
status: ruled
---

Settled by the user on 2026-09-14, found while building `#905` and built as
`#906`.

# The flag was defeated by the layer

The plan, rack and schematic canvases push the viewport as a `pushTransform`
layer above a cached picture, so a pan re-projects a texture instead of
repainting. `FlutterDiagramCanvas` starts its own transform stack at identity
every paint, so its stroke rules read scale 1 at every zoom.

That had two consequences, and neither was visible from the code. A stroke
marked `scaleWithGeometry: false`, CR-082's spelling of "chrome does not
scale", was divided by 1 and painted at its width times the zoom. The connect
overlay's own comment says the flag *"handles the STROKE WIDTH"*; it did not.
And the 0.5 floor was compared in scene units, so zoomed-out lines could
thin to a twentieth of a pixel.

# Measured before ruled

| Chrome | Authored | Rack at open, 3.02x | Rack at 12.1x | Schematic at 4x |
|---|---|---|---|---|
| Selection outline | 2 px | 6.0 px | 24.2 px | n/a |
| Hover ring | 1.5 px | 4.5 px | 18.1 px | n/a |
| Port chip | 1 px | 3.0 px | 12.1 px | n/a |
| Connect rings | 2 px | n/a | n/a | 8 px |
| Connect band | 1.5 px | n/a | n/a | 6 px |

The rack's rings are raw `Paint` strokes that no flag ever reached. The grid
painter and the editing overlay painter already divided by the zoom and were
right.

# What was ruled

- **Chrome is drawn at its authored width at every zoom.** Visibly thinner
  when a rack first opens, because it opens at about 3x; freezing that
  opening look was offered and refused, because it contradicts docs/04's
  "2 px outline" and would not have matched the schematic.
- **No line paints thinner than half a physical pixel.** Telling a canvas its
  zoom moves the floor to physical pixels for lines that scale, too, which is
  what CR-082's floor already means on paper.
- **One scale per canvas, passed where its layer is pushed**, and read at
  paint time by anything painted under it.
- **The rubber band is solid, and its colour was never open** (§11.169.6,
  added at `#907`). This ruling's own scope note first called the band's
  styling an open gap; DR-114 §11.113.2 had already ruled it cursor chrome in a
  theme role, and a dashed band on this canvas already means a right-to-left
  marquee (CR-102).

# The channel that looked right and was not

The first build handed the scale to each device box in its parent data. A
test went red at the same number as before the fix, because
`RackDevicePlacement` gives parent data to the rack canvas's DIRECT child,
and that child is the `FocusableActionDetector` which `DeviceBox.build` puts
above the render object. The scale landed on the wrapper. The box now walks
to its nearest `RenderRackCanvas` and reads the viewport there.

# Related

* [DR-169, a plan mark says what it is](dr-169-a-plan-mark-says-what-it-is.md):
  §11.168.11 found the transform layer on the plan canvas first.
* [A test that counts the mechanism will certify the
  defect](/practices/assert-the-artifact-not-the-mechanism.md): every case here
  reads what was painted, and one selector that picked strokes by colour had
  to be replaced with a paint-with-and-without comparison.
