---
type: Design Ruling
title: DR-158 — A template is removed from a project as a whole, and it takes the devices standing on it
description: >-
  Removing a device template from the current project. The unit is the template
  id and every version of it goes; only project-authored rows offer the control;
  the devices placed from it are removed with it after a confirmation counting
  templates, devices and cables in three units; and it is a document edit, so one
  undo puts all of it back. An unused template is still asked about, which is
  where this departs from the four removal plans before it.
tags: [ruling, templates, deletion, undo, confirmation, dr-158, dr-013, cr-050, cr-054, cr-106]
timestamp: 2026-09-12T00:00:00Z
ruling_id: DR-158
canon_section: "11.157"
status: built
---

Settled by the user on 2026-09-12, closing `#871`. Reported while running the
`PLAN-J` demo: *"I also have no way to delete device templates, or to delete
floor plan pages."*

# Nothing existed at all, which is what separates it from `#870`

The floorplan half of the same report needed no ruling. `RemovePlanUnderlayCommand`
had shipped at `PLAN-C/6` with a real revert, a pin cascade and seven tests, and
nothing in any `lib/` ever built one; the work was wiring.

This half had no command, no plan, no dialog and no surface. There is no
`Remove`/`DeleteTemplate` class anywhere in the tree, and `doc.templates.remove`
appears only inside revert bodies undoing a save or a fork. Unbuilt rather than
unwired, so the shape of it had to be decided before any of it could be written.

# The rule was already written and it governs something else

docs/06 §7.1: *"Library operations (delete a template, import, set favourite) are
not undoable and are therefore individually confirmable or trivially reversible."*

That sentence governs the **shelf**, which is M4-N and does not exist.
`SaveTemplateToProjectCommand`'s own header already made the argument for the
opposite direction and it holds in both: a snapshot in `RackDocument.templates` is
project data, it is persisted in every `.rmpj`, and editing it is editing the
project. So removing one is a document edit, it goes on the document's undo stack
like every other edit, and the confirmation can honestly say so.

# The unit is the template id, not the snapshot

Every version goes, in one command.

The product addresses ids everywhere a person can see one.
`buildPlaceableTemplates` reduces to the newest version per id, the palette and
the browser each list one row per id, a placement gesture carries an id and never
a version (DR-077 §11.76.3), and `countDevicesOnTemplate` counts by id because *"a
count that split by version would understate what the badge is reassuring the user
about"*.

A removal that took one snapshot would be **the first gesture in the product to
address a version**, and its visible effect would be a palette row that disappears
and then silently comes back at the previous version. CR-050 keeps every earlier
version resolvable as an archival mechanism; it is not a thing a person chooses
between.

# Project-authored only

The seeded 48 are removable in the narrow technical sense: `blank_document.dart`
writes them once at creation, so a removed one would not grow back. Refused
anyway. They are what the build ships and are identical in every project, so a
per-project hole in them is a difference carried in the file forever, found later
by somebody who did not make it, and repairable by nothing in the product.

Pruning a palette down to what a shop actually installs is a **filtering**
question and belongs to the shelf (`#817`), not to a delete.

# The devices go with it, and the blast radius was stated before it was chosen

`DeviceInstance.templateRef` is the **only referent in the entire model**: no
other field anywhere points at a template. So the cascade has exactly one edge,
and the only question is what to do along it.

Removing the template and leaving the devices was never available. CR-054 says a
`TemplateRef` *"ALWAYS resolves to one"*, and a device whose snapshot is gone has
no body, no footprint and nothing to draw.

The recommendation put to the user was a refusal naming the count, with the
cascade offered beside it and its cost written down: a template delete becomes a
device delete, behind a small control, and those devices take their cables with
them under DR-013 §11.13.1. **The user took the cascade.** What makes it
acceptable is what makes every other destructive gesture here acceptable: the
dialog names what goes, in the units it goes in, and one undo puts all of it back.

# Three numbers in three units

On `LocationRemovalPlan`'s reasoning, restated because this is the fourth plan to
need it. **Templates** removed, **devices** removed, **cables** cut. A device
leaves the project; a cable leaves the schedule, which is the deliverable and is
what makes DR-013 §11.13.2 expensive. They are not summed.

# And this one always asks

`confirmDeviceRemoval`, `confirmLocationRemoval` and `confirmUnderlayRemoval` each
return true without building anything when the act is consequence-free, on DR-013
§11.13.2's last sentence: *"a prompt for a consequence-free delete is the nag that
teaches people to click through prompts, including this one on the day it
matters."*

A template removal is never that. Authoring one is minutes of work that exists
nowhere else in the project, so removing an unused one still destroys something no
route but undo brings back. The prompt is **shorter** when nothing stands on it.
It is not absent.

# One transaction, one undo, and the order is load-bearing

The gesture is one `RemoveDeviceCommand` per device and then the template removal,
which is the shape `_deleteSelection` already uses for a multi-device delete. Each
device command re-plans against the aggregate as it stands when it applies, so the
plans compose in sequence: a cable between two departing devices goes with the
first of them, and a net carried only by departing cables is collected at the last
device that could still have carried it. `Transaction` reverts in reverse order,
so undo puts the template back **before** the devices whose `TemplateRef` resolves
it.

# What it found on the way

**`#873`**, and it had already shipped. `DeleteDeviceDialog` summed one
`DeviceRemovalPlan` per selected device, and a cable landing on two selected
devices is in both plans while the transaction removes it once. Selecting both
ends of a run said two cables and removed one. Named here because this ruling's
dialog counts the same way and would have inherited it.

**`#874`**, which is larger than either. `UndoIntent` has exactly one handler in
the whole tree and there is no Undo menu item, so `Ctrl+Z` works on one of six
tabs. Every destructive confirmation in the product ends by promising undo, and
three of the four are reached from tabs where the key does nothing.
