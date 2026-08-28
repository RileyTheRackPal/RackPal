---
type: Design Ruling
title: DR-095 — A milestone closes on clauses discharged or parked, and parking costs a ruling
description: >-
  Roadmap §8.9. A milestone opens only over a predecessor whose clauses are all
  discharged or parked. Nothing new is defined: §8.1 and docs/12 §0 already said
  what complete means. What is created is a boundary at which it must be true,
  because the habit held for two transitions out of four and nothing had named it.
tags: [ruling, process, milestone, exit-criterion, dr-095, dr-017, dr-027, dr-040, m0, m3, m4]
timestamp: 2026-08-26T00:00:00Z
ruling_id: DR-095
canon_section: "11.94"
status: ruled
---

# DR-095 · A milestone closes on clauses discharged or parked, and parking costs a ruling

Settled by the user 2026-08-26, in DR-017's lineage as a ruling governing **process rather
than product**.

## The habit held twice out of four, and nothing had named it

The account was that each milestone finished before the next opened. Checked against the
record, **that is true of two transitions and false of two**: M1 to M2 and M2 to M3 held;
M0 to M1 and M3 to M4 did not. M3's subject-tagged work ran to 2026-08-10 and M4 opened on
2026-08-13.

The habit was real and it was a habit. **Nothing named it, so nothing noticed when it
lapsed**, and the lapse stayed invisible for thirteen days because the artifact that would
have shown it, docs/12 §5.2's header row, was itself stale.

## No new definition, only a place the old one must be true

§8.1 already rules that the exit criterion is the unit of truth. docs/12 §0 already rules
that `DEMONSTRATED` and `CONFIRMED` are **the only two of seven marks that discharge a
clause**. Between them, "complete" has been defined since the board was written. What this
adds is a **boundary at which the definition is checked**.

## Parking, because a strict reading deadlocks

Some clauses cannot be discharged by the milestone that owns them. M3's criterion asks for
a Pull Sheet export that is M6's work to build. [DR-027](dr-027-m3-owes-rows-m6-owns-sheets.md)
had already built the way out by **splitting the clause**: M3 owes the derivation, M6 owns
the sheet.

So **parked** means reassigned **by ruling ID** to a **named later** milestone, with the
structural reason stated. Not "deferred", not "won't fix", and never a bare move.

**Closing is the moment that binds; opening is soft.** Work landing early against a later
milestone stays legal, which is what keeps the rule from being a stop-the-world gate.
Unlike §8.8, it is **retroactive to M0**, because a clause's evidence can be re-run.

## The ruling's own worked example is a paragraph that was true and stale

As first published, §11.94.7 recorded M3's clause 2b as *"owed, and the expensive one"*,
and carried the consequence that **M4 could not close until landings existed in the
model**. Every sentence of that was true on 2026-07-27 and false by the time it was
written: [DR-040](dr-040-a-drop-lands-on-a-panel-port.md) had settled it on 2026-08-11,
`BindEndpoint` was built, and the allocator's callers were no longer confined to its own
test.

A ruling written to catch staleness was published containing some. That is the argument for
the boundary rather than against it, and it is kept in canon rather than corrected away.
See [a confident paragraph is a
tell](/practices/two-documents-agreeing-is-not-verification.md) and
[DR-097](dr-097-the-tracker-grows-a-fourth-level.md), which found the same class on the
tracker: three milestones whose criteria were met and whose board rows still read `To Do`.
