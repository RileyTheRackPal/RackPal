---
type: CI Gate
title: Commands have callers — a Command a person cannot reach fails the build
description: A source-level reachability graph over every `*/lib/**.dart`. A Command class must be constructed by some declaration reachable from a UI package, or be exempted against the board item that retires it. Twelve are exempt today, and the gate fails when one of them becomes reachable and stays on the list.
tags: [gate, ci, commands, reachability, dr-143, dead-code]
timestamp: 2026-09-12T00:00:00Z
resource: apps/rackpal/test/structure/commands_have_callers_test.dart
status: enforced
---

Added by `#872`, asked for by the user immediately after `#870` found
`RemovePlanUnderlayCommand` fully built, tested seven times, and constructed by
no `lib/` code for four months. It runs inside the `rackpal_app` suite rather
than as its own `Invoke-Gate` step, which is why the gate count did not move.

# The shape it exists for

**Five instances, and every one was found by a person rather than a suite:**
`DR-143` (the importer with no caller), `#674` (`onRemoveGang` declared and
invoked by nothing), `PLAN-E/5` (six functions and a dialog with no caller),
`LEN-A/3` (a derivation whose own absence-of-caller test could not see the
caller, because the scan walked one package) and `#870`.

All of them compile, analyse clean and have green tests. The class **is** used:
its own suite constructs it. Nothing in Dart can require that a person can get
to it.

# Why a graph, when three greps were tried first

Each attempt was wrong, and each was caught only by checking an answer somebody
already knew:

1. matching `Name(` missed every **named** constructor and reported
   `SetRoomEstimateCommand` unreachable on the day it was wired;
2. counting any **mention** in another lib file let a name in a **comment**
   count as reachable, and `RemovePlanUnderlayCommand` fell off the list;
3. counting constructions by name reported 24 of 72, still wrong: this codebase
   builds most commands through `buildXCommand` functions, so a command
   constructed only by its own builder reads as unreachable while the **builder**
   is what has callers.

So a node is a top-level declaration in any `*/lib/**.dart`, an edge is "D's body
names E" outside comments and strings, roots are every declaration in a UI
package, and a Command is reachable when some declaration that **constructs** it
is reachable from a root. `addTemplateRemoval` is the worked example: `#871`'s
command is reached through a builder, which is the hop attempt 3 could not make.

# Its blind spot, which is the half that matters

**Every declaration in a UI package is a root.** That is an over-approximation and
a deliberate one, because deciding which widget is actually mounted needs a build
graph this scan does not have, and a gate that guessed would cry wolf.

The consequence is precise: **a command built by a UI method that nothing calls
reads as reachable**, and so does one behind a callback parameter that no mount
supplies. `#875` is exactly that case: `ValidationDrawer` declares
`onAcknowledge`, `onWithdraw` and `onRemedy`, the product mounts it once, and it
passes none of them. This gate sees those commands only because nothing
constructs them anywhere, not because it understood the mount.

That half belongs to [callbacks have callers](callbacks-have-callers.md) (`#674`),
which asks whether a declared callback is ever invoked. **Between them they still
leave a hole**: that gate reads `*Actions` records in `rackpal_ui/lib` only, so a
widget taking loose callback parameters is outside both.

# The exemption list, and what stops it rotting

Twelve commands are unreachable today, each verified by hand, each exempted
against a board item: `#875` through `#881`.

Three cases guard the list rather than the tree:

- an exemption whose value is not a board item **fails**, so a row cannot be a
  bare name somebody can hide behind;
- an exemption that has become **reachable** fails too, so the list cannot become
  a record of things that were true once;
- an exemption for a class that no longer exists fails, because a line nobody can
  act on is worse than no line.

# And it counts what it found

The prototype's splitter used a character class containing `\s`, which let an
**indented method** match as a top-level function. 439 files produced 18,222
"top-level" declarations, 41 per file, and 49 of 73 commands came back
unreachable with **zero** construction sites, `MoveDeviceCommand` among them,
which the rack canvas builds on every drag.

The number is what caught it, which is why the corpus-size band is asserted from
both directions: too few declarations means the splitter stopped matching, too
many means it is matching methods. Same anti-vacuity discipline as
`internal_setter_grep_test.dart` and `actions_have_callers_test.dart`.
