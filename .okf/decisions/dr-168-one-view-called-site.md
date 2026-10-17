---
type: Design Ruling
title: DR-168 — The Location and Plan views are one view, called Site
description: >-
  Two tabs did adjacent halves of one job, and docs/15 had put the location tree
  in the Plan view's rail since the chapter brief. What the design withheld was
  editing it there, and the route it named instead had been deleted underneath
  it.
tags: [ruling, views, locations, plan-view, cr-112, cr-047, dr-091, dr-168, m6]
timestamp: 2026-09-13T00:00:00Z
ruling_id: DR-168
canon_section: "11.167"
status: built
---

Settled by the user on 2026-09-13, closing `#889` and its five chapters.

# The merge was half-done in the design

docs/15 §6's layout paragraph has read *"Left is the underlay list and the
location tree"* since the chapter brief. The tree was already in the Plan view's
rail. Two of its words are why this is a merge and not a rename: the tree was
**read-only**, with an *"edit in `Project ▸ Locations…`"* affordance, and that
menu does not exist. DR-091 (canon §11.90) promoted Locations to a tab and
deleted the `Project` menu.

So the question was never *"should these be one view"* so much as *"why are they
two"*. **§11.90.4 is what permits the answer**: it declined to freeze the view
set before M6, in as many words, and this is the first change to spend that
deferral. §11.90.3's table goes from seven rows to six and is corrected in
place, because the rule it exists for is that the strip is ordered by JOB, and
that is untouched.

# What was ruled

- **One view at position 1**, `Locations`' place, because the rooms are the
  first thing anybody enters.
- **Called `Site`**, which is neither half's name: a site HAS rooms, and some of
  them are drawn on a plan. It survives a project that never imports a
  floorplan, which is the state CR-112 exists to protect.
- **The rail is the TREE.** The underlay list appears above it once a floorplan
  exists, so a project with no plan is an ordinary project rather than an empty
  view with an import button.
- **The tree creates a room; an outline is an attribute of one.**
  Drawing-creates-a-room was refused because CR-047's arbitrary-depth tree makes
  a new room answer which parent, which kind and where in the order, and a drag
  on a plan has nowhere to ask.

CR-112, CR-047 and docs/15 §6's *"no fourth region"* all stand. `LocationsPanel`
and `showLocationsPanel` are deleted rather than ported: the modal had no caller
in `lib/` and none in any test.

# The third region, which had nothing to show until now

`PLAN-E/5` built two of docs/15 §6's three regions and said why in its own
header: *"there is no standard inspector to put there … the column is absent
rather than invented"*, because `InspectorPanel` requires a `Rack` and a pin's
carrier may be an outlet or an off-rack device. That was honest, and the merge
is what supplies a subject the region can show: **the selected room**, which
both halves of this view are about, and whose outline on the open plan is one of
its properties.

# Related

* [Copy outlives the route it
  names](/practices/copy-outlives-the-route-it-names.md): `#888`, the three
  on-screen strings that survived DR-091 by hiding among fifteen comments.
* [A deferral reads as a
  decision](/practices/each-surface-deferred-to-the-other.md): `PLAN-E/5`'s
  absent region is the honest form of the same shape.
* [DR-143, the importer had no
  caller](/decisions/dr-143-the-importer-had-no-caller.md): a thing ruled, built
  and left with nothing that reaches it, one view over.
