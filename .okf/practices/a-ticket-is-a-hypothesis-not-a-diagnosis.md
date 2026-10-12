---
type: Practice
title: A ticket is a hypothesis, not a diagnosis
description: A board item names a symptom, a cause, a price and what it will touch, and all four are guesses that have sat in a database looking authoritative. Find the limits that decide whether the symptom is reachable, grep the consumers, and diff the canon since the ticket was written, because a census of the tree cannot see a ruling that was never applied.
tags: [practice, board, estimation, census, canon, dr-050, dr-171]
timestamp: 2026-10-12T00:00:00Z
status: adopted
---

A board item states a symptom, a location and a price, and a design document lists
what a change will touch. **Treat every one as a hypothesis.**

# What it looked like

- **`#803`** said the port grid overflowed an 800 px window by 63 px. True, and
  **unreachable**: the window cannot be made narrower than 1000 px. Sweeping the range a
  person can actually open found the real defect: the preview dock was admitted 23 px
  before it fitted, under a comment calling its threshold *"MEASURED, NOT CHOSEN"*.
- **`#801`** was priced as one argument at one call site. That argument removed 47 of a
  48-port switch's ports from the sheet, and needed a whole interaction built first.
- **`#846`** said a field was populated nowhere, which was exactly true, and concluded
  that searching by protocol had never matched anything, which was false: the search
  works through the port's signal family and the device's tags, and a test had
  asserted it since M4. **A finding about a field is not a finding about the feature
  it feeds.**
- **docs/15 §7** listed six things adding `drawImage` would touch. Two were wrong, and
  the one file that did break was on nobody's list. An impact list is wrong in both
  directions at once, and the omission is the expensive half.
- **A `D`-item's title is a defect statement, not a status.** *"D4: CI has one job,
  pinned to Windows"* reads like a fact and is macOS debt saying a second job is owed.

# The census is blind to the canon

Every habit above greps the tree. At PLAN-G (2026-09-08) that missed the one thing that
could void the chapter: **DR-050 §11.49.2 said `ScheduleLengthSource` *"gains nothing"***,
written after the Story that added a fifth tier. A ruling that has not been applied
leaves no trace in the code, so no grep finds it. The check is one command:
`git log --since=<the ticket's date> -- docs/canonical-decisions.md`.

And a board item marked *"RULED"* may never have reached canon: `#558` carried
*"RULED 2026-08-03"* for six weeks with no canon section, and measured, the case it left
open was every case. It became DR-171. **Grep canon for the item number and the key
phrase before treating a board label as settled.**

# The rule

Before writing code: (1) find the enforced limits that decide whether the symptom is
reachable at all; (2) grep the consumers of whatever the change touches; (3) diff the
canon since the ticket was written; then measure a range, not the single point the
ticket names. If the finding contradicts the ticket, say so and re-price it out loud.
See [a claim about the code is grepped](verify-codebase-claims-by-reading.md) and
[census before building](census-before-building.md).

# Citations

[1] Board `#801`, `#803`, `#846`, `#558`; docs/15 §7; canon §11.49.2 (DR-050), DR-171
