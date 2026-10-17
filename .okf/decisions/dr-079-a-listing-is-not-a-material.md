---
type: Decision
title: DR-079 — A listing is not a material, and three code rules stop overstating what they know
description: LSZH was treated as satisfying NEC plenum, which is a false pass; two code rules asserted violations the product cannot establish; and an 80 percent figure was labelled as a code result.
tags: [m5, nec, validation, jacket, code-rules, g4, cr-024, dr-051, trade]
timestamp: 2026-08-19T00:00:00Z
ruling_id: DR-079
canon_section: "11.78"
status: built
---

The user reviewed the corpus against NEC and US practice and returned four
findings. Three are confirmed by the text; the fourth has no target here, and
saying so was worth more than inventing work to match it.

This is the **fourth time** an objection grounded in how the trade actually works
has beaten one grounded in these documents (see
[trade objections are questions, not findings](/practices/trade-knowledge-beats-workflow-reasoning.md)).
It is the first where the corpus was not merely incomplete but **wrong in the
user's favour**, which is the direction that does not announce itself.

# A false pass is worse than a false failure

`CODE-002` read *"error when the pathway is a plenum space and the jacket is not
`cmp` or `lszh`"*, citing NEC 800.154.

**LSZH is a jacket compound characteristic, not a listing.** Low smoke zero
halogen is an IEC and European concern about smoke density and halogen acid gas
during evacuation. It says nothing about the flame spread and smoke development
testing a plenum listing rests on, and an LSZH cable may carry no plenum listing
at all.

So the product would have told somebody their unlisted cable was fine in a
plenum. The false failure gets argued with; the false pass gets built.

Three defects sat underneath, found by reading the model rather than the rule:

* `JacketRating { cl2, cl3, cmr, cmp, lszh, directBurial }` mixed **four axes**:
  NEC article, listing, material, application.
* `Link` carried **both** a `JacketRating?` and a bare undocumented `bool
  plenum`, so a link could say `cmp` and `plenum: false` at once.
* No `CL2P`/`CL3P`, no `FPL` family, no fibre `OFN`/`OFC` classes, no `CATV`
  family, no `CM`/`CMG`/`CMX`.

`JacketListing` now carries listings only, across the five articles this
product's media touch, and LSZH becomes a separate material characteristic.

**The timing is the argument for doing it now.** No file on disk carries `lszh`,
the codec resolves by enum name, and `jacketOptions` is empty on all 38 seeded
media types. Today it is a rename; the first customer file carrying a value makes
it a migration.

# Substitutions are a lookup table

NEC permits a higher listing wherever a lower one is required. A rule checking
only for an exact match would fail a correctly-specified plenum cable in a riser,
which is the same false positive as the rules below, arriving from the other
direction.

So the hierarchy is data, on [CR-024](/invariants/)'s own distinction: a genuine
lookup table stays data while a rule stays a Dart function.

**The article boundary is the clause that will be got wrong.** A fibre listing
does not substitute for a communications one. The table is per-article, and a
listing from an article the requirement does not name resolves to **unknown
rather than false** ([G4](/invariants/g4-unknowns-are-counted.md)): a rule must be
able to say it cannot judge, because that is true.

# A code citation is a claim about somebody's licence

`CODE-001` (Class 2/3 sharing a pathway with line voltage) was a blanket error.
NEC 725.136 runs to a substantial list of permitted arrangements, and this
product models none of the facts that distinguish them, so the error fires most
often on the commercial rows where the arrangement is most likely deliberate.

`CODE-002` is accurate for the common case once the listing model lands, and
still cannot see NEC 300.22(C), which permits ordinary cable in a plenum inside
metal raceway. **This product does not model raceway.**

Both become warnings that cite the article, name the exception the product cannot
see, and say what to verify. This costs nothing that was ever enforced: G2 and G3
already guarantee no finding blocks a deliverable or gates the bytes. What
changes is whether the product tells a professional they are in violation when it
does not know that.

# The 80 percent figure is a planning estimate

`Circuit.continuousLimitAmps` is 80 percent of the breaker, commented
`NEC 210.19(A)(1)`. That is the continuous-load allowance, not a load
calculation: no demand factors, nothing classifying a load as continuous, and
what the product sums is typical times diversity in VA, a third quantity again.

**The code was already more careful than the documents**, and that half is
protected rather than changed: `totals.dart` refuses to convert `typicalWatts`
into VA without an authored power factor (AC-039), and `PWR-001` was already
demoted to a warning. No arithmetic changes. The product starts saying what the
number is.

# A stale citation carries a date, not a guessed revision

`TIA-570-D` is cited in five documents; `TIA-606-C` in one, already noting 606-D
beside it. **`TIA-607` is cited nowhere**: bonding and grounding are unmodelled.

No revision number is asserted from memory. The standards are paywalled, and a
wrong revision in a normative document is worse than a dated one.
[DR-051](dr-051-documentation-is-referenced-never-embedded.md) already built the
mechanism: a reference carries a retrieved-on date, because G4 handles unknown
and has no mechanism for stale.

The architectural facts taken from 570-D, the star topology and the Distribution
Device, are revision-independent and untouched.

# What it does not rule

It does not build the rule engine. M5 is not started, no `rules/` directory
exists, and these are catalogue rows in `docs/02` §5 and nothing else, so the
severity and copy corrections are documentation today and land as behaviour when
M5 builds them. It does not model raceway, which is what would let `CODE-002`
see the exception rather than name it. It does not model bonding or grounding.
And it does not touch the jacket **colour** convention, a different fact wearing
a similar word.
