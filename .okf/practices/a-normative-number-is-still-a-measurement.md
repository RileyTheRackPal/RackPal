---
type: Practice
title: A number in a ruling is still a measurement, and a ruling is where nothing checks it
description: >-
  A figure written into a normative clause is read as settled by everyone who
  meets it afterwards, including the person who wrote it. DR-152 was ruled on a
  cap of "roughly 180 rows" that measured 60, and the wrong number was copied
  into two more files before a test asked for it. Run the arithmetic before it
  is ruled on, and pin it in a test rather than describing it in prose.
tags: [practice, decisions, measurement, testing, mutation, plan-h]
timestamp: 2026-09-09T00:00:00Z
---

`DR-152 §11.151.4` chose the schedule band's layout on a measured table, and then
closed with one sentence that was not measured:

> **A COUNTED OVERFLOW SURVIVES AS THE LAST RESORT AND IS EXPECTED NEVER TO
> FIRE.** Three columns at the band's cap hold roughly 180 rows.

**The cap was sixty.** Rows-per-block times blocks had been multiplied in the
wrong direction. Sixty is DR-037 §11.36.1's own rough-in, the exact scenario the
exit criterion names, so the last resort fired on the sixty-first drop of an
ordinary house.

# Why a number in a ruling is worse than a number in a comment

The corpus already knows that **a second copy of a moving number is a
liability**. This is the harder case, and two things make it so.

- **A ruling is normative.** A stale comment is corrected by whoever next reads
  the code beside it. A ruling is the thing the code is checked against, so a
  wrong figure there is not a stale copy of a truth held elsewhere: for a while,
  it is the only copy.
- **It propagates as agreement.** The 180 went from the ruling into the file
  header and into an export comment, and by then three places said it. Three
  files agreeing is what verification is supposed to look like, which is
  [two documents agreeing is not verification](/practices/two-documents-agreeing-is-not-verification.md)
  arriving with a citation attached.

# The rule

**Run the arithmetic before the clause is written, and then pin it in a test
rather than describing it in prose.** The test that found this one is three
lines:

```dart
test('the cap on a real T1.01 is eighty rows, and the 81st is counted', () {
  expect(band(80).omitted, 0);
  expect(band(81).shown, 80);
  expect(band(81).omitted, 1);
});
```

A capacity, a threshold, a break-even point or a budget stated in a ruling is a
claim about the code, so it belongs where a claim about the code is checked. The
prose should then say what the number MEANS, and let the test say what it IS.

# The tell

**A superlative attached to an unmeasured figure.** *"Expected never to fire"*,
*"no document this product can make comes near it"*, *"roughly"*: each of those
is a confidence statement standing in for the arithmetic, in the one place where
the paragraph is binding. Grep a finished ruling for its own numbers and check
each one against something that runs.
