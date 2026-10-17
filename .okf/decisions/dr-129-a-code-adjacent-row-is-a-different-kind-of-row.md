---
type: Design Ruling
title: DR-129 — A code-adjacent finding is a different KIND of row, and the button that was ruled twice
description: >-
  `CODE-002`'s NEC article was findable only by reading to the end of a sentence,
  and `RuleMeta.governing` holds this repository's ids rather than the code's. The
  catalogue gains `codeCitation` and the row gains `ConsoleStatus.caution`, a
  diamond rather than a triangle, because a code row is a different question and
  not a louder warning. The severity is untouched. And the panel finally renders
  `Finding.remedy`, which DR-128 had already claimed it did.
tags: [ruling, validation, drc, code-001, code-002, nec, remedy, rulemeta, console-status, m5, dr-079, dr-125, dr-128, pal-1]
timestamp: 2026-09-06T00:00:00Z
ruling_id: DR-129
canon_section: "11.128"
status: built
---

# DR-129 · A shape says "different kind" where a colour says "different amount"

Board `#840` (M5-M), authorised by
[DR-127](dr-127-the-review-s-unpriced-findings-enter-m5.md). Settled by the user
2026-09-06 on the twelfth of the M5-H2 review's findings: *"a code-adjacent
finding wants more than a row in a panel."*

## The finding: the citation was prose, and that is the whole problem

`CODE-002`'s message ends *"Verify against NEC 800.154; 300.22(C) permits a metal
raceway, which this product does not model."* Every word of it is right, and
**the article is findable only by reading to the end of a sentence that begins
with a cable designator.**

`RuleMeta` carries `summary`, `rationale` and `governing`, and `governing` holds
**this repository's own ids** (`AC-027`, `DR-079`), not the code's. So nothing in
the model said "this rule turns on an external document", and the panel drew
these two rows exactly like a cable being three metres too long.

## Ruled: the catalogue authorises the fact, the surface renders it

`RuleMeta` gains `codeCitation`, on DR-125's precedent (canon §11.124; it has
no concept in this bundle yet, which is the twenty-two-ruling gap the index
records) rather than a widget inferring something from the shape of a rule id.
`CODE-001` declares `NEC 725.136`, `CODE-002` declares `NEC 800.154`. **Two rules
and no others**, which is a checkable claim and is checked, NAMED in the test
rather than counted: a count of two passes on the wrong two.

`300.22(C)`'s metal-raceway exception stays in the message. It is an argument
about what this product cannot see, not a citation to look up, and a sentence is
where an argument belongs.

## A different shape, not a louder colour

`ConsoleStatus` carries five values and `statusForSeverity` maps four.
**`caution` had been defined, themed, and reachable by no finding since M5-F**;
`status_marker.dart` draws it as a **diamond** where warning is a triangle.

The reason is the one DR-079 gave when it demoted both rules to `warning`: **this
product cannot see the thing the code article turns on.** A code row is not a
louder warning, it is a different question, and a shape says "different kind"
where a colour says "different amount". PAL-1's argument one domain over is that
hue alone is never the channel.

**THE SEVERITY IS UNTOUCHED, and that is asserted rather than assumed.**
`Finding.severity` stays `warning`, the filter still finds these rows under
Warning, and an override still moves them. Only the marker differs, which is a
rendering fact and not a validation one.

## And the button that was ruled twice

DR-128 §11.127.5 states that the issues panel *"renders it as a button"*. **It did
not.** `Finding.remedy` shipped, `PWR-003` declared one, `addOutletsToRack`
implemented it, and `drc_panel.dart` never read the field, so `[ Add a rack PDU ]`
existed nowhere a person could press it.

**That is the second phantom button in two rulings.** The first was
`SpringBackRemedy`'s two members, and **Dart's exhaustive switch caught that one
within the hour**, because a chip's handler must match every enum value. This one
had no such backstop: **a nullable field a widget ignores compiles perfectly and
tests green**, because every test that could have noticed was written against the
model.

So the gate is the correction. `remedy_pairing_test.dart` asserts the pairing in
**both directions**, in the shape the chips already use. *"A remedy nothing
renders is a button nobody can press"* is now a failing test rather than a
sentence written twice. See
[a-modelled-field-is-not-a-reachable-one](../practices/a-modelled-field-is-not-a-reachable-one.md).

## What was offered and not taken

A separate verification dialog for code rules, recording who checked what against
which edition. `AckedFinding` already carries `reason`, `by` and `at`, so the
record exists; what a code acknowledgement wants is a different QUESTION, and
**the place that earns its keep is T0.02, the exceptions sheet, which is M6-C and
not built**. Building the dialog first would design a form for a page nobody has
drawn.

## What building it found: the panel has no host

Wiring the remedy button meant finding the panel's caller. **There is none.**
`DrcPanel` appears in exactly two files in the tree, the one defining it and the
one testing it, and outside that widget file nothing calls `evaluateDocument` or
`groupFindings` at all.

**Everything M5-F built is real, tested and unreachable**, so docs/12 §5.4.6's
closing *"They can now"* is false and is corrected. Filed as `#847` and NOT fixed
here: mounting the panel is a shell decision that `docs/04` §4.1 already describes
a seam for (`PanelHost` keyed by `PanelId`, neither of which exists in the tree),
and improvising a mount point inside a rule-surfacing chapter would be the shelf
mistake a second time.
