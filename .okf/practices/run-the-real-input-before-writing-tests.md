---
type: Practice
title: Run the real input before writing the tests, and check whether the refusal is right for the right reason
description: >-
  The PDF lifter refused all 18 pages of the first real plan set with a plausible
  content refusal while the parser was fine; no hand-written fixture could have
  found it. The second real set agreed with the fixtures exactly, which is what
  makes this a rule of thumb rather than a law.
tags: [practice, testing, fixtures, parsers, pdf, plan-view]
timestamp: 2026-09-08T00:00:00Z
---

# The founding case

`PLAN-D/3`'s page lifter was run against the first real plan set before a line of
test was written. It refused **all 18 pages** with *"has an unreadable image
object"*, and the parser was working perfectly.

`_body()` read an object from `obj` to `endobj` inside a 64 KB bound. An image
XObject is a small dictionary followed by hundreds of kilobytes of JPEG, so it
found neither terminator and returned null.

**The failure mode is the lesson.** A parser bug presented as a *content* refusal,
in the one shape where a content refusal is plausible and would have been
believed. **A synthetic fixture could not have found it**, because a fixture small
enough to write by hand has its `endobj` inside the bound. After the fix: 18 of 18
lifted, byte counts matching an independent Python carve exactly.

docs/12 §5.9.6.4 carries the measurement.

# The counter-case, which is why this is a rule of thumb

[DR-145](/decisions/dr-145-the-second-plan-set-is-all-vector.md)'s AutoCAD plot
was refused on all three pages, and the synthetic case
*"no XObject at all is refused"* had asserted the same string all along. **The
fixtures were right that time.** Nothing about the first case predicts which time
it will be; running the real input is what establishes which one you are in.

# The check that separates them

**A refusal can be right for the wrong reason, and the two look identical from
outside.** Ask *where in the code the message comes from*, and what the code had
to get right to reach it.

`draws no image` sits in `liftPage` **after** the MediaBox, malformed-box and
Resources checks. So a real file reaching it proves the parser resolved the
cross-reference table, walked the page tree, read a usable `/MediaBox` and
resolved each page's resource dictionary first. Had any of that failed, the
message would have been a different one, by name. That is what turns "it refused,
as expected" into evidence.

The first case failed exactly this test and nobody applied it: *"has an unreadable
image object"* is emitted **after** the same checks, but it is emitted **for a
reason the file did not have**, and the way to see that was to ask why 18 of 18
pages would all carry an unreadable object.

# What is still unproven

Running one real file proves the paths that file exercises and nothing else.
Neither real set has an object stream, so `PdfCompressedCrossReferenceError` has
still only ever fired on a fixture; and neither has a page that is *partly* an
image, so the picker's mixed grid is untested against a real document.

Say which paths a real input covered, rather than letting "tested against a real
file" stand for the whole surface. See
[a gate's scope is part of its claim](a-gates-scope-is-part-of-its-claim.md) and
[a stated cost is a hypothesis](a-stated-cost-is-a-hypothesis.md).
