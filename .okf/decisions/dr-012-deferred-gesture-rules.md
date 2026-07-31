---
type: Design Ruling
title: DR-012 — the four gesture rules DR-011.8 deferred, and the three empty fields that decided them
description: Chain-draw's "matching", multi-draw's "rank", type-weighted snap's axis, and where the coach mark's "first" lives — three settled by the same arithmetic, that the fields which look purpose-built are populated on none of the 727 seed ports.
tags: [ruling, m2, wiring, gesture, snap, coach-mark, dr-012]
timestamp: 2026-07-31T00:00:00Z
ruling_id: DR-012
canon_section: "11.12"
status: ruled
---

Settled by the user on 2026-07-31, at the point M2-F Phases 0–3 had shipped
and Phase 4 could not start without them.
[DR-011](/decisions/dr-011-connect-gesture.md) §11.8 named three and said they
would be ruled "when M2-F Phase 4 reaches them, not before"; the fourth is the
coach-mark question the same clause sent to Phase 5.

# One piece of evidence decided three of the four

**Three `PortDef` fields that look purpose-built for these questions are
declared, round-trip through the codec, and are populated on NONE of the 727
seed catalog ports**: `acceptedFamilies`, `channelIndex`, and — per DR-011's
own finding — `maxConnections`. `seed_registries.dart:394` says the first one
outright: *"The exclusion list is not on the M0 class yet; the family
separation is."*

A rule written against an empty field does nothing on every real document.
That is the trap `effectiveMaxConnections` was introduced to escape in M2-F
Phase 0, and these clauses escape it the same way — which is why the shape
recurs rather than being coincidence.

# The clauses

**§11.12.1 — chain-draw's "matching output" is the same `signalFamily`.** The
reading that sounds most natural is ruled out by docs/05:482's OWN worked
example: `ATV-1 → MTX-1 IN1` then `MTX-1 OUT1 → DA-1`. **A matrix switcher has
no pairing between IN1 and OUT1** — that is what makes it a matrix — so
*matching* cannot mean "the output paired with that input", and nothing in the
model pairs them. First free output of the same family, tie-broken by
`PortDef.order` then `key`: the sort `PORT_SEQ` already uses, because two
orderings of one port list is how a pin gets one number on the schedule and
another in the set that wires it. No such output ⇒ the chain ENDS and says so.

**§11.12.2 — multi-draw's "rank" is that same order, and it stays N `Link`s.**
`channelIndex` is undocumented, nullable and set nowhere, so a rule reading it
falls through to this answer on every real document with a branch nothing can
test. The N-Links half was never truly ambiguous — docs/05:484 says "N `Link`s"
and the next paragraph says an atomic set is "one `Link` with N `Conductor`s"
— and is ruled so it cannot drift: **eight cables on the pull sheet is a
different bill of materials from one cable with eight conductors.**

**§11.12.3 — type-weighted snap weights the FAMILY, absolutely.** docs/05:477's
example names connector types while :473 defines compatibility over
`signalFamily`, and the difference is the product's worst available mistake:
RJ45-carrying-`video.hdbaset` and RJ45-carrying-`net.ethernet` are the same
connector, docs/05:145 calls them the two most dangerous ports in the taxonomy,
and the seed registry records that patching HDBaseT into a switch does not work
and its 100 W PoH can damage the switch. A magnet steering toward that would
make the hazard sixty times an hour. The weight is **absolute rather than a
number** because the corpus gives none (only "more than 3 px"), and the 12
screen px snap radius already bounds it; `Ctrl` is the documented override and
was built in Phase 3.

**§11.12.4 — the AC-048 coach mark's "first" lives in app-support prefs.** Not
document state — it re-fires per file and puts UI chrome inside
[CR-117](/invariants/cr-117-byte-exactness.md)'s byte surface, the identical
objection that decided §11.11.4 against pinning every symbol. Not unpersisted —
a mark that returns every launch is a nag. Per USER, not per project: the
second project is not the first time they have seen the app.

# What it leaves unruled

**The T2 compatibility matrix is still absent.** `acceptedFamilies` is declared
and empty and `SIG-001` does not exist until M5, so §11.12.3 is an ORDERING
HEURISTIC over pins the tier-1 rules have already allowed. It is not validation
and must not be read as any — see
[DR-011](/decisions/dr-011-connect-gesture.md) §11.5, which refuses T1 outright
and leaves every T2 rule to M5. When M5 populates the matrix,
`effectiveAcceptsFamily` is the seam it lands on.

# Citations

[1] canonical-decisions.md §11.12 (`docs/canonical-decisions.md`)
[2] `docs/05-schematic-editor.md` :473, :477, :482, :484, :145, §11.6, §14
[3] `packages/rackmate_core/lib/src/catalog/seed_registries.dart:394`
[4] `packages/rackmate_core/lib/src/derived/connect_target.dart` —
    `effectiveMaxConnections`, the shape §11.12.3 reuses
