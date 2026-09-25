---
type: Practice
title: A diff over the old keys cannot see a new one
description: >-
  epoch_mask_test compared a document before and after each command by walking
  the keys it had BEFORE. The codec omits `underlays` when it is empty, so a
  project's first underlay created a key the loop never visited, and the test
  reported that the command had changed nothing at all.
tags: [practice, testing, epochs, persistence, cr-114, ac-014]
timestamp: 2026-09-24T00:00:00Z
---

A before-and-after diff answers **"which of these keys changed?"**, and the
question is only as wide as *these*. Walk the keys the old state had and a key
the change *creates* is not in the question, so it cannot be in the answer.

# Where it bit

`_changedTopLevelKeys` in `epoch_mask_test.dart` (AC-014) snapshotted the
document map, ran the command, snapshotted again, and looped over
`before.keys`. For the maps that write `{}` when empty it made no difference.
`underlays` does not write one: `json_codec.dart` omits it when empty so that
every existing file still re-encodes byte for byte (the codec cites DR-136
§11.135.3), which is CR-114's absent-key rule applied to a whole map.

So `AddPlanUnderlayCommand` on a project with no plan returned
**`changed: {}`**, measured by putting the old loop back (`#944`). The command's
mask was never checked against the one thing it did. It passed.

# The rule

**Diff over the union of both states' keys.** One line:
`{...before.keys, ...after.keys}`.

This repository makes the trap more likely, not less, because it
**deliberately** omits things: G4 serialises unknown as an absent key, and
more than one ruling has stopped writing empty collections to shrink files. So
every "nothing" here can be a missing key, and every diff should expect a key
to appear or vanish.

# Related

- [A blanket rebuild hides a missing subscription](a-blanket-rebuild-hides-a-missing-subscription.md):
  the same test's subject, from the consumer's side.
