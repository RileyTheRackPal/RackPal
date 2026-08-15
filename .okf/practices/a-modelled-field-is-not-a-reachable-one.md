---
type: Playbook
title: A modelled field is not a reachable one; look for the gesture, not the field
description: Fields with no writer, a callback with no caller, and one field whose only writer is the JSON decoder. Ask what a person clicks, and follow it down.
tags: [practice, model, commands, verification]
timestamp: 2026-08-12T00:00:00Z
status: adopted
---

**Before planning work that reads a field, grep for what WRITES it.** A field
can be modelled, persisted, byte-round-tripped, seeded and consumed by four
readers, and still be unreachable because no command sets it.

**And then go one layer further out.** A field with a writer can still be
unreachable if the gesture in front of the writer has no caller. Ask **"what
does a person click"**, and follow that answer all the way down, rather than
starting at the field and stopping at the first thing that assigns it.

**And a third shape, which is the cheapest to miss: the field is reachable, and
the DATA is not there.** `SignalFamilyDef.aliases` was modelled, persisted,
byte-round-tripped and read by a picker's search key, and was **the empty list
on all 55 seeded families**, behind a `_family()` helper that did not accept the
parameter. Two board tasks and canon CR-058 all asserted it was populated. The
grep that answers this one is not "what writes it" but **"what is in it"**: a
count of non-empty values across the seed, which took a minute and unblocked a
milestone task written from the opposite belief (DR-060 §11.59.2).

# Why, with the evidence

**All but the last were found the same way: by trying to use the thing.** Not by
reading the model, and not by a test. The exception is at the bottom and is worth
the most, because it was found before anybody tried.

The first five are fields with no writer. The sixth is a different shape, and is
the reason no heading here carries a count: a sentence that says "four times" is
wrong the moment there is a fifth, and this file has been wrong that way once
already. **The frontmatter said "six" while the body held seven**, which is the
same failure one layer out, so the count has now left the description too.

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
* **`OutletTemplate`'s termination** (DR-044). The fifth, and **the first caught
  before the field was written**: DR-043 proposed leaving it null on the shipped
  templates, and nothing in this product can author an `OutletTemplate`, so null
  on the shipped ones is null everywhere for ever. A census before a line was
  built is what turned that into a ruling instead of a defect.

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

# The seventh has NO writer at all, and it was found before anybody tried to use it

**`NetworkConfig` on `Port`** (`{hostname, ip, subnet, gw, mac, vlans[],
portRole}`), plus `DeviceInstance.macAddressPrimary`. In the model since M0,
encoded and decoded by `json_codec.dart`. Censused 2026-08-12 while pricing a
feature request for static IP settings on the sheets:

```
grep -rn "network\s*=\|network:" --include=*.dart .
→ json_codec.dart:1361:  network: decodeNullableObject(
```

**One hit, and it is the decoder.** Not a command, not a widget, not a test
fixture. The only way a `NetworkConfig` has ever existed in this product is if
somebody hand-edited a `.rmpj`. Every earlier entry had at least a fixture; this
one is the pure case.

**It reads as nearly-shipped from three directions at once**, which is what makes
it worth the entry. The field is modelled. The codec round-trips it. And
`sheet_def.dart`'s `kReservedNcsIds` **reserves `T6.50` for "the v1.1 Network/IP
Schedule"**, with docs/08 §2.2 saying in terms that its deferral is *"a ruling,
not an omission"*. A reader finds a modelled field, a working codec and a
reserved sheet number, and concludes the work is mostly done. **It is zero
percent reachable.** The reserved id is doing the same damage a citation does in
[two documents agreeing is not verification](two-documents-agreeing-is-not-verification.md):
it is evidence of intent that reads as evidence of existence.

**This is the first one found by reading rather than by using**, which the
paragraph at the top of this file used to say never happens. It did not happen by
accident. It happened because a **feature request was censused before it was
priced**, which is the same instrument as
[census before building](census-before-building.md) pointed at a proposal instead
of at a corpus. **That is the cheap moment**: an unreachable field discovered
while scoping costs a paragraph, and the same field discovered mid-build costs an
unscheduled command.

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
