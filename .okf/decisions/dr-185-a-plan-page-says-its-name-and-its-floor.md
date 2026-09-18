---
type: Design Ruling
title: DR-185 · A floorplan page can be renamed and says which floor it shows, and an import asks
description: >-
  A plan was named after its file forever and PlanUnderlay.locationId had no writer, so three pages of
  one PDF read the same and every plan's unpinned strip listed the whole building. An Edit plan dialog
  on the open plan's row now sets both in one undo entry, and an import proposes both and asks.
tags: [ruling, plan, import, locations, dialog, dr-185, dr-142, dr-144, dr-184]
timestamp: 2026-09-18T00:00:00Z
ruling_id: DR-185
canon_section: "11.184"
status: ruled
---

Ruled by the user on 2026-09-18 on board `#912`, found while measuring
[DR-184](/decisions/dr-184-a-floorplan-turns-in-quarter-turns.md).

# Two fields with no writer

- **The name.** `FloorplanIo.import` names every page after its file, and nothing renames one. Three
  pages lifted from `A-101 REV3.pdf` are three rows reading `A-101 REV3`.
- **The floor.** `PlanUnderlay.locationId` is accepted by every import signature and passed by no
  caller. The rail's room line can never print, and
  [DR-142](/decisions/dr-142-what-the-unpinned-strip-lists.md) rules that a plan with no location
  lists every unpinned carrier, so each floor of a three-storey house showed the whole building.

This is the shape [a modelled field is not a reachable one](/practices/a-modelled-field-is-not-a-reachable-one.md)
names, for the fourth or fifth time on this view alone.

# What was ruled

- **An `Edit plan…` dialog** on the open plan's row, beside `Calibrate…`: Name and Shows, one undo
  entry. Inline editing was declined because double-click-to-rename is invisible and a dropdown in a
  240-pixel rail truncates, and the inspector because docs/15 §6 gives it to the selected room.
- **An import proposes and asks.** The name is the file's, plus the page when the PDF has more than
  one; Shows is the Site tree's selection. The dialog opens pre-filled so `Enter` accepts, the import
  and its details are one undo entry, and dismissing keeps the proposal rather than throwing away the
  page somebody just picked.

# The tenth location carrier

Giving `locationId` a writer made it reachable by [DR-021](/decisions/dr-021-location-delete-cascades.md)'s
cascade, which had censused nine fields and could not have counted this one. Deleting a floor now
clears the plans that showed it and undo puts them back (canon §11.184.3, §12.37).

# What this does not rule

Replacing a plan's picture with a revised drawing while keeping its pins, which is its own feature
with its own geometry question.
