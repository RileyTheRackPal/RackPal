---
type: Practice
title: A widget test that reaches a control by finding it never tests the path to it
description: Nineteen tests drove the builder's form and missed that Tab went through the section rail, because `enterText` finds a field and a person walks to one. Two user reports in the first minute.
tags: [practice, testing, ui, keyboard, accessibility, m4-d]
timestamp: 2026-08-14T00:00:00Z
status: adopted
---

`tester.enterText(find.widgetWithText(TextField, 'Manufacturer'), ...)`
teleports. **A person presses Tab.** Any defect living between two controls is
invisible to every test written the first way, no matter how many there are.

# The evidence

M4-D's builder shipped with **nineteen passing widget tests** over its form:
the save gate, the change class, the unknown-vs-zero rules, the unit
conversions. A user opened it and reported two problems inside a minute, and
the first was this:

> Tabbing between these two fields results in the focus being sent to the
> sidebar first, then jumping back to the text input.

Flutter's default `ReadingOrderTraversalPolicy` orders focus by **geometry**.
The section rail and the form are two columns of similar pitch, so reading
order interleaved them:

```
Display name -> RAIL TILE -> RAIL TILE -> Manufacturer
```

Every one of the nineteen tests passed throughout, because not one of them
ever moved between two fields the way a hand does.

# It was worse than an annoyance, and that is the general shape

A `ListTile` fires `onTap` on `Enter` or `Space`. So somebody tabbing toward a
field and typing without watching **changes section**, and the keystrokes land
nowhere. The user's second report was that the designator prefix
*"doesn't appear to work at all"* — and the field wrote correctly and had a
passing test proving it. What was broken was getting to it.

**A navigation defect presents as a data defect.** Expect the bug report to name
the wrong control.

# The check

For any surface with more than one focusable region, write one test that sends
real `LogicalKeyboardKey.tab` events and records what each stop actually is,
resolved to something a person would recognise (walk `visitAncestorElements` for
the nearest `TextField`, `ListTile` or button). Assert the sequence, not a count.

The fix is usually a `FocusTraversalGroup` per region. **Group, never remove**:
keyboard-only operation is M7's exit criterion and M1's drill already showed
what an unreachable control costs. Grouping changes the ORDER, not the
reachability, and the test should assert both halves.

# The sibling finding, from the same two screenshots

The same session found **twenty-six user-facing strings citing the corpus**:
`MTX — seeds MTX-1, MTX-2 (CR-041, CR-045)`, `Optional (AC-049)`,
`Feeds RCK-013`, plus raw Dart enum names in dropdowns (`rackEars`,
`zeroUVertical`). docs/12 states the rule for end-user documentation, and it
binds a form harder, because nobody reads a form twice:

> The corpus is the source of truth for that document, never the source of text.

A ruling id on screen tells a user nothing they can act on. The citation belongs
in a comment beside the control, where the next implementer stands.
`builder_copy_and_focus_test.dart` greps the screen's own source for ruling and
milestone ids in string literals, skipping comment lines for exactly that reason.

One more distinction that cost a report of its own: **an example is a
placeholder, never a helper line.** `HDMI Matrix 16x16` as `helperText` went on
sitting under `Pro Max 24 PoE` after the user typed a name, and read as a second
value. Examples are `hintText`; `helperText` is for guidance that is still true
once the field is filled.

# Citations

[1] `packages/rackmate_ui/test/builder/builder_copy_and_focus_test.dart`
[2] `packages/rackmate_ui/lib/src/builder/device_builder_screen.dart`
[3] [assert the artifact, not the mechanism](assert-the-artifact-not-the-mechanism.md)
