---
type: Playbook
title: A modelled field is not a reachable one; look for the gesture, not the field
description: Six times now. Five were fields with no writer; the sixth was a callback with a writer behind it and no caller in front, which this file's own check passes. Ask what a person clicks, and follow it down.
tags: [practice, model, commands, verification]
timestamp: 2026-08-10T00:00:00Z
status: adopted
---

**Before planning work that reads a field, grep for what WRITES it.** A field
can be modelled, persisted, byte-round-tripped, seeded and consumed by four
readers, and still be unreachable because no command sets it.

**And then go one layer further out.** A field with a writer can still be
unreachable if the gesture in front of the writer has no caller. Ask **"what
does a person click"**, and follow that answer all the way down, rather than
starting at the field and stopping at the first thing that assigns it.

# Why, with the evidence

This has now happened four times, and the fourth was found the same way as the
first: by trying to use the thing.

* **`Pathway`** (M3-E/4). In the model since M0, round-tripped by the codec, read
  by the schedule's `PATH` column, the Structure editor and
  `structure_matrix.dart`. **Nothing created one.** The only writer of
  `doc.pathways` was `RemoveLocationCommand` clearing references during DR-021's
  cascade. So `Link.pathwayId` could never point at anything real and every
  drop's `PATH` cell was the unknown marker by construction.
* **`registries.mediaTypes`** (M3-F/6). docs/07 §5.1 says an unmatched CSV cable
  "creates a new media type with a confirmation chip; it is never a rejected
  row", and RJ-012 rules it. **Nothing in `lib/` had ever written that map** -
  the only writers in the repository were test fixtures. The rule could be
  honoured only by rejecting the row it forbids rejecting.
* **`Link.pathwayId`** (M3-F/6). Settable at creation and never afterwards, so a
  drop pulled before anybody chose its conduit was stuck outside every trunk. A
  revised pull list changing its `Bundle` column is an ordinary revision.
* **A derived location code** (M3-F/6). docs/07 §5.3.1 promises "create room
  inline, pre-filled with a derived `code`". No derivation existed anywhere;
  every room so far had been coded by hand, which is not available when a sheet
  creates twelve at once.

# The sixth is one layer up, and this file's own check misses it

**`OutletsActions.onRemoveGang`** (M3-H/5). The command was built and tested
including undo, the callback was declared, and the app side implemented it with
its bounds check and refusal sentence. **Nothing invoked it.** The only way to
remove a gang was `Ctrl+Z` or a full destructive `Arrange`.

The guidance below is *"grep for what WRITES it"*, and **the field had a
writer**. What it lacked was a **caller for the callback in front of that
writer**. So the check as stated passes on a defect of exactly the kind it
exists to find.

**A declared-and-implemented callback reads BETTER than an unreachable field**,
because both ends are present and only the middle is missing:

* the analyzer sees nothing unused, because the record is constructed with every
  member supplied and then passed to a child;
* the app-side implementation has its own tests, and they pass;
* the command has its own tests, including undo, and they pass;
* every reader of the record compiles.

The only absent thing is a widget that says `actions.onRemoveGang(...)`, and no
Dart type can require one.

**It is a gate now rather than a habit.** `actions_have_callers_test.dart` scans
every function-typed callback on a `*Actions` record in `rackmate_ui` and fails
when one has no call site: 18 callbacks, one hole on its first run. It was
**watched failing** before being trusted, and it deliberately skips nested
records (`StructureEditorActions.dropEntry`, `.outlets`) because those are passed
rather than invoked, and a gate that cries wolf on its first run gets weakened.

# The check, which costs a minute

For each field the work will read or write:

```
grep -rn "fieldName" lib/ | grep -v "test"
```

and ask which of the hits **assigns** it. Hits that only read it, only serialise
it or only document it are not writers. A field whose only writers are test
fixtures is seed-only in practice, whatever the model says.

The tell is a field with many readers and no gesture: it reads as
well-integrated precisely because every consumer already handles it.

# Why the corpus does not catch this

The corpus describes the MODEL, and the model is right in all four cases. The
data-model document lists the field, the codec test round-trips it, and the
design document describes the behaviour that reads it. Every one of those
artifacts is accurate. None of them is evidence that a person can change the
value, and
[two documents agreeing is not verification](two-documents-agreeing-is-not-verification.md)
is the same lesson one layer up: there, a field named by a ruling AND a design
document was in neither the model nor the codec.

**So the estimate is what this costs.** All four were found while implementing
something else, and each added a command nobody had scheduled.

# Citations

[1] `packages/rackmate_core/lib/src/commands/pathway_commands.dart`, file header
[2] `packages/rackmate_core/lib/src/commands/media_type_commands.dart`
[3] `LinkField.pathwayId`, `deriveLocationCode`
[4] docs/07 §5.1, §5.3.1; RJ-012, RJ-009
