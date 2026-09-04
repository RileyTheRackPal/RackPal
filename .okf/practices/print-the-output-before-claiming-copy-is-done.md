---
type: Practice
title: Print the output before claiming copy is done
description: A `contains` assertion cannot see grammar, density, or a sentence that has quietly become false; every instance of this in the corpus was found by reading the rendered string, never by a passing test.
tags: [ux, copy, testing, g4]
timestamp: 2026-08-19T00:00:00Z
status: adopted
---

**User-facing text is not reviewed until somebody reads it rendered.** A test
that asserts `contains('already landed')` proves a substring is present. It
cannot see that the sentence around it is ungrammatical, unreadably dense, or
**no longer true**.

# The instances, and what each one cost

**M4-G, the Quick Add summary.** A dozen green `contains` assertions over a line
that printed `1 ports`, `HDMI · HDMI` and `IEC device power (C13/C14, C19/C20)`.
Beside it, on the same read, an `ir35 in` alias resolving to the IR EMITTER
family on a command labelled `IR IN`: **the first defect that milestone where a
wrong answer destroys hardware**, and no validation dot would have flagged it,
because an emitter port with direction `in` is not structurally invalid. The
tests now pin whole strings.

**DR-074, `#724`.** A landing's refusal was reused for a move, so a panel with
no free position told a person *"that drop was not landed"*: that their cable
is loose, when it was exactly where they left it. The worse of the two things
somebody can believe about a rack they cannot see. Found by writing the test that
provoked it, not by reading the code.

**DR-074, `#726`.** `buildBindEndpointCommand` was still saying *"Moving a drop
to a different port is not something this can do yet"* **four commits after it
became possible**, guarded by a `contains('already landed')` assertion that went
on passing over copy that had become false.

# The rule

* **Pin whole sentences**, not substrings, for anything a person reads. A
  `contains` is a claim about a token; copy is a claim about a sentence.
* **A refusal is copy.** So is a status line, a menu item, a tooltip, and an
  `OpenEndpoint`'s description, which `derived/schedule.dart` prints straight
  into the schedule's TO column.
* **When a limit is lifted, grep for the sentences that announced it.** A
  refusal outlives the thing it refused, and the test that guards it will not
  notice.

# The sharpest corollary

**A wording decision reaches further than the code that makes it when the
wording is stored.** DR-074 unified two code paths on one sentence for an
unlanded end and could not reach the third: the shipped starters say *"Rack end
not yet terminated"* on 27 open ends, and every document already on disk carries
whatever string it was written with. The description is persisted, so a sweep
would move the bytes of every file holding a drop
([CR-117](/invariants/cr-117-byte-exactness.md)). Choose stored copy as though it
were a schema, because it is one.
