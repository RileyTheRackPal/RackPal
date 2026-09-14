---
type: Practice
title: Copy outlives the route it names, and the comments repeating it are the camouflage
description: >-
  `Project ▸ Locations…` appeared eighteen times after the menu holding it was
  deleted. Fifteen were comments, which is why nobody doubted the three that
  were on screen, and each of those three fired exactly when somebody had no
  rooms and needed one.
tags: [practice, copy, routes, census, dr-091, dr-168, m6]
timestamp: 2026-09-13T00:00:00Z
---

DR-091 promoted Locations from a menu item to a tab and deleted the `Project`
menu. The menu went. **The strings naming it did not**, and they were still
there two months later:

* *"This project has no rooms yet. Add one in Project ▸ Locations…"*
* *"Rooms are named in Project ▸ Locations…"*
* *"also named in Project ▸ Locations…"*

docs/04 §3.4's rule is about a control that silently does nothing. **An
instruction that cannot be followed is one step past that**, because the user
spends real time hunting for the route before concluding the software is wrong,
and all three of these fire at the moment somebody has no rooms and needs one.

# Why it survived a rename that touched the whole shell

**A phrase repeated eighteen times reads as vocabulary.** Fifteen of the
eighteen sites were comments explaining why something is the way it is. Any one
of them, read alone, looks like somebody establishing where locations live; a
reader checking a fourth instance finds three more that agree with it. The three
live strings were indistinguishable from the crowd they sat in.

The rename itself is not where to look, either. Deleting a menu is a change to
the menu file, and a careful author checks the callers of what they deleted.
**Copy has no callers.** It is a string sitting in a widget three packages away,
and nothing in the language or the toolchain connects the two.

# What to check

**Grep the SHAPE, not the name.** `▸` is how this corpus writes a menu path and
it appears in no other context, so its presence in a string is the whole signal.
Searching for `Locations` returns hundreds of legitimate hits; searching for the
glyph returns every route the product claims to have, in one screen.

**Split live copy from history, and gate only the live half.** A test that
refuses the phrase everywhere makes it impossible to write down why something
changed. The case here skips any line whose trimmed start is `//`, which keeps
fifteen comments and gates three strings.

**Read the real menu bar rather than a list kept beside it.** A hand-kept list
of route names is the second copy of a moving fact, and it cannot fail the way
this defect happened: the menu was REMOVED. Pumping the app and collecting the
`SubmenuButton` labels costs one `pumpWidget` and notices a deletion the day it
lands.

**And assert the census is non-empty in both directions.** The case checks that
the menu bar was found AND that some copy names a route, because a selector that
silently matches nothing passes over an app whose every route was deleted.

# Related

* [Print the output before claiming copy is
  done](print-the-output-before-claiming-copy-is-done.md): twelve green
  assertions over a line reading `1 ports`. Copy is where green tests are least
  informative.
* [Census before building](census-before-building.md): the same search
  discipline, one artifact over.
