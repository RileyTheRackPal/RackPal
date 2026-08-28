# M4-R: the mark legibility check, on paper

**Board `#757`. DR-059 §11.58.5, DR-083 §11.82.1, AC-054.**

This is the half of M4-R that no assertion in `rackpal_core` can perform. Everything else about the
seventeen marks is gated: they all resolve, they all draw, each is a distinct drawing, every seeded
template reaches one, the ink flips on a dark accent, and the elevation emits exactly one mark per
device. **None of that says whether a person can tell them apart.**

> **The question, stated once.** DR-059 capped the set at seventeen because *"the mark draws 1U tall
> on a greyscale photocopy"* and a forty-way silhouette distinction is unreadable at that size.
> DR-083 then placed the mark **inline at cap height on the designator line**, which at the shipped
> 11 pt designator is about **8 pt** of drawing. **Is seventeen still the right cap at 8 pt?**

---

## 0. What you need

A printer. Ideally the ANSI B laser M6's exit criterion names (AC-054), because that is the machine
that will decide this eventually. **A domestic laser or inkjet is worth doing first anyway**: if the
marks fail on a good printer they will not improve on a bad one.

A photocopier, or a printer with a copy function, for step 4. This is the condition DR-059 sized the
set against and it is the one most likely to fail.

---

## 1. Print an elevation

1. Launch RackPal. `File ▸ Open` and choose `whole_house.rmpj` from
   `apps/rackpal/assets/starters/`. It is the densest starter and it draws the widest spread of
   marks.
2. `File ▸ Export PDF…`. Save anywhere.
3. Open the PDF, find the elevation sheet, and print **that page only**, at **100%** scale. Do not
   let the print dialog "fit to page": the whole point is the size the mark actually prints at.

---

## 2. Read it cold, before looking at any list

**Do this before step 3 and do not skip the order.** Knowing the answers makes the marks legible in
a way a stranger's eye will not reproduce.

Look down the rack and, for each device, say out loud what the mark is a picture of. Not which
device it is: what the **shape** is. A switcher is a box with a cross; a patch panel is a shallow box
with four ticks; a speaker is a cone.

**Write down every mark you cannot name, and every pair you had to compare side by side.**

---

## 3. Check the four neighbourhoods the artwork already suspects

`device_glyph_art.dart`'s header names these, in the order they are most likely to collide. They are
recorded there rather than discovered, because *"look at all seventeen"* is not a test.

| # | The neighbourhood | What to look for |
|---|---|---|
| 1 | **The round family**: `camera`, `control`, `power` | Three marks whose outer stroke is a curve. Do the two concentric rings of `camera` stay two rings, or close into a blob? |
| 2 | **The box family**: `matrix`, `switcher`, `processor` | Identical outlines differing only inside: a plus, a cross, an inner box. At 8 pt does the interior survive at all? |
| 3 | **`amplifier` versus `source`** | The same right-pointing triangle, hollow and solid. **Fill is the only difference** and a photocopy is what flattens fill |
| 4 | **`blank` and `shelf` on a hatched body** | The only marks drawn over ink rather than over the body fill. Does DR-083's knocked-out panel actually clear the 45° lines, or does the mark still sit in a thicket? |

---

## 4. Photocopy it

Copy the printed page once, on the worst setting you would tolerate on a job site. Then re-read
step 2 **on the copy**.

This is the condition the whole seventeen-mark cap was chosen for, and it is the step most likely to
produce a finding.

---

## 5. What would refute it

Any of these is a real result and worth reporting rather than working around:

- **Two marks in one neighbourhood are indistinguishable at 100% on a good printer.** Redraw the
  weaker one. The set does not shrink: DR-059's cap is a ruling and a legibility failure is an
  argument about *artwork*, not about the count.
- **A mark is legible on the print and gone on the copy.** Same remedy, and note which channel died,
  fill or stroke.
- **The mark crowds the designator**, or the text now starts too far right on a narrow device. That
  is DR-083 §11.82.1's placement, and the answer is the cap-height factor
  (`kDeviceGlyphCapFactor`), not a new drop rule.
- **The mark is too small to be worth its space at all.** That is the strongest possible finding
  and it reopens DR-083's rejected alternative, a larger mark on the right, which was declined on
  cost rather than on merit.

**What is NOT a refutation**: a mark you cannot name but can tell apart from its neighbours. The mark
identifies a device against the devices beside it. It is not a pictogram anybody has to read cold,
which is what the designator is for.

---

## 6. The verdict

Record in `docs/12` §5.3 and in the closing commit:

- the printer and the paper size;
- whether the copy step was performed, and on what;
- every mark redrawn, and why;
- and, if the cap survived, **say so explicitly**: *"seventeen marks, read at 8 pt on \<printer\>,
  and the four suspect neighbourhoods held"*. A drill that passes and is not written down is a drill
  that will be run again.

---

## 7. The run, 2026-08-28: CONFIRMED

**Performed by the user. Board `#757`, closing `#694`.** The cap survives:
**seventeen marks, read at 8 pt off an ANSI B plot, and the four suspect neighbourhoods
held.** No mark was redrawn.

| Condition | What it was |
|---|---|
| Printer | **HP DesignJet T790**, at 100% scale, no fit-to-page |
| Paper | **ANSI B**, which is the size AC-054 names |
| Copy step | **Performed**, on a Brother mono laser, from a section cut out of the plot |
| Marks redrawn | **None** |

**THE PLOTTER IS AN INKJET AND THE COPY IS WHERE THE TONER CAME FROM**, which is the
one thing about this run a later reader must not lose. §0 asks for the ANSI B laser
because that is the machine M6 will decide this on. A DesignJet lays down ink, not
toner, and ink spreads at a stroke edge where toner does not, so the original plot is
the SIZE condition met and not the LASER one. The laser condition was met by the
photocopy, whose output is toner by construction, and which is also the harsher of the
two: DR-059 capped the set at seventeen against the photocopy specifically.

So the run answers the question DR-059 asked. **What it does not do is discharge
AC-054's ANSI B laser print**, which M6 still owes and which `M6-J`'s print matrix
(`#357`) still has to perform. Naming that here rather than in `docs/12` alone, because
this is the file somebody reads before deciding whether to run it again.

**THE COPY WAS OF A CUT SECTION, NOT THE WHOLE SHEET.** A section carrying enough
devices to read was cut from the plot and copied, which is the sensible way to get an
ANSI B plot through a Letter copier and is exactly what a person would do. It does mean
the copy limb covered the marks in that section rather than all seventeen. The verdict
above is the operator's, on the neighbourhoods §3 names; a later run that wants
whole-sheet copy coverage would need a copier that takes ANSI B, which is M6's machine
and not this one.

**WHAT WOULD REOPEN THIS.** §5's refutation list, unchanged. A mark that dies on a copy
at a size this run did not reach is still a real finding, and the cap is not the thing
that would move: DR-059's seventeen is a ruling, and a legibility failure is an argument
about artwork.
