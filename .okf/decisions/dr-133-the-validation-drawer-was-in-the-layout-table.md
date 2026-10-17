---
type: Design Ruling
title: DR-133 — The validation drawer was specified in the layout table and never built
description: >-
  `#847` was filed saying the mount point was an open shell decision and listing
  three questions. docs/04 answers all three: §1's layout table has a row for a
  28 px validation drawer that auto-expands on the first error, and §8 binds
  F7/F8/Shift+F8. The panel needed a host, not a design.
tags: [ruling, ui, shell, validation, drc, keymap, reachability, m5, dr-129, ac-056, rj-006]
timestamp: 2026-09-06T00:00:00Z
ruling_id: DR-133
canon_section: "11.132"
status: built
---

# DR-133 · The decision had been made and simply never built

Board `#847`, ordered into M5 by the user behind `#838` and `#839`. Settled the
same day, and **settled mostly by reading docs/04** rather than by deciding
anything.

## The item was filed claiming a decision that was already made

`#847` said *"mounting it is a shell decision, not a widget one"* and listed
three open questions: where the panel lives, how it opens, what it displaces.
**All three were already answered.**

§1's layout table carries a row that was written and never built: a **validation
drawer**, 28 px default, 28/320 range, *"auto-expands to 180 px once, on the
first error per session, never again"*. §8's keymap names `F7` re-check, `F8`
next issue, `Shift+F8` previous. **None of the three was bound.**

## And one of those answers is better than what was about to be proposed

A keybinding was going to be offered. The spec says **it opens by itself**, and
that is the stronger answer: **a person who does not know the validation engine
exists cannot press a key to find it**, which is exactly the state M5-F's closing
sentence claimed to have ended.

The drawer is also a horizontal band rather than a fourth column, so it needed
neither the unbuilt `PanelHost` seam nor a share of the inspector's 320 px. **The
whole estimate rested on a seam the work did not touch.**

## The one thing the spec does not say

*"The first error per session"* leaves open what an error IS at that moment, and
the choice is load-bearing because `RuleOverride` and `AckedFinding` both move
severities.

**Ruled: the RESOLVED severity, after overrides and acknowledgements.** A project
that demoted a rule has said it does not want to be stopped by it, and re-opening
a drawer for it would overrule a decision the user recorded, which is RJ-006's
whole reason for keeping the acknowledgement machinery.

**Session means the app run**, taken literally. The per-document alternative is
defensible and is recorded rather than taken.

## Two gates nobody had met caught this chapter

- **`draw_source_gate_test`**: every test file a production comment cites must
  exist, because a reader following a dead reference to confirm a rule *"finds
  nothing, which reads exactly like the gate having been deleted"*.
- **RULE 14** in `session_layering_test`: *"a partial keymap reads as a whole
  one, so a group lands only when it is complete."* `F7` had been left unbound on
  the argument that a re-check key has nothing to do while validation recomputes
  on every build. The rule was right, and **so was the argument's opposite**:
  "re-check" promises to re-run the check and does. A phantom button is one that
  does NOTHING.

See
[a-modelled-field-is-not-a-reachable-one](../practices/a-modelled-field-is-not-a-reachable-one.md):
this is that practice done to a PANEL rather than a field.
