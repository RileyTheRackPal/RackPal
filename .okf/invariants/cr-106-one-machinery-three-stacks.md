---
type: Invariant
title: CR-106, one Command machinery and three stacks
description: The undo system is generic over its aggregate, there are exactly three stacks, one of them is deliberately empty, and the rule that keeps them from becoming two mechanisms.
tags: [invariant, commands, undo, builder, m4, cr-106]
timestamp: 2026-08-13T00:00:00Z
status: built
---

`UndoStack<A>` and `Command<A>` are generic over the aggregate they change,
and there are **exactly three stacks**:

| Stack | Aggregate | Lifetime |
|---|---|---|
| Document | `RackDocument`, in `DocumentController` | The open project. |
| Device Builder | the `TemplateBody` being edited, in `TemplateEditSession` | Discarded on close without save. |
| Settings and library operations | none: **not undoable** | Each is individually confirmable or trivially reversible instead. |

The Structure editor's edits are ordinary document commands on the document
stack. Stated once so nobody builds a second mechanism.

# The type parameter arrived four milestones late, and the delay was recorded

M0 transcribed `Command` from docs/03 §5.1 literally, hard-typed to
`RackDocument`, while `UndoStack<A>` already carried its `<A>` for CR-106's
documented intent and its `undo`/`redo` still took a concrete document.
`undo_stack.dart`'s header named the mismatch as deferred debt and said to
revisit it *"if/when the Device Builder's own stack is built"*.

**M4-A is that revisit.** Doing it any later would have meant migrating the
builder's own commands too, which is exactly why the milestone's decomposition
put it first.

# Why it could not be done in three commits

The board split it into the interface, the stack and the migration. Dart
refuses the split:

* an override's parameter type must be a **supertype** of the base's, so every
  `apply(RackDocument doc)` stops overriding `apply(A)` the instant `Command`
  gains a parameter, and all 36 subclasses break together;
* the obvious escape, leaving `UndoStack` holding a raw `Command`, is closed by
  `strict-raw-types: true`, under which `strict_raw_type` is a **warning** and
  warnings are gated at zero.

Worth knowing before pricing a similar refactor: **a type parameter on a widely
implemented interface has no partial landing.**

# The mask went nullable, and null is not zero

`Command.touches` is `EpochMask?`. `EpochMask.none` asserts a command touched
no epoch; `null` says the aggregate has **no epoch model to touch**, which is
true of a `Command<TemplateBody>` and of nothing else.
[G4](g4-unknowns-are-counted.md)'s shape, applied to a bitmask.

The consequence is mechanical rather than philosophical. A document command
that returned `none` would invalidate nothing, so the model would change and
**the canvas would not repaint** - undo appearing to work while the screen
lies. `epoch_mask_test` now asserts that every `Command<RackDocument>` declares
a mask, an assertion the nullability made both possible and necessary.

`Transaction<A>.touches` folds only the children that declare one, so a
document transaction still folds to a real mask. `Selection` went nullable for
the same reason: it is a set of `Uuid`s, and a `TemplateBody`'s ports are keyed
by `PortKey`.

# The builder edits a copy, and that is what makes "discarded" true

`TemplateEditSession` deep-copies the `TemplateBody` handed to it. Without
that, "discarded on close without save" is a comment: dropping the stack would
leave every cancelled edit in memory for the next device placed from that
template to pick up, and **no test that reads only the undo stack would ever
see it**.

The copy is `copyTemplateBody`, a **codec round trip**, not a hand-written
clone. The body has ~50 fields and eight growable lists; a clone drifts the
first time somebody adds field 51, and a field a clone forgets is a *list
shared between the copy and the original*. The encode/decode pair is already
under [CR-117](cr-117-byte-exactness.md)'s gate, so a field the copy loses is a
field the file loses, and that gate fails first and loudly.

**The two copy tests do not cover each other, which was learned by watching
them fail.** Sabotaging `copyTemplateBody` to `(b) => b` fails the two identity
tests and **passes** the 48-template byte sweep, because a body compared with
itself is trivially byte-identical. The sweep catches a copy that *loses* a
field; the identity tests catch one that *shares* one.

# The third row is a rule with no code, and it must stay that way

Library operations - delete a template, import one, set a favourite - are not
on the builder's stack. The temptation is real and it is a design error: an
undo scoped to one template cannot coherently undo an act on the shelf that
template sits on, and a `Ctrl+Z` that *sometimes* un-deletes a file is worse
than one that never does.

# Citations

[1] `docs/canonical-decisions.md` CR-106
[2] `docs/03-architecture.md` §5.1, §5.4, §5.6
[3] `packages/rackpal_core/lib/src/builder/`, `commands/undo_stack.dart`
[4] `docs/12-milestone-board.md` §5.3.1
