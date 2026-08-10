---
type: Playbook
title: Two documents agreeing is not verification
description: >-
  Three times now a field has been named by a ruling AND by a design document and
  existed in neither the model nor the codec. Agreement between two documents
  reads exactly like a check, and is the one form of confirmation that costs
  nothing to produce and nothing to be wrong about.
tags: [practice, verification, corpus, drift, model, dr-037]
timestamp: 2026-08-10T12:00:00Z
status: adopted
---

**A ruling and a design document can agree with each other without either having
read the model.** When they do, the second mention does not confirm the first; it
inherits from it. Reading both and finding them consistent feels like
verification and is not, because the disagreement that would have caught the
error was never available: they have one source between them.

The test is one `grep`, and it has now paid three times.

# The three

**`MediaTypeDef.maxLength` (canon §11.19.7).** DR-020 §11.19.2(4) asked for *"a
new `maxLength` on the media registry"* and three derived documents named the
same field. There was no such field and there never was one to add: the registry
has carried `maxRunLengthPassive` and `maxRunLengthActive` since M0. The ruling
that fixed it says why it was ruled rather than left in a board comment: *"the
next reader to implement `LEN-002` would otherwise add a third."*

**`unknown` on `Placement` (§11.18.1).** DR-018 asserted that omitting the plan
carrier would cost a format migration. It would not: the format already absorbed
it. What DID exist was a smaller and realer G5 item nobody had named, because
`json_codec.dart` decoded `OffRackPlacement` as exactly two fields and re-encoded
exactly those two, so an older build **silently dropped plan pins on save**. The
ruling's own summary: the reasoning *"was assumed from the shape of the question
rather than checked against `persistence/`."*

**`Location.riseAllowance` (DR-037 §11.36.5).** DR-020 §11.19.2(1) defines
`planLowerBound` as the straight line *"plus the location's `riseAllowance` if one
is set"*, and docs/15 §4.1 repeats it. Zero occurrences in every `.dart` file in
the tree, four days and several citations later. Found while decomposing the epic
that would have been the first thing to read it.

# Why this shape and not carelessness about names

All three were **specified correctly**. Nobody misremembered what the field
should do; `riseAllowance` is exactly the right field and DR-037 adds it verbatim.
What went missing in all three is the step between specifying a field and it
existing, and the reason that step is skippable is that **the corpus is large
enough for a specification to be cited before it is built**. A citation reads as
evidence of existence. It is evidence of intent.

The pattern also explains why it keeps happening in the same place: a *design
document* is the artefact most likely to name a field, and a *ruling* is the
artefact most likely to cite the design document.

# What to do

**Grep the identifier, not the concept.** `riseAllowance` returns nothing in a
second; "does the plan account for vertical drop" returns three documents that
say yes.

**Do it when the field is first read, not when it is first written down.** All
three were caught by the task that was about to consume the field, which is the
latest possible moment and still cheap. The earlier moment is when a ruling cites
a field it did not itself introduce.

**Treat two citations as one.** If a ruling and a design document both name a
field, ask which of them introduced it. The other one is not a second source.

Related: [census before building](/practices/census-before-building.md), which is
the same discipline one level down: that one checks whether a field that exists
is *populated*, this one checks whether it exists at all. And
[re-read a task against canon](/practices/re-read-a-task-against-canon.md), which
catches the mirror case: a task description that is stale because a ruling moved
under it.
