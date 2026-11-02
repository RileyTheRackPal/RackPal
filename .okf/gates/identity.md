---
type: CI Gate
title: Identity
description: Every commit reachable from HEAD is the identity DR-257 ruled, at +0000. A shallow clone fails it; on a PR build only the service's own merge is skipped.
tags: [gate, ci, identity, timezone, anonymity, dr-258, dr-257]
timestamp: 2026-11-02T00:00:00Z
resource: tools/identity_gate.py
status: enforced
---

`python tools/identity_gate.py` walks every commit `git log HEAD` reaches, merge parents included, and
exits 1 when an author or committer is not the identity [DR-257](/decisions/dr-257-one-pseudonymous-identity.md)
ruled or either offset is not `+0000`. [DR-258](/decisions/dr-258-the-identity-gate.md) is the rule;
board `#1287` built it.

# What it reads

- Six header fields per commit: author and committer name, email and offset.
- Nothing else. It names the identity it allows and never the ones it refuses, because a tracked list of
  forbidden names would publish them.

# How it runs on CI

The checkout is `fetchDepth: 1`. The step first runs `git fetch --unshallow --filter=tree:0` for the
build's ref (commits only, 3.8 s for the whole history when measured), passing the job token for that
fetch alone. Then `--ci`: on a PR build, `HEAD` is the service's own merge and is skipped only when it is
a two-parent merge one of whose parents is `SYSTEM_PULLREQUEST_SOURCECOMMITID`.

# Non-vacuity

Thirteen planted throwaway repositories run first, each with one defect: each field, a bad commit
reachable only through a merge's second parent, a shallow clone, and four PR-merge edge cases. Pointed at
the pre-rewrite tip on the day it was written, it refused 1,698 of 1,698 commits, and the offset on
exactly the 1,467 the DR-257 census had counted.

# What it does not see

- **The tree's content.** A scrubbed name typed back into a file is not a header, and a check for it
  would have to name it.
- **Tags**, which nothing here creates.
- **A commit already on a remote**: it reports one, and mending it is a history rewrite and a ruling.
