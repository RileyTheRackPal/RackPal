---
type: Design Ruling
title: DR-154 — The plan advisories are a second band, the count they must not join was already wrong, and three sweeps that said "every rule" meant one catalogue
description: >-
  docs/15 §9's four PLN rules ship in their own list rather than as four more
  rows in docs/02 §5, because CR-021's "a rule not listed there does not exist"
  is about a specific there. The band is separate and the machinery is not. The
  chapter's own opening count was stale by one in twelve places, PLN-002 found a
  shipped surface dropping outlets by a comparison, and once the catalogue was
  two lists three gates went on proving things about one of them.
tags: [ruling, plan-view, validation, drc, cr-019, cr-021, cr-022, ac-051, g4, dr-154, plan-i]
timestamp: 2026-09-10T00:00:00Z
ruling_id: DR-154
canon_section: "11.153"
status: ruled
---

Ruled and built on 2026-09-10 as `PLAN-I/1` (`#645`) and `PLAN-I/2` (`#646`).

# A second band, not four more rows

`PLN-001` to `PLN-004` are listed in docs/15 §9. docs/02 §5 is the v1 DRC
catalogue: the one AC-040 sized, AC-051 gates and `rule_catalogue.dart` carries.
CR-021 says *"a rule not listed there does not exist"*, and **each band has a
there**, so `kPlanRules` is bound to docs/15 §9 by a test that parses that table
exactly as `rule_catalogue_test.dart` parses docs/02 §5.

**The band is separate and the machinery is not.** `kRulesById` spans both lists,
`evaluateDocument` runs both maps, and a `PLN-*` finding takes an override, an
`off` and an acknowledgement through the same three steps in the same order. A
second path is what `drc.dart`'s header already forbids and what CR-019 already
refused for the mute.

**It is not a fourth tier.** `RuleTier` describes *when* a rule runs and all four
are post-hoc; the band is about *which catalogue* they belong to, which is a
different question.

# The count the chapter was about was already wrong

`#645` opens by naming the trap: *"AC-040 pins v1's catalogue at 27 and DR-020
made it 28 (8 + 6 + 14)."* It is **29**. DR-132 restored `ELE-005` at `#838`, the
table and the test moved with it, and the prose did not, in twelve sentences
across six documents including a box in an ASCII diagram.

Every one now cites the tier arithmetic or points at the test. **The warning
against writing a count down was delivered inside a paragraph containing a stale
count**, which is the sixth instance in this corpus.

# `PLN-004` cannot be a `DrcRule`

A `DrcRule` takes a `RackDocument`, which holds no bytes: an underlay names a
container member and the members ride on the session. So the comparison happens
where the bytes are, once, and `evaluateDocument` takes the answer. A hash
computed inside the evaluator would be a sha256 over every underlay **on every
widget build**, since findings are recomputed in `build`.

The comparator answers `null` rather than `false` for an unparseable hash, on
`templateHashMatches`'s ruled precedent: `false` asserts *this was edited* and
`null` says *there is nothing here to check against*.

It is a **warning** and the other three are advisories. Three of them say *you
have not done this yet*; this one says *what you are looking at may not be what
you measured*. It still blocks nothing (CR-022, G3), which is AC-042's own rule.

# A shipped surface was wrong underneath `PLN-002`

`unpinnedCarriersFor` compared locations for equality. docs/15 §3.1 says an
underlay's location is *"usually a floor"*, so on a `Level 1` plan an outlet filed
in `Great Room` matched neither the scope nor the unknown branch: it was **dropped
by a comparison and appeared in no count at all**. That is the `0 pathways`
failure `unlocatedCount` exists to prevent, arriving through the door beside the
one it was watching.

**The order of the two findings is the lesson.** The clause was ruled from the
design document alone; the shipped code disagreed with it twenty minutes later.

# Three sweeps that said "every rule" and meant one catalogue

Once the catalogue was two lists, the tests carrying *"every rule is
acknowledgeable"* (CR-019), *"every rule that files a finding has a severity"* and
*"every severity still exports"* (CR-022) all kept looping over `kRuleCatalogue`.
None broke and none could: **a `for` loop is correct about the collection it names
and has no way to say it expected more.** See
[a gate's scope is part of its claim](/practices/a-gates-scope-is-part-of-its-claim.md).

The severity one is not cosmetic. `projectSeverity` returns null for a rule it
cannot find and `evaluateDocument` **drops** a finding on a null rather than
defaulting, which is G4 one layer up. A plan rule missing from `kRulesById` would
not throw and not warn. It would never fire.

# And the issues panel could not name any of them

`locusLabel` resolves a finding's primary through four collections and returns
null for anything else; every `PLN-*` points at a `PlanUnderlay`, so all four
grouped under `No single location`.

**The guard that promised to catch this sat through it.** The surface's header
said a fifth type would be *"a test failure, not a blank cell"*, and the test
carrying that promise asserts `locusLabel` returns null for a hand-written
stranger id: a statement about an id **no** rule produces, which cannot see a type
that rules **do** produce. It was the sixth type, not the fifth: `ELE-005` has
pointed at a `Net` since `#838`.

The census is now taken over the corpus, where every rule's known-bad already
runs, and it found both on its first run.

# What this does not rule

Not whether `PLN-*` ever becomes v1 scope rather than v1.1. Not the remedy actions
a plan finding might offer, which nothing asks for. Not `T0.02`'s rendering of an
acknowledged plan advisory, which is M6's sheet and which the export proof names
as the item that retires its one absence assertion.

**Related:** [DR-146](dr-146-uncalibrated-states-what-it-costs.md) ·
[DR-142](dr-142-what-the-unpinned-strip-lists.md) ·
[DR-132](dr-132-ele-005-restored-a-rule-that-already-had-an-id.md) ·
[DR-149](dr-149-the-plan-sheet-and-the-export-path.md)
