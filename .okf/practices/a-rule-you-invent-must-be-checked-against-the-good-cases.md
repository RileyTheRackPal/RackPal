---
type: Practice
title: A rule you invent from one bad case must be checked against the good ones
description: A gate written from a single wrong instance codifies a distinction that may be linguistic rather than structural. Run it against what already works before committing it, and when it disproves itself, pin the artifact instead.
tags: [gates, verification, vocabulary, m4-g]
timestamp: 2026-08-15T00:00:00Z
status: adopted
---

**Finding one wrong instance is not finding a rule.** Before turning a
correction into a gate, run the proposed gate over the cases that are already
right. If it fails them, the distinction you saw is real but is not the one you
wrote down, **and it may not be mechanical at all.**

When that happens, **pin the artifact rather than widen the rule until it
fits**. A short table of known-good outputs is honest; a rule with carve-outs is
a rule that has stopped meaning anything.

# Why, with the evidence

DR-060 §11.59.10(a) made a signal family's FIRST ALIAS the head of its derived
bank name, so `16 hdmi in` lands in "HDMI Inputs" as docs/06 §4.1's own example
prints it. The command `1 de9 bi` then derived a bank called **"DE9 Ports"**: a
connector shell labelling a signal bank, because `de9` was `ctl.rs232`'s only
alias.

The correction was right. The rule written from it was not:

> no family may lead with a token that names a connector

**It failed on its first run, against `hdmi`**, which names `conn.hdmi_a` AND
`video.hdmi.2_0`, and where "HDMI Inputs" is exactly what the specification
asks for. `rj45`, `c13` and `euro2` are connector names wearing a family's
clothes; `hdmi` is a signal standard the connector was named after. **What
separates them is a fact about English**, and no property of the registries can
see it.

The gate was deleted and replaced with eight commands and the exact bank each
one derives. The failed attempt stays recorded in the test file, so the next
reader does not rebuild it.

# The tell, in hindsight

The rule was written in the same minute the bad case was found, and the comment
justifying it was longer and more confident than the code deserved. That is
worth watching for on its own: on this milestone, three separate errors each
shipped inside an assured explanatory paragraph, including [a keymap note that
stated its own rule backwards](/practices/one-keymap-registry.md). **A paragraph
arguing for a one-line rule is a signal to run the rule, not to trust the
paragraph.**

# What to do

* **Enumerate the passing cases first.** If a proposed invariant would fail
  something already shipped and correct, it is not the invariant.
* **Ask whether the distinction is structural or linguistic.** Vocabulary,
  trade names and display copy are usually the second; those get a pinned table
  and a human decision, never a derived rule. See [trade objections are
  questions](/practices/trade-knowledge-beats-workflow-reasoning.md).
* **Record the disproof beside the replacement.** A deleted gate leaves no trace
  and gets reinvented; a gate whose failure is written down does not.

# Citations

[1] `packages/rackmate_core/test/catalog/signal_family_alias_test.dart`: the
    attempt, and why it was abandoned
[2] `packages/rackmate_core/test/builder/quick_add_test.dart`: the pinned
    artifact that replaced it
[3] canonical-decisions.md §11.59.10(a)
[4] Commit `3947192`
