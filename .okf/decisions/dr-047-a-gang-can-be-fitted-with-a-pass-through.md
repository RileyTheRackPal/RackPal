---
type: Design Ruling
title: DR-047 — A gang can be fitted with a pass-through, and the plate follows from what is in it
description: >-
  The brush plate DR-045 filed and did not model. Asked as "outlet or drop", the
  answer is neither: a gang opening somebody decided gets no strap is the third
  scale of a distinction this project has already got wrong twice.
tags: [ruling, m3, structure, plate, materials, g4, dr-007, dr-045, dr-047]
timestamp: 2026-08-12T18:00:00Z
ruling_id: DR-047
canon_section: "11.46"
status: ruled
---

Settled by the user on 2026-08-12, answering the question
[DR-045](dr-045-rj45-plug-and-plateless-outlet.md) §11.44.6 filed as board #678:
some off-plate runs still come through a **pass-through or brush plate**, which
*"occupies no strap cell and IS a purchasable line item"*, and nothing in the
model could say so.

# Asked as "outlet or drop"; the answer is neither

§11.44.6 named two places the fact could live. A census before pricing found a
third, **already built and already carrying the right distinction**: `Gang.strap`
is nullable, and null means *nobody has picked a part yet*. A brush plate is a
gang opening somebody has **decided** gets no strap, which is a different fact.

**That is DR-007 §11.7.4's distinction at a third scale, and the two below it are
already ruled:**

| Scale | Undecided | Decided, and a purchase |
|---|---|---|
| cell | no entry | `BlankInsert` (§11.7.4) |
| outlet | no drops land here | **needs no plate** (§11.44.4) |
| gang | no fitting chosen | **a pass-through** (this ruling) |

**Each of the first two was got wrong once and cost a correction.** The cell case
is what `gang.dart`'s header exists to defend; the outlet case shipped at M3-H
reading *"no gangs yet"* over a finished AP box and was fixed a milestone later.
The third is ruled before it is built rather than after.

**Not the drop.** `StructureOrigin.outletId` is **non-nullable**, so every drop
already has an outlet and the drop buys nothing. It costs: three runs through one
brush plate become three claims about one physical object, two drops sharing a box
can disagree about what covers it, and a materials line would have to de-duplicate
by `outletId` to recover the outlet-level answer.

**Not a plate kind on the outlet.** It cannot express a **mixed plate** (one
2-gang plate, a keystone strap behind one opening and a brush at the other), and
it is a **second copy of a fact the gangs carry**: a gang holding six keystones
requires a Decora opening, so a document could assert `brush` over it with nothing
to catch the contradiction. CR-107 deleted `StructureDrop` over that shape.

# `Gang.strap` becomes `Gang.fitting`

```
GangFitting (sealed, nullable)
  ├─ Strap        W x H cell grid, exactly as today  [DR-007 §11.7.1]
  └─ PassThrough  a hole in the plate, with a style  [NEW]
```

Null still means UNKNOWN and is still an absent key on the wire
([G4](/invariants/g4-unknowns-are-counted.md), CR-114).

**The rename is not cosmetic.** A `Strap?` field makes *"this opening is a brush"*
unsayable, and the sealed switch is what forces every reader to say which of the
three states it means. **No convenience getter returns null for a pass-through**,
because that is exactly the collapse this ruling removes.

# Two styles, and the vocabulary was asked

`brush` and `bullNose`. The user names three parts they buy: a whole brush or
pass-through plate, a **Decora-format brush insert**, and a **bull-nose or grommet
plate**. The first two are the same opening in two forms, and the derivation below
decides which; the third is a different opening and is the second value.

**A keystone-format brush insert was offered and declined**, so there is no fourth
`CellOccupant` and nothing here touches a strap's cells. Recorded because a
declined option is evidence and an unasked one is not: this is §11.44.2's standing
enum-growth question, asked and answered in the same breath as the fitting.

# The plate is derived, and the rule is total

| The gangs | The plate | The inserts |
|---|---|---|
| none at all | **no plate** (§11.44.4's plateless outlet, unchanged) | none |
| every one a pass-through, **all one style** | one N-gang plate **of that style** | none |
| any gang holds a strap, or the styles differ | one N-gang **Decora** cover plate | one per pass-through gang |
| any gang's fitting unchosen | as above for what IS chosen | a **lower bound**, read beside that count |

**The middle rows are a fact about stock, not about the model.** Nobody
manufactures every Decora-plus-brush combination, so a plate with a strap behind
one opening and a brush at another is bought as a standard plate plus an insert.
Mixed styles fail the same way, which is why the rule keys on *one style* rather
than on *all pass-through*.

**No field records which form was bought, and §11.27.2 is why.** A derivation with
its reasoning written down outranks a stored field without one, so a shop that
stocks Decora plates and inserts rather than brush plates can be served later by an
override that wins **with nothing to withdraw**. The alternative was a plate-form
field null on every outlet in every existing document.

# What the counts do

`PlateFill` gains a pass-through count and renames `strapsUnchosen` to
`fittingsUnchosen`: **a gang destined for a brush was never a strap nobody chose**,
and a name that has stopped describing its field is worse than a missing one.

A pass-through provides **zero cells** and blocks nothing, so a plate whose every
opening is decided is `isSettled` whether or not any of them holds a jack.

**`needsNoPlate` does not move**, and that is the correction. It stays
`gangCount == 0`: an outlet covered by a brush plate is **not** a plateless outlet,
it is an outlet with a plate that has no jacks in it.

# `Arrange` neither invents one nor destroys one

`planPlateArrangement` sizes straps from what the drops need in cells. A
pass-through is a decision about a part, so a plan that invented one would assert a
purchase nobody made. The other direction matters more: `Arrange` over an outlet
whose openings a designer has already brushed must not replace them with straps
sized for zero cells.

# Scope

**No scope change to roadmap §2.** One sealed type, two enum values, one command,
one picker, one derived rollup. **`kSchemaVersion` does not move**: the `strap` key
is written exactly as before, and `passThrough` is a key no document in existence
contains, which is [CR-117](/invariants/cr-117-byte-exactness.md)'s additive case.

# Citations

[1] canonical-decisions.md §11.46, §12.19 (`docs/canonical-decisions.md`)
[2] canonical-decisions.md §11.7.4, §11.7.8 (DR-007), §11.44 (DR-045), §11.27.2
[3] `packages/rackmate_core/lib/src/model/gang.dart`
[4] `packages/rackmate_core/lib/src/derived/plate_fill.dart`
