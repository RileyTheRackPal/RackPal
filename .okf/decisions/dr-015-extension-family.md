---
type: Decision
title: DR-015 — the rm extension family, and a device archive that is not a zip
description: .rmpj / .rmdx / .rmda replace .rackmate / .rmdev / .rmlib; the archive is one JSON file, and .rackmate still opens.
tags: [decision, file-format, persistence, back-compat]
timestamp: 2026-08-03T18:00:00Z
ruling_id: DR-015
canon_section: "11.15"
status: superseded-in-part
superseded_by: [DR-179]
---

Three user-visible file kinds were named in three idioms (`.rackmate`,
`.rmdev`, `.rmlib`) and only the first has ever existed. The owner chose one
family.

| Was | Is | State |
|---|---|---|
| `.rackmate` | **`.rmpj`** project | Built, `dc22ddc` |
| `.rmdev` | **`.rmdx`** device | Spec only: nothing constructs one |
| `.rmlib` | **`.rmda`** device archive | Ruled, not built |

**Not a format change.** No byte inside a document moves, `schemaVersion` does
not advance, the migration chain is not involved. Saying otherwise would put a
format break in the record that did not happen.

# `.rackmate` is accepted, never written

Not deprecated, not migrated on open, not renamed underneath anyone.
`kDocumentExtensions` lists both; the path normaliser appends `.first` and
treats **every** entry as already-correct.

The shape was forced by one call site. `SessionController.save()` runs the
**already-open** path back through that normaliser, so a single-entry list
would turn a team's `Smith.rackmate` into `Smith.rackmate.rmpj` on `Ctrl+S`,
a second file, the first left holding older bytes and still in the recents
list, and **nothing looking wrong until they open the wrong one.**

A list per-caller rather than one extension plus a shared "also accept" set,
because the PDF export shares the normaliser and must not decide that
`Smith.rackmate` is already correctly named.

# Two silent-loss paths the rename exposed

Both are the same mistake, **rebuilding a filename you already have**, and
neither was found by a failing test. They were found by asking what the app's
own files are called.

* **Snapshot prune** rebuilt the path from the current extension, so ten
  `.rackmate` snapshots from an earlier build would be *counted*, cap reads
  as met, then fail to delete, silently, because a snapshot that will not
  delete is deliberately swallowed.
* **Recovery scan** classified by the current extension only. A recovery pair
  exists *only across a crash*, so the one window where a `.rackmate` snapshot
  meets a `.rmpj` build is exactly the window the feature exists for. The
  sidecar would have been orphaned, and `scan` deletes orphans without a word.

Both now carry the path found on disk instead of deriving it.

# The archive is one JSON file, not a zip

`.rmda` renames `.rmlib` **and re-opens the part of AC-042 that cut it**: a
scope edit under roadmap §8.3, recorded as one rather than smuggled in as
naming.

AC-042 argued one cut but made two: it kept `contentHash` ("three lines, and
it is what makes the embedded-snapshot argument true") and threw away the
cryptographic apparatus. **An archive needs only the half that was kept.**

And the container resolves the way CR-091 already resolved it once, for the
project file: *the zip existed to carry per-face device images; images are cut
(AC-057)*. A device template is inert JSON with no binary member, so a zip of
pure JSON buys compression at the price of the entire D8 surface, 
**zip-slip, entry-count limits, decompression bombs**, all of which
critique-completeness lists as needed-and-absent for `.rmlib`. One JSON file
introduces no new attack surface at all, inherits the existing JSON depth and
size limits, stays diffable, and can be protected byte-exactly by
`.gitattributes` like the other two.

The cost, stated so nobody discovers it: **no compression.** 500 templates is
a few MB of JSON against a few hundred KB zipped, in a file people email once.

# What is ruled but not built

The format is the small half. "Multiple device libraries in the palette,
filtered as needed" needs a library directory service, an import/export
surface, a notion of which library a template came from, and a palette filter
keyed to it. None exists, critique-completeness A8.2 says the whole template
lifecycle has "no implementation home". Ruling the format now is deliberate:
it is what other decisions must be consistent with and it is decidable today.

# Citations

[1] `docs/canonical-decisions.md` §11.15, the ruling
[2] `docs/10-decisions.md` ADR-003, the container table it amends
[3] `apps/rackmate/lib/src/storage/save_paths.dart` (`kDocumentExtensions`
[4] `apps/rackmate/test/storage/save_paths_test.dart`, `snapshot_store_test.dart`, `recovery_store_test.dart`) the five tests that die without legacy acceptance
