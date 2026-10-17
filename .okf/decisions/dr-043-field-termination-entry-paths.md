---
type: Design Ruling
title: DR-043 — The field termination gets three entry paths; the default stays Unspecified
description: >-
  Nothing in the product could set the field termination, so M3-H's Arrange
  refused every drop it could create. The fix that mattered was not the modifier
  the board asked for: it was the template field, because the mouse path was the
  one route that could not express the fact.
tags: [ruling, m3, structure, drop-line, templates, g4, dr-007, dr-024, dr-043]
timestamp: 2026-08-11T18:00:00Z
ruling_id: DR-043
canon_section: "11.42"
status: superseded-in-part
superseded_by: [DR-044]
---

Settled by the user on 2026-08-11, from board #668: nothing in the product sets
`StructureOrigin.terminationField`, so DR-007 §11.7.2.1's cell-count table has no
input and M3-H's `Arrange` correctly refuses every drop the product can create.

# The default does not move

`terminationField` stays **nullable, defaulting to null, meaning Unspecified**.

M3-J made it nullable precisely so neither entry surface would write a value it
did not have, and both surfaces' own code called `unterminated` *"the nearest
true value, not the right one"*. **Nothing here re-introduces that guess.** A
drop created by any path below still comes out Unspecified unless somebody said
otherwise. See [G4](/invariants/g4-unknowns-are-counted.md).

# Three paths, and the ordering is the argument

The question that produced this was *"do we have a GUI path yet? Typing a large
amount of text is going to put off a lot of people."* A census found **five**
drop-entry surfaces, four of them already mouse-driven: `+ Add outlet ▾`, the
Matrix tab, the table's cells, and CSV import. The typed line is one of five.

| Path | Gesture | Who it serves |
|---|---|---|
| `OutletDrop.termination` on a template | **zero extra clicks** | the mouse-first person |
| `4x Cat6:keystone` on the drop line | 9 characters per item | the typist |
| Multi-select and batch set | tick rows, set once | fixing a house after the fact |

**THE TEMPLATE IS THE LOAD-BEARING ONE AND IT IS NOT WHAT WAS ASKED FOR.** #668
proposed a modifier. A modifier serves the person already typing and does nothing
for the person clicking, who is the one the question was about. A template
already says *"TV location = 2 × Cat6 + 2 × RG6"*, and **how that Cat6 terminates
is a property of the recipe rather than of the day**.

Shipping only the modifier would have left `+ Add outlet ▾`, the one route a
mouse-first person lives in, as the single route that could not express a
termination.

# Why a colon and not another modifier

Items parse as `count` + `mediaToken`; the five existing modifiers are
**line-level**, scanned off the end. A per-item termination is a genuine grammar
change, not another modifier.

`4x Cat6:keystone` binds to the item it follows and costs **9 characters against
`@term=`'s 15**, which matters when AC-018's measured script is 433 keystrokes.
The second ground is worse than the count: `@term=` would look identical to five
modifiers that apply to the whole line while applying to one item, with nothing
in the syntax to say so.

**The separator was checked, not assumed.** No media display name or alias in the
seed catalog contains a colon. They contain spaces and slashes (`Cat6 F/UTP`,
`16/4`), and the room separator is the line's *first* colon at a different
nesting level, so an item's own first colon is unambiguous.

# No alias is invented

A token matches `terminationLabel`'s spelling and the enum name, both normalised
for case and non-alphanumerics: `f barrel`, `fbarrel`, `F BARREL` and `fBarrel`
all reach `TerminationType.fBarrel`.

**Nothing shorter is accepted.** `post` does not resolve to `bindingPost`,
because inventing trade shorthand in a parser is how a product ends up with two
vocabularies, and a refusal that lists the accepted set is the cheaper teacher.

# The six shipped templates stay null

> **SUPERSEDED BY [DR-044](dr-044-templates-carry-terminations.md) THE SAME DAY**,
> before a line of it was built. **Nothing in this product can author an
> `OutletTemplate`**, so the sentence below describes a capability that does not
> exist, and this clause together with the template argument above would have
> produced a permanently unreachable field. The DR-024 precedent is also
> mis-cited: that ruling refused a *standards citation*, and a termination is a
> recipe fact of the same kind as the cable count already in the recipe. **All
> nine shipped templates are seeded.**


**This is [DR-024](dr-024-board-151-is-a-field-and-a-picker.md) §11.23.2's
refusal repeated deliberately.** That ruling kept `tia570Grade` null on all six
because *"TV location makes no standards claim, and writing one would put a
citation in a document nobody made"*. A termination is the same class of claim.

A shop authoring its own template says what it terminates in. The shipped six say
nothing and produce Unspecified, which is the honest output.

# Multi-select is new machinery

The table has **no selection model today**; docs/07 §4's wireframe draws row
checkboxes that nothing implements. The batch goes through the same refusing
builder a single cell edit does, is **one undo entry** on `importCsv`'s
reasoning, and is **all or nothing**, because a batch that wrote nine of ten rows
and reported an error leaves a person to work out which nine.

# Scope

**No scope change to roadmap §2.** `OutletDrop` gains one nullable field, the
drop-line grammar gains one production, and the table gains a selection model it
was already drawn with.

M3 gains an issue, **M3-L**, which is a decomposition gap rather than a growth:
the clause was never in an exit criterion, and DR-007 §11.7.2.1 named
`TerminationType` as *"the hook M3 should read"* while saying nothing about what
writes it. That is the same shape as
[a modelled field is not a reachable one](/practices/a-modelled-field-is-not-a-reachable-one.md),
found the same way, by trying to use the thing.

# Citations

[1] canonical-decisions.md §11.42 (`docs/canonical-decisions.md`)
[2] canonical-decisions.md §11.7.2.1 (DR-007), §11.23.2 (DR-024), §11.19 (DR-020/M3-J)
[3] `packages/rackmate_core/lib/src/structure/drop_line_parser.dart`
[4] `packages/rackmate_core/lib/src/model/outlet.dart`
