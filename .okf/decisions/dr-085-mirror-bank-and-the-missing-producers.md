---
type: Design Ruling
title: DR-085 — Mirror bank, and the two models with a reader and no writer
description: >-
  The whole specification of Mirror bank is one table row, and reading it as a
  spec produces three questions it cannot answer. The census beside it found the
  larger thing: the SET dropdown ships live over a list nothing can add to.
tags: [ruling, m4, m4-j, banks, port-sets, passthrough, cr-051, cr-060, dr-078, dr-085]
timestamp: 2026-08-22T00:00:00Z
ruling_id: DR-085
canon_section: "11.84"
status: built
---

Settled by the user on 2026-08-22 (board `#181`, `#760`), at M4-J's pick-up and
**before any code**. A decomposition ruling: `Mirror bank` is already in scope
and [DR-078](dr-078-the-five-grid-operations.md) records that it was deliberately
left untouched.

# The whole specification is one table row

docs/06 §4.6: *"Duplicates a bank with direction flipped and the label prefix
swapped IN↔OUT, the output side of a matrix in one click."*

That is an illustration, and reading it as a specification produces three
questions it cannot answer:
[a spec table is an illustration until censused](/practices/a-spec-table-is-an-illustration-until-censused.md),
for the fifth time this milestone.

# The census found something larger than the missing action

| Model | Writers outside the seeded catalog | The surface reading it |
|---|---|---|
| `PortSetDef` | **none** | a **live** `SET` dropdown built from that empty list |
| `PassthroughPairDef` | **none that create one** | `PAIRED WITH`, read-only |
| `BankDef` | one, `quick_add.dart:721` | the grid's bands, and `Ctrl+M`'s destinations |

**A person authoring a template from scratch opens the `SET` picker and finds
one entry, `—`, and will find only that one forever.**

This is
[a modelled field is not a reachable one](/practices/a-modelled-field-is-not-a-reachable-one.md)
**with the halves reversed**. The practice was filed on `NetworkConfig`, a field
whose only writer was the JSON decoder: a writer and no reader. Here the READER
shipped, is editable, and waits on a producer that does not exist. **So M4-J is
the two missing producers, and `Mirror bank` is its smallest task rather than its
largest.**

# The three clauses

**`source` and `sink` flip; the other three copy through.** CR-060 gives five
directions and only two are opposites. The preview names every row it leaves
alone, which is DR-078's `Change type…` affordance reused, **not its reasoning**:
that refuses to write `direction` because the model cannot tell a chosen value
from a defaulted one, while a mirror is a person asking for a flip in so many
words. What carries over is the honesty about what was untouched.

**`IN`/`OUT` swap where they occur; otherwise the person names the bank.** The
row's example is a matrix, where banks really are called `IN` and `OUT`. The
general case is not: `uniqueBankName` derives a label from the signal family, so
a Quick Add bank is `HDMI` or `HDBaseT` and has nothing to swap. These are
silkscreen labels that reach the panel drawing and the schedule, and no device
has `(mirrored)` printed on it. [G4](/invariants/g4-unknowns-are-counted.md)'s
temperament applied to a string: where the answer is not known, ask.

**New keys derive from the new bank key**, through Quick Add's generator. The
mirrored ports are NEW ports, so nothing writes a `renamedFrom` and CR-051's join
is untouched. Suffixing the source key reads well in a diff and is declined for
that appeal: it encodes a relationship in a string no field records, and a key
that means something is a composite key wearing a different hat.

# Built 2026-08-25

All three clauses ship (`#223`, `87e8034`, `9c9c31d`). `Mirror bank` is on a menu
built once by `bankMenuItems` and hung off two places: the rail's bank tree and
the grid's band header. `mirrorBankImpact` reads its `after` column off the port
the command will actually add, so the preview that names the untouched rows
cannot disagree with the write; the summary line says *"3 rows matched, 2 will
change, 1 to check"*, which is clause 1 arriving as a sentence.

**The bank-delete cascade below was left to M4-J1 and M4-J1 answered it:
removing a bank keeps every port and clears its `bankKey`.** CR-055 makes a bank
PRESENTATION, so taking authored ports with a cosmetic action would destroy data,
and it CLEARS rather than dangles on `RemovePortCommand`'s precedent one type
over. The ports land in `Not in a bank`, which the grid already draws.

**The census's larger half is still open.** `#224` gives `PortSetDef` its
producer and `#225` gives `PassthroughPairDef` its own.

# What it does not rule

It does not pair the two banks: a matrix's mirrored output is a **second
output**, not a passthrough. It does not decide the bank-delete cascade, which is
DR-013's family and M4-J1's own. It does not give `PortSetDef` its producer,
which is M4-J2 and is the larger half of this issue.
