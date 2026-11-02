---
type: Design Ruling
title: DR-011 — the connect gesture is pin-to-pin, ports materialise on connect, and the sheet holds still
description: Seven clauses scoping M2-F, forced by three findings — nothing ever materialises a Port, committing a link re-lays-out the sheet, and every link would land in the wrong domain.
tags: [ruling, m2, wiring, gesture, keyboard, accessibility, dr-011]
timestamp: 2026-07-29T00:00:00Z
ruling_id: DR-011
canon_section: "11.11"
status: superseded-in-part
superseded_by: [DR-187]
---

Settled by the user on 2026-07-29, at the point M2-F was scoped and the connect
API [DR-008](/decisions/dr-008-wiring-model.md) shipped was read against the
document M2-F actually has to run on.

# The three findings that forced it

**Nothing in the application ever materialises a `Port`.** The only
`doc.ports[id] = Port(...)` in the tree is in a **build tool**, not app code.
`resolvePortSet` fills `portId` only where `doc.ports` already holds the derived
id, and `planAtomicConnect` skips any position where both are null. So on a
document built by placing devices from the palette, **the document the M2 exit
criterion starts from**, every port set resolves to all-null members and the
plan comes back with zero conductors. The connect API could not have created a
single conductor.

**Committing a link re-runs Sugiyama and moves every symbol.** The command
touches `EpochMask.wires`; the schematic listens on it, bumps its scene epoch,
misses the cache keyed on that epoch, and rebuilds, layout included. Only
`SheetItem.pinned` items are exempt, and **no command anywhere writes
`EpochMask.sheet`**: the sole occurrence in the tree is the declaration.

**Every link would land in domain `str`.** `AtomicConnectCommand.apply`
hardcoded `structure.undetermined` on both the `Net` and the `Service`.

# The clauses

**§11.11.1: ports materialise inside the command's `apply()`.** Not at
placement (contradicts AC-006's lazy design, inflates every file), and not as a
sibling in a transaction, `TxnScope.add` applies immediately, so a transaction
that materialises then bails leaves a history entry that did nothing visible.
Idempotent; `revert` removes what it added and **never** a pre-existing port.

**§11.11.2: the gesture is PIN-TO-PIN.** A new `ConnectPortsCommand` is the
general path; `AtomicConnectCommand` is reserved for sets flagged
`atomicConnect: true`. **The evidence is arithmetic: 223 of 257 catalog ports
carry no `setKey`**, so no HDMI, RJ45, IR or outlet port is reachable
set-to-set. Under a set-only gesture the exit criterion's sixty connections are
not hard, they are *unreachable*.

**§11.11.3: the command carries the port's real signal family.** The hardcode
was not a small wrong default: it contradicts
[DR-001](/decisions/dr-001-net-labels-by-default.md) and the coach mark that
teaches it. AC-048 fires *"Filter to a domain to draw the wires"*, under the
hardcode every wire the user just drew appears under Structure, never Digital
Video. The render model and the commit path disagreed.

**§11.11.4: creating a link does not re-lay-out the sheet.** Positions freeze;
wires and labels rebuild. This is docs/05:747 as already written, *"Auto-layout
never fires as a side effect"*. What is new is that it is now **true**. It is
also the only one of the three candidate shapes that adds nothing to the saved
file: pinning every symbol would put a `SheetItem` per device inside
[CR-117](/invariants/cr-117-byte-exactness.md)'s byte surface to carry UI state.

**§11.11.5: T1 violations are refused outright.** The corpus contradicted
itself: docs/02:854 gives T1's escape as *"None. There is nothing to escape
to"*, docs/05:441-456 offers `[ Connect anyway ]`. **docs/02 governs**: M2 would
otherwise ship a way to persist a topology violation two milestones before M5's
validation exists to flag it. Every refusal carries the rule id **and a sentence
naming real designators**. See [G4](/invariants/g4-unknowns-are-counted.md) for
the sibling principle: a refusal, like an unknown, is shown rather than
swallowed.

**§11.11.6: `Enter` commits on both canvases, under one label.** docs/05:490
specifies `Enter`, and the [keymap registry](/practices/one-keymap-registry.md)
**as built cannot express it**: the rack scope owns bare `Enter` as *"Apply the
compaction preview"*, and `meaningDrift` compares label strings across scopes.
Both scopes bind it under a single shared label and `applyCompaction` is
retrofitted. **The rejected alternative is the interesting one**: widening
`meaningDrift` to permit per-scope labels was the smaller edit and is wrong,
because that rule exists to stop one key meaning two things and *a keyboard-only
user cannot see a scope boundary*. That is the population the clause is for.

**§11.11.7: pinning-on-manual-move and Tidy are out of M2-F**, into their own
task, so the roadmap line does not silently stay open.

# What it leaves unruled

Three gesture rules the corpus never defined, deferred to the phase that reaches
them: chain-draw's *"the sink device's matching output"* never says what
*matching* means; multi-draw's *"in rank order"* never says what *rank* is, and
multi-draw is N Links where `atomicConnect` is one Link with N Conductors, one
line apart in the same document, and swapping them changes the schedule's row
count. And *"type-weighted"* snap is unquantified, with its only example naming
**connector** types where compatibility is defined over **signalFamily**:
weighting on the connector pushes toward SIG-001, since RJ45-carrying-HDBaseT
and RJ45-carrying-Ethernet are the same connector and the corpus calls them the
two most dangerous ports in the taxonomy.

# What shipped, and the two claims that died on the way

**All seven clauses are built as of `13758ff`** (M2-F, six phases). §11.11.1's
port materialisation is in `ConnectPortsCommand.apply` AND, from Phase 4C, in
`AtomicConnectCommand.apply`, which is where the finding above had SURVIVED:
Phase 0 added a guard against the symptom whose own comment described the
disease, so the set path still could not have created a conductor on a
palette-built document. §11.11.4's layout hold is a LATCH consumed at build
time, not an epoch stamp: the first implementation silently did nothing,
because `ConnectPortsCommand.touches` is `wires | meta` and the meta bump
advanced the scene epoch past the stamp the wires listener had just written.

**Two defects surfaced that no existing test could see**, both worth recording
because the shape recurs (see
[diagnose before fixing](/practices/diagnose-before-fixing.md)):

* **Every successful commit announced "Wire cancelled" to a screen reader**
  before announcing success, invisible to `find.text`, because the status line
  only ever shows the last message. Caught by intercepting
  `SystemChannels.accessibility` rather than by reading the widget tree.
* **A tap on a pin silently created a cable** from that pin to itself, because
  a connect that never left the click slop still committed.

**§11.11.7's Tidy/pinning task and multi-draw are the two things M2-F did not
do**, both tracked rather than dropped.

# The order that matters

**The keyboard path is built and driven first, not last.** M1's equivalent
clause was refuted by the user: they hit the time target but needed a mouse,
because each placement made the new device the sole selection and the caret was
consulted only when the selection was empty. Back-to-back Enters used the caret
once, then fell back. See
[diagnose before fixing](/practices/diagnose-before-fixing.md); this is the
same shape, a mechanism that reads as working because its first invocation does.

# Citations

[1] canonical-decisions.md §11.11 (`docs/canonical-decisions.md`)
[2] `packages/rackmate_core/lib/src/commands/atomic_connect.dart` (the precedent
[3] `docs/05-schematic-editor.md` §14, :441-456, :472-490, :747
[4] `docs/02-data-model.md` :854, :864-871) the T1 rules
