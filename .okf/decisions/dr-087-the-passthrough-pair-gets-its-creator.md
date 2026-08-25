---
type: Design Ruling
title: DR-087 — The passthrough pair gets its creator, and the LIU that cannot be paired
description: >-
  The pairing action is additive and idempotent, the PAIRED WITH cell makes the
  wrong answers inexpressible, and one seeded template stays unpaired on purpose
  because the model is 1:1 and the hardware is not.
tags: [ruling, m4, m4-j, passthrough, cr-057, ac-025, g4, dr-087]
timestamp: 2026-08-25T00:00:00Z
ruling_id: DR-087
canon_section: "11.86"
status: ruled
---

Settled by the user on 2026-08-25 (board `#181`, `#225`, `#762`), at M4-J3's
pick-up and **before any code**. CR-057 already rules `passthroughPairs` into
`.rmdx` and says the grid column and the pairing action write it;
[DR-085](dr-085-mirror-bank-and-the-missing-producers.md) §11.84.2 found that
neither does.

# Three models, three surfaces, no producers

`PassthroughPairDef` is the third and last. Its one writer is
`RenamePortKeyCommand`, rewriting pairs that already exist, and `PAIRED WITH` is
read-only. Two of the 48 seeded templates are `isPassthrough`, and **one of them
carries every pair in the catalog**: N03's 24.

**And `sameNet` is the third field in this issue with no reader**, beside
`BankDef.order` and `PortSetDef.kind`. The sentence docs/06 §4.7 promises for it,
*"a trace resolves jack to panel-front to panel-rear to switch as one logical
path"*, has no implementation: `wire_trace.dart` does not mention passthrough at
all.

# The action is additive and idempotent

It walks both faces in **declared order**, pairs every **unpaired** front to every
**unpaired** rear, stops when either runs out, and leaves existing pairs alone.

Replacing every pair was declined: **one press over a panel where somebody
corrected a crossed pair by hand puts the crossing back.** Acting on the ticked
selection was declined too, though every other §4.6 bulk operation does: the
natural gesture on a fresh 24-port panel is *pair the whole thing*, and 48 ticks
first makes the fast path slower than the slow one.

**It gets no chord.** It is a button in the `Passthrough` pack's header, shown
only when `isPassthrough` is on, because it is run once per template and a keymap
row is a real cost against M7's generated table.

# The cell makes the wrong answers inexpressible

`PAIRED WITH` offers only ports on the **other face** that are **not already
paired**, plus a blank that unpairs. A front-to-front pair and a double-booked
port are therefore not states this product can mint, rather than states it
validates afterwards, which is AC-030's temperament one type over.

A 24-port panel with one crossed pair needs a **one-cell** fix, and a bulk action
cannot express it.

# The LIU stays unpaired, on purpose

N04, the seeded 24-fibre LIU, is `isPassthrough` with **12 duplex LC front
adapters, 24 rear splices and zero pairs**. A duplex adapter carries two fibres,
so the relationship is **1 front : 2 rear**, and `PassthroughPairDef` holds one
`frontKey` and one `rearKey`.

**A 1:1 pairing here is a false fact on a sheet somebody works from.** `LC 01 →
SPL 01` is half true: LC 01 terminates splice 1 *and* splice 2, and the schedule
would name one of them. [G4](/invariants/g4-unknowns-are-counted.md)'s temperament
decides it. Re-authoring the panel as 24 simplex front ports was declined for
AC-025's reason, which is N03's own description: modelling both faces the same way
is the error that makes the Termination Schedule wrong on the column that matters.

So **the product carries a passthrough it cannot express, deliberately, and says
so.** Whether `PassthroughPairDef` should ever become 1:N is a model change with a
codec and a migration behind it, and is not M4's question.

# sameNet is written true and gets no control

A front jack and the punchdown behind it are one electrical path; that is what
passthrough means and what all 24 seeded pairs say. Nothing reads the field, so a
switch would be a control whose only observable effect is a byte in a file. It is
kept rather than removed because deleting it moves N03's bytes and breaks CR-117.

Recorded as **a field with no reader and no false case**: if a pairing that is
positionally associated but electrically separate is ever real, this is where it
goes, and whoever needs it will find this paragraph.

# What it does not rule

It does not build the trace docs/06 §4.7 promises, which is M5's and M6's. It does
not touch `isPassthrough`. And it does not decide what a pair means on a template
that is not `isPassthrough`: the column is hidden there, the pairs survive a
toggle, and `RemovePortCommand` still takes them with their ports.
