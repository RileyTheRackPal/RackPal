---
type: Decision
title: DR-078 — The five grid operations, and what a bulk write shows before it fires
description: One chord collides with a Flutter macOS default and is taken anyway; a move offers only the banks that exist; and both bulk-write dialogs show a per-row impact list, because undo cannot reach a published key.
tags: [m4, m4-f, device-builder, keymap, macos, bulk-edit, cr-051, dr-009, dr-060, dr-063]
timestamp: 2026-08-19T00:00:00Z
ruling_id: DR-078
canon_section: "11.77"
status: ruled
---

Three questions raised by censusing M4-F's six remaining tasks before writing
any of them: `Duplicate`, `Renumber…`, `Find & replace`, `Change type…`,
`Move to bank…` and writing a field from the batch inspector.

Every operation already had a binding in `docs/06` §4.6. What was missing was a
behaviour column, a platform collision nobody had checked, and a safety question
the table does not reach.

# One of five chords was already taken

`Ctrl+T` is `TransposeCharactersIntent` in Flutter's `_macShortcuts`, and DR-009
puts macOS in v1. `Ctrl+J`, `Ctrl+R`, `Ctrl+H` and `Ctrl+M` are clean in every
platform map and in this product's own registry.

**The direction of the collision is the part worth knowing.** `docs/04` §8
records that Flutter dispatches key events leaf to root while
`DefaultTextEditingShortcuts` sits at the app root, so ours wins: transpose does
not eat `Change type…`, `Change type…` eats transpose. On macOS, inside a builder
cell, `Ctrl+T` stops transposing two characters.

Taken anyway, because §4.6 specifies the chord and because DR-011.6 requires one
chord to wear one meaning across the product, which a per-platform split breaks
on an axis a keyboard-only user can see even less than a scope boundary.
Recorded as macOS debt (`docs/13` §3.6) rather than absorbed silently.

**The check was run over the framework's source, not recalled.** `Ctrl+D`'s
keymap note had already established the check years of commits ago; this is the
first time it came back positive.

# A move offers the banks that exist

`Move to bank…` lists the template's declared banks and refuses, with a sentence,
when there are none. It does not mint one.

Creating a bank is `BankDef` CRUD and belongs to M4-J1. A creation path in this
dialog would be a second surface that has to agree with J1's about naming,
ordering and collisions **before J1 has decided any of them**, which is the
losing move this codebase keeps re-learning: invent a rule in a dialog, leave a
later task to match it.

# Undo cannot reach a published key, so the preview is not optional

`Find & replace` and `Change type…` each write across N rows at once, and both
get the same thing: a scrollable per-row before-and-after list, a count, then
`Apply`.

For `Change type…` this was already the stated deliverable, because
`SignalFamilyDef` carries `defaultConnector`, `defaultDirection` and
`defaultTopology` and DR-060 rules that a default loses to a named value. Without
a preview, retyping a bank silently overwrites whatever somebody had already
named, N rows at a time.

**The key scope is why the lighter option loses.** `PortDef.key` is the template
migration join (CR-051), and a key already published when the builder opened may
have another project's cables resolving through it. Undo covers the open document
completely and cannot reach that, so "replace all, `Ctrl+Z` if it looks wrong" is
a safety story that works for every scope except the one that needs it.

A per-scope split was rejected: an impact list for keys and a plain count for
everything else is two behaviours in one dialog selected by a dropdown, which is
a rule a person learns by being surprised rather than by reading the screen.

# What it does not rule

Not `Renumber…`'s copy, which is `label_pattern.dart`'s existing parse errors and
repair chips shown where the user is; `#697` already forbids a second parser and
this adds nothing to it. Not the batch inspector's control set, which is a
refactor with a stated trap rather than a design question. Not `Mirror bank`,
which is M4-J1's.

And it does not weaken §4.6's rule that `LABEL` and `DESIG` edit one row: a
`Find & replace` scoped to labels is a *matched* rewrite per row rather than one
value written across rows, which is the distinction
[DR-063](dr-063-a-disagreement-is-not-an-unknown.md) drew and this preserves.
