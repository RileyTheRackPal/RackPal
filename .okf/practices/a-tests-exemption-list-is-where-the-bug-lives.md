---
type: Practice
title: A test's exemption list is where the bug lives
description: When a check covers some cases and a comment explains why the others are exempt, the comment is the lid. Widen the loop; the exemption was written to make a defect look intentional.
tags: [testing, gates, verification, m4-g, m4-h]
timestamp: 2026-08-15T00:00:00Z
status: adopted
---

**When a verification loop covers a subset and carries a comment explaining
why the rest are exempt, widen the loop before trusting the comment.** The
exemption is not usually a lie. It is usually an accurate description of a
defect, written by someone who mistook it for a design.

The related, cheaper form: **assert what a refusal SAYS, not that a refusal
happened.** "It errors" is satisfied by erroring for the wrong reason.

# Why, with the evidence

## The chip loop that checked two of twelve

`LabelPatternFailure.repair` carries the suggested fix a surface renders as a
one-click chip. Its class docstring promised, in those words, *"the WHOLE
pattern with the fix applied, not a fragment, so accepting it is one click and
never a merge."*

Three of its six failure sites returned a bare token instead. The gate said:

> **only whole-pattern repairs are checked; fragment repairs are the token to
> substitute and are asserted above.**

That sentence is true, and it is the bug's obituary written in advance. The loop
tested the two cases that happened to satisfy the docstring and excused the
three that did not. Widening it from two inputs to all twelve failed
immediately, and on a case nobody had considered: the chip for `{L,}` was
`{L}`, **which does not parse**, because a braced token with no comma is read as
a token NAME. The chip handed the user a second error.

This is [a stated difference the code does not
make](/practices/a-modelled-field-is-not-a-reachable-one.md) one layer out. The
usual form is a comment explaining a distinction the code does not draw; this is
a TEST explaining why a promise is only half kept.

## The refusal that refused for the wrong reason

The same file bans composing two pattern modifiers, because roadmap §2 names
generalising that grammar as M4's scope hazard. `{n@2:2}` was duly refused, and
a test asserting "this is refused" passed.

The check was unreachable. It sat after the branch that swallowed the input, so
`{n@2:2}` matched `n@`, failed `int.tryParse("2:2")`, and reported **"A repeat
count must be a whole number, not `2:2`"**: a true sentence about the wrong
problem. Only an assertion on the MESSAGE could see it.

A designed-error system (AC-050/A2.4) makes this sharper than usual: when the
sentence IS the product, a test that ignores the sentence is not testing the
product.

## And the same shape at the top of the milestone

M4-G's bank derivation asserted, at the parse level, that three `@Control` steps
each yielded the string `Control`. They did, and it was green throughout a
defect that produced **Control, Control 2 and Control 3** and a template with
eight banks against an exit criterion that says six. Building the ports and
counting the banks caught it in one line.

Three instances, three layers: a chip, a message, a count. In all three the
narrow check was green and the wide one was red on the first run.

## And the widest form: a property, where an example would not do

M4-G's field mode needed a plan rendered back to a command. The gate written
for it was not an example but a PROPERTY: `parse(render(p)) == p`, over every
command the milestone's worked example types. It failed on the first run and
the bug was in the PARSER, not the renderer: the first type token's family
DEFAULT occupied the connector slot, so `16 speaker euro2 out` authored a
binding post rather than a euroblock.

**Nothing written by hand had covered that**, because nobody writes the command
that exposes it. A round-trip property enumerates its own cases.

# What to do

* **Loop over the whole set the property claims to hold for.** If the property
  is "every repair chip parses", enumerate every failure the parser can
  produce, not the ones convenient to construct.
* **When you write an exemption, treat it as a bug report.** Either the exempt
  cases satisfy the property and the loop should include them, or they do not
  and the code is wrong. There is no third case; "these are different" is what
  the comment always says.
* **Assert the sentence, not the severity.** For anything with designed errors,
  pin the message and the span. A test that only checks that something was
  refused cannot tell a correct refusal from a lucky one.
* **Where a round trip exists, gate the round trip.** `parse(render(x)) == x`
  and `write(read(b)) == b` (CR-117 is the same idea on the file format)
  enumerate cases nobody would think to write, which is exactly the set a
  hand-written example misses.

# Citations

[1] `packages/rackpal_core/test/builder/label_pattern_test.dart`: the widened
    loop, and the two cases it found
[2] `packages/rackpal_core/lib/src/builder/label_pattern.dart`: the
    one-value-set repair, and the reachability comment on the composition check
[3] `packages/rackpal_core/test/builder/quick_add_test.dart`: the bank count
[4] `packages/rackpal_core/test/builder/quick_add_test.dart`: the
    render/parse round trip
[5] Commits `70d4fc5`, `c57c6b1`, `2a8180c`
[6] [Assert the artifact, not the
    mechanism](/practices/assert-the-artifact-not-the-mechanism.md), of which
    this is the failure mode from the other side
