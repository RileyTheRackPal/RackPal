---
type: Design Ruling
title: DR-102 — The palette answers for the document AND the loaded libraries, and a template in two of them is two rows
description: >-
  The palette's single source was `buildPlaceableTemplates(doc)`, a property
  DR-077 made explicit and guarded with a test. M4-N makes it answer for N
  libraries too. One merged list tagged by source, a template id in two sources
  appears once per source, and `TemplateProvenance` becomes a sealed class
  rather than an enum beside a nullable field.
tags: [ruling, palette, library, rmda, provenance, dr-077, dr-101, cr-104, cr-050, m4]
timestamp: 2026-08-29T00:00:00Z
ruling_id: DR-102
canon_section: "11.101"
status: built
---

# DR-102 · The palette answers for every shelf

Board `#241` and `#242`, under `#170` (M4-N). Settled by the user 2026-08-29,
before any code, on the precedent this milestone had by then set four times
(DR-077, DR-098, DR-100,
[DR-101](dr-101-an-id-collision-on-import-is-a-question.md)).

## The census found a chapter already built

`#241` read: *"THE ITEM MOST LIKELY TO BE UNDERESTIMATED. Nothing carries this
today. It is a field on a RUNTIME object, NOT on `TemplateBody`, because the same
template can legitimately arrive from two libraries."*

**`TemplateProvenance` already existed, on a runtime object, in exactly that
shape**, built at M4-S with two values and a class comment already reasoning
about what the build cannot tell apart. The architectural call the chapter was
going to make was made and shipped, and what remained was the widening. That was
the fifth time in one milestone a chapter written from an absence met a filled
one, and the first time the surprise was in the cheap direction. See
[census before building](../practices/census-before-building.md).

## The ruling on source

`buildPlaceableTemplates` takes the loaded libraries alongside the document and
returns **one sorted list tagged by provenance**. `#242`'s chips narrow it.

The alternative was real: keep the palette on the document alone and require a
library template to be *added to the project* before it can be placed. That
preserves DR-077 untouched and makes *place* always mean *place something this
document holds*. **Declined on cost to the common case**: it puts a step in front
of every use of a library and makes M4-O a prerequisite for M4-N being useful at
all.

**DR-077's property widens and is restated where it is held.** It becomes *the
palette lists the document plus the loaded libraries, and never a constant*.

## The ruling on collision: two rows, each tagged

A template id present in two libraries, or in a library and the document, appears
**once per source**.

**`#241`'s own sentence is the argument**, written before anybody asked: a field
on the body *"would force a false choice between them"*. That reasoning only
holds if both survive to the screen. And it is
[DR-101](dr-101-an-id-collision-on-import-is-a-question.md) one level up:
`templateIdFor` derives ids from display names, so a colliding id means **two
people typed the same name**.

A precedence rule was declined for hiding a device the user deliberately loaded,
which reappears when they unload the other library and reads as a bug. **Refusing
to load a colliding library was declined harder**: two libraries that each hold an
`HDMI Matrix 16x16` could never be loaded together, so the multi-library feature
would refuse its own main use case.

**This is not the duplicate-row defect DR-077 §11.76.2 closed.** That was ONE
template appearing twice with no way to tell the copies apart. This is TWO things
that share a name, each answering for a different shelf, and the tag is what
makes them two things rather than a bug.

## The ruling on shape

`TemplateProvenance` becomes a **sealed class**, not an enum with a nullable
`libraryId` beside it. An enum plus a nullable field is a two-field invariant no
constructor can enforce and no `switch` can exhaust, and this repository already
spells that shape as a sealed class in `Outcome`, `FileContent` and `FsOp`.

## What building it found

**The comparator was total only by accident of the old shape.** It ended on
`a.id.compareTo(b.id)`, which was total while one row per id was guaranteed.
Libraries end that guarantee and Dart's `List.sort` is not stable, so an id-only
comparator would let map iteration decide the palette's order between two runs of
one build. It now ends on `(sourceRank, sourceKey)`.

**`PlaceableTemplate.key` was a lookup key that would silently miss.** Typed
`String?` and renamed `documentKey`, the compiler named both readers on the first
analyze, one of them comparing two keys for selection identity where two nulls
compare equal.

## What it does not rule

Where the library directory lives (`#238`'s), the `.rmda` format (DR-015's),
favourites and smart folders (M4-O's), and **what happens when a library fails to
load**, which [DR-103](dr-103-a-library-row-copies-itself-in.md) settles.
