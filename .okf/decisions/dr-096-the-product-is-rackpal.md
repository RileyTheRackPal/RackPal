---
type: Design Ruling
title: DR-096 — The product is RackPal, and the wordmark is the one thing this repository cannot re-cut
description: >-
  A trademark search found a homelab hardware company using RackMate, with a high
  assessed likelihood of a cease and desist. The name is withdrawn. The search ran
  before any certificate or domain was bought, which is the whole reason the finding
  was cheap, and the sweep's rule is rename the product, never the record.
tags: [ruling, naming, trademark, sweep, dr-096, rj-017, dr-006, dr-089, m8]
timestamp: 2026-08-26T00:00:00Z
ruling_id: DR-096
canon_section: "11.95"
status: superseded-in-part
superseded_by: [DR-179]
amended_by: [DR-251]
---

# DR-096 · The product is RackPal, and the wordmark is the one thing this repository cannot re-cut

Settled by the user 2026-08-26. **RackMate is withdrawn; the product is RackPal.**

Not a §8.3 amendment on [DR-089](dr-089-the-wordmark-ships-as-outlines.md)'s reasoning: §8.3
governs moving an item between scope bands and nothing moves. The scope list is untouched,
every exit criterion stands verbatim, no milestone gains or loses a clause. What changes is
an identifier, and it takes a ruling ID because §8.2 wants one for a change this size.

## A rule that paid, on a board otherwise listing the ones that did not

RJ-017 put *"a trademark search before any certificate or domain is bought"* into hardening,
and [DR-089](dr-089-the-wordmark-ships-as-outlines.md) restated it while shipping the
wordmark. **It ran, and it found a company producing homelab-focused hardware using
RackMate**, with the likelihood of a cease and desist assessed high.

Nothing had been bought and nothing signed when that came back.
[DR-006](dr-006-self-signed-distribution.md) had already chosen self-signed distribution
with no OV/EV reputation ramp, so **there was no certificate to reissue and no SmartScreen
history to lose**. This is the cheapest moment the finding could have arrived, and it
arrived there because a rule said it had to arrive *before* the purchases rather than with
them.

RackPal cleared its own search before being ruled, rather than adopted on assumed
availability, which would have repeated the failure at twice the cost.

## Rename the product, never the record

The sweep is mechanical except where the string is a quotation, and that exception is the
whole risk. Canon quotes rulings and critiques word for word, so a name inside a blockquote
is **a record of what was said under the name in force at the time**. The identical
argument already protects blockquotes from the em-dash sweep.

Blockquotes, the M1 implementation log and the `.okf` bundle are history and keep the old
name. Everything else, code, identifiers, package names, paths and live prose, becomes
RackPal.

## The count was wrong twice before it was right, and both errors are kept

This is the transferable part, and it is kept in canon rather than corrected away.

* **First it read 9.** The pattern was case-sensitive, and eighteen occurrences are the
  lowercase form inside quotations. *A pattern written against the name as a reader says it
  cannot see the name as a machine spells it.*
* **Then it read 27.** `^>` anchors the quote marker to column zero, and three lines are
  indented inside a list. `^ *>` returns 30.

**The second miss happened in the same paragraph that was documenting the first.** A count
corrected once is not a count verified: the correcting pass inherits the blind spot of
whatever it corrected with. See [census the field, not the
name](/practices/a-spec-table-is-an-illustration-until-censused.md).

The obligation is 24 sites in 11 files, not 30: the other six are inside a file excluded
whole, so they are protected by the file rule rather than the line rule. **Post-conditions
measured on two different sets are how a sweep passes its own check and still fails.**

## What it does not rename

Not the file format, the schema version, or any extension but `.rackpal`. **Not the Azure
DevOps project, the repository, or the board's area path** (§11.95.9), all three of which
remain `RackMate`. Not the mascot. It does not disturb
[DR-089](dr-089-the-wordmark-ships-as-outlines.md), whose outlines-not-text ruling is why
re-cutting the wordmark is the long pole rather than a find and replace.

**That exclusion list was never turned into a check, and the sweep duly edited a line
inside it**: `CLAUDE.md` was left claiming the ADO project and area path were `RackPal`,
which cost a later session six failed commands. See
[DR-097](dr-097-the-tracker-grows-a-fourth-level.md).
