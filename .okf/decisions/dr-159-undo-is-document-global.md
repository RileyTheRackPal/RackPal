---
type: Design Ruling
title: DR-159 — Undo is document-global, it says what it will take back, and the builder keeps its own stack
description: >-
  UndoIntent had exactly one handler in the whole tree and the app had no Edit
  menu, so Ctrl+Z worked on one of seven tabs. The binding moves to
  KeyScope.global; the rack and the device builder keep their own handlers,
  because nearest-Action-wins and each does something the fallback cannot. The
  Edit menu docs/03 §13.3 specified at M0 is built, against an explicit
  LabelKey-to-text map with a parity gate. An empty quick-entry box hands the
  key back to the document.
tags: [ruling, undo, keymap, menus, dr-159, cr-106, dr-091, plan-j]
timestamp: 2026-09-12T00:00:00Z
ruling_id: DR-159
canon_section: "11.158"
status: built
---

Settled by the user on 2026-09-12, closing `#874`. Reported while running the
`PLAN-J` demo: *"Undo doesn't appear to work anywhere across the program
currently."*

# The intent was always right and only the installation point was wrong

`UndoIntent` and `RedoIntent` had **exactly one handler in the entire tree**,
inside `RackCanvasScreen`'s own `Shortcuts`. The application had one menu, `File`,
with no Undo item anywhere. The strip is seven tabs.

That handler's own comment read: *"the key is DOCUMENT-GLOBAL. Undo and redo must
keep working from the palette, the inspector and the toolbar; scoping them to the
canvas would reintroduce the exact defect app_shell.dart's header post-mortems for
`Ctrl+S`."* The registry row said the same from the other side and named the
remedy as a rebinding owed a ruling. So nobody was wrong about the design; the
binding was simply installed in the wrong place and nothing could see it.

# A count went stale in four places, and the fourth was written today

`rack_canvas_screen.dart` and the keymap registry each said `Ctrl+Z` reaches
nothing *"on the Schematic and Schedule tabs"*, written when the strip had four.
`main.dart`'s header still described a **three-tab strip with two inert tabs**
rendering `UnbuiltView`, which M2-E and DR-091 had both falsified. And the first
draft of this ruling said six tabs.

DR-091 §11.90.3 reordered the strip into job order and added three views;
`PLAN-E/5` added Plan. No copy moved either time. None of the four now carries a
number: `ShellView.values` is the list.

# Two screens keep their own handlers

Flutter resolves an `Action` from the focused context upward, so a nearer one
wins and the shell's is the fallback.

The **rack** keeps its own because `undoLast` returns the selection as it was, and
restoring it is what makes undoing a delete put the selection back rather than
leaving somebody staring at an empty inspector.

The **device builder** keeps its own because there are two stacks. CR-106 scopes
its stack to the `TemplateBody` and it dies with the window;
`KeyScope.builder`'s own note already refused to share a scope with the canvas
because *"that would say the two stacks were one thing"*. It had Undo and Redo **buttons** since M4-A/4 and no key at all.

So one key means two things on one tab. The user chose that over always taking the
document's stack, which would have undone something in the project behind the
window: a larger blast radius, invisible from where the person is standing.

# The Edit menu was specified at M0 and never built

docs/03 §13.3: *"The Edit menu shows a localized 'Undo Move device'; the log shows
the stable enum name."*

`LabelKey` has **101 values and many exist only because of this menu**.
`commitPortSort` is its own value rather than `reorderPorts` because *"'Undo
Reorder' in front of somebody who has just been through a confirm dialog names the
wrong act"*. `clearRoomEstimate` is split from `setRoomEstimate` so the menu cannot
name the opposite act. All of that argument was written against a surface nobody
could see.

The map is **explicit and gated**, not de-camel-cased: the obvious wording is wrong
for exactly the values that were split. A parity gate fails when a value has no
entry, with no fallback, on DR-156's argument that a default is a hole.

**It is not localized.** §13.3 also asks for `AppLocalizations` and `l10n.yaml`;
neither exists in this tree, so the map holds English strings and that half stays
owed. A menu built against half a specification has to say which half.

# The per-tab sweep found the fix incomplete

Structured Wiring still did nothing. Its `Add drops` box autofocuses and clears
itself on submit, so a text field held focus permanently and
`DefaultTextEditingShortcuts`, which sits nearer a focused field than the app's own
`Shortcuts`, claimed `Ctrl+Z` for `UndoTextIntent` with nothing to restore. **The
complaint survived inside its own fix**, on the one tab whose primary verb is bulk
data entry.

An empty box now forwards; a box with text keeps the key, because that typing is
worth taking back. Dropping the autofocus was the alternative and was refused: it
buys a flat rule by taking away the reason the tab is fast.

**And the shell's own text-field guard was removed rather than weakened.** It is
redundant, because a focused field's nearer binding consumes the key before
`UndoIntent` is raised; and harmful, because it would have caught that forward and
thrown it away. A guard that re-asks a question the dispatch has already answered
can only get it wrong.

# What it cost, and what caught it

Thirty-nine existing cases were green in a configuration the product does not ship:
they pumped `RackCanvasScreen` under a bare `MaterialApp` and got the key from the
rack scope. See
[a fixture's default is not a proof](/practices/a-fixture-default-is-not-a-proof.md),
whose fourth instance this week this is.

Two gates caught the move and both were right to: `keymap_arbitration`'s per-scope
counts moved in opposite directions by the same three, and `session_layering`'s
RULE 14 failed because a global binding is a decision and adding one means taking
it again.
