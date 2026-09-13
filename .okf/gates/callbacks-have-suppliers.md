---
type: CI Gate
title: Callbacks have suppliers — a control nothing hands a callback to is a control nobody can press
description: Every nullable function-typed field on a widget in rackpal_ui/lib must be passed by at least one construction of that widget, anywhere in rackpal_ui/lib or apps/rackpal/lib. A supplier is a construction OF THAT WIDGET, not a parameter name found somewhere. Its exemption list is empty and keeping it empty is the value.
tags: [gate, ci, widgets, reachability, dr-128, dr-129, dead-code]
timestamp: 2026-09-12T00:00:00Z
resource: apps/rackpal/test/structure/callbacks_have_suppliers_test.dart
status: enforced
---

Added by `#875`, which `#872`'s reachability gate found on the day that gate
landed. It runs inside the `rackpal_app` suite rather than as its own
`Invoke-Gate` step, so the gate count did not move.

# The third question

Three gates now ask three different things about reachability, and none of them
subsumes another:

| Gate | Asks |
|---|---|
| [callbacks have callers](callbacks-have-callers.md) (`#674`) | is a declared callback **invoked**? `*Actions` records in `rackpal_ui/lib` only |
| [commands have callers](commands-have-callers.md) (`#872`) | is a Command **constructed** on a path from a UI package? every UI declaration is a root |
| this one (`#875`) | is a widget's nullable callback ever **handed over** by a mount? |

`#872`'s own header named this hole before anything fell through it, which is why
finding the case took a day rather than a milestone.

# What fell through

`ValidationDrawer` declares `onAcknowledge`, `onWithdraw` and `onRemedy`, passes
all three to `DrcPanel`, and `DrcPanel` renders a control for each when it is
non-null. **There is exactly one mount of `ValidationDrawer` in the product and it
supplied none of them.**

Each is nullable and documented as *"null shows no button rather than a dead
one"*. That is a good rule and it is what made this invisible: the controls were
**absent**, not broken. So `AcknowledgeFindingCommand`,
`UnacknowledgeFindingCommand`, three dialogs and PWR-003's whole remedy chain were
unreachable, each with a real revert and its own suite.

# Matching by parameter name alone would have missed it

`onRemedy:` **is** supplied somewhere: `schematic_canvas_screen.dart` passes one to
`SpringBackChipCard`. A gate that grepped the name would have called the drawer's
`onRemedy` supplied and missed the defect it exists for.

So a supplier is a construction **of that widget** whose argument list names the
parameter. The argument text is taken by counting parentheses from the opening
one, which `dart format` makes reliable and which a regex cannot do. A case
asserts that property directly rather than describing it.

# The exemption list is empty, and that is the value

The first run found six: the drawer's three, `DrcPanel`'s two filter callbacks
(the severity chips and the `Acknowledged` toggle, both rendered, both unable to
move, with `groupFindings` already taking the parameters they feed), and
`SpringBackChipCard.onWhy`, whose viewer and `RuleMeta.rationale` were built at
`#296`.

**All six were wired rather than exempted.** A gate whose list is empty on the day
it ships is a gate nobody has to be talked out of believing, and adding a row to
it later is an explicit claim that a control the product draws is deliberately
dead.

Three cases guard the list rather than the tree, on
[a tests exemption list is where the bug lives](../practices/a-tests-exemption-list-is-where-the-bug-lives.md):
a row whose value is not a board item fails, a row that has since been supplied
fails, and the corpus-size band fails if the scan stops finding widgets.

# Its blind spot

It asks whether a callback is handed over, not whether the widget that receives it
is ever **mounted**, and not whether the handler does anything. A screen nobody
navigates to, passing every callback faithfully, passes this gate. Deciding which
widgets are actually reachable needs a build graph none of the three gates has,
and a gate that guessed would cry wolf.
