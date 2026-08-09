---
type: Playbook
title: A test that counts the mechanism will certify the defect
description: A test asserted "one corridor per pin", passed, and the sheet drew a fifth of its ink twice — because the reader sees overlapping wires, not corridor counts. Three mouths to the trap, the third being parts that are each right while the compound claim is never asserted.
tags: [practice, testing, mutation-testing, schematic, exit-criteria]
timestamp: 2026-08-09T00:00:00Z
status: adopted
---

`wire_trace_layering_test.dart` group 1 asserted **distinct escape corridors
per pin**. That is the *mechanism* the comb uses. What a reader sees is **no two
cables drawn along one line**: the *artifact*. For two revisions of the comb
the two came apart, and the test certified the defect it was written to forbid.

# What happened

`b48e96c` let the two halves of a symbol's edge reuse one set of comb heights,
arguing that the detour sends the near half round one side of the body and the
far half round the other, so two pins reflected about the middle can never
overlap.

That is true of the **detour**, which is the last resort. It is false of the
ordinary staircase, which is what nearly every cable takes: two top pins both
escape upward whichever half they sit in.

The test counted corridors **per half**. Every pin had one "of its own" within
its half, so it passed, while the sheet drew **24 collinear pairs, 10885
units, a fifth of all the ink on a 48-cable edge, painted twice.** The field
reported it as *"still getting a few overlapping wires"*.

**The test was not weak. It was precise about the wrong quantity.** That is the
harder failure to spot, because precision reads as rigour.

# The trap has a second mouth

The replacement measures collinear overlap between the drawn segments and
asserts zero. Writing it, a companion test for the crossed-patch case keyed on
each route's **topmost point**, and the mutation it existed to kill *survived*
it. A wrongly-placed corridor still reaches its far escape; it only doubles
back afterwards. So the topmost point was distinct per cable while all 48 long
runs sat on one row.

Counting the **horizontal runs**, the segments that actually overlap, kills
the mutation with `one corridor carries 48 of the 48 cables`.

**The proxy is seductive twice**: once when the rule is written, and again when
the test that replaces it is written.

# The check

Ask of an assertion: **if this passes and the user still reports the bug, what
would have to be true?**

If there is a plausible answer, the assertion is about a mechanism and the user
is looking at an artifact. Find the quantity where that question has no answer.

* "distinct corridors" ⇒ *they could be distinct and still overlap* → proxy.
* "zero collinear overlap between any two wires" ⇒ *nothing* → artifact.

Note that the second is also **cheaper to read**: its failure message names the
pairs and the units, so a regression arrives already diagnosed.

# And a third mouth: every part right, the claim never asserted

M3-D/4 found the same family of gap from the other side. Exit clause 3 is a
compound claim — a rough-in produces rows **sorted by room and pathway** with
**per-room footage subtotals**. The sort, the room grouping and the footage
rollup each had passing cases in `schedule_test.dart`, each asserting a genuine
artifact, none of them a proxy.

**None of them had ever been pointed at the same document.** Three good tests
over three fixtures demonstrate three mechanisms; they do not demonstrate the
claim, because the claim is about one rough-in and nothing had ever built one.

Roadmap §8.1 is what makes this a defect rather than a tidiness question: the
exit criterion is the unit of truth, and a milestone whose evidence is a set of
component tests has not met a compound criterion. The fix is one fixture that
every part reads:
`packages/rackmate_core/test/derived/pull_sheet_clause_test.dart`.

Two details make that file carry its weight rather than merely exist. **It is
built to falsify**: rooms and pathways are created in an order that is not their
sorted order, so a build that preserved insertion order fails instead of
coinciding. And **it asserts the boundary too** — `SheetRole` is pinned to its
three values, so if a Pull Sheet role ever appears the case fails and whoever
added it has to say whether M3's clause or M6's now owns the sheet
([DR-027](/decisions/dr-027-m3-owes-rows-m6-owns-sheets.md)).

# Where this does not apply

An artifact-level assertion is not always available, and inventing a bad one is
worse than a good proxy. The test for the comb's *determinism* is still an op
comparison, because "byte-identical display list" is itself the artifact. The
rule is to prefer the quantity the report is phrased in, not to avoid
mechanisms on principle.

# Citations

[1] `packages/rackmate_ui/test/canvas/schematic/wire_trace_layering_test.dart`
    (group 1, and its own header recording both wrong versions)
[2] `docs/12-milestone-board.md` §5.1, the six field reports this came out of
[3] Commits `b48e96c` (the mirrored comb), `5d53512` (the measurement that
    replaced the count)
[4] `packages/rackmate_core/test/derived/pull_sheet_clause_test.dart`, and
    `docs/12-milestone-board.md` §5.2's M3-D/4 close
