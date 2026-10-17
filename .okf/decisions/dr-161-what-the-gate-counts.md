---
type: Design Ruling
title: DR-161 — What the reachability gate counts, and when an exemption may be permanent
description: >-
  Two of #872's twelve unreachable-Command rows were about the gate. SnapshotCommand
  does not exist and was counted from a sketch inside a comment; AddLinkCommand
  exists, is used twenty-one times, and is deliberately not for a person. The
  inventory now strips comments, and a second exemption map holds permanent rows
  whose values are sentences rather than board items.
tags: [ruling, gates, census, testing, dr-161, dr-013, cr-117]
timestamp: 2026-09-13T00:00:00Z
ruling_id: DR-161
canon_section: "11.160"
status: built
---

Settled by the user on 2026-09-13, closing `#880` and `#881`. **Neither was a
defect in the product.**

`#872`'s gate reported twelve `Command` classes with no path from a person. Ten
were real and are closing one at a time. The other two failed in opposite
directions, and both became board items with a `DONE WHEN` clause each on nothing
but the gate's own word.

# A comment is not a declaration

`snapshot_command.dart` declares nothing. Its header says so as the point: it
exists *"purely as a marker for where that lands; it deliberately defines no class
so nothing here reads as more built than it is"*. What it holds is an indented
sketch inside a `//` comment, written at M0 to record that building the class
needs `RackDocument.restoreEntities` and an encode/decode dispatch table
`json_codec.dart` deliberately does not export.

The gate's pipeline already knew comments do not count and applied it unevenly:
step 2, the declaration scan, has always run over `_strip`ped text; step 1, the
Command inventory, read the raw file. **Measured over the three scan roots: 73
commands raw, 72 stripped, one phantom, and nothing is lost by stripping.**

**The identical mistake is recorded in that file's own header, pointing the other
way.** Attempt 2 of its three failed censuses *"let a name in a COMMENT count as
reachable"*, and `RemovePlanUnderlayCommand` fell off the list because of it. That
was fixed on the EDGE side and survived on the NODE side for the whole life of the
gate.

# An exemption may be permanent, and must say why in a sentence

`AddLinkCommand` mints a `Link` with two open ends and an implicit `Net`, needing
no device, no port and no panel, which `link_commands.dart`'s M0 header states as
the design: *"usable anywhere in a command sequence rather than only after a
device has been placed."*

The ticket's hypothesis was supersession by `buildConnectPortsCommand`. The census
refuted it. Four things mint a `Link` in `lib/` and the other three attach the
cable to something; nothing in docs/ asks for a gesture that makes an unattached
cable, and there is no picture of one, because the schematic draws links between
ports and such a link has none. Of its twenty-one test sites, twelve are fixture
convenience and nine are not: `allocateNetNameFor`'s two properties (a revert
frees the name, a redo reuses it) have **no other coverage**, and
`command_roundtrip_test`'s thousand-sequence CR-117 sweep has **no other
link-creating step**.

So it stays, in a second map. `_exempt` is a DEBT and every row is owed to a board
item, refusing any value that does not look like one because *"a list of names is
a place to hide"*. `_infrastructure` is a standing claim that nobody should reach
the command; its format test refuses anything shaped like a board item, for the
mirror of that reason, and another test refuses a name appearing in both.

**The staleness check binds both maps. The permanence is in the reason, not in
the checking**: the day somebody wires one of these the claim is false, and the
failure message says to decide in a ruling which of the wiring and the claim is
wrong rather than deleting whichever is cheaper.

# What this does not do

It does not delete the marker file, whose record of what building the class would
need is worth more than the tidiness of removing it. And it does not rule on
whether snapshots are in scope, which `#880` asked for: there was never a
question, because there is no class.

# Related

* [A gate's output is read as a fact](/practices/a-gate-is-read-as-a-fact.md) is
  what building this produced.
* [A gate's scope is part of its
  claim](/practices/a-gates-scope-is-part-of-its-claim.md) is the neighbouring
  failure, where the gate scanned less than its name promised.
