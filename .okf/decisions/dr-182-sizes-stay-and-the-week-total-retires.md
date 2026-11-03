---
type: Design Ruling
title: DR-182 · The roadmap keeps its sizes and retires its week total
description: >-
  The roadmap priced M0 to M5 at 29 to 44 weeks and they took about 7.3. The user ruled that every v1
  epic gets an S, M or L size from its stories, closed milestones show their actual duration, and the
  44 to 67 week total is withdrawn rather than re-estimated.
tags: [ruling, roadmap, estimates, process, dr-182]
timestamp: 2026-09-15T00:00:00Z
ruling_id: DR-182
canon_section: "11.181"
status: built
---

Ruled by the user on 2026-09-15 on board `#796`, with `#797` to `#799`.

# A total that describes another team

docs/09 §6 priced ten milestones at 44 to 67 weeks, written for a human team. On 2026-08-30 the user
left it alone and filed the gap. By 2026-09-15 six milestones had closed.

# What was measured

- M0 to M5: estimated at 29 to 44 weeks, taken in about 7.3.
- The v1 saga holds 20 epics; §6 has rows for ten.
- The Plan view is sized `L` with no row, and nine epics have no size at all.
- docs/09's M4 heading reads `M` against §6's `L`.

# What was ruled

- **Every v1 epic gets a size**, `S`, `M` or `L`, from its stories, with the evidence named.
- **A closed milestone shows its actual duration** beside its estimate.
- **The week total is withdrawn, not re-estimated.** Relative sizes still order the work.
- The M4 heading is corrected in the same change.
- Refused: a full re-cost in weeks, a caveat on 44 to 67, and leaving docs/09 alone.

No scope changes and no epic moves between Sagas.

# Built

`#796` landed it on 2026-09-16 (``2ff90c8b``), with `#799`. Roadmap §6 is a size table over all
twenty v1 epics, argued from the board read that day, and the week columns are gone from it, from
the roadmap's header, from docs/00 and, by a note, from canon's own re-cost table.

**THE TOTAL HAD DRIFTED BETWEEN THE THREE DOCUMENTS THAT STATED IT**, which the ruling's measurement
did not reach and which strengthens it. A later amendment moved canon's total to 53 to 80; the
roadmap section never gained that row and went on saying 44 to 67; the roadmap's header said 42 to
65 for longer still. Three numbers, one cost, none of them measured. A relative ordering cannot drift
that way because it has nothing to add up.

**FIVE OF THE SIX CLOSED MILESTONES HAVE NO SEPARABLE DURATION, AND THE BOARD LOOKS LIKE IT HAS ONE.**
They did not run end to end: one milestone's last exit clauses were vacuous until a later
milestone's work expired their reasons, so its criterion was met months of calendar after its code
shipped. And three of the six carry the same `ClosedDate`, which is the day every work item migrated
between types: a migration artefact wearing a date. Reading durations off that column would have
produced three confident wrong numbers inside a section written because a confident wrong number is
worse than none.

**The sizes are not a function of any count**, and the counts are printed beside them so nobody has
to take that on trust: one `L` milestone has nine stories and one `M` has twenty. The largest open
epic keeps the letter it had, because the ruling authorises sizing the epics that have none and
refuses a re-cost; the evidence for a future re-size sits on its row instead.
