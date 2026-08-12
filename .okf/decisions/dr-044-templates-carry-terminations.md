---
type: Design Ruling
title: DR-044 — The shipped templates carry terminations, and a euroblock occupies no cell
description: >-
  DR-043 was wrong one clause deep and a census caught it before a line was
  built: nothing in this product can author an OutletTemplate, so the field it
  called load-bearing would have been null everywhere for ever.
tags: [ruling, m3, structure, templates, seed, g4, dr-007, dr-024, dr-043, dr-044]
timestamp: 2026-08-11T20:00:00Z
ruling_id: DR-044
canon_section: "11.43"
status: ruled
---

Settled by the user on 2026-08-11. This ruling exists because
[DR-043](dr-043-field-termination-entry-paths.md) §11.42.5 was wrong one clause
deep, and a census caught it **before a line of it was built**.

# What the census found

§11.42.2 made `OutletDrop.termination` **the load-bearing path**, on the argument
that a modifier serves the person already typing while the question was about the
person clicking. §11.42.5 then left the shipped templates null, because *"a shop
authoring its own template says what it terminates in"*.

**Nothing in this product can author an `OutletTemplate`.** No command, no
editor; the only writer of `registries.outletTemplates` outside test fixtures is
`buildSeedRegistries()` at document creation. `seed_outlet_templates.dart`'s own
header says so: *"NO LIBRARY FLOW ... This ships the master, not an editor for
it."*

The two clauses together would have produced a field **null on every template in
every document, for ever, with nothing able to set it**: the fifth instance of
[a modelled field is not a reachable one](/practices/a-modelled-field-is-not-a-reachable-one.md),
and the first caught **before** the field was written rather than in the next
milestone.

# Why the precedent was mis-cited

§11.42.5 leaned on [DR-024](dr-024-board-151-is-a-field-and-a-picker.md)
§11.23.2, which kept `tia570Grade` null on the six named templates because *"TV
location makes no standards claim"*.

**That is a ruling about a STANDARDS CITATION.** A citation asserts conformance
to an external document somebody must be answerable for. A termination is a fact
about the recipe of the same kind as the cable count already in it: *"TV location
= 2 × Cat6 + 2 × RG6"* already says what gets pulled, and saying the Cat6 lands on
a punchdown is that sentence continuing.

# The five values, and why asking beat offering

| Media | Termination | Source |
|---|---|---|
| `media.cat6`, `media.cat6a_futp` | **`punchdown`** | Stated. NOT the `keystone` that was recommended |
| `media.rg6_quad` | **`fBarrel`** | Stated, and the part in DR-007 §11.7.9's reference photographs |
| `media.22_4` | **`euroblock`** | Stated. Zero cells, so a keypad needs no keystone |
| `media.16_4` | **`bindingPost`** | Not asked again: already on the record in §11.7.2's supersession |
| `media.os2` | **`keystone`** | Stated. An LC keystone, one cell |

**`punchdown` over `keystone` is the row that proves the method.** Face-on the two
are the same object (§11.7.9 B), so the drawing is unaffected and the
**Termination Schedule** is not. Had the recommendation been taken, nothing would
have looked wrong and one printed column would have been quietly false on every
data drop in every job.

# A euroblock occupies zero cells

§11.7.2.1's table names `keystone`, `fBarrel` and the module family as one cell
per `Link` end, binding posts as one per `Conductor`, and `unterminated` and
`fieldConnector` as zero. **It does not mention `euroblock`.** M3-H put it at
**one**, silently, in the same arm as `keystone`.

The ruling is **zero**. A euroblock is a pluggable screw terminal on a *device*:
the conductors land on a keypad or an amplifier and no jack occupies a cell. The
keypad makes it concrete, because the device fills the gang, and a plate sized to
give it a keystone as well is one cell too big on every keypad drop in a house.

**How it was found is the reusable part.** Not by reading the code and not by a
test: by **seeding a value and having to say what the value meant**. The Keypad
template could not be seeded without answering "and how many cells is that".

> A fact you have to write down gets audited. A fact you infer does not.

# A sentence of this ruling was false, and the goldens caught it

§11.43.6 first claimed `registries.outletTemplates` is `{}` in every shipped
starter, so the seed would cost no file a byte. **All four starters carry all nine
templates**, and `starter_assets_test.dart` failed on every one.

**The claim was inherited, not invented.** It is a verbatim copy of a paragraph
that has sat on `OutletTemplate.tag` since DR-022, and **it was already false
there**: the same starters carry `tag` on six templates and `tia570Grade` on
three, on disk, today. Doc comment, to second doc comment, to normative ruling,
in three steps and one afternoon, each looking like a citation of the one before.

Neither existing rule fired.
[Two documents agreeing is not verification](/practices/two-documents-agreeing-is-not-verification.md)
did not apply, because it was not two documents: it was one sentence read twice.
**A sentence asserting a count is not checkable by reading the sentence**, and
what caught it was a test that reads the bytes.

# What is still unreachable

There is **still no authoring surface for `OutletTemplate`**, and this ruling does
not add one: DR-024 §11.23.4 records which surface edits the registries as
unsettled, and DR-033/DR-034 place the library flow in the community-catalog work.
The nine shipped templates now carry the fact, so the mouse path produces
arrangeable plates today. A shop wanting its own recipe still cannot have one, and
§11.43.5 records that as a live cap on §11.42.2's argument rather than a
discharged one.

# Scope

**No scope change to roadmap §2.** One clause of a same-day ruling is superseded,
one gap in DR-007 §11.7.2.1 is closed, nine seeded records gain a field, and four
golden starters are regenerated. `kSchemaVersion` does not move: an
omitted-when-null key is additive and an older reader skips it (CR-117).

# Citations

[1] canonical-decisions.md §11.43 and §12.18 (`docs/canonical-decisions.md`)
[2] canonical-decisions.md §11.42 (DR-043), §11.7.2.1 (DR-007), §11.23.2 (DR-024)
[3] `packages/rackmate_core/lib/src/catalog/seed_outlet_templates.dart`
[4] `packages/rackmate_core/test/structure/drop_line_termination_test.dart`
