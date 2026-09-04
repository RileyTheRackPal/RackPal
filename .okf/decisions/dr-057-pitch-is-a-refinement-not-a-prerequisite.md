---
type: Design Ruling
title: DR-057 — Connector pitch is a refinement, not a prerequisite
description: >-
  Sparse pitch was priced as a feature cut, auto-layout on 14 of 45 templates,
  and the price came from a derived document's pseudocode. Every ruling says the
  layout flows from footprints. The cut was never real.
tags: [ruling, m4, m4-b, m4-k, catalog, connectors, g4, cr-071, dr-057]
timestamp: 2026-08-14T00:00:00Z
ruling_id: DR-057
canon_section: "11.56"
status: ruled
---

Settled by the user on 2026-08-14 during M4-B (board `#173`). It supersedes
nothing and **corrects a reading of docs/06 §5 that was about to cut a feature
nobody had ruled out.**

# What M4-B found

`ConnectorTypeDef.pitch` and `.genderApplies` were documented from M0 and
declared by neither the Dart nor the codec. They turned out to be authorable on
opposite terms.

**`genderApplies` was never open work.** Canon §6.3 carries a complete yes/no
column for every connector id, so all 49 entries are a transcription and none is
a judgement: 31 true, 18 false. CR-059 is why the field exists at all, the
five-value gender enum contained two synonym pairs and silently broke `CON-002`,
whose *"both ends male or both ends female"* never fired for jack+jack.

**`pitch` is stated for 13 rows naming 14 ids** in docs/catalog/seed-devices.md
§5.2, and for nothing else in the corpus.

# Shared shells: six inherit, and the instrument is borrowed

`conn.3_5mm_ts` from `_trs`, `conn.xlr5` from `xlr3`, `conn.iec_c13` from
`_c14`, and `conn.nema_5_15p` / `_5_20p` / `_5_20r` from `_5_15r`. **Every one
of those pairings is already made and cited in `assets/catalog/sources.md`'s
footprint table**, so this reuses a documented derivation rather than inventing
a second kind of provenance.

Held in the test as a **relation, not six literals**: each inheritor must equal
its source, so re-authoring `conn.xlr3` drags `conn.xlr5` with it. Duplicated
numbers drift, which is the failure a shared-shell rule invites.

# Twenty-nine have no pitch, permanently

A pitch is **not derivable from a footprint**, though it looks it. Most stated
ones sit 2 to 4 mm above theirs, which reads as a uniform clearance. Then
`conn.binding_post` states **20 mm against a 24 mm pair footprint, below it**,
because ¾ inch is the centre spacing binding posts are physically built on, and
`conn.euroblock_3`'s own name carries a 3.5 mm *contact* pitch unrelated to its
15 mm connector pitch. A formula fitted to the rest gets both wrong.

# And that costs nothing, which is what this ruling is actually for

The question was first put to the user as a trade-off between sparse pitch and
auto-layout coverage, priced at **14 of 45 shipped templates**. **That price came
from docs/06 §5's pseudocode** (*"flow left → right at
`ConnectorTypeDef.pitch`"*) in a derived, priority-3 document.

Every normative statement says **footprint**:

* **CR-071 §1**: panel geometry is *"auto-laid-out from connector footprints"*
* **docs/catalog §5.2's own introduction**: the layout *"needs a real footprint
  per connector"*
* **roadmap §2**: *"the connector footprint table complete for every shipped
  connector"*

**The word pitch appears in no ruling.** So the algorithm advances by
`pitch ?? (footprintWidth + gutter)` and skips the three connectors §5.1 gives
no cutout, since a hardwired lead occupies no panel width. Auto-layout runs on
**45 of 45**. The gutter is one stated layout constant, the same kind of thing
as `kGridUnit`, and not a physical claim about 29 connectors; its value is M4-K's
to pick against a rendered panel.

# The near miss, recorded as one

This is the second premise error in three days.
[DR-056](dr-056-generic-is-the-trades-word-for-unspecified.md) §11.55.1 read a
Dart constructor as a product rule; this read a derived document's pseudocode as
a requirement. **Both were caught by the same instrument**,
[re-reading the question against canon](/practices/re-read-a-task-against-canon.md),
and this one only just: the ruling was already being drafted when the check ran.

> A derived document that describes a mechanism is not a ruling about what the
> mechanism needs.

# Scope

No scope change to roadmap §2, which never named a pitch, and no feature is cut.
No migration, and `kSchemaVersion` does not advance: both keys are written only
when present, so every document on disk still satisfies
[CR-117](/invariants/cr-117-byte-exactness.md). The four starters regenerate and
their whole byte delta is the two new keys.

**M4-B (`#173`) ships the fields, the codec, the authoring and the gates. M4-K
(`#182`) owns the algorithm, the gutter and the skip**, none of which exists
yet, there is no `panel_layer.dart`. `ConnectorTypeDef.pitch`'s doc comment
carries this ruling, because that is where the next implementer stands.
