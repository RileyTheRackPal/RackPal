---
type: Practice
title: An older test is a specification, and a new ruling does not outrank it
description: >-
  A clause in DR-187 said the schematic's layout freeze should be its own undo entry. Two tests
  written long before the ruling asserted the Edit menu's promise that one undo takes back the whole
  gesture, and both failed on the first build of it. The clause was wrong, not the tests.
tags: [practice, testing, rulings, undo, dr-187, dr-156]
timestamp: 2026-09-22T00:00:00Z
status: active
---

# The shape

`DR-187` §11.186.2 ruled that the schematic records its symbol positions on the first edit that would
re-flow them, and added a clause saying the write *"lands as its own undo entry beside the edit"*.
Built exactly that way, it worked: the positions were recorded, the sheet held, and the suite went
red in two places that had nothing to do with the schematic's layout.

| Test | What it asserts | Age |
|---|---|---|
| `schematic_remedy_test.dart` | *"ONE undo takes back the device AND the cable"* | predates DR-187 |
| `schematic_remedy_dr128_test.dart` | *"one undo takes back the converter and both cables"* | predates DR-187 |

Both are the Edit menu's standing promise about a gesture that does two things. A freeze pushed as a
second entry on top of every edit broke it everywhere at once: the first `Ctrl+Z` took back the
ARRANGEMENT and left the edit, so the sheet visibly scrambled, the device stayed deleted, and undoing
one delete cost two presses.

**That is the behaviour DR-187 exists to abolish, reintroduced by the clause meant to deliver it.**

# Why it is worth writing down

A ruling is normative, and the instinct when a ruling and a test disagree is to update the test. That
instinct is right when the ruling changed the product deliberately and the test pins the old
behaviour. **It is wrong when the test encodes a promise the ruling never considered**, which is what
an old test usually is: nobody writes *"ONE undo takes back the device AND the cable"* unless somebody
once shipped two undos and was told about it.

The tell is the words. A test asserting an intermediate value has no standing against a new ruling. A
test whose name is a sentence about what a person experiences is a specification, and a ruling that
breaks it has to say so on purpose.

# What to do

- When a ruling changes something cross-cutting (undo, selection, dirty state, the file format), run
  the whole suite before believing the clause, not only the tests for the feature being built. **The
  blast radius of an undo-stack change is every gesture in the product.**
- Read a failing older test's NAME before its assertions. If the name is a promise to a person, the
  new clause is the thing under suspicion.
- When the clause loses, correct the ruling in canon with the measurement rather than editing it
  quietly: §11.186.2.1 carries the defect, the two test names and the replacement.
- Check who wrote the clause. This one was the option author's sentence attributed to the user's
  choice, which is [record the choice, not a reason they did not give](/practices/record-the-choice-not-a-manufactured-reason.md)
  for the second time: **a manufactured reason gets reasoned from, and then built.**

# Related

- [Assert the artifact, not the mechanism](/practices/assert-the-artifact-not-the-mechanism.md), which
  is why these two tests were able to catch a defect in a subsystem they never mention.
- [DR-187](/decisions/dr-187-the-schematic-holds-its-layout.md), the ruling, and its §11.186.2.1.
- [DR-156](/decisions/dr-156-a-command-reports-whether-it-applied.md), whose "first child names the entry"
  is what makes the corrected shape read right in the menu.
