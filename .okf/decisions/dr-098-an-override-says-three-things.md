---
type: Design Ruling
title: DR-098 — An override says three things, and two of its six fields were saying somebody else's
description: >-
  A per-instance override is tri-state: inherit, this value, or explicitly unknown.
  `null` had been carrying both G4's "unknown" and the class's own "not overridden",
  so a device could not disown a template's weight without inventing a replacement,
  and the rack subtotal totalled a figure nobody stood behind. Also deletes two
  override fields that duplicated facts the instance already carried, and puts
  door 1 in the inspector column rather than a modal.
tags: [ruling, model, overrides, g4, cr-114, cr-053, device-builder, dr-098, dr-077, dr-079, dr-080, cr-054, m4, m5]
timestamp: 2026-08-28T00:00:00Z
ruling_id: DR-098
canon_section: "11.97"
status: built
---

# DR-098 · An override says three things, and two of its six fields were saying somebody else's

Board `#785`, under `#183` (M4-L). Settled by the user 2026-08-28, before any code, on
[DR-077](dr-077-a-template-authored-here-reaches-the-rack.md)'s precedent: the questions
M4-L could not start without were product decisions rather than authoring work.

## The census that raised it

`DeviceOverrides` and `PortOverrides` have existed since M0, both codec-covered and both
under CR-117's byte round-trip, and **neither had ever been constructed by anything but
its own class and the codec**. Three things the issue had not recorded:

| Found | The measurement |
|---|---|
| Every `overrides` block on disk is empty | Four starters and six fixtures hold 800+ of them and **zero keys** between them, measured by walking the parsed JSON. A grep for the field name returns 847, because `displayName` also lives inside every `TemplateBody` |
| Two of six `DeviceOverrides` fields have no reader | `typicalWatts` and `weight` reach `derived/device_loads.dart`; `accentColor` reaches `draw/scene/device_layer.dart` by DR-080. `displayName`, `typePrefix` and `bodyDepth` reach nothing |
| `PortOverrides` has no reader at all | `connect_target.dart` and `schedule.dart` both read `PortDef.label` straight off the template |

The empty-corpus figure is what makes every ruling below free, and it is
[DR-079](dr-079-a-listing-is-not-a-material.md)'s timing argument arriving in the same
words: today a field deletion, and a migration after the first customer file.

This is [a modelled field is not a reachable one](../practices/a-modelled-field-is-not-a-reachable-one.md)
again: two classes declared at M0, carried by the codec and gated by CR-117 ever since,
with no producer anywhere in the tree.

## `null` was doing two jobs

G4 and CR-114 rule that null is **unknown, never estimated**. This class's own header ruled
that null is **not overridden**. Both were right about their own subject and they shared one
sentinel:

> A generic 2U amplifier template declares 30 lb. The unit actually in this rack is a
> different model and its weight is not known. There was no way to say so.

`RCK-003` then totals the template's figure as a measurement and the subtotal prints a mass
with no unknown counted against it: the fabricated rollup CR-114 exists to forbid, reached
through the one door built to let a person correct the record.

## The rulings

**State.** An override is tri-state on every overridable field: **inherit** (key absent),
**set** (key present with a value), **unknown** (named in a present `cleared` list). The
third state cannot be an explicit `null`, because CR-114 makes an absent key mean unknown
and here an absent key already means inherit. Uniform across all fields, because a
tri-state on some and not others is a class whose next reader has to learn which is which.

**Fields.** `displayName` and `typePrefix` are deleted: `DeviceInstance.name` and the
designator allocator already carry those facts. `bodyDepth` stays declared and unread, and
the tri-state is what makes that honest, since absent asserts nothing. M5's `RCK-012` is
its named consumer.

**Surface.** Door 1 is a section of the inspector column, not a modal: two of the four
fields change something the user is looking at, and a modal hides it.

## What it does not settle

`PortOverrides` still has no reader, so **M4-L4 owes a resolver before it owes a form**.
Which `PortDef` facts are overridable, and whether ports take the same tri-state, are
`#233`'s to raise against a resolver that exists.

## Links

* [G4 · unknowns are counted, never estimated](../invariants/g4-unknowns-are-counted.md)
* [CR-117 · byte exactness](../invariants/cr-117-byte-exactness.md)
* [DR-080 · the accent reaches the elevation](dr-080-the-accent-reaches-the-elevation.md)
* [Census before building](../practices/census-before-building.md)
* [Ask what consumes each task's output](../practices/ask-what-consumes-each-tasks-output.md)
* [Assert the artifact, not the mechanism](../practices/assert-the-artifact-not-the-mechanism.md)
