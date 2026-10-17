---
type: Design Ruling
title: DR-036 — RackMate is a public GPLv3 project, the catalog is CC0, and nothing is priced
description: "Reverses DR-006's posture and discharges DR-033's precondition. Two clauses matter more than the licence names: the catalog is deliberately not copyleft, and the licence carries an output exception, both because copy-on-place embeds templates into every client deliverable."
tags: [ruling, licence, gplv3, cc0, distribution, dco, scope, dr-036]
timestamp: 2026-08-10T00:00:00Z
ruling_id: DR-036
canon_section: "11.35"
status: superseded-in-part
superseded_by: [DR-189]
---

Settled by the user on 2026-08-10. This is the ruling
[DR-033](/decisions/dr-033-community-catalog-submission.md) §11.32.7 declined to
make and named as its precondition. It reverses
[DR-006](/decisions/dr-006-self-signed-distribution.md)'s first clause, answers
§10.3 **on its own terms** rather than leaving it moot, and unblocks the v1.1
community catalog.

# The ruling

1. **RackMate is a public project.** Developed in the open.
2. **Application code: GPLv3-or-later.**
3. **Community catalog: CC0 1.0**, a public domain dedication, and **not** GPL.
4. **Contributions: a DCO sign-off**, not a contributor licence agreement.
5. **Nothing is priced.** No fee, no tier, no gate, no enforcement.

# The census was measured, not recalled

Read out of the pub cache, because a licence claim reasoned from the shape of a
question is the error canon §11.18.5 already records once. See
[verify by reading](/practices/re-read-a-task-against-canon.md).

| Licence | Packages |
|---|---|
| **Apache-2.0** | `pdf` 3.13.0 |
| MIT | `uuid`, `path_drawing`, `window_manager`, `screen_retriever` |
| BSD-3-Clause | `collection`, `meta`, `path`, `vector_math`, `path_provider_windows`, Flutter SDK |

Everything is permissive, so every option was open **but one**: `pdf` being
Apache-2.0 **closes GPLv2 permanently**, its patent-termination and indemnity
terms being additional restrictions under v2 and explicitly accommodated by v3.

**The SIL OFL fonts AC-058/D7 speaks of are not bundled yet**: `assets/` holds
only `catalog/`. That obligation is future rather than current, and D7 now also
owes GPLv3 its own `LicenseRegistry` entry.

# Why the catalog is not copyleft, which is the clause that would have been got wrong

Copy-on-place (**AC-041**) embeds a full `TemplateSnapshot` into
`RackDocument.templates` so that a `.rmpj` is self-contained and the recipient
does not need your library.

**Under a copyleft catalog, every project file an integrator sends a client
contains catalog-derived content.** The product would be handing professional
users a licensing question about their own deliverables. Nobody reads a licence
before emailing a drawing set, so they would simply be quietly non-compliant, at
scale, because of an architectural decision made for an unrelated reason.

**CC0 removes the question rather than answering it**, and is the honest
description of content that is largely uncopyrightable fact: a device has four
rack units and eight HDMI inputs whoever writes it down. Attribution survives
where it belongs, in the pull request history and in `submittedBy`, which DR-033
§11.32.5 already made a credit and not a licence term. **CC-BY was refused** for
putting that same travel problem back into every embedded snapshot.

# The output exception, because the seed has the same problem

The seeded catalog is **Dart source inside `rackmate_core`** and is therefore
GPLv3 as code. Copy-on-place embeds *seeded* snapshots exactly as it embeds
community ones, so fixing only the community catalog leaves the identical defect
wearing the archetypes that ship in the binary.

So the licence carries an explicit **output exception**, in the manner of the
GCC runtime library exception: **a document RackMate produces is the user's own
work and is not a derivative of RackMate**, seeded snapshots and exported PDF
sheets included. **Stated in `LICENSE` and the README, not inferred**, because
an exception nobody can find is not one.

Without it, GPLv3 on a program whose whole purpose is to emit a client
deliverable is a trap set for the people the product exists to serve.

# DR-006's own fallback fires on schedule

DR-006 named **Microsoft Trusted Signing** as the fallback *"if external
distribution is ever required, adoptable at M8, with no earlier milestone
needing to anticipate it"*. That condition has fired and **the promise holds: no
milestone before M8 moves.** Public distribution makes the switch necessary
rather than optional, a self-signed binary downloaded over the internet carrying
Mark-of-the-Web and meeting the SmartScreen ramp. §11.6.1's finding that the
two-milestone lead time was OV/EV-specific is untouched.

# §10.3, and the watermark that never gets built

§13 recorded §10.3 as MOOT with a standing note that it reopens exactly as
written if DR-006 is reversed, watermark hazard included. It has reopened, and
the answer is that nothing is priced.

**The watermark is the part that mattered.** §10.3's option (c) would have
stamped client-facing sheets, and **DR-005 makes the whole sheet set a client
deliverable**, which is what makes a watermark unshippable rather than merely
unpleasant. AC-058/D7 shrinks a second time, permanently rather than pending.

# A DCO, and what it deliberately forecloses

A `Signed-off-by` line asserting the right to submit. DR-033's flow can add it
automatically, so contributor friction is zero, which is the argument: a signed
agreement deters exactly the one-device drive-by contribution the catalog exists
to collect.

**The accepted cost is that clause 2 is near-irreversible.** Without a CLA the
code licence cannot change without every contributor's consent.

# Neither licence grants the name

*RackMate* and **Riley the RackMate** (§10.12(f)) are trademarks. A fork may take
the code and **may not take the name or the mascot**.

# What it obliges, and what it does not rule

Owed, none of it on v1's critical path: a verbatim `LICENSE` with the output
exception beside it, a CC0 `LICENSE` in the catalog repository, a
`CONTRIBUTING.md` carrying the DCO, `LicenseRegistry` registration, and the M8
switch to Trusted Signing.

**Not ruled:** the date the repository actually becomes public, which is a
readiness call; which forge hosts it; governance and merge rights; and the
licence on a user's own authored templates, which were never the project's to
license.

# Citations

[1] canonical-decisions.md §11.35 (`docs/canonical-decisions.md`)
[2] canonical-decisions.md §12.16; §13's §10.3 row, MOOT to ANSWERED
[3] canonical-decisions.md §11.32.7, the discharged precondition
