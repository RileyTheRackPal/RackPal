---
type: Design Ruling
title: DR-058 — A fork whose source cannot be seen is silent and counted
description: >-
  CR-062 says what a fork shows when its source was corrected and nothing about
  what it shows when the source cannot be found at all. No badge on the device,
  and the rollup reports the count: G4 applied to a comparison instead of a value.
tags: [ruling, m4, m4-c, g4, cr-062, cr-114, templates, provenance, dr-058]
timestamp: 2026-08-14T00:00:00Z
ruling_id: DR-058
canon_section: "11.57"
status: ruled
---

Settled by the user on 2026-08-14 during M4-C (board `#198`). It supersedes
nothing and fills a gap CR-062 left because the case had not come up.

# The gap

CR-062 compares a fork's `derivedFrom{templateId, version}` against the source's
current version and shows a passive badge when the source has moved on. That
comparison needs a **shelf** holding the source, and there are four of them
arriving across four milestones: a document's own `templates` map, the seeded
catalog, the user library (M4-N) and [DR-034](dr-034-community-library-fetch.md)'s
fetched community pack.

**A project opened on a second machine reaches a state where no shelf in view
holds the id.** So does one whose author deleted the library template years ago,
and so does a shelf carrying only a version *older* than the fork claims, which
is a partial shelf rather than a correction.

# The ruling

**No badge on the device. The rollup reports the count.** Three options were put:

| | What it does | Why not |
|---|---|---|
| **No badge, counted** | Device shows nothing; the list reports *"N forks could not be checked"* | **RULED** |
| A quiet neutral badge per device | A greyed *"source not available"* marker | Fires on every fork in every project opened anywhere else, which is normal. A marker that is always on stops being read, and CR-062's whole design is a badge that means something when it appears |
| Treat it as up to date | No badge, no count | Makes an unknown look like a measured *no* |

# It is G4 applied to a comparison rather than to a value

> Null is unknown, never estimated. Every rollup reports its unknown count
> rather than fabricating a total.

A resolver answering `current` when it merely failed to look is the same defect
as a load rollup that totals the devices it could price and omits the ones it
could not. See [g4-unknowns-are-counted](/invariants/g4-unknowns-are-counted.md).
The count is what makes the silence visible somewhere rather than nowhere.

Watched failing rather than assumed: sabotaging `sourceUnknown` to `current`
fails five tests, four of them by name.

# One consequence, because it decides a pixel

**The version a partial shelf DID find is withheld along with the verdict.** A
badge reading *"the catalog is at v1"* beside *"you forked v3"* invites the
reader to conclude the catalog rolled backwards, which is a claim nobody made.
So `ForkResolution.currentSourceVersion` is null on `sourceUnknown`, and
`showsStaleBadge` is a property rather than a `status != current` comparison
spelled at each call site, because that comparison is wrong in exactly this case.

# Scope

No scope change: CR-062 already names the badge and roadmap §2 already carries
the device library. `ForkStatus`, `ForkResolution` and `ForkAudit` are
`rackmate_core` only and **no widget ships**, because nothing forks yet
(Duplicate is M4-D `#175`) and no library holds one (M4-N). No migration and
`kSchemaVersion` does not advance: `derivedFrom` is written only when present,
so every document on disk still satisfies
[CR-117](/invariants/cr-117-byte-exactness.md).

`builder/fork_status.dart` carries this ruling in its own header, for
[DR-057](dr-057-pitch-is-a-refinement-not-a-prerequisite.md) §11.56.7's reason:
that is where the next implementer stands.
