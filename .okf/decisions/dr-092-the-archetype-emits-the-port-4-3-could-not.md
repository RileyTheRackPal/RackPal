---
type: Design Ruling
title: DR-092 — The Matrix archetype emits the port §4.3 could not
description: >-
  docs/06 §4.3's Matrix I/O checkbox list emits 67 ports where §9.2 promises 68
  across 6 banks. The missing one is IR IN, which the worked example types and
  the control list has no producer for; it rides the per-output IR tick, and
  four more of §4.3's clauses turn out to be illustrations.
tags: [ruling, device-builder, archetype, matrix, m4-i, dr-092, ac-052, census]
timestamp: 2026-08-26T00:00:00Z
ruling_id: DR-092
canon_section: "11.91"
status: ruled
---

# DR-092 · The archetype emits the port §4.3 could not

Board `#220` (M4-I1). Settled from a census run against docs/06 §4.3 and §9 **before**
the generator was written.

## The arithmetic is the finding

§4.3 offers Matrix I/O as *"N inputs × M outputs, connector per side, with checkboxes
for the usual companions: mirrored outputs, per-output audio de-embed, per-output IR,
control (LAN + RS-232), AC inlet"*.

§9's target device is 68 ports across 6 banks, and §9.2's step 6 says the button emits
exactly that. Count what the checkboxes make:

| Row | Ports |
|---|---|
| Four bulk rows at 16 | 64 |
| Control, as §4.3 writes it | 2 |
| AC inlet | 1 |
| **Total** | **67** |

`IR IN`, which §9.1 types at step 12, **has no checkbox and therefore no producer**.
That is [ask what produces each task's input](/practices/ask-what-produces-each-tasks-input.md)
arriving one level below where the practice found it: the feature's own worked example
names a port the feature's own control list cannot make.

## The ruling

**IR IN rides the per-output IR tick.** A matrix carrying IR emitter outputs is routing
IR and IR has to arrive from somewhere; a matrix without them has nothing to route, and
an IR input on it is a port somebody deletes. It costs no step, because §9.2's step 5 is
already a tick group, and it reaches 68 across 6 exactly.

Rejected: an unconditional third port, and a fourth checkbox, which is honest and free
in step count and is still one more decision for a user who by the criterion's own
wording **has seen the tool once**.

## Four more clauses that were illustrations

| §4.3 says | What it is |
|---|---|
| "above Quick Add" | §2's own layout sketch draws the buttons UNDER the bar, and the fast path must be the first thing under the hand |
| "connector per side" | `rj45` defaults to `net.ethernet`; the output side is `video.hdbaset` on that same connector. Both pickers ship |
| "4 to 7 banks" | The floor is **2**. Inputs and outputs are the only rows that cannot be switched off |
| the de-embed default | `audio.line_bal` defaults to XLR3, which is right for the family and wrong for every rack matrix ever built. Balanced on a 3-pin Euroblock |

## What a generator knows that a parser cannot

It **writes `pinoutVariant`**: `mono-tip-sleeve` for emitters, `xantech-stereo` for the
receiver, which are the strings the seeded catalog already uses in fourteen places. It
chose the family, so it knows the pinout, and `port_validation.dart`'s only
hardware-safety warning (AC-052) would otherwise mark all seventeen IR ports. The
thirteen-step DSL path cannot and does not, because a parser knows only its token.

## The mechanism, and why it is one and not three

The generator emits `QuickAddPlan`s and Quick Add's own builder turns them into
commands, against **one shared allocator**. A generator that constructed `PortDef`s
itself would be a second copy of the bank-reuse rule, the label expander and the ordinal
allocator, which is the objection `uniqueSlugKey`'s own comment already records against
a third derivation of a key.

## Citations

[1] `packages/rackmate_core/lib/src/builder/archetypes.dart`
[2] `packages/rackmate_ui/lib/src/builder/archetype_dialogs.dart`
[3] [DR-093](dr-093-the-switch-copies-the-seeded-switch.md), the sibling generator
[4] [DR-094](dr-094-the-paste-sheet-declares-its-separator.md), the third button
[5] [a spec table is an illustration until censused](/practices/a-spec-table-is-an-illustration-until-censused.md)
