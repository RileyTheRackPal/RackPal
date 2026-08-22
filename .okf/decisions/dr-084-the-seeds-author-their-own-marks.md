---
type: Design Ruling
title: DR-084 — The seeded catalog authors its own marks, so seventeen does not ship as nine
description: >-
  0 of 48 seeded templates author a glyph, so the seventeen-mark set resolved to
  nine category defaults and eight marks were unreachable. The test that missed
  it was green and correct: an existence assertion cannot see a collapse.
tags: [ruling, m4, m4-r, catalog, glyph, census, dr-059, dr-083, dr-084]
timestamp: 2026-08-21T00:00:00Z
ruling_id: DR-084
canon_section: "11.83"
status: ruled
---

Settled by the user on 2026-08-21 (board `#694`, `#758`), from a probe run while
building `#753` and before the mark had reached a single sheet.

**A roadmap §8.3 amendment, narrow.**
[DR-059](dr-059-the-device-glyph-ships.md) ruled the seventeen marks in and ruled
the category defaults; it left the seeded catalog's own `glyph` field alone. This
changes that one thing. The cap stays at seventeen and `kCategoryDefaultGlyph`
keeps doing its job for every template nobody has authored.

# The measurement is the whole argument

A probe over `buildSeedCatalog()` at `64b953c`:

| | |
|---|---|
| Templates authoring a `glyph` | **0 of 48** |
| Distinct marks the 48 actually draw | **9**, not 17 |
| Marks no seeded device ever draws | **8** |
| Ids resolving to `display` | **18**, the whole `Field Devices` category |

So on any project nobody has hand-edited, a speaker, a camera, a keypad and a
projector all draw a rectangle on a stand.

# DR-059 saw it and deferred it, which is why this is an amendment

`device_glyph.dart` says so unprompted: *"`display` is the modal answer rather
than the right one, which is why the form's picker matters more here than
anywhere else."* A defensible call. What it costs is the **first impression**:
the elevation is the sheet taped inside the rack door and the mark's job is to be
right at a glance on a document nobody edited.

# The assignment was already written down

Every `DeviceGlyph` value's doc comment names the catalog ids that motivated it.
DR-059 calls those ids *"the evidence that the set was censused rather than
invented"*. **This turns that evidence into the assignment it always described**,
so no judgement is added: a table already in the tree is transcribed onto the
field that reads it.

# The test was green, correct, and asking the wrong question

`device_glyph_test.dart` asserts *"every one of the 48 seeded templates resolves
to a mark"*. It has always passed, because they do.

**An existence assertion cannot see a collapse.** Forty-eight resolving to nine
satisfies it exactly as well as forty-eight resolving to seventeen. The number
that mattered was never asked for, and the replacement asks for the **count of
distinct marks**.

That is [census before building](/practices/census-before-building.md) for the
sixth time, with a twist worth naming: the earlier five found a field that was
**empty**, and an empty field is caught by the first query anybody writes. This
one found a field that **resolves perfectly and collapses**, which survives every
query except the one that counts the range.

# What it costs, stated before it is discovered

**This ruling's own first draft got the mechanism wrong, and that is recorded
rather than quietly fixed.** The draft said the key *"is written only when it
differs from the category default"* as though the codec did that.
`json_codec.dart:3420` writes `glyph` whenever it is **non-null**, and its comment
says why: *"Absent means INHERIT THE CATEGORY'S DEFAULT, not unknown"*, and
writing a resolved value would *"lose the author's choice the moment the category
changed"*.

So the economy is a property of **what is authored**, not of the codec.
**Twenty-six of the forty-eight** get a `glyph`, being those whose mark differs
from their category default; the other twenty-two inherit and stay null. Those
twenty-six move bytes, and **the four checked-in starters must be regenerated** or
a starter draws the old category mark while a new project draws the authored one.

That is the third DR-059 sentence to fail against the tree in three days, and the
first of mine: see [a stated cost is a hypothesis](/practices/a-stated-cost-is-a-hypothesis.md).

`accentColor`'s seeds stay unauthored on purpose: an accent is the author's own
mark and a seeded catalog has no business choosing one. See
[DR-080](dr-080-the-accent-reaches-the-elevation.md).
