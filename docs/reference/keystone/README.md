# Keystone strap and Decora plate reference

Physical reference for **DR-007 §11.7** (keystone strap geometry, M3).

## What belongs here

Photographs or drawings of the real parts, so that plate rendering is built
against objects rather than against a description of them. The user supplied
a set on **2026-07-28** covering:

* keystone straps — **1, 2, 3, 4 and 6 port** (no 5-port part exists, which is
  the prediction `W ∈ {1,2} × H ∈ {1,2,3}` makes — DR-007 §11.7.1)
* Decora cover plates — **1, 2 and 3 gang**

A second batch followed on the same day covering the **occupants**: Cat6
couplers, an F-type barrel, an HDMI right-angle coupler, a 3.5 mm/IR module,
blank inserts, and a speaker binding post.

All of it is now in this directory.

## What the reference settled, and what it did not

Recorded in full at **DR-007 §11.7.8**. In short:

| | |
|---|---|
| **Confirmed** | the 1/2/3/4/6 port table, the absence of a 5-port part, and 2-wide geometry on the 4- and 6-port straps |
| **Changed** | the Decora cover plate is a separate purchasable part and a separate line item; the cell grid is **centred** in the plate opening, not anchored to an edge |
| **STILL OPEN — needs a caliper, not an inference** | whether a cell on a 2-wide strap is the same size as a cell on a 1-wide strap |

That last row is the one to be careful with. The arithmetic permits a single
uniform cell size, but permitting is not being, and a uniform-cell assumption
that turns out false is wrong on every plate drawing at once. **Measure a real
3-port and a real 6-port before building any dimensioned rendering.**

## Two things to be careful with

**The speaker terminal contradicts the ruling.** The reference binding post is
**one post per keystone** — two separate single-cell modules, red-banded and
black-banded. DR-007 §11.7.2 rules that a speaker terminal spans **two cells
and is orientable**. Both parts exist in the world; which one the shop uses
decides whether the cell model needs multi-cell occupants at all. **Settle it
by looking at the van, not by reading this.** DR-007 §11.7.9 A has the stakes.

**The Cat6 colours mean nothing.** They are what one seller photographed. An
earlier draft of §11.7.9 read green and grey being absent from that lineup as
a catalog constraint and invented an availability-modelling requirement from
it; that was wrong and is retracted in place. Keystones come in every colour
the wire comes in (CR-121). Related: from the front — which is how a plate
elevation draws — a punchdown jack and a coupler are the same object, so the
renderer needs only `(connector type, colour)`.

## Related

* `docs/canonical-decisions.md` §11.7 — DR-007, the ruling
* `docs/07-structure-device.md` — the Structure editor that will host the strap UI
* `docs/12-milestone-board.md` §5.2 — M3, where this work is scheduled
