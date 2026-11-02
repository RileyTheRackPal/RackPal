---
type: CI Gate
title: The .gitattributes byte-exactness sweep
description: Proves every extension sitting in a byte-exact root is pinned, so a fresh clone receives the bytes that were committed.
tags: [gate, ci, persistence, cr-117]
timestamp: 2026-07-28T00:00:00Z
resource: apps/rackpal/test/gitattributes_byte_exactness_test.dart
status: enforced
---

[CR-117](/invariants/cr-117-byte-exactness.md) is only as strong as the guarantee
that the bytes on this disk are the bytes that were committed. `.gitattributes`
is that guarantee; this gate proves the rule is present and correct.

# The failure it was written after

`*.json` was pinned, and everything else fell through to `* text=auto` with `eol`
unspecified, so on Windows it checked out per `core.autocrlf`. The four starters
are `assets/starters/*.rackmate` (today `apps/rackpal/assets/starters/*.rppj`),
matched no rule, and were untracked. The moment
they were committed, the next Windows clone would have received them
CRLF-normalised and the byte-exact suite would have failed **on a clean checkout
while staying green for everyone who already had the tree**.

It derives the extensions needing protection from what is **actually sitting** in
the byte-exact roots, not from a list somebody must remember to extend.

# The traversal bug, and why it matters beyond this gate

The sweep originally used `listSync(recursive: true)` and then filtered through a
skip list. That order is the bug: **`listSync(recursive: true)` enumerates
eagerly**, so it descended into `windows/flutter/ephemeral/.plugin_symlinks/`, 
symlinks into the pub cache whose plugins carry macOS example projects past
Windows' 260-character `MAX_PATH`, and threw for the entire sweep *before* the
filter ran. `/ephemeral/` was already in the skip list. A post-hoc `.where` cannot
prevent a traversal that has already happened.

It surfaced when agent worktrees under `.claude/worktrees/` were added: the sweep
walked into a second checkout, counted every file twice from a path no clone has,
and died in its build artifacts.

**The fix is a walk that prunes during traversal and treats an unlistable
directory as skipped rather than fatal.** Any other repo-root sweep should be
written the same way, the general lesson is that a filter applied after
enumeration does not protect the enumeration.

# Citations

[1] `apps/rackpal/test/gitattributes_byte_exactness_test.dart`
[2] `.gitattributes`
[3] Commit `27dd492`
