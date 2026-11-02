---
type: Design Ruling
title: DR-258 · A gate refuses any commit with another identity or an offset other than +0000
description: >-
  From SCRUB-1 (#1287), answering the gate DR-257 offered. Every commit reachable from HEAD must be the
  ruled identity at +0000, locally and in both pipelines; a shallow clone fails it, and on a PR build
  only the service's own merge is skipped.
tags: [ruling, gate, anonymity, identity, timezone, ci, scrub-1, dr-258, dr-257]
timestamp: 2026-11-02T00:00:00Z
ruling_id: DR-258
canon_section: "11.257"
status: ruled
---

Settled by the user on 2026-11-02, on the recommendation, from `#1287`. The gate is
[the identity gate](../gates/identity.md); the history it protects is
[DR-257](dr-257-one-pseudonymous-identity.md)'s.

# Why a rewrite needs a gate behind it

Three routes back were each one step away the day DR-257 landed: an IDE started before `TZ=UTC0`, a
clone with no identity of its own on a machine whose global one is different, and a merge from a
pre-rewrite ref. None shows in a diff, and the public remote cannot take a push back.

# Two CI facts that shaped it

The clone is `fetchDepth: 1`, so a history check there would vouch for one commit; a shallow clone
therefore FAILS the gate, and the step fetches commits only first. A PR build's `HEAD` is the service's
merge, stamped with the old identity; only that commit is skipped, and only when its parents include the
build's source commit.

# Related

* [DR-257](dr-257-one-pseudonymous-identity.md), the rewrite and the landing procedure.
* [The identity gate](../gates/identity.md), what it reads and what it cannot see.
