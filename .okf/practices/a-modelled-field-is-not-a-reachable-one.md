---
type: Playbook
title: A modelled field is not a reachable one; look for the gesture, not the field
description: Fields with no writer, an ERROR TYPE with no producer, a PROTECTION that never covered what it was bought for, a callback with no caller, one field whose only writer is the JSON decoder, a missing producer that was the seed catalogue's own port builder, a field the panel never read, a panel nothing mounts, a note found by censusing a ruling's own escape hatch, and a field with a producer and no consumer that a new ruling nearly added a second copy of. Ask what a person clicks, follow it down, and remember that a widget test supplies the step it is meant to prove.
tags: [practice, model, commands, verification, catalog, ui, persistence, dr-019, dr-136, dr-124, dr-125, dr-126, dr-128, dr-129, dr-130, dr-131, dr-132, dr-133, m5]
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

**And a FOURTH shape, which nothing in this practice covered until PLAN-B: an
ERROR TYPE with no producer.** `ContainerUnreadableError` was written for a
truncated `.rmpj`, on the assumption that `ZipDecoder` throws when it cannot read
an archive. **It does not.** It reads the central directory, which lives at the
END of the file, so a truncated archive simply has none and it returns an EMPTY
`Archive`. Measured at six truncation points and on a file that was nothing but
the four signature bytes: zero throws, every time.

So the `catch` arm was unreachable, and the consequence was not cosmetic. Every
truncated project would have fallen through to the *foreign archive* state,
been told "this is not a RackPal project", and been **refused the backup that
would have rescued it** — a user-facing failure caused entirely by a state
nothing could reach. The fix was to make *zero entries* the damage signature and
to write down that the exception arm is the belt-and-braces one.

**The generalisation: an error taxonomy is a set of claims about a LIBRARY's
behaviour, and libraries are the thing this practice keeps saying to measure.**
"What does a person click" has a sibling: **what does the dependency actually
DO when the thing goes wrong**. Both are answered by running it, and neither is
answered by reading it.

**AND A FIFTH, WHICH IS THE OTHER FOUR POINTED AT A PROTECTION RATHER THAN A
FEATURE.** DR-019 bought an `unknown` passthrough to stop an older build dropping
plan pins on save. M3-I built it as a reserved container, correctly, and said in
capitals that it collects no unrecognised sibling keys. `planPin` is a sibling
key. **So the remedy never reached the hazard**, and nothing noticed for a month.

The reason nothing noticed is the reusable half: **a protection bought for a
feature that does not exist has no way to be wrong until the feature arrives.**
There is no writer to grep for, no gesture to follow, no data to count. Every
check in this practice needs something to point at, and a guard for a field
nobody has added yet points at nothing.

So the moment to re-check a protection is **the moment you first need it**, not
the moment you first cite it. PLAN-C found this by trying to write the test its
own brief asked for and discovering the test could not exist; DR-136 is what came
out of that.

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

# And one with the halves reversed: a reader that shipped, with no producer

**`PortSetDef`, censused at M4-J's pick-up** (DR-085, board `#760`). Every entry
above is a writer missing behind a field. This one is the mirror image, and the
usual check cannot see it.

`port_grid.dart` ships a **live `SET` dropdown**. It is editable, it writes
`PortDef.setKey`, it lists `body.portSets` with a null option first, and it works.
**Nothing outside the seeded catalog has ever created a `PortSetDef`.** So a
person authoring a template from scratch opens that picker, finds one entry, the
unknown dash, and will find only that one for ever. `PassthroughPairDef` is the
same shape one column over: its only writer is `RenamePortKeyCommand`, which
rewrites pairs that already exist, and `PAIRED WITH` is read-only.

**The question at the top of this file is *"what writes this?"*, and here the
answer is reassuring and useless.** A cell writes it. What is missing is the
thing that mints the row the cell points at, and no grep for a field name asks
that. The question that finds this shape is **"where does a person make the
FIRST one?"**, asked of every collection a control offers choices from.

**It re-scoped an issue rather than adding a task.** `#181` reads as an editor
over three existing models; the census turned it into **two missing producers
plus a small action**, which is a different size and a different order of work.
Found before any code, which is the whole return on
[census before building](census-before-building.md).

**Beside it, a field with no reader at all: `BankDef.order`.** Allocated by
`nextOrder`, encoded by the codec, and read by nothing that orders anything. The
symbol orders pins by `PortDef.order`, the grid bands by first appearance, and
`movableBanks` follows the grid. It surfaced only because M4-J1's bank tree had
to decide what to sort by, and the answer was *not this field*: the tree is
navigation, and a navigation list ordered differently from the surface it
navigates is a defect. **An unreachable field is not always a thing to make
reachable.** Sometimes the honest move is to record that nothing reads it and
leave it alone until a ruled gesture needs it.

# Three in one issue, and the two questions that find them

**Board `#181` turned up six**, across three models and three fields, and the
haul is worth the entry because none of them was carelessness:

| | What was missing |
|---|---|
| `BankDef.order` | no reader anywhere |
| `PortSetDef` | no producer, under a live picker |
| `PortSetDef.kind` | no reader outside the codec |
| `PassthroughPairDef` | no creator, under a read-only cell |
| `sameNet` | no reader anywhere |
| `BankDef` | one writer, and no rename, remove or mirror |

**THE COMMON CAUSE IS SCHEDULING.** All six were modelled from a design document
at M0, encoded, and gated by the byte round trip. The surfaces that would have
exercised them were scheduled four milestones later, so between M0 and M4 nothing
could fail: **a field with no writer round-trips perfectly, and a field with no
reader round-trips perfectly too.** A codec gate cannot tell a value that is
inert from a value that is correct.

**AND THE QUESTION AT THE TOP OF THIS FILE FINDS ONLY ONE OF THE THREE SHAPES.**
*"Grep for what writes it"* finds `PortSetDef`'s and misses both others. Two more
questions earn their place beside it:

* **"Where does a person make the FIRST one?"** Asked of every collection a
  control offers choices from. This is what catches a picker that is editable,
  correct, and permanently empty.
* **"What READS this, and what would it do differently if the value changed?"**
  Asked of every field the work is about to write. A field whose only readers are
  the encoder and the decoder is a field describing nothing, and the honest move
  is often to record that rather than to invent a reader for it: making the bank
  tree sort by `BankDef.order` would have put the navigation out of step with the
  grid it navigates, in exchange for honouring a field no ruled gesture can write.

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

The corpus describes the MODEL, and the model is right in every case above. The
data-model document lists the field, the codec test round-trips it, and the
design document describes the behaviour that reads it. Every one of those
artifacts is accurate. None of them is evidence that a person can change the
value, and
[two documents agreeing is not verification](two-documents-agreeing-is-not-verification.md)
is the same lesson one layer up: there, a field named by a ruling AND a design
document was in neither the model nor the codec.

**So the estimate is what this costs.** Every one found by USING the thing was
found while implementing something else, and each added a command nobody had
scheduled. The ones found by reading cost a paragraph, which is the argument for
reading first.

# The seed BUILDER is a producer too, and it hid three fields in one milestone

**Every case above asks what COMMAND writes a field. M5 found a different
producer missing: the catalogue's own port builder.** `catalog_ports.dart`'s
`p()` constructs all 727 seeded ports, and a `PortDef` field it has no parameter
for takes its default **by construction rather than by anybody's choice**. That
reads as authored data and is not.

| Field | Found by | Cost |
|---|---|---|
| `maxConnections` | DR-124 | `TOP-003` refused the second head of a dual-head IR flasher at the gesture, with no `[ Connect anyway ]` to escape through. `seed-devices.md` had documented `2` since M0 |
| `acceptedFamilies` | DR-126 | `SIG-002` refuses every cross-family pairing in the shipped catalogue. Invisible until DR-126 deliberately created one that is not same-family |
| `RuleMeta` severity band | DR-125 | Not the builder, but the same shape one layer up: `evaluateDocument` discarded the predicate's severity, so `RCK-003`'s `advisory` had never reached a user since M5-E |

**Three in one milestone, all found the same way: a rule fired on a connection
that is correct.** That is now the strongest single signal in this repository
that a field has no producer, and it is a better detector than reading, because
it costs nothing to notice and arrives on its own.

**A CANARY IS WORTH MORE THAN A CENSUS HERE**, and one existed.
`connect_rules_test.dart` asserted *"NOT ONE seed catalog port declares
acceptedFamilies"* and said in writing that a failure would mean the catalog had
started declaring. It fired at exactly the right moment and was widened to a
named set rather than deleted. A census finds a field once; a canary finds the
day it changes.

**THE CENSUS THAT WAS OWED HAS RUN**, as `#841`, and it narrowed the claim
rather than widening it. Eleven `PortDef` fields have no `p()` parameter, but
**almost every one is written by the DEVICE BUILDER**, where a person authors a
port. They are not fields nothing can write; they are fields **the shipped
catalogue cannot express**. The sharp question is who READS one outside the
builder, and two do: `topology`, covered deliberately because the seed declares
`PortDirection.busNode` instead, and `carriedProtocols`, which nothing populates,
so **searching the catalogue by protocol matches nothing and always has**
(`#846`).

**THAT SECOND SENTENCE IS TRUE AND SAYS LESS THAN IT SOUNDS, WHICH IS THE
CORRECTION WORTH KEEPING.** Searching by PROTOCOL works: `dante` finds the
seeded DSP through the port's own `signalFamily` and the device's tags, and a
test has asserted it since M4. What matched nothing was the extra tokens this
one field contributed. **A finding about a FIELD is not a finding about the
FEATURE it feeds**, and the second claim needs its own measurement rather than
inheriting the first one's. DR-134 deleted the field: it was a second copy of two
facts the model already recorded properly, and its emptiness was never the cost
it appeared to be.

It found more stale claims than fields: three in `connect_target.dart`, all in
doc comments that REASON from them, all falsified within two days by DR-124 and
DR-126. **The lesson is not "sweep harder"**: a claim about what the catalogue
contains belongs in a test, where it fails, rather than in prose, where it is
believed. `seed_producer_census_test.dart` NAMES the eleven rather than counting
them, because a count of eleven passes on the wrong eleven.

# The widget is a producer too, and the layer above it is where this ends

**Two more arrived in DR-128 and DR-129, and the second is the largest.**

`Finding.remedy` shipped with a writer (`PWR-003` declares it), an implementation
(`addOutletsToRack`) and a ruling stating that the panel *"renders it as a
button"*. **The panel never read the field.** The reachability gap had moved off
the model entirely and onto the surface, and **nothing caught it** because a
nullable field a widget ignores compiles and tests green. Contrast
`SpringBackRemedy`, whose identical error in the same ruling **Dart's exhaustive
switch caught within the hour**, because a chip handler must match every enum
value. **Where the type system cannot make the pairing mandatory, a test must**,
and it must assert in both directions.

**AND THEN THE PANEL ITSELF HAD NO CALLER.** `DrcPanel` appears in exactly two
files in the tree: the one defining it and the one testing it. Nothing mounts it,
and outside that widget file nothing calls `evaluateDocument` or `groupFindings`
at all. Everything M5-F built (the findings list, the grouping, the severity
filter, acknowledge and withdraw, the `Why?` viewer) is real, tested and
**unreachable by any gesture a person can make**, and docs/12 recorded that it was
reachable (`#847`).

**AND AN EIGHTH ARRIVED BY A ROUTE NONE OF THE OTHERS TOOK.**
`OffRackPlacement.mountNote` (DR-130) was found by **censusing a ruling's own
escape hatch**: DR-125 priced the cabinet head end as *"expressible as
`OffRackPlacement` with a `mountNote`, but crude"*, and the crude option turned
out not to exist either. Nothing a person could reach had ever written it; the
only writers were the starter generator's, which is why four seeded devices
carried sentences no user could type. **The grep that answers this one is the
same as the first**, and the new part is WHEN to run it: **a disposition that
says "already expressible" is a claim about a producer, and it is worth two
minutes before it is worth a milestone.**

**AND THE NINTH AND TENTH ARRIVED TOGETHER, ONE OF THEM BY COLLISION.**
`Port.tapWatts` (DR-131) had the right home and the right doc comment, *"per
INSTALLATION, not per template"*, and no writer; `PortDef.bus.maxTapWatts` was
authorable in the device builder and declared on **zero of 727 seeded ports**.
The second is a shape none of the earlier ones had: **a producer with no
consumer.** A person could type a tap wattage and it participated in not one
calculation.

**THE COLLISION IS THE LESSON.** DR-131 was drafted ruling a NEW tap field onto
`DeviceInstance`, because the census that priced it grepped `maxTapWatts` and
never grepped `tapWatts`. That is `census-the-field-not-the-name` a fifth time,
and the cheap post-condition is the one that keeps being skipped: **before adding
a field, grep the SHORTEST form of its name, not the one the ticket used.**

**THE WIDGET'S TESTS PASS BECAUSE ITS TESTS MOUNT IT THEMSELVES.** That is this
whole practice in its final form: the thing exists, something reads it, every test
is green, and no path a person walks reaches it. **"What does a person click"
means the WHOLE path, ending at a window that opens on its own**, and a widget
test is not evidence of the last step, because the test supplies the step it is
meant to prove.

**AND WHEN THE PATH IS MISSING, READ THE SPEC BEFORE DESIGNING ONE.** `#847`
was filed calling `DrcPanel`’s mount point an open shell decision with three
questions; docs/04 §1 had a layout-table row for the drawer and §8 had its
three keybindings, so all three questions were closed and one of the answers
was better than the one about to be proposed (DR-133). **A thing that is
unreachable is often a thing that was SPECIFIED AND SKIPPED, not a thing
nobody decided**, and the cheap check is to grep the spec for the surface
before designing it.

# And a COUNT with no reader, one chapter after the census that should have caught it

**`PlanMeasurability.pinnedCarrierCount`** (DR-146, `PLAN-F/3`). Built at
`PLAN-F/2` with a doc comment that named its own intended caller: *"a surface that
had only the first would report a fully pinned plan as empty."* **Zero call sites
in `lib/`.** The surface it named is the underlay row, and that row printed a bare
`Not calibrated`.

**The new half is WHY it was unread, and it is not scheduling.** Every earlier
entry here is a field whose consumer was a milestone away. This one was built one
day earlier, deliberately, for a row the same epic was about to write, **and it
guessed that row's rule**: it counted racks plus subjects, and the ruling that
settled the row chose the other population, because a count including the rack
would print forty stranded pins before a calibration and thirty-nine measurable
after it.

So the honest move was to **replace** it rather than to wire it up or leave it.
Making an unread field reachable is not automatically the fix, which
`BankDef.order` above already showed; this adds the case where the field is not
merely unread but **built on an assumption a later ruling contradicts**. A field
authored for a surface nobody has ruled yet is a guess with a type on it, and the
cheap habit is to build the count when the sentence that prints it is settled.

# Citations

[1] `packages/rackmate_core/lib/src/commands/pathway_commands.dart`, file header
[2] `packages/rackmate_core/lib/src/commands/media_type_commands.dart`
[3] `LinkField.pathwayId`, `deriveLocationCode`
[4] docs/07 §5.1, §5.3.1; RJ-012, RJ-009
