---
type: Decision
title: DR-062 — Fill series infers its sequence from the top selected cell
description: docs/06 §4.6 says fill series re-applies "the label pattern"; no such pattern is stored anywhere in the tree, and storing one would cover only the ports Quick Add made.
tags: [m4-f, grid, fill, labels, ux, g4]
timestamp: 2026-08-15T00:00:00Z
ruling_id: DR-062
canon_section: "11.61"
status: built
---

`Ctrl+Shift+D` reads the **last run of digits** in the top selected cell and
counts from there. `IN 01` yields `IN 01, IN 02, IN 03`.

# The census, which found the artifact missing

docs/06 §4.6: *"Re-applies **the** label pattern across the selection with a
fresh `start`."*

| | Finding |
|---|---|
| `PortDef` | no pattern field |
| `BankDef` | `key`, `label`, `abbr`, `symbolSide`, `collapseInSymbol`, `order` |
| `TemplateBody` | no pattern field |
| `LabelPattern` | referenced by **two files**: its own and `quick_add.dart`, where it lives in a `TextField` and dies when the bar clears |

The definite article points at nothing. This is [a modelled field is not a
reachable one](/practices/a-modelled-field-is-not-a-reachable-one.md) inverted:
not a field with no gesture, but a gesture naming a field nobody modelled.

# The row four lines below settles the shape

`Renumber…` `Ctrl+R` reads *"re-applies **a** label pattern to the selection"*.
**Indefinite article, and an ellipsis**, which by convention means a dialog.
`Fill series` has neither.

So the corpus already separates them: one asks for a pattern, the other works it
out. A prompting `Fill series` would be `Renumber…` with a second binding, and
one of the two would have to go.

# The last digit run, not the first

Labels here routinely carry a standard's number before the port's:

```text
HDMI 2.0 IN 1   ->  HDMI 2.0 IN 2
802.3bt PORT 4  ->  802.3bt PORT 5
RS-232 CTL 2    ->  RS-232 CTL 4
```

A first-run rule counts the standard and leaves the port number alone, which is
wrong in exactly the cases that matter most.

**The top cell is the start**, which is what *"a fresh `start`"* becomes once the
pattern is inferred: fresh relative to the selection, not to the bank. Selecting
rows 9 through 16 keeps them 09 through 16; restarting at 1 would renumber them
over the eight above.

# Why not store it

`BankDef.labelPattern` is the only reading that makes *"the"* literally true, and
it was rejected on **coverage** rather than cost. It is null for every port made
by `+ Add port`, by paste (M4-I3), or by any archetype generator M4-I builds, so
the feature would work on Quick Add's banks and decline everywhere else.
Inference works on all of them.

# A refusal is a sentence, never a silence

Five ways a fill declines, each naming the way forward: fewer than two rows, no
focused column, a column no fill may write, a series asked of a non-text column,
and a top cell with no digits.

**A key that quietly does nothing is indistinguishable from one that is not
bound**, which is how a person concludes a feature does not exist. `SPEAKER`
refuses rather than falling back to a copy, because the fallback would be
discovered sixteen rows later.

# Text-only, and narrowly

Three columns carry a series: `LABEL`, `DESIG`, `NOTES`. `poeWatts` 15, 16, 17
would rewrite a bank's electrical facts as a counting sequence. **`SET` and
`ROLE` are excluded for a stronger reason**: they are keys into `PortSetDef`, so
a series down one invents memberships no set declares, which is the
dangling-reference state the grid draws a red band for. Both still fill *down*.

# What the implementation cost, and the two type facts behind it

A fill has to write a column chosen at runtime, and the obvious move fails twice.

`PortDefField.all` is a `List<PortField<Object?>>`, which is sound only because
nothing calls `.set` through it. A `PortField<T>` holds `void Function(PortDef,
T)`, and **function types are contravariant in their parameters**, so `(PortDef,
String) => void` is not a `(PortDef, Object?) => void`. Reading `.set` off an
upcast field throws before the call is made.

The fallback of testing the type at runtime is closed too: the ids are
`extension type const ConnectorTypeId(String v)`, **erased at run time**, so a
`PortField<ConnectorTypeId>` IS a `PortField<String>` while running. A series
would have written `IN 02` into a connector id and nothing would have objected.

So the static type is kept at the switch arm where it is known, and what escapes
is a closure already checked.

# Citations

[1] canonical-decisions.md §11.61 (DR-062)
[2] docs/06 §4.6, the `Fill series` and `Renumber…` rows read against each other
[3] `packages/rackmate_core/lib/src/builder/port_fill.dart`
[4] Board `#208`; `#697` is the `Renumber…` this keeps distinct
