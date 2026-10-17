---
type: Design Ruling
title: DR-243 · A cloned family's dash is chosen from one pattern per class, at the weights the palette already uses
description: >-
  DR-122 lets a person clone a signal family and choose its dash and weight, and named no menu. The
  menu is the shipped palette's own dash classes, one pattern each, crossed with the weights it
  already uses, derived from the seed rather than listed. PAL-1 itself does not move.
tags: [ruling, pal-1, signal-family, clone, palette, sfe, dr-243, dr-122]
timestamp: 2026-10-07T00:00:00Z
ruling_id: DR-243
canon_section: "11.242"
status: built
---

Settled by the user on 2026-10-07 for SFE-A3 (board `#824`), the headroom query that tells a person
which dash and weight a new family can still take.

# What was ruled

Three menus were offered, each priced against the shipped palette:

| Offered | Size | What it costs |
|---|---|---|
| **One dash per class**, at every shipped weight | 13 × 5 | Every swatch reads differently in greyscale |
| Every dash pattern the catalogue ships | 37 × 5 | `3,3`, `4,3`, `6,3` and `8,3` appear as four options, all class `short` |
| A typed pattern, checked live | unbounded | The nearest thing to the hand-rolled surface RJ-012 objected to |

The user chose the first, the recommended option, and gave no reason of their own; the table's
reasons are the recommendation's.

**The menu is derived from the seed, not listed**, so it cannot drift from the palette
[registry parity](/gates/registry-parity.md) holds. Which pattern stands for a class is the
implementation's choice and is recorded as such: the one the most shipped families use, ties to the
smallest permille list.

# What it does not change

PAL-1. The gate still checks any dash a family carries, and the within-domain limb still compares
exact patterns, so a narrower menu declines to OFFER what the rule permits; it refuses nothing.

# The ticket's premise, measured

SFE-A3 called digital video and control the crowded domains. By family count, yes; by headroom, no.
What constrains a choice is the **cross-domain luminance band**, so `str`, `ctl` and `net` are
tightest and `video.digital` is among the roomiest. A clone uses exactly one combination in its own
domain, so "none left" arrives by repetition. The figures live in `pal1_test.dart`: the ones shown when
this was offered were computed under a provisional pattern-per-class choice and differ from the built
ones by one in three domains.

# Citations

- canon §11.242; docs/10 DR-243 row
- canon §11.121 (DR-122), §14 (PAL-1)
- `packages/rackpal_core/lib/src/draw/pal1.dart`
