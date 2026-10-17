---
type: Decision
title: DR-077 — A template authored in this project reaches the rack, and the palette says where it came from
description: The builder saved into a map nothing read. The shelf was already the document; the palette was reading a constant beside it.
tags: [m4, device-builder, palette, templates, cr-050, provenance, exit-criterion]
timestamp: 2026-08-19T00:00:00Z
ruling_id: DR-077
canon_section: "11.76"
status: built
---

M4's exit criterion has two clauses and the second one could not be performed at
all. A template authored in the Device Builder saved into
`RackDocument.templates`, round-tripped through the file, and **no surface
offered it for placement**. The 93-second template of the clause-1 drill existed
in the project and could never reach a rack.

# The machinery was already right

The census is the interesting part, because three of the four pieces needed no
change:

| | |
|---|---|
| `blank_document.dart` | writes all 48 seeded archetypes into `doc.templates` at version 1 |
| `buildPlaceFromCatalogCommand` | resolves from `doc.templates`, never from the seed catalog |
| `SaveTemplateToProjectCommand` | writes an authored body into that same map |
| `DevicePalettePanel` | is handed `buildSeedCatalog()` |

**A document's `templates` map is the one shelf a project has**, and the seeded
catalog is a contributor to it rather than a second shelf beside it. So the fix
is that one widget stops being handed a constant. Nothing about placement,
resolution or persistence moves.

`_catalog` was also `late final`, which is the same defect's second half:
pointed at the right shelf it would still never notice a save. It is memoised on
`stateId` now, the mechanism `ScheduleScreen` already uses.

# Provenance shows twice while browsing and once while searching

An authored template is filed into its own category beside the seeded ones and
repeated in a `This project` group pinned above them. Two placements because two
questions: the category is where a person looks for a network switch, the pinned
group is where a person looks for the thing they saved thirty seconds ago.

**The pinned group is browse-state only, and that limit is part of the ruling.**
A non-empty query flattens the panel to one list across every category, and a
row appearing twice there makes the count wrong and `Enter` on the top match
ambiguous.

**A template with no category still has a home.** `_canSave` requires a display
name, a type prefix and a meant occupancy, and not a category, so the panel's
iteration over `kCatalogCategoryOrder` made an uncategorised template invisible:
not refused, not badged, simply absent. See
[a modelled field is not a reachable one](/practices/a-modelled-field-is-not-a-reachable-one.md).

# A second Save forks a version

CR-050's own rule, implemented in `nextTemplateVersion` and never called.
`buildDeviceBuilderActions` was constructed once with `editing: null`, so every
save called `templateIdFor`, found the id taken, and returned `tpl.foo_2`. The
builder offers a plain `[Save]` beside `[Save & Close]` precisely so a person
can save and keep working, so two templates with one display name was the
ordinary path. It was invisible for exactly as long as nothing read what `Save`
wrote.

The consequence reaches placement: `catalogTemplateKey` pinned `@1`, so the
instant a v2 exists the palette offers a row resolving a stale body or nothing.
Placement resolves the **highest** version for an id. Behaviour is identical
wherever only v1 exists, which is every seeded id in every project and fixture,
and that identity is the check that this is a widening rather than a change.

# The equipment list is a sheet

The second finding was that `buildEquipmentList` has one caller in the whole
tree, the PDF backend, so the criterion's *"appears correctly in the equipment
list"* could only be read through an export. **That is the criterion's own
reading, not a gap.** `T6.30` is a sheet, no view of it is promised anywhere,
and M1's exit criterion already reads the equipment list through an exported PDF
in the same words.

Building an on-screen equipment list is the amendment this ruling declines: a
second table that must never drift from the sheet, added to unblock a criterion
that did not ask for it.

# The finding worth keeping

[Ask what produces each task's input](/practices/ask-what-produces-each-tasks-input.md)
was filed when five tasks built a port grid and none of them created a port.
This is the same lesson wearing the other shoe, and it is now a practice of its
own:
[ask what consumes each task's output](/practices/ask-what-consumes-each-tasks-output.md). A save was built, gated, tested, and nothing read it. Seventeen
issues, sixty-three tasks and fourteen green gates could not see it, and the
builder's own file header had been asserting *"a template authored here is
therefore placeable immediately"* since the day it shipped.

A decomposition can be complete on both counts and still leave a milestone's
criterion unreachable, because the two questions are asked of different ends of
the same task.
