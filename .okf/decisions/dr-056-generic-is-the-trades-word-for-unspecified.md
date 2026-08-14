---
type: Design Ruling
title: DR-056 — Generic is the trade's word for unspecified, so the builder pre-fills it
description: >-
  Raised as a contradiction between AC-049's three required fields and
  TemplateBody's constructor. There was none. The census run to check found the
  real unruled question one layer along, and trade convention settled it against
  the G4 argument.
tags: [ruling, m4, builder, g4, cr-114, ac-049, dr-056, trade-knowledge]
timestamp: 2026-08-14T00:00:00Z
ruling_id: DR-056
canon_section: "11.55"
status: ruled
---

Settled by the user on 2026-08-14, ratifying `docs/06-device-builder.md` §3.1's
existing sentence *"Defaults to `Generic`"* and giving it the ruling it never
had. It supersedes nothing, and **AC-049 is untouched**: the builder's three
required fields remain `displayName`, `frontU` and `typePrefix`.

# The question was raised as a contradiction, and there was none

M4-A closed with a flag: board `#175` names three required fields as
`displayName`, RU height and `typePrefix`, while `TemplateBody`'s constructor
requires `manufacturer`, `model` and `displayName`. Two different threes, so
which binds?

**Neither, because they are not claims about the same thing.** AC-049 rules the
FORM's required set and docs/06 §1 and §3 state it in terms; the constructor is
a Dart signature the builder satisfies by supplying values. **A constructor
parameter was read as a product rule.**

This is [re-read a task against canon](/practices/re-read-a-task-against-canon.md)
failing in exactly its own documented shape, and the cheap check that practice
prescribes, one grep of §11 for the task's nouns, would have caught it before it
was ever filed as open.

# The census run to check it found the real question

`docs/06` §3.1 has always said `manufacturer` *"Defaults to `Generic`"*. That
sentence lives in a **derived, priority-3 document**, and its stated reason is
about the seed: *"The whole seeded catalog is `Generic`"*, which 31 catalog
entries confirm. **That justifies the seeded bodies and says nothing about a
user's untouched field**, and the two diverge the first time somebody authors a
real device.

The difference is printed, not theoretical:

* `equipment_list.dart:428` runs `_trimToNull(body?.manufacturer)`;
* `equipment_sheet.dart:606` renders `row.manufacturer ?? kUnknownCell`;
* so a blank manufacturer reaches paper as `—` and counts as an unknown, and
  `Generic` reaches paper as `Generic` and counts as known.

# The ruling, and the trade fact behind it

**The form pre-fills the literal `Generic`.** `Generic` is standard within the
industry in a manufacturer column: the recognised token for *unspecified*, *by
others*, *contractor's choice*. It is therefore **not a fabricated value under
[G4](/invariants/g4-unknowns-are-counted.md)** but the trade's own spelling of
the same fact `—` states, on a document whose readers already know the word.

`model` is **not** defaulted and stays blank. No trade convention was offered
for a model string, and an invented one would be the fabrication the
manufacturer default is careful not to be.

# The objection, put and answered

Against: a value the user never typed reaches a client-facing deliverable, where
`Generic` would read as a claim that a real device is a no-name unit, and the
unknown rollup that exists to catch that before a sheet goes out cannot see a
field holding a value.

**That argument depends entirely on how a reader parses the word, and it was
wrong about the reader.** A convention the trade already reads as "unspecified"
is not misread as a product claim.

The same class has been overruled on the same grounds at canon §11.47 (DR-048:
*"the drawing machine is not on the rack's network"*, when a project copy at the
client's home routinely is) and at §11.54.7 (DR-055: two visits, therefore two
sheets). **Named rather than counted**, so the list stays true when there is a
fourth. The generalisation is why this ruling has a practice page beside it:
[trade knowledge beats workflow reasoning](/practices/trade-knowledge-beats-workflow-reasoning.md) -
put "how the trade works" objections as **questions, not findings**.

# One consequence, stated rather than hidden

The unknown rollup will report **zero** devices missing a manufacturer, because
the field holds a value. That is intended under this ruling and is not a defect
in `totals.dart`. A future reader finding *"0 devices have no manufacturer"*
beside a sheet full of `Generic` should read this rather than file a bug.

# What was offered and not taken

Making `TemplateBody.manufacturer`/`model` nullable, so an untouched field is an
**absent key** per CR-114 rather than an empty string normalised by
`_trimToNull` at read time. It would have cost a codec change, a migration for
the seeded templates and a [CR-117](/invariants/cr-117-byte-exactness.md)
re-verification. The present-key-holding-empty-string shape stands.

# Scope, and who builds it

No scope change to roadmap §2, no model change, no codec change, no migration,
and `kSchemaVersion` does not advance. **M4-D (`#175`) builds it**; nothing ships
with the ruling, because the form does not exist yet.
`TemplateBodyField.manufacturer` in `builder/template_commands.dart` carries the
citation, because that is where an implementer is standing when the question
comes up.

# Citations

[1] `docs/canonical-decisions.md` §11.55, AC-049 §2.3
[2] `docs/06-device-builder.md` §1, §3.1
[3] `docs/12-milestone-board.md` §5.3.1
[4] `packages/rackmate_core/lib/src/derived/equipment_list.dart`, `draw/sheet/equipment_sheet.dart`
