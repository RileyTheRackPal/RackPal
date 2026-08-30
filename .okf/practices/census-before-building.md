---
type: Playbook
title: Census the data before building the rule that reads it
description: Print the field over the whole corpus first, and make sure "the whole corpus" is not really "the directories I thought of". It has caught an empty field, an unmeasured cost, a wrong ordering nobody had compared, a field that collapses rather than being absent, and once a census whose own glob missed the generator of four shipped artifacts.
tags: [practice, measurement, catalog, debugging, m2]
timestamp: 2026-08-01T00:00:00Z
status: adopted
---

Before writing a rule that reads a field, **print that field over the whole
corpus and look at it**. It costs one throwaway test. It has now paid three
times, in three different ways, which is why it is a practice rather than an
anecdote.

# One: the field is empty (DR-012)

`acceptedFamilies`, `channelIndex` and `maxConnections` are declared, round-trip
through the codec, and are populated on **none of the 727 seed ports**. Three
gesture rules were about to be written against them. A rule reading an empty
field does nothing on every real document, and its tests pass because they
supply the fixture the catalog does not.

The census is what turned three plausible designs into
[DR-012](/decisions/dr-012-deferred-gesture-rules.md)'s single piece of
evidence.

# Two: the cost was never measured (M2-G)

M2's exit criterion asks for a 300-link fixture "within one frame at commit",
and the clause was marked `DEMONSTRATED` against a test measuring the display
list being BUILT, 3 ms. Counting the actual paint found **63.9 ms against a
16.7 ms frame**, 83 % of it repeated text layout.

The same census refuted the roadmap's own sizing twice: it prescribes a cache
for ~10,000 runs against a measured working set of **703**, and its prescribed
key would have caused the thrash it warned about.

# Three: the ordering was wrong and nothing had ever compared it (#93)

Checking that `bankKey` was reachable from the shipped catalog (the DR-012
habit, applied) meant printing each bank's ports in rank order. `A01` came
out as `src.1.l src.3.l src.3.r src.4.l … src.1.r`, which is not an order at
all.

**678 of 727 ports were mis-ordered**, and had been through every milestone.
See [the gate that now holds it](/gates/catalog-port-order.md). Every existing
test consumed the same wrong answer the code did, so they agreed with each
other perfectly; the two orderings had never been put side by side.

# The shape

The three failures are the same failure. **A value that is never compared
against anything cannot be wrong**, because there is nothing for it to
disagree with. Tests written from the same assumption as the code inherit the
assumption. A census breaks that by introducing a second source, the corpus
itself, and reading it with human eyes rather than an `expect`.

**Do it before, not after.** All three of these were caught before shipping the
rule that would have depended on them, which is the whole margin: the same
finding a week later is a regression in a released build.

# The variant where the CENSUS ITSELF was scoped wrong (`#795`)

**Every instance above assumes the census covered the corpus. This one did
not, and nothing in the method notices.**

Making `contentHash` a real sha256 began with a census of every writer:
`grep -rn "contentHash: '" packages/*/lib apps/*/lib`. Eight sites, all
handled. **Two more were outside the glob.**
`apps/rackpal/tool/starters/authoring.dart` is in `tool/` rather than
`lib/`, and it is the generator of **four shipped artifacts**. Left alone,
the four starter projects would have kept `sha256:seed-A01` while a freshly
created blank project got real hashes: two conventions in one product, in
the files a new user opens first.

**It was caught by an artifact disagreeing with an expectation, not by the
method.** `generate_starters.dart --check` reported all four unchanged when
they should have moved. Had the starters been generated at build time rather
than checked in, nothing would have said anything.

> **Scoping a census by directory is a filter, and a filter needs the same
> justification as a query.** `packages/*/lib apps/*/lib` reads like "the
> source", and it is really "the source I thought of". `tool/`, `test/` and
> anything generating a tracked artifact are all places a production value
> can be spelled.

The cheap correction is to census the whole tree first and *then* explain
each hit you are excluding, rather than excluding by path before looking.
That inverts the failure: an unjustified exclusion becomes visible, where an
unconsidered directory never is.

# The variant that survives a census: a field that collapses

**DR-084 is the sixth instance and it is not the same shape as the other
five.** Those found a field that was **empty**, and an empty field is caught by
the first query anybody writes: `accentColor` on 0 of 48 templates,
`acceptedFamilies` on 0 of 727 ports, `NetworkConfig` with no writer.

`TemplateBody.glyph` was different. It is null on all 48 seeds, but it
**resolves**, through `effectiveGlyph`, to a category default. So every query of
the form *"does this have a value"* answers yes, and
`device_glyph_test.dart` asserted exactly that and passed, correctly, for weeks:
*"every one of the 48 seeded templates resolves to a mark."*

**They resolved to nine marks out of seventeen.** An existence assertion cannot
see a collapse: 48 resolving to 9 satisfies it as well as 48 resolving to 17.

So the census question is not only *is the field populated*. It is **how many
distinct values does the corpus actually produce**, which is the number a person
looking at the artifact would count. Print the histogram, not the coverage.

**Then leave a gate behind.** A census is a one-off; the assertion it justifies
is what stops the finding coming back. DR-012's became
`multi_draw_test.dart`'s first group, M2-G's became `paint_budget_test.dart`,
#93's became [catalog-port-order](/gates/catalog-port-order.md).
