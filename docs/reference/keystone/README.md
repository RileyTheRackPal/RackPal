# Keystone strap and Decora plate reference

Physical reference for **DR-007 §11.7** (keystone strap geometry, M3).

## What this was, and why the pictures are gone

Photographs and drawings of the real parts, gathered so that plate rendering
is built against objects rather than against a description of them. The user
supplied a set on **2026-07-28** covering:

* keystone straps, **1, 2, 3, 4 and 6 port** (no 5-port part exists, which is
  the prediction `W ∈ {1,2} × H ∈ {1,2,3}` makes, DR-007 §11.7.1)
* Decora cover plates, **1, 2 and 3 gang**

A second batch followed on the same day covering the **occupants**: Cat6
couplers, an F-type barrel, an HDMI right-angle coupler, a 3.5 mm/IR module,
blank inserts, and a speaker binding post.

**The files themselves are no longer in the repository, in any version.**
They were retailer product photographs and manufacturer drawings, which the
project has no right to redistribute, and DR-259 §11.258.2.2 removed them from
every commit before the source went public. What they established is recorded
below and in DR-007 §11.7.8, which is what the work needs. The sources, by
name: product listings from several retailers; the On-Q decorator strap sheets
(WP3411 to WP3414); a Hubbell keystone frame drawing (C773248); and RJ45 and
F-type connector drawings, all from their manufacturers' public sites.

## What the reference settled, and what it did not

Recorded in full at **DR-007 §11.7.8**. In short:

| | |
|---|---|
| **Confirmed** | the 1/2/3/4/6 port table, the absence of a 5-port part, and 2-wide geometry on the 4- and 6-port straps |
| **Changed** | the Decora cover plate is a separate purchasable part and a separate line item; the cell grid is **centred** in the plate opening, not anchored to an edge |
| **STILL OPEN: needs a caliper, not an inference** | whether a cell on a 2-wide strap is the same size as a cell on a 1-wide strap |

That last row is the one to be careful with. The arithmetic permits a single
uniform cell size, but permitting is not being, and a uniform-cell assumption
that turns out false is wrong on every plate drawing at once. **Measure a real
3-port and a real 6-port before building any dimensioned rendering.**

## Two things to be careful with

**The speaker terminal already overturned a ruling.** The reference binding
post is **one post per keystone**, and the user confirmed the shop uses
single-post keystones, **one per conductor**. DR-007 §11.7.2 had ruled that a
speaker terminal spans two cells and is orientable; it is superseded. **Every
occupant is now 1 × 1**: no orientation, no packing, no refusal message.

That ruling was written from a verbal description and picked the expensive
branch of a fork it did not know it was on. The photograph is what caught it.
Consequence worth knowing: a 16/4 speaker run is four conductors, so four
posts, so **four cells**: it does not fit on a 1-, 2- or 3-port strap.

**The Cat6 colours mean nothing.** They are what one seller photographed. An
earlier draft of §11.7.9 read green and grey being absent from that lineup as
a catalog constraint and invented an availability-modelling requirement from
it; that was wrong and is retracted in place. Keystones come in every colour
the wire comes in (CR-121). Related: from the front, which is how a plate
elevation draws, a punchdown jack and a coupler are the same object, so the
renderer needs only `(connector type, colour)`.

## Third batch, 2026-08-09: manufacturer drawings and a supplier palette

A `technical drawings/` folder held vendor drawings for the 1, 2, 3, 4 and 6
port straps plus the RJ45 and F-type connectors, and a palette folder held one
supplier's finish range. Both left the repository with the photographs.

**Had they been read with the Read tool, they would have said nothing.** The PDFs were vector
with the text converted to outlines, so they carried **no extractable strings**:
a text extractor returned zero runs, and they were read by rendering with
`pypdfium2` (`pdf[0].render(scale=8).to_pil()`). Incidentally that meant **pdfium read
them fine**, which is a small corroboration of DR-029's costing, since pdfium
is the rasteriser that ruling names for the Plan view.

### What the drawings state

| Fact | Value | Source |
|---|---|---|
| **Keystone opening**, 6 places, all identical | **0.575 × 0.676 in = 14.605 × 17.17 mm** | Hubbell C773248 |
| The opening is a **standard**, not a vendor choice | *"STANDARD NEMA RECTANGULAR OPENING (WD60S2)"* | Hubbell note 2 |
| 6-port frame envelope | 1.450 × 4.058 × 0.375 in | Hubbell |
| Screw centres | 0.750 across, 3.812 up | Hubbell |
| Opening window height | 2.730 in for three rows | Hubbell |
| On-Q strap envelope, 1 and 3 port | 1.7 × 4.2 × 0.4 in | WP3411, WP3413 |
| On-Q strap envelope, 4 port | **1.6** × 4.2 × 0.4 in | WP3414 |
| On-Q finishes | Ivory, Brown, Black, Almond, Light Almond, White | every On-Q sheet, note 5 |

**Use the Hubbell sheet for anything dimensioned and the On-Q sheets for shape
only.** Hubbell is `SCALE 1/1` with a tolerance block (`.XX = ±.01`,
`.XXX = ±.005`, `.XXXX = ±.0025`); the On-Q sheets are `SCALE: NONE` with
one-decimal dimensions. The 1.6 against 1.7 between the On-Q 4-port and its
1- and 3-port siblings is inside one-decimal rounding and **must not be read
as a real 1-wide/2-wide difference** without a dimensioned source.

### THE OPENING IS NOT THE NOSE, and both numbers are right

DR-028 rules the occupant cell as the **front nose** at 14.5 × 16 mm. The
drawings give the **opening** at 14.605 × 17.17 mm. These measure different
things and neither corrects the other:

* the widths agree to **0.1 mm**, which is side clearance;
* the opening is **1.17 mm taller**, which is where the latch tab lives.

The nose sits *inside* the opening. A renderer needs both: the **opening** to
cut the plate, the **nose** to draw the occupant. Only one of them was ruled.

### What this does to §11.7.8 change 3

Change 3 asks whether a cell on a 2-wide strap is the same size as one on a
1-wide strap, and demands a caliper rather than an inference. What arrived is
better than a caliper and worse than two of them: **a standards citation**.
The opening is `WD60S2` and every strap here says *"ACCEPTS KEYSTONE STYLE
INSERT"*, so a jack from any vendor must fit any strap and the opening cannot
vary by port count. That explains *why* they are the same rather than
observing that they are.

**It is one dimensioned part, though.** The On-Q straps do not dimension their
openings at all, so this is a standards argument corroborated by a single
measurement, not the two-part comparison change 3 asked for. Whether that
closes it is a ruling and has not been made.

### The palette is PER PART TYPE, and it mixes two different axes

| Part | Colours |
|---|---|
| Plates | 6: Almond, Black, Brown, Ivory, Light Almond, White |
| Straps (1, 2, 3, 4, 6 port, and Blank) | **4**: Black, Brown, Light Almond, White |
| RJ45 keystones | **12** |
| F-type keystones | 5: Black, Brown, Ivory, Light Almond, White |
| HDMI keystones | **2**: Light Almond, White |
| Speaker terminals | one image, no colour split |
| `Straps/CED` | CED 130 and CED 135, a cable-entry part the model has no concept of |

Two things to be careful with before any of this is seeded.

**Strap finishes are a SUBSET of plate finishes.** Straps come in four and
plates in six; there is no Almond or Ivory strap. A model that assumes one
finish list covers both parts is wrong on two colours.

**The RJ45 list is two axes wearing one name.** Five of its twelve are
*finishes* shared with the other parts (Black, Brown, Ivory, Light Almond,
White). The other seven (Blue, Green, Grey, Pink, Purple, Red, Yellow) are
*identification* colours, which is what M3-H/3 means by *"the keystone follows
the CONVENTION colour"*. An F-type jack has the five and none of the seven,
because nobody colour-codes a coax barrel by service.

**And this does not reinstate availability modelling.** The retraction above
still stands: CR-121 says keystones come in every colour the wire comes in, and
that was ruled after an earlier draft read one seller's photograph as a catalog
constraint. A supplier's range is a **palette source**, giving real finishes to
render rather than invented ones. Whether it also *bounds* what a user may pick
is a different question, the user has said the range "should suffice for v1",
and no ruling has been made.

## Related

* `docs/canonical-decisions.md` §11.7, DR-007, the ruling
* `docs/canonical-decisions.md` §11.27, DR-028, the 14.5 × 16 mm front nose
* `docs/07-structure-device.md`, the Structure editor that will host the strap UI
* `docs/12-milestone-board.md` §5.2, M3, where this work is scheduled
