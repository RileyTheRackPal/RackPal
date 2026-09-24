---
type: Practice
title: A blanket rebuild hides a missing subscription, and a mask names who must redraw
description: >-
  The Rack view never listened to the wires epoch and the app never showed it,
  because the shell rebuilt everything on every commit. The same review found the
  opposite error: two rack display toggles declared an epoch that only the
  Schematic hears, and it froze the schematic into the file each time.
tags: [practice, epochs, invalidation, widget-tests, full-tree-review]
timestamp: 2026-09-23T00:00:00Z
---

An epoch mask is two claims at once: **this command changed something**, and
**these are the views that must redraw for it.** The full-tree review (`#97`)
found each half wrong once, on the same afternoon.

# Too narrow, and invisible

`RackCanvasScreen` listened to `structure`, `rack` and `meta`, and computed the
outlet chip and the findings drawer in `build`. DR-171 had moved consumed outlets
onto the cords drawn to a device, so a `wires`-only commit changed the chip and
repainted nothing. Mounted alone, the screen read `outlets 3/4` over a rack whose
only cord was gone (`#932`).

**Nobody saw it, because the app rebuilds the world.** `DocumentSession` notifies
on every commit and `AppShell` calls `setState`, so every view rebuilds whether it
subscribed or not. The strip's own test pumped the strip alone, which proves it
renders what it is handed and says nothing about whether its host ever hands it
anything new.

That is a correctness property borrowed from a performance accident. The day
somebody makes the shell stop rebuilding everything, which is the obvious
optimisation, every missing subscription goes stale at once with every test green.

# Too broad, and it writes

`Rack.ruNumbering` and `Rack.mirrorRearElevation` declared `rack | style`, "because
it redraws the RU ruler". The Rack view redraws its ruler on `rack` and has never
listened to `style`. The one view that does is the Schematic, which reads `style` as
a re-layout, and DR-187's freeze hooks exactly that. So a ruler preference wrote
every schematic symbol's position into the file (`#933`). Nothing moved on screen,
which is why it was never reported, and a unit test asserted the mask as intended.

Over-declaring is what AC-014 sanctions, and for a view that only redraws, it
costs a frame. **It stops being free the moment a listener has a side effect.**

# What to check

- **Mount the view without its host** when a test is about what it listens to. A
  view that is only ever tested inside a shell that rebuilds everything cannot fail
  a subscription test.
- **For each epoch a command declares, name the listener that needs it.** If you
  cannot, the epoch is a guess, and a guess is only harmless while every listener
  is a pure redraw.
- **Grep the listeners for side effects** before widening a mask. Here it was one
  `addConsequence` hook in the Schematic.

# Citations

[1] `packages/rackpal_ui/test/canvas/rack_canvas_epochs_test.dart`
[2] `packages/rackpal_ui/test/canvas/schematic/schematic_freeze_layout_test.dart`
[3] `packages/rackpal_core/lib/src/commands/command.dart`, `EpochMask.style`
