---
type: Design Ruling
title: DR-052 — Git sync is v1.2 and gated on evidence; live collaboration is never
description: >-
  Diffable is not mergeable, and that gap is the whole engineering risk. A v2 row
  that read as one feature turned out to be two, and splitting it moved one half
  forward and the other to never.
tags: [ruling, sync, collaboration, cr-117, determinism, dr-033, dr-039, dr-052]
timestamp: 2026-08-12T23:30:00Z
ruling_id: DR-052
canon_section: "11.51"
status: ruled
---

Settled by the user on 2026-08-12, from two requests taken together because they
are one question: git syncs the file between people, live collaboration edits it
simultaneously.

# Live collaboration is never, on three independent grounds

Any one would be sufficient.

**It deletes determinism's precondition.** *Same document, same display list, same
exported bytes* holds **because there is one writer**. Concurrency does not weaken
that guarantee, it removes what makes it true, and the 1000-sequence fuzz harness
asserting byte identity is asserting a property of a single-writer system.

**It renegotiates [CR-117](/invariants/cr-117-byte-exactness.md).** A CRDT needs
per-field causal metadata in the file: a schema version, a migration chain, and the
end of *an absent key means not present*, which is the sentence the whole
persistence suite rests on. Operational transform avoids the format cost and needs
a server plus **a rebase rule per command type**, of which there are around forty.

**Undo has no good multi-user answer.**
[DR-039](dr-039-history-is-a-journal-first.md) §11.38.5 already had to explain that
undo-to-a-point works and edit-in-the-middle does not, because each operation was
written against the state its predecessor produced. Multi-user undo asks *whose*
undo, and reverts either the user's last act or the document's. Both are wrong
often enough that shipping products maintain apology pages about it.

# Diffable is not mergeable

CR-117 gives byte-exact key-sorted output, so `git diff` reads well and `git log`
is genuinely useful. **A three-way merge is a different problem.** Two designers
who each add a device produce a textual merge that **succeeds** and a document that
may carry duplicate designators, colliding `FracIndex` orders, or an `UndoStack`
that no longer describes the file.

**So the ruling forbids the tempting half: RackMate performs no merge, in any
release.** It detects that the file changed underneath it, refuses to overwrite
silently, and offers a side-by-side. Merging is git's job and a person's, and an
in-app three-way merge UI for this format is how a sync feature becomes a
corruption feature.

# A v2 row that was two features wearing one name

Roadmap §2.4 carried *"Cloud sync and multi-user: the model is already cloud-ready
... nothing more is spent until someone asks."* **Splitting it is what let one half
move forward and the other move to never**, and the row's own reasoning is why the
split works: a cloud-ready model is exactly what makes **sync** cheap, and it is
**irrelevant** to concurrent editing, which fails on determinism, CR-117 and undo
rather than on identity.

Its gate was also not a gate. *"Until someone asks"* gives no way to tell whether
being asked settles it, and somebody has now asked. The sync half gets a real one:
**real projects showing a handoff that a file share does not already solve.**

# What it does not replace

**DR-039's journal.** §11.38.2 put history **in the file** because *"history left
on the author's machine is absent from the artifact under investigation"*, and the
user's stated reason was troubleshooting a project somebody sends you. **Git puts
history on a server**, so a `.rmpj` emailed to a client carries none of it. The two
solve different problems.

**DR-033's no-secrets constraint** governs the authentication and is not re-opened:
no desktop binary can hold a secret, so it is the authorization-code flow with
PKCE. **DR-034's "fetched, never cloned"** is not contradicted either, and its
ground (clone does not survive a platform with no git) is exactly why the **v1**
item is plain file divergence rather than git.

# Citations

[1] `docs/canonical-decisions.md` §11.51, §12.22
[2] `docs/09-roadmap.md` §2.1, §2.3, §2.5
