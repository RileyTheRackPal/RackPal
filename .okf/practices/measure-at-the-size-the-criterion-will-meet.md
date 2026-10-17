---
type: Practice
title: A performance criterion is only met at the size it was measured at
description: The schematic met its one-frame budget at 300 links and missed it by 5.8x at 3,600; the fixture, not the code, was what nobody had questioned in three milestones.
tags: [practice, performance, fixtures, testing, m2, m8-f]
timestamp: 2026-08-15T00:00:00Z
status: adopted
---

**When a criterion names a fixture size, write down what that size represents
and measure one deliberately larger.** A budget met at the size somebody chose
while writing the budget is evidence about that size and nothing else.

# The evidence

M2's exit criterion is *"routes a 300-connection fixture within one frame at
commit"*. It has passed on every push since M2-C, at **5.8 ms against a 16.7 ms
budget**, defended by a real committed `.rmpj` golden with a genuine cycle,
zero-port devices, a shelf chain and off-rack destinations. The instrument was
good. The number was true.

**300 links is a house with one rack.**

| Links | Scene build | Against one frame |
|---|---|---|
| 300 | 5.8 ms | within |
| 1,200 | 93 ms | 5.6x over |
| 3,600 | 97 to 110 ms | **5.8x over** |
| 7,200 | 207 ms | 12x over |

Measured on 2026-08-15 by a probe built to answer a question about the
persistence layer, which turned out to be fine. Nothing in three milestones had
asked the schematic the same question, because the gate was green.

# Why it stayed invisible, and it was not carelessness

Every property that makes the 300-link fixture a good fixture also makes it a
comfortable one. It is committed, so it never drifts. It is asserted for shape,
so it cannot silently shrink. It is realistic, so the number means something.
**None of those is a statement about size.**

The failure mode is specific: **a green gate reads as "this is fast" when it
only ever said "this is fast at N".** The larger N is never tested because the
gate is green, and the gate is green because the larger N is never tested.

# A second instance, and it is not about performance

DR-138's PDF lifter was run against a real 18-sheet plan set **before a line of
test was written**, and refused all 18 pages with *"has an unreadable image
object"* while the parser was working perfectly. Its object reader scanned from
`obj` to `endobj` inside a 64 KB bound; an image XObject is a dictionary
followed by hundreds of kilobytes of JPEG, so it found neither terminator and
returned null.

**A hand-written fixture could not have found it**, because a fixture small
enough to write by hand has its `endobj` well inside the bound. That is this
practice's sentence exactly, in a correctness setting rather than a performance
one: *every property that made the fixture good also made it comfortable.*

**And the failure mode is the part to remember.** A parser bug presented as a
*content* refusal, which is the one shape where the refusal is plausible and
would have been believed. The synthetic suite that followed is 31 cases and every
one of them passes against the broken version.

# The check

For any perf gate, ask two questions of the fixture rather than of the code:

1. **What does this size represent in the trade?** Write the answer in the
   fixture's header. "300 links" is not an answer; "a house with one rack" is,
   and it invites the obvious follow-up.
2. **What is the largest thing a customer will open?** Measure that too, even
   when it fails. Especially when it fails.

# A case that fails today is still a gate, if it says so

The headroom case cannot assert the real budget: it would fail on every commit,
and a permanently red gate is one people learn to ignore. So it asserts a
**ceiling** far above the measured figure, which catches a regression making an
already unacceptable number worse.

**And it asserts the number is still over budget**, which is the half worth
copying:

```dart
expect(ms, lessThan(_kHeadroomCeilingMs));  // the ratchet
expect(ms, greaterThan(_oneFrameMs),        // the debt
    reason: 'the headroom case now fits in ONE FRAME, which means #702 '
            'has been fixed. Delete _kHeadroomCeilingMs and assert '
            '_oneFrameMs here.');
```

The day the defect is fixed, the test fails and tells whoever fixed it what to
change. A debt recorded only in a comment is a debt nobody is told they have
paid. Compare [a test that asserts an absence names its due
date](a-test-that-asserts-an-absence-names-its-due-date.md), which is the same
idea pointed at a different kind of gap.

# The corollary about caches

The schematic screen memoises its scene, carefully, with a header explaining why
it must not rebuild "because a chip was clicked". It does not rebuild for any of
those. It rebuilds on **every document change**, because the epoch it keys on is
bumped by `_onDocumentChanged`.

**A cache is only as good as the coarseness of its invalidation**, and a cache
whose key changes as often as the thing it caches is a cache in name. Read the
bump site, not the lookup site.

# Citations

[1] docs/12 §5.1.9, the measurement and the ruling that followed it
[2] Board `#702` (the fix, blocking M6), `#424` (M8-F1, the probe)
[3] `packages/rackpal_core/test/scene/schematic_perf_test.dart`, the headroom group
[4] `apps/rackpal/tool/scale_probe.dart`
[5] AC-008, whose per-domain partition was built for paint and not for recompute
