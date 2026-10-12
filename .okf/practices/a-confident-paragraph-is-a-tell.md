---
type: Practice
title: A confident paragraph is a tell
description: On this project the errors that ship arrive fully argued, inside long assured comments citing the right rulings. When the prose justifying a rule outweighs the code, run the rule against the cases that already work before trusting the paragraph.
tags: [practice, review, comments, gates, m4-g]
timestamp: 2026-10-12T00:00:00Z
status: adopted
---

When an explanatory paragraph is longer and more assured than the code it justifies,
that is the signal to check the code. The mistakes on this project do not arrive as
hesitant guesses. They arrive fully argued, in the house style, citing the right
rulings.

# Four in one milestone (M4-G), each inside a confident comment

- A check that "modifiers do not compose", placed after the branch that swallowed its
  input, so it could never run, beside a paragraph explaining the hazard it guarded.
- An invented invariant, *"no family may lead with a token that names a connector"*,
  gated the minute it was conceived. It failed against `hdmi` on its first run: the
  distinction was English, not structure.
- A keymap note stating `meaningDrift`'s rule **backwards**, while the docstring one
  file over argued the opposite.
- A docstring promising `repair` returned *"the WHOLE pattern, not a fragment"*, while
  three of six sites returned a fragment and a test comment excused them.

The gates caught all four. Nothing about reading the prose did.

# Why

The prose is written from the same reasoning as the code, so it inherits the error and
then makes it look adjudicated. A reviewer reads the confident citation and moves on.

# The rule

Before committing a comment that argues for a rule, **execute the rule against the
cases that already work**. For an invariant that means running the proposed gate over
the passing set first ([a rule you invent must be checked against the good cases](a-rule-you-invent-must-be-checked-against-the-good-cases.md)).
When a test carries an exemption list, widen the loop rather than believing the
exemption ([a test's exemption list is where the bug lives](a-tests-exemption-list-is-where-the-bug-lives.md)).
The same failure in rulings is [a claim about the code is grepped](verify-codebase-claims-by-reading.md).

# Citations

[1] M4-G's chapters on the board; the four defects named above
