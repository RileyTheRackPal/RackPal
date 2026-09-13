---
type: Design Ruling
title: DR-167 — The 0U occupant's fields move to the device inspector
description: >-
  They were on the rack panel because a 0U device could not be selected. #883
  removed that obstacle, so the fields went where AC-044 always put them, and
  both clauses that argued for the old placement are corrected in place.
tags: [ruling, zero-u, inspector, ac-044, dr-163, dr-166, dr-167, m5]
timestamp: 2026-09-13T00:00:00Z
ruling_id: DR-167
canon_section: "11.166"
status: ruled
---

Settled by the user on 2026-09-13, closing `#887`.

# A placement argued from an obstacle that is gone

AC-044 puts a 0U occupant's *"channel, start U, span"* on the inspector, and
every other device property is edited on the DEVICE inspector.
[DR-163](/decisions/dr-163-zero-u-from-the-inspector.md) §11.162.1 put these
three on the RACK panel and said why: **a 0U device could not be selected**.
[DR-166](/decisions/dr-166-a-zero-u-occupant-has-a-span.md) drew the bar and
made it hit-testable.

**Both earlier clauses are corrected in place rather than left to read as
current.** A reader who finds a placement argued from an obstacle that no longer
exists does not conclude that it was re-decided; they conclude the obstacle is
still there. §11.162.1's own closing paragraph is about that failure pointed the
other way, and it would otherwise have become an example of itself.

# What did not move

A channel is a rail on a rack: adding one, removing one, and the occupant count
that makes a Remove about to refuse say so first are facts about the RACK. The
occupant's own three fields are facts about the DEVICE. **Nothing is editable in
two places**, and a case pins both halves.

# What the move cost the test harness

`_rack` and `_doc` read their values off `RackInspectorPanel`, which is mounted
only while the inspector is on the rack. A case that selects a device in order
to edit it swaps that panel away, so every assertion afterwards died on
`Bad state: No element` rather than on what it was about. **A test accessor
keyed on a widget that exists in only one state breaks the moment a case changes
state on purpose.**

# Related

* [A surface tested alone has never met its
  host](/practices/a-surface-tested-alone-has-no-host.md): the three cases that
  changed route are `#883`'s gesture doing real work rather than being asserted
  once.
