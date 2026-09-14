---
type: Practice
title: Count the data before you believe a derivation
description: >-
  "Colour a device by its signal domain" has an obvious implementation: read
  the domains off its ports. A census over the 51 shipped templates found 13
  that answer, and a television that reads as video, audio and network at once.
tags: [practice, derivation, census, g4, dr-169, m6]
timestamp: 2026-09-14T00:00:00Z
---

The user asked for plan marks coloured by what a device IS. The product already
knows a device's ports, each port names a signal family, and each family names a
domain. So the domain is derivable, and no new field is needed.

**It is not, and the numbers are not close.** Of the 51 seeded templates:

| | |
|---|---|
| ports in exactly ONE domain | **13** |
| the same, excluding `pwr`, `ctl` and `str` | 26, and **nine then have none at all** |

A television reads as `(video.digital, audio.analog, net)`. A control keypad,
once the infrastructure domains are excluded to clean up the count, reads as
nothing at all: the excluded ones were all it had.

# Why the derivation was so convincing

**It answers a DIFFERENT question correctly.** A set of port domains is an
accurate answer to *what can be plugged into this*. The question asked was
*what is it*, and the two coincide on exactly the devices anybody checks first:
a patch panel is network, a power amplifier is audio, a splitter is RF. A spot
check of three passes and the rule looks sound.

**And the fix for the first counter-example makes the second one worse.**
"Everything has a power lead and a control port, so exclude those" is the right
instinct and it takes a keypad's only port away. Each repair moves the failure
somewhere less visible.

# What to do instead

**Count before you commit.** The census here is fifteen lines in a throwaway
test and it ran in a second. It replaced an argument with a number, and the
number ended the discussion in both directions: it refused the derivation for
devices AND it showed the outlet recipes nearly work, five of nine, which is
what made the outlet decision a judgement rather than a guess.

**Ask which entity the field belongs to.** The template answers for the device;
the recipe answers for the outlet; the rack answers for neither, because it is
the datum. Three carriers, three lookups, one of them deliberately none.

**And let null mean unknown** (G4/CR-114). An authored field has a real absence:
a blank panel carries no signal at all, a hand-built outlet belongs to no
recipe, a cabling grade is not a service. Those must draw the neutral mark
rather than being assigned the first value in some order.

# The half-truth to watch for

The derivation's defenders will point out that it works for the cases in front
of them. That is the census's whole point: **the population, not the sample.**
The same shape appears wherever a field looks computable from neighbours it
merely correlates with.

# Related

* [A number in a ruling is still a
  measurement](a-normative-number-is-still-a-measurement.md): the same
  discipline pointed at a figure instead of at a rule.
* [Census before building](census-before-building.md).
