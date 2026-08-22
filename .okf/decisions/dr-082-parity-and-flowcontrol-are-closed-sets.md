---
type: Design Ruling
title: DR-082 — parity and flowControl are closed sets, and the corpus can now say so
description: >-
  Two shipped cells sat above a comment reading "a vocabulary the corpus has not
  ruled on". The refusal was right at M4-F and wrong to leave standing. No Other
  row ships, because a value set with a free-text row is a free-text column.
tags: [ruling, m4, port-grid, serial, g4, vocabulary, dr-075, dr-082]
timestamp: 2026-08-21T00:00:00Z
ruling_id: DR-082
canon_section: "11.81"
status: ruled
---

Settled by the user on 2026-08-21 (board `#747`, `#750`). **The only one of
`#747`'s three that blocks nothing**: it is a comment in shipped code, settled
because a census found it rather than because it stood in the way of anything.

# The comment was right to refuse, and wrong to leave standing

`port_commands.dart:300` declares `parity` as free text under the note that
*"a dropdown here would fix a vocabulary the corpus has not ruled on"*.
`flowControl` sits beside it on the same terms, and `SerialSpec` carries the
same disclaimer on both.

**That refusal was correct at M4-F.** Fixing a vocabulary while building a cell
is how a product acquires rules nobody decided, which is what
[a rule you invent must be checked against the good cases](/practices/a-rule-you-invent-must-be-checked-against-the-good-cases.md)
exists to catch. Leaving it refused indefinitely was the error, and nothing was
ever going to raise it except a census.

# The ruling

| Field | Values |
|---|---|
| `parity` | `none`, `even`, `odd`, `mark`, `space` |
| `flowControl` | `none`, `rtsCts`, `xonXoff` |

# Five values where the model comment suggests three

`SerialSpec.parity` reads *"e.g. `none` | `even` | `odd`"*. It says **e.g.** and
was illustrating rather than enumerating:
[a spec table is an illustration until censused](/practices/a-spec-table-is-an-illustration-until-censused.md),
applied to a doc comment.

The five are RS-232's own set rather than an invention here. **Whether `mark` and
`space` appear on gear a RackMate user actually meets is a trade question, and
this ruling does not claim to answer it**:
[trade objections are questions, not findings](/practices/trade-knowledge-beats-workflow-reasoning.md)
has beaten a confident claim from this side of the keyboard four times, and this
is not the fifth. The argument is asymmetric cost and nothing else: an unused
enum value costs one line, while a missing one costs a workaround in the notes
column on a port somebody has to physically wire. If the trade says two of the
five are dead, deleting them is a smaller edit than this paragraph.

# Why a free-text column is the defect, not the typing

One column holding `none`, `NONE`, `N` and `no parity` is four values for one
fact. The grid **sorts**, [DR-078](dr-078-the-five-grid-operations.md)'s
`Find & replace` **matches**, and the schedule **prints**. A column that cannot
be sorted is a defect in the schedule, and it is not repaired by asking users to
be careful.

# No `Other` row, and this clause has an argument

An escape hatch re-introduces exactly the dirty column the value set exists to
prevent, and [G4](/invariants/g4-unknowns-are-counted.md) already supplies what
an escape hatch usually reaches for: absent means unknown, and the grid renders
it today. **A value set with a free-text row is a free-text column wearing a
dropdown.**

# Migration is nearly empty, and the remainder follows DR-075

**0 of the 727 seed ports author either field**, so nothing seeded needs mapping
and no starter moves. A value already typed into a project that does not match
the set is **retained and shown as it was typed**, not silently dropped. DR-075
(canon §11.74) settled this shape one domain over for an imported rack label,
and its reasoning transfers unchanged: a wrongly discarded assertion is gone,
while a retained one is visible and correctable.

`busProtocol` sits three declarations away and is **deliberately untouched**:
there is no closed set of control-bus protocols, and it stays free text for
precisely the reason `parity` no longer does.
