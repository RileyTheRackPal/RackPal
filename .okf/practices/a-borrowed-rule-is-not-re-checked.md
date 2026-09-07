---
type: Practice
title: A rule borrowed from an adjacent domain arrives pre-justified
description: The claim that already-compressed rasters do not deflate is true of photographs and false of line art on white, and this product receives line art on white. The rule was imported from the domain where it holds into the domain where it does not, shipped behind four confident sentences, and read as self-evident in both until a real plan set was measured.
tags: [practice, measurement, assumptions, persistence, dr-137, dr-019, plan-view]
timestamp: 2026-09-07T00:00:00Z
status: adopted
---

The dangerous claim is not the one somebody guessed. It is the one that is
**genuinely true somewhere else**, arrives with its justification already
attached, and is therefore never re-run in the place it has just been applied.

# The instance

`container.dart` stored binary members uncompressed, behind this:

> A PNG or JPEG is already compressed; deflating it again buys ~nothing and
> costs real time at level 9 on a multi-megabyte architectural page.

Both halves are wrong **for this product's input**, and the first real plan set
it was ever given says so: an 18-sheet ARCH D residential permit set.

| | |
|---|---|
| *"buys ~nothing"* | **Every page deflates**, 7.0% to 34.3%, mean **16.0%**. The **floor plans deflate BEST**, at 34.3% |
| *"costs real time at level 9"* | **6.2 ms** on the sheet a user actually imports. 230 ms for all 18 at once, on a save that already runs in `Isolate.run` |

The sentence is a correct statement about **photographs**. A JPEG of a photograph
is close to incompressible because its entropy coder has already taken the
redundancy out. **A floor plan is not a photograph.** It is line art on white,
mostly white, and JPEG leaves that redundancy on the table. The pages that
deflated *worst* in the set were the dense structural-notes sheets, which is the
same fact from the other end.

# Why this shape is worse than a guess

**A borrowed rule is pre-justified, so the reflex that catches invented claims
never fires.** Nobody wrote "JPEGs don't compress" as a hunch to be checked
later. It was written as a known property, with a mechanism attached, by
somebody who could have explained *why* it is true. All of that was correct. The
only unexamined step was the one that never got written down: **that the input
here belongs to the domain where the rule holds.**

That step is invisible precisely because it is not a claim. It is an assumption
about what kind of thing the product receives, and it does not appear in the
sentence at all.

**Two supporting tells were in the same file, and both are ordinary.**

* **The list was padded with a reason that discriminated nothing.** A fourth
  argument for storing was that the file *"opens in any zip tool with the
  architect's original page inside it."* Every zip tool inflates a deflated
  entry, so that sentence was true either way and decided nothing. A reason that
  does not distinguish the options makes a list look longer than it argues.
* **The test asserted the branch, not the behaviour.** It checked which
  compression *method* the zip header named, which the writer answered by an
  `if`. It could not have caught this, because it was reading the decision back
  rather than its consequence. Its fixture was even described as
  "incompressible-looking content" and deflates 2.2x, and nothing noticed,
  because nothing asked.

# The rule

**When a rule is true elsewhere, name the domain it is true in, then check that
this is that domain.** One sentence in the comment, and it turns an invisible
assumption into a claim somebody can falsify:

> JPEG deflates poorly *because photographic entropy coding leaves little
> redundancy*. Our inputs are architectural line art on white.

Written that way, the mismatch is visible without measuring anything.

And where the domain check is cheap, **just run it**. Here it was
`zlib.compress(page_bytes)` over one real file: seconds, against a rule that had
shipped and was costing 34% of every floor plan a user imported.

# What this is not

It is not [a stated cost is a hypothesis](a-stated-cost-is-a-hypothesis.md).
There, a **number** in the corpus decided what got built and nobody ran the thing
that produces it. Here there was no number to run: a **general truth** was
imported from an adjacent domain, and what went unchecked was whether the
adjacent domain was this one.

It is not
[a wrong ruling ID resolves](a-wrong-ruling-id-resolves.md), though both are
about a citation of authority that survives inspection. That one borrows the
authority of a real ruling; this one borrows the authority of a real fact.
