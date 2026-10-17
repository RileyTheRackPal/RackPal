---
type: Design Ruling
title: DR-189 · The licence is AGPLv3-or-later, and a vendor's door is the CC0 catalog
description: >-
  Reverses DR-036's GPLv3 clause. The AGPL objection the question remembered is recorded nowhere and
  was searched for; the real finding is that the project has never been licensed at all, because no
  LICENSE file exists and DR-036's output exception has been undischarged since it was ruled.
tags: [ruling, licence, agplv3, cc0, catalog, provenance, dr-189, dr-036]
timestamp: 2026-09-23T00:00:00Z
ruling_id: DR-189
canon_section: "11.188"
status: built
---

Settled by the user on 2026-09-23. Reverses
[DR-036](/decisions/dr-036-public-gplv3-cc0-catalog.md) §11.35.1 clause 2 and nothing else.

# What was ruled

- **The application code is AGPLv3-or-later.** The other four clauses of §11.35.1 stand: the project
  is public, the community catalog is CC0, contributions arrive under a DCO sign-off, and nothing is
  priced.
- **Vendor and manufacturer contributions arrive as CC0 data, never as source.** CC0 imposes no
  conditions and flows into AGPL freely; the reverse would put a vendor's product data under
  copyleft, which is the friction the question exists to remove.
- **Provenance needs no ruling**, and the model already holds the line.

# The objection the question remembered does not exist

The question said *"I remember there being a reason that this ended up being a potential problem"*.
**`AGPL` and `Affero` appear nowhere**: not in the tracked tree, not in `docs/`, not in `.okf/`, not
in any commit message on any branch. Searched rather than assumed: a licence claim reasoned from the
shape of a question is the error §11.18.5 already records once, which is why §11.35.2 read the
dependency census out of the pub cache rather than from memory.

Two recorded facts are adjacent and are the likely memory:

| What is recorded | What it actually says |
|---|---|
| `pdf` is Apache-2.0 | Closes **GPLv2** permanently, not v3. The tree was always clean for v3, and is clean for AGPLv3 on the same terms |
| §11.35.4's output exception | A real *"this turned out to be a problem"*, solved by exactly the mechanism the question proposed: carving an exception |

# What AGPL changes today is nothing, and that is the point

§13 binds interaction **over a network**. RackPal is a Windows desktop application with no server,
no accounts and no telemetry, so §13 is inert. The value is prospective: it forecloses a hosted
RackPal built on this code without released modifications. **A licence chosen after that becomes
attractive is chosen too late.**

The cost is recorded rather than discovered: AGPL is prohibited outright by some organisations'
open-source policies, which is a narrower door than GPLv3 for a manufacturer wanting to contribute
CODE. It does not touch the template path, which is the one the question cared about.

# The real finding: the project has never been licensed

**There is no `LICENSE` file, and README line 168 still called the licence TBD** six weeks after
DR-036 answered the question. §11.35.4 requires the output exception (a document produced by RackPal
is the user's own work and not a derivative of RackPal) to be *"stated in `LICENSE` and in the
README, not inferred, because an exception nobody can find is not one"*.

So the switch costs nothing precisely because nothing was ever published, and **the outstanding work
is not this ruling**. The text goes to a qualified reviewer: §11.35.4's own precedent is the GCC
Runtime Library Exception, drafted by the FSF's counsel, and this is the one deliverable where
approximately right is not a category that exists.

# Provenance: the model already refuses to overclaim

The user raised vendor provenance and declined it themselves, over network scope. Measured rather
than designed: `TemplateProvenance` is already a sealed class answering *"where a placeable template
came from, **as far as THIS build can tell**"*, and `ProjectProvenance` already states the
discipline outright, that the name says **which shelf and not which author**.

A manufacturer library is therefore another shelf. `LibraryProvenance` carries its id and name, and
the badge-versus-filter split (DR-033's handle-and-id split applied one level down) already handles
two libraries claiming one name. **No network operation is required, because trust is established on
acquisition rather than at runtime**, and the limit is stated rather than papered over: a badge means
a library file said so. Signed archives are the next rung if one is ever wanted, and signature
verification is also local; the cost is key distribution, which is administrative.

# Related

- [DR-036](/decisions/dr-036-public-gplv3-cc0-catalog.md), whose clause 2 this reverses and whose
  other four clauses carry the whole vendor answer.
- **The corpus already had both halves.** The exception the question wanted to carve was already
  clause 3 of the ruling being amended, and the provenance model it worried about building shipped
  at M4-N. Grepping the corpus before adding a rule is what turned two features into two citations.
