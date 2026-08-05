---
type: Design Ruling
title: DR-014 — drawing a wired set member at a different device splits the set
description: No modifier, no mode, no dialog — the drag itself says it. Four conditions keep the gesture from firing where it could mean anything else, and the third is what stops a split from being a silent delete.
tags: [ruling, m2, connect, atomic-set, gesture, schedule, dr-014]
timestamp: 2026-08-01T00:00:00Z
ruling_id: DR-014
canon_section: "11.14"
status: built
---

Settled by the user on 2026-08-01, against all four options costed on board
item #110.

# The defect

`atomicConnect` ([DR-008](/decisions/dr-008-wiring-model.md) §11.8.3) makes a
stereo pair ONE `Link` with two `Conductor`s. Both jacks are then full, so
`TOP-003` refuses every later cable from either of them.

Reported from the field as *"the Right analog audio channels can't have
connections made once the left channel is made."*

**Both halves of that were true, and the document was the honest one.** `R`
really did carry a conductor. What the product lacked was any way to say the one
thing the user meant: *this half goes somewhere else now.* The user's own case
is not exotic, a pair of 16-zone amplifiers handling each audio channel across
32 zones needs exactly this, and so does an HDMI matrix whose de-embedded
output is a 3.5 mm breakout into two unbalanced jacks.

# Why there was nothing obvious to bind it to

#110 costed four ways to express a split and found that **no free single
modifier exists**:

| Key | Already means |
| --- | --- |
| `Ctrl` | magnet suppressor, and additive selection (docs/04 §3.5) |
| `Alt` | [DR-001](/decisions/dr-001-net-labels-by-default.md)'s drawn-wire hover |
| `Shift` | multi-draw's run-selection (#93), and chain-draw at commit |

So every option was a chord, a scarce unmodified letter (canon §1.10's
`letterCollision` governs those, and the budget is nearly spent), a pointer
gesture with no keyboard equivalent (which breaks §11.11.6's parity, the clause
M1 was REFUTED for lacking) or a re-ruling of §11.11.2's *"the jack decides"*.

# The ruling

**The drag says it.** Splitting is automatic when a wire is drawn from an
already-wired set member to a **different device**. No modifier, no mode letter,
no double-click, no dialog.

That spends no input vocabulary at all, which is what makes §11.11.6's parity
free rather than argued, and it means there is nothing to discover: the drag the
user already tried IS the gesture.

# What keeps it safe is that the gesture is unambiguous, not that it is convenient

A gesture that acts without being asked has to be sure. `planSetSplit` answers
`null` unless **all four** hold:

1. **The pin is FULL.** A connect `TOP-003` would allow never splits. This is
   what keeps the ruling inert on the 223 catalog ports carrying no `setKey`
   and on every unwired pin in the document.
2. **EXACTLY ONE conductor end lands on it.** Two occupants is a bus tap or a
   hand-edited file, and *"which of these did you mean to displace"* has no
   derivable answer. A conductor looped back to the same pin counts twice and is
   excluded by the same clause.
3. **Its `Link` carries MORE THAN ONE conductor.**
4. **The far end is not already on the device being drawn to**: the user's own
   wording, and load-bearing rather than decorative.

An `OpenEndpoint` or `PlaceEndpoint` far end **does** split: neither names a
device to be the same as. An unresolvable `PortEndpoint` **does not**, because
*"I cannot tell which device that is"* is not *"it is a different one"*.

# Condition 3 is what stops a split from being a delete

Lift the only conductor out of a `Link` and the cable becomes a `W` number and a
schedule row with no electrical path, the state
`ConnectPortsCommand`'s own zero-conductor guard calls *"no conductor at all"*
and throws over.

Re-routing a single run by dragging its end is a real gesture and a reasonable
thing to want. **It is not this one**, and it must not happen by accident to
somebody aiming at a stereo pair. G1 makes that the expensive failure: the
schedule is the deliverable, and the loss is invisible until it is printed.

# The bill of materials is named out loud

A split moves one conductor across the line between *one cable with N
conductors* and *N cables*, the pull sheet gains a row and an existing row
loses a path. A silent choice between those two is precisely the harm
[DR-012](/decisions/dr-012-deferred-gesture-rules.md) §11.12.2 exists to
prevent, so naming the `W` number is not enough on its own. The sentence states
the **count**:

> W004 connected AMP-1 J09 to MTX-1 J03, split out of W001, which now carries 1
> conductor instead of 2.

The Edit menu label is `splitSet`, not `connectPorts`, for the same reason: a
user who reads "Undo connect" and takes it at its word expects one cable to
disappear, not a lifted conductor to go back where it came from.

# §11.11.2 is amended, not overturned

The branch is still decided BY THE JACK. What changes is that a set which is
**already one cable** has no legal set gesture left, every member is full, so
`planAtomicConnect` meets `TOP-003` at the grabbed position against every
candidate and the gesture arms with nothing to aim at. That was the report. A
full member therefore arms the pin-to-pin path, where the split lives.

An unwired member still arms the whole set. **A set is one cable the first time
and splittable afterwards.**

# What this does not settle

Dragging FROM an unwired set member ONTO a wired one still arms the set gesture
and still finds the target set unavailable. Splitting a WHOLE target set out of
its cable is a materially larger action than lifting one member, and it was not
ruled on.

Two board items inherit from this: **#111** (the set bracket) now has to
distinguish a set that is one cable from one that has been split, and **#112**
(stereo pairs for de-embedded zone audio on V01/V02/V03) is the catalog half of
the user's own HDMI-matrix case.
