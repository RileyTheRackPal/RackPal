---
type: Design Ruling
title: DR-234 · A set and a multi-draw ask tier 2 per pair, and a set's chip names the first
description: >-
  DR-116 reaches the atomic set and multi-draw gestures, neither of which asked tier 2. First chip wins
  and names that pair plus a count; Connect anyway commits the whole gesture; a set chip offers only
  CON-001's adapter, one per cable.
tags: [ruling, tier-2, spring-back, atomic-connect, multi-draw, schematic, dr-234, dr-116]
timestamp: 2026-10-04T00:00:00Z
ruling_id: DR-234
canon_section: "11.233"
status: built
---

Settled by the user on 2026-10-04, building `#909` and `#999`.

# What was ruled

- **Per paired position, first chip wins**, in declared (or plan) order; open positions are not asked.
  Target pins whose pairs would chip wear the amber ring at arm time (DR-116 §11.115.5).
- **The chip names the first failing pair** and counts how many more would spring back.
- **`[ Connect anyway ]` commits the whole gesture**: the set as one cable, the run as N.
- **On a set, only `CON-001`'s adapter**, and only when `CON-001` is the only rule any pair trips. One
  adapter on the cable clears every conductor. Device-inserting remedies would split a one-cable set and
  are withheld.
- **A multi-draw chip offers no rule-specific remedy**: the implementer's stated default, not a user ruling.

# How the gap was found, and why it was two gestures

`#909` named the set gesture. Pricing it found multi-draw's arm-time comment promising *"The commit path
checks it per pair"* over a commit path that checked nothing. A comment stating a guard reads as the guard
itself, which is [flagged is not handled](/practices/flagged-is-not-handled.md) in another form.

# Not ruled

A 16/4 tapped at one speaker and continued to the next is a `Breakout`, which has no writer; the
hand-authored conductor map is v1.1 (AC-053). `#1000` holds it.

Canon §11.233 holds the full text.
