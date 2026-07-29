---
type: Practice
title: One keymap registry, arbitrated across every platform
description: Every keybinding is a row in one table whose primary modifier resolves in a single place — and the gate must ban the construction, not name a file.
tags: [keyboard, accessibility, macos, portability, gates, m2-h, d7]
timestamp: 2026-07-29T00:00:00Z
status: built-gate-incomplete
---

Every keybinding in RackMate is a row in `kKeymap`. Nothing constructs a
`SingleActivator` anywhere else. The primary modifier — `Ctrl` on Windows,
`Cmd` on macOS — resolves in exactly one function,
`KeyBinding.activatorFor(TargetPlatform)`, through `defaultTargetPlatform`.

# Why it exists

Three debts, paid at once, which is why this was the single item pulled forward
out of the [macOS work list](/decisions/dr-009-macos-in-v1.md):

* **macOS modifiers.** 43 bindings across six files hard-coded `Ctrl`.
* **M7's exit criterion** requires *"no keybinding bound twice in the generated
  table"* — and nothing generated a table.
* **CR-101's collisions**, which nothing checked.

# The measurement that justified the ordering

The debt register recorded **22 bindings**. By the time the extraction was built
there were **43** — two other tasks had added twenty-one *in between*. A ~95%
growth in a single day of work on other things, against an estimate of "~40"
that was already exceeded.

**That is the property to look for when deciding what to pull forward.** Not
size, not risk — whether the item's cost grows with every unrelated commit.
Nothing else in that register does.

# A real collision does not throw

This is why the arbitration needed a **test**, not a review.
`ShortcutManager` groups by trigger and takes the first activator that accepts,
so a duplicate binding is dead code that still reads as live. Nothing crashes,
nothing logs, and the second feature simply never fires.

`arbitrate()` therefore checks four conflict kinds **across every
`TargetPlatform`** — the only way a Windows machine catches a macOS-only
collision. Verified by injecting a duplicate `Ctrl+S` and watching it fail with
`duplicateInScope: Ctrl+S — openDocument vs saveDocument`, naming both sides.

# What the consolidation exposed

Someone had **already hand-rolled this, for undo alone**: `Ctrl+Z`/`Cmd+Z` and
their Shift variants were four literals. Collapsing them removed `Win+Z` on
Windows, which no document ever bound — it was collateral of hard-coding `meta`.

It also surfaced a live bug the registry could not fix: **undo and redo are
Rack-tab-only.** The handlers gate on `!_textFieldHasFocus` and the comment says
*"document-global"*, but the `Shortcuts` subtree is the rack canvas screen, so
`Ctrl+Z` does nothing on Schematic or Schedule. The same failure was
post-mortemed for `Ctrl+S`, fixed there, and never re-examined for undo — it was
unobservable until both other tabs became real.

# THE GATE IS THE HALF THAT WAS DONE WRONG

The ban is enforced by a layering test that reads **one named file** and asserts
it contains no `SingleActivator(`. That is the entire enforcement.

The package where most remaining UI work lands has **no layering test at all**,
and the arbitration test is pure in-memory — it never reads a source file, so it
cannot see a binding that never reached the table. A hand-rolled
`SingleActivator` there compiles, ships, hard-codes `Ctrl` on macOS, and is
invisible to both `arbitrate()` and M7's table. **Nothing fails.**

**A structural rule needs a structural gate. Ban the construction across the
tree and allow the one legitimate site; do not name the file you happened to be
editing** — a per-file ban leaves exactly as many holes as there are files you
did not think of.

# Citations

[1] `packages/rackmate_ui/lib/src/keymap/keymap.dart`
[2] `docs/13-macos-debt-register.md` §3, §3.1
[3] canonical-decisions.md §11.9.2 (the ordering argument), §11.11.6 (the
    shared-label retrofit [DR-011](/decisions/dr-011-connect-gesture.md) needs)
[4] Commit `b36c04c`
