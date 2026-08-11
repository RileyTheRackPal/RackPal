---
type: Design Ruling
title: DR-039 — Project history is a journal first, and the diff is what answers "why"
description: >-
  A request for snapshots that cited the journal's benefit. What did it look
  like and why did it change are two artifacts with wildly different costs, and
  only the second needs to be in the file today.
tags: [ruling, history, journal, snapshots, diff, cr-117, cr-095, cr-098, dr-039]
timestamp: 2026-08-11T00:00:00Z
ruling_id: DR-039
canon_section: "11.38"
status: ruled
---

Settled by the user on 2026-08-11, as a §8.3 scope amendment. Roadmap §2 gains a
line for project history: an in-file journal, an operation panel,
promote-not-overwrite snapshots and a document diff.

# The request, and the gap inside it

The ask was *"a full undo/redo history ... with snapshots taken at regular
intervals ... that can be rolled back to if a bulk of edits needs to be undone
quickly"*, refined to Autodesk Fusion's revision system, then to the reason:

> I do want the versioning in-file; it may be necessary to have this for
> troubleshooting in the future. The more documentation that is held over the
> HISTORY of a project, the easier it is to read WHY a change was made.

**The request named snapshots and cited the journal's benefit.** A snapshot
answers *what the file looked like at 14:20*: a whole document, ~870 kB of
uncompressed JSON. Recovering a REASON from ten of them means diffing and
inferring. A journal answers *why*: what happened, when, by whom, with a
comment. It is text, it is kilobytes, and unlike a snapshot it fits in the file
today.

Both ship. The journal ships first, because it is what the stated reason needs.

# Why the journal can be in-file now and snapshots cannot

[CR-117](/invariants/cr-117-byte-exactness.md)'s additive-optional contract: a
key written **only when present** leaves every existing document encoding
byte-for-byte, so `kSchemaVersion` does not move. Reading and writing a file
without editing it appends nothing, so `write(read(bytes)) == bytes` is
untouched.

Snapshots would need a container. `.rmpj` is plain uncompressed JSON, so ten
versions inside it is a ~9 MB file parsed in full on every open. A ZIP container
fixes that and shrinks files ~8×, and it is **explicitly a separate ruling**: one
to two weeks dominated by CR-117 determinism (ZIP carries per-entry mtime,
compression level, entry order and CRC, none of which may vary), thirteen
re-baselined byte-exact fixtures with their `.gitattributes` pins, and
AC-058/D8's zip-slip and inflation-limit work becoming mandatory on `File ▸
Open` rather than deferrable on import.

**The sequencing argument is the load-bearing one.** Application-support
snapshots do not block a container: versions are files, and moving them in later
is a copy loop and one migration. In-file snapshots *now* would make the
container a prerequisite for shipping any history at all.

# CR-095 already built half of this and nothing ever called it

`Tombstone{deletedAt, entityType, by}` is modelled, encoded, decoded and
byte-round-tripped. Its own doc comment says it *"Ships in v1 even though no
history UI exists yet"*. **Nothing in `lib/` has ever constructed one**, so
`doc.tombstones` is empty in every document this product has produced.

Fourth instance of
[a modelled field is not a reachable one](/practices/a-modelled-field-is-not-a-reachable-one.md),
and the reason the work starts by filling in a gesture rather than inventing a
parallel record. `EntityMeta{createdAt, updatedAt, updatedBy}` is likewise on
every entity, in the file, and surfaced nowhere.

# The diff, and the two rules that make it trustworthy

**The format already supports diffing and most do not.** `json_codec.dart`
writes plain, pretty-printed, **deep-key-sorted** UTF-8, gated byte-for-byte by
CR-117. Sorted keys make a textual diff stable and minimal; byte-exactness makes
every difference a REAL change rather than serialisation noise.

**Computed over the codec's output, never the object graph.** The codec is total
and the 1000-sequence fuzz harness proves it; a hand-written walker would be a
second traversal with no such proof, and the field it forgot would be invisible
in exactly the way a diff must never be.

**The accessor tables prettify and never enumerate.** `LinkField` and its
siblings name and format a field for a human, and an unrecognised key falls back
to its raw spelling. Enumerating the comparison *from* them would be the trap
[census the field, not the name](/practices/census-before-building.md) describes:
they cover fields a gesture edits, not fields that exist, so a diff built on them
would silently omit every field nothing is wired to yet.

A consequence worth having: `unknown` passthrough maps appear in a diff
automatically, so a field written by a **newer** build shows up as a change
rather than as nothing.

# Three constraints the ruling states so nobody rediscovers them

**The operation panel is not a Fusion timeline.** Fusion scrubs a PARAMETRIC
feature tree: edit feature 12 and 13 through 40 recompute. `UndoStack` is a
linear log of applied mutations with a `revert()`, so 13 through 40 were written
against the state 12 produced and cannot be recomputed against a rule.
Undo-to-a-point is available; edit-in-the-middle is not. The surface says so by
its shape rather than by a tooltip.

**Restore is PROMOTE, never overwrite.** Restoring version 7 while on 12 creates
13 as a copy of 7 and destroys nothing. That removes the need for DR-013's
destructive-confirm pattern and lets restore reuse `DocumentSession.adopt`, the
existing `File ▸ Open` path, instead of adding a mutation primitive to the layer
roadmap §2 calls *"the most expensive retrofit in the project"*.

**Versions are file states; revisions are issued drawings.** `RevisionEntry
{revision, date, description, by}` already means the second, and one word for
both would put two meanings on one term in one document class.

# What changed elsewhere

CR-098's *"pruned to the last 10"* is amended **for interval snapshots** to a
user-set retention defaulting to a day of history. Ten was chosen for
pre-migration backups where it is generous; at ten-minute intervals it is 100
minutes. CR-098's pre-update behaviour is untouched.

# Citations

[1] Canon §11.38; roadmap §2, §8.3
[2] `apps/rackmate/lib/src/storage/snapshot_store.dart` — already writes,
    sequences and prunes; one call site
[3] `packages/rackmate_core/lib/src/model/tombstone.dart` — CR-095, G5
[4] Board #655, tasks #656 through #660
