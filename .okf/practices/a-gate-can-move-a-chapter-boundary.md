---
type: Playbook
title: When a gate refuses finished work, check whether the boundary is wrong before you satisfy the regex
description: >-
  PLAN-E/3 built a callback, a menu item and two green tests, and
  callbacks-have-callers refused the lot. The call site could have been reworded
  until the scanner matched. The gate was right, because the gesture was
  unreachable and the work belonged in a later chapter.
tags: [practice, gates, decomposition, plan-view, plan-e, reachability]
timestamp: 2026-09-08T00:00:00Z
status: adopted
---

A gate that refuses work you have finished offers two moves. One is to make the
check pass. The other is to ask **what the check knows that the plan did not**.

# The instance

`PLAN-E/3` built the drop table's half of the pin fast path:
`StructureEditorActions.onPinOnPlan`, threaded through the table to a row,
opened by a secondary tap, two cases green including one asserting the action is
absent when the host supplies none.

[callbacks-have-callers](/gates/callbacks-have-callers.md) failed:

```
Expected: empty
  Actual: ['StructureEditorActions.onPinOnPlan']
```

**The cheat was available and cheap.** The scanner looks for `\.name\s*\(` over
`lib/`, and the call site was `pin(row.linkId)` through a local alias, so it
never matched. One rewording and the gate would have gone green.

# Why the gate was right

Nothing in `lib/` *supplies* the callback. The Plan view is not in the tab strip
until a later chapter (DR-091 keeps it out until it is built), so a menu item
arming a mode whose only surface is unmounted is **a control that does nothing**.

That is the same defect the gate was written for: M3-H/5's
`OutletsActions.onRemoveGang` had a command, an app-side implementation, tests
for both, and no caller.

> Satisfying the regex would have satisfied the letter and shipped exactly the
> thing the gate exists to prevent, with a green tick over it.

So the producer moved to the later chapter, where the view gets a home and the
whole path becomes reachable in one commit.

# The shape

**A reachability gate is a claim about the PRODUCT, not about the file.** When it
fires on work that is correct in isolation, the usual cause is that the work is
correct in isolation: the piece is fine and the boundary it was built inside is
wrong.

Three questions, in this order:

1. **Is the thing actually reachable by a person?** Not "is it called
   somewhere", but: can a user get to it in the shipped build. If not, the gate
   is right whatever the regex says.
2. **What would make it reachable, and is that in this chapter?** If the answer
   is another chapter, the work belongs there.
3. **Only then**, if it is genuinely reachable and the scanner cannot see it,
   fix the scanner or the call shape, and say which in the commit.

# The corollary about decompositions

This one exposed something larger than a callback. Three consecutive chapters
were building behaviour for a view a fourth mounts, so **each was ending with
code the product could not reach**. That is legal, and it means the mounting
chapter is not the small one its brief implies: it is the chapter that makes
three others true.

**A gate found that, and no amount of reading the chapter briefs had.** See
[ask-what-consumes-each-tasks-output](ask-what-consumes-each-tasks-output.md),
which is the same question asked before the work rather than after.
