---
type: Design Ruling
title: DR-024 — Board #151 is a model field and a picker; its data half already shipped
description: #150 closed over half of #151 without either being wrong. The three TIA-570-D presets shipped with the seed; what is left is the one field that lets a preset stamp its own standards tag, and the gesture that places it.
tags: [ruling, m3, outlet-templates, scope, dr-024]
timestamp: 2026-08-08T00:00:00Z
ruling_id: DR-024
canon_section: "11.23"
status: ruled
---

Settled by the user on 2026-08-08, after board #150 closed at `5abb8b3`.

# What #150 already delivered against #151's own brief

#151 is *"TIA-570-D presets"*, and it stated the reason they are not
decoration in its own words: **"Grade is a CITATION, not a suggestion: it
names a published standard, so a preset that does not match the standard
is a wrong fact in the document (G4). Transcribe with the source beside
it."**

`outlet.tia570d_grade1`, `2` and `3` shipped with the nine seeded outlet
templates, transcribed from docs/07 §1's table with that source named,
**including the part that reads oddly**: docs/07 gives Grade 3 a lower
twisted-pair grade and fewer coax than Grade 2, which is not how the
published standard stacks them. Correcting it silently in code would have
made the seed disagree with the document it claims to transcribe, so the
transcription stands and the disagreement is flagged for docs/07.

So the task's data half is done, and what remains is neither presets nor
data. It is re-scoped rather than left to be found half-finished.

# The remainder is one model field

**`OutletTemplate.tia570Grade: String?`.**

CR-108 keeps `Outlet.tia570Grade` a **standards tag, never an axis**, and
the whole-house fixture sets it by hand. A grade preset therefore cannot
stamp the one field it exists to carry, and the picker has nothing to
copy from.

**The rejected answer is a builder special case on the three seeded ids.**
Cheaper, needs no model change, and keys the behaviour to the strings
`outlet.tia570d_grade1..3`. It fails on the property CR-108 exists to
protect: user-defined templates are **first-class**, so a shop authoring
its own Grade 2, or one citing a builder's spec rather than TIA's, could
never stamp anything. It also makes an id rename a silent behaviour
change, which a `String?` on the entity is not.

**Not a migration, and CR-117 is not at risk.** The key is additive and
absent when null, so the six named templates write nothing and re-encode
byte for byte. A document written between `5abb8b3` and this change
carries the three grade entries without the key; reading yields null,
writing omits it, and `write(read(bytes)) == bytes` holds. Same contract
`tag` landed on in [DR-022](/decisions/dr-022-service-token-is-the-template-tag.md).

# The picker is `+ Add outlet ▾`, and no task claimed it

docs/07 §4's button bar carries it and §4.3 says what it does:
instantiate an `OutletTemplate` in one action, *TV location* into one
`Outlet` with four `Link`s and four label pairs. #148 is the table's rows
and columns, #149 is the matrix tab; neither description mentions it, and
#150 shipped the master without any gesture to instantiate it.

One `Command`, one undo entry, and it stamps `Outlet.tia570Grade` from
the template. It is also **the first caller of
[DR-023](/decisions/dr-023-service-fallback-chain.md) step 2**: the
chain's middle arm, the outlet's template tag, has had no way to be
reached, because nothing until now creates an outlet *from* a template.

# What it does not rule

The **library flow** that edits templates. CR-108 makes user-defined
templates first-class and the registries are ordinary editable stored
data after the seed copy (docs/03 §5.6), but which surface edits them is
not settled here.

Nor **AC-034/m24**, *"which location fields the inspector demands is
driven by the template"* — a ceiling speaker pair asks for
`mountSurface: ceiling` and never for a wall compass direction. That
needs a second model field and a UI contract, and folding it in would
repeat the mistake this ruling corrects.

# Scope

**No scope change to roadmap §2.** #151 is narrowed in one direction and
named in the other. The task count is unchanged and no milestone moves.

# Citations

[1] canonical-decisions.md §11.23 (`docs/canonical-decisions.md`)
[2] CR-108, outlet templates first-class and grades as a tag
[3] docs/07-structure-device.md §1 (the grade table) and §4.3 (the gesture)
[4] `packages/rackmate_core/lib/src/catalog/seed_outlet_templates.dart`,
    the nine seeded templates and the absences its header names
