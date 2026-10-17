---
type: Design Ruling
title: DR-156 — A command reports whether it applied, and a transaction may take its label from its first child
description: >-
  Two defects in the command machinery, one subject. apply returns bool so a
  refusal never reaches the undo stack, and a transaction's label may be
  deferred to its first child and read after apply. Both were found by LEN-A and
  filed rather than fixed in flight, because each changes the Command protocol
  every command in the product implements.
tags: [ruling, commands, undo, architecture, dr-156, dr-027, cr-106, len-a]
timestamp: 2026-09-12T00:00:00Z
ruling_id: DR-156
canon_section: "11.155"
status: built
---

Settled by the user on 2026-09-12, closing `#863` and `#866`.

# A refusal never reaches the undo stack

A command that self-refused inside `apply` still became a child of its
transaction: the transaction was recorded, the epochs bumped over a document
that did not change, and the next `Ctrl+Z` called `revert` on a command that
never applied, which throws.

**`_commit` already had the concept and could not see this case.** It reads
*"no-op edits add no history"*. What was missing was any way for a command to
SAY it declined. `TxnScope.add` now drops a child that returned false, and that
guard reaches the case it was written for.

`void apply(A)` became `bool apply(A)`: **78 implementations across 40 files, 24
of which can refuse.** The user chose the return type over a `bool get applied`
beside a `void apply`, because two members can drift and a defaulted one is a
hole every future refusing command falls into silently. There is no default to
fall through.

**The `StateError` in `revert` stays.** It catches *revert called before apply*,
which is a real programming error. The defect was never the throw.

# The label is read at commit, not at the call

`run` was `transact(c.label, (tx) => tx.add(c))`. Dart evaluates the argument
before the closure runs and the closure is what calls `apply`, so a command that
decides its label from the document was asked while the document still held the
old state.

**Three commands decide that way and every one names the second half of a
deliberate pair**: `SetPlanPinCommand`, `SetRoomOutlineCommand` and
`SetPlanScaleCommand`. Half of each pair never reached a person. Two more
commands look dynamic and are not, discriminating on state known at
construction.

`transact`'s label is nullable now, meaning **the first child names this entry**,
resolved at commit. **A caller that names the act still wins**, which keeps
*Undo Import CSV* from becoming *Undo Set Property*.

> **The obvious mirror was drafted and rejected.** `Transaction.mergeKey` already
> forwards to a single child and the same three lines would have fixed this. They
> would also silently override a caller who named the act, and `LEN-A/4`'s
> outline close adds one child or two depending on whether the estimate
> auto-filled, so one gesture would have produced two different menu entries
> depending on a derivation nobody can see.

# One ruling, because the asymmetry needs recording

`TxnScope` is shared by both undo stacks, so the refusal fix lands **once**.
`TemplateEditSession` carries its own `_TxnBuilder` and `_commit`, so the label
fix lands **twice**. No command on the builder's stack decides its label from the
template today, which is exactly the condition under which a defect gets fixed in
one place and left in the other.

**Related:** [CR-106](/invariants/cr-106-one-machinery-three-stacks.md) ·
[a test that asserts an absence names its due date](/practices/a-test-that-asserts-an-absence-names-its-due-date.md) ·
[a property proven by a fixture's default is not proven](/practices/a-fixture-default-is-not-a-proof.md)
