---
type: Design Ruling
title: DR-174 · A set on one cable draws one pennant on a bracket
description: >-
  Board #111 was ruled on the board in August and never reached canon. An atomic set draws a bracket
  across its pins, with one pennant centred on it, only when every member is on the same cable; a
  split or partly wired set keeps a pennant per pin.
tags: [ruling, schematic, net-labels, port-sets, dr-014, dr-174]
timestamp: 2026-09-15T00:00:00Z
ruling_id: DR-174
canon_section: "11.173"
status: built
---

Ruled by the user on the board on 2026-08-01, recorded and completed on 2026-09-15, and built as
`#111`.

# A pair on one cable read as two things

The net-label layer labels a link by its first conductor alone, so a stereo pair on one cable drew
its pennant on the L pin and left the R pin unmarked. DR-014 then made a third state reachable: a set
that was one cable and has had a member lifted out.

# What was ruled

- **A bracket only when the whole set is one cable**, read from the document: every member of the
  atomic set has a conductor end on the same link.
- **A split set or a partly wired set draws no bracket**, and each wired pin keeps its own pennant.
- **The one pennant is centred on the bracket** (2026-09-15), so it names the cable, not its first
  conductor.
- **The bracket takes the leader's signal colour and stroke** (2026-09-15), adding nothing PAL-1
  reads.

# What building it found

- A raw NUL byte in `net_label_layer.dart` made grep skip the file; fixed in its own commit first.
- The first census counted the stored `left` default as an edge; the drawing falls through it to
  direction, and every seeded set is two adjacent pins on a left or right edge.
- The bracket fits inside the leader's own room, so the gutter reservation does not change and no
  committed drawing moves.

# Where it lives

- `packages/rackpal_core/lib/src/draw/scene/net_label_layer.dart`: `_bracketOf` and `emit`.
- `packages/rackpal_core/test/scene/net_label_layer_test.dart`: the DR-174 group.
- `docs/05-schematic-editor.md` §11.5: the paragraph.

Not ruled: a set on a top or bottom edge, a collapsed bank, the drawn-wire mode, and the drag onto a
wired member. No scope change.
