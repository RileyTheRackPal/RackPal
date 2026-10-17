---
type: Design Ruling
title: DR-099 — Door 2 moves the device it was opened from, and the Device Manager holds one draft
description: >-
  AC-041's copy-on-place left one instance unaccounted for: the one the gesture was
  invoked on. Door 2 forking a template while the device you right-clicked stays
  pinned forever is a menu item that provably cannot affect its own subject, so the
  originating instance rebinds and every other stays pinned. Separately, door 2 must
  open into the Device Manager's single draft, and it refuses rather than prompting,
  because a discarded draft has no recovery path.
tags: [ruling, device-builder, templates, copy-on-place, ac-041, cr-054, cr-106, dr-099, dr-098, dr-077, m4]
timestamp: 2026-08-29T00:00:00Z
ruling_id: DR-099
canon_section: "11.98"
status: built
---

# DR-099 · Door 2 moves the device it was opened from, and the Device Manager holds one draft

Board `#794`, under `#231` (M4-L2). Settled by the user 2026-08-29, before any code, on
[DR-077](dr-077-a-template-authored-here-reaches-the-rack.md)'s and
[DR-098](dr-098-an-override-says-three-things.md)'s precedent.

## The gap AC-041 created and did not notice

AC-041 cut the Update Manager to v1.2 and made v1 **copy-on-place**: the snapshot is embedded,
`templateRef` is recorded, and *"placed instances untouched until opted in"*. That cut is right and
nothing here reopens it.

It says nothing about **the instance the gesture was invoked from**. Read literally, CR-054's door 2
produces this:

> Right-click `AMP-1`. Choose **Edit the template**. Change the wattage. Save. The template is now
> v2, `AMP-1` is still on v1, and nothing in v1 of this product can ever move it.

A menu item invoked on a device that provably cannot affect that device is not a feature. It is the
same class as DR-077's finding, where a template saved in the builder could not reach a rack: the
machinery was right and the route was missing.

## The rulings

**Binding.** The originating instance **rebinds**; every other instance stays pinned. Choosing door 2
*on a device* is the opt-in AC-041 asks for. This is **not** an §8.3 amendment: none of the five
things AC-041 cut (the semver classifier, the diff view, the safe/additive/breaking grouping, the
per-cable remap, the merge) is built. One reference advances at the moment its own user asks.

**Collision.** Door 2 opens into the Device Manager, which keeps **one** draft alive across view
switches. When that draft is dirty, door 2 **loads nothing** and shows *"Finish or discard this
template first."* No discard prompt: that dialog is the shape people dismiss by reflex, and a
discarded draft has **no recovery path**, because the session is an in-memory deep copy with nothing
for `Ctrl+Z` to reach and nothing on disk to reopen.

## What was declined, and on what grounds

* **Leave everything pinned and explain on save.** AC-041's letter. Declined on its copy: the
  sentence it requires is a permanent apology printed at the moment of success.
* **Drop door 2 from the device menu.** Declined because it leaves CR-054's three doors unreachable
  from one place, which is the shape CR-054 rules.
* **A second builder window.** Declined as the largest change for the least return: two live
  `TemplateEditSession`s and two undo stacks would reopen CR-106's reasoning for a collision one
  guard closes.

## What it does not settle

Door 3's rebind is CR-054's own text and is `#232`'s. The stale-fork badge still has no widget:
`fork_status.dart` has carried the rule since M4-C and the surface is nobody's, recorded here so the
next reader does not go looking.

## Links

* [DR-098 · an override says three things](dr-098-an-override-says-three-things.md)
* [A modelled field is not a reachable one](../practices/a-modelled-field-is-not-a-reachable-one.md)
* [Ask what consumes each task's output](../practices/ask-what-consumes-each-tasks-output.md)
