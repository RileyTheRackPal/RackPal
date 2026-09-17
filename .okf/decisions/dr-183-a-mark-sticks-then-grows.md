---
type: Design Ruling
title: DR-183 · A plan mark sticks at a floor size and grows with the plan above a crossover
description: >-
  The canvas drew a plan mark at a constant 7 points at every zoom, which is DR-169 §11.168.2. The
  user asked for a bigger mark that also grows with the underlay once you zoom past a threshold. The
  radius is now the larger of an 11-point floor and 1/200 of the plan, which supersedes §11.168.2 in
  part and keeps its agreement clause untouched.
tags: [ruling, plan, canvas, appearance, zoom, dr-169, dr-183]
timestamp: 2026-09-17T00:00:00Z
ruling_id: DR-183
canon_section: "11.182"
status: built
---

Ruled by the user on 2026-09-17 on board `#910`.

# The report, and the number it did not contain

*"We need to increase the site view pin size a bit; I feel like it should 'stick' at a certain size
below a certain zoom level ... zooming out it stays physically this size, zooming in it should grow
relatively in size to the room plan underlay."* It arrived with a screenshot showing the minimum
size.

**The screenshot yields no number.** It is a crop at an unknown zoom of a plan whose pixel dimensions
are unknown, so nothing in it converts into points. That is recorded rather than worked around,
because a request that arrives WITH an example is exactly the one where a measurement feels
available and is not.

# What was measured

- `plan_canvas_screen.dart` computed `kPlanMarkerRadiusPt / viewport.scale`: **a 7-point radius on
  screen at every zoom from 5% to 3200%**, by construction rather than by measurement.
- That is [DR-169](/decisions/dr-169-a-plan-mark-says-what-it-is.md) §11.168.2, whose own words were
  *"the proportional rule is retired, not re-tuned"*.
- §11.168.10 had already measured the underlay's longer side as an anchor, on paper: 6.87 points on
  a 2000x1500 plan, 5.15 on 1500x2000, 10.20 on a 4000x1000 panorama, from one fraction.

# What was ruled

- **The radius is `max(11 points / scale, (1/200) x planSize)`** in scene units. Constant on screen
  below the crossover, a fixed piece of the drawing above it.
- **The floor rose from 7 to 11 points**, chosen from three sizes drawn at actual size. Eleven is
  where the domain glyph inside the mark becomes readable.
- **The plan's size is the geometric mean of its two sides**, not the longer one. The one clause the
  user did not choose, taken on §11.168.10's measurement.
- Refused: **1/100**, which is within rounding of the retired 1/110 and would reach four times the
  floor at four times the fitted zoom, the size the original complaint was about. And **1/300**,
  which barely grows before somebody is inside one room.
- The PRINTED mark and the line weight are untouched: a sheet has no zoom to cross a threshold with.

# Built

`#910` landed it on 2026-09-17. The rule, the two constants, the hover label's own radius, six cases
and the test floor.

**IT SUPERSEDES §11.168.2 IN PART, WHICH IS WHY IT HAS AN ID.** `#904` and `#905` each ADDED a clause
to DR-169 without contradicting one, so each became §11.168.10 and §11.168.11. This one changes what
§11.168.2 decided, so it is a ruling and appears at canon §12.36. **The half that survives is the
half nobody was complaining about**: one place computes the radius per surface, and the drawn mark
and the hit box are the same figure at every zoom. DR-183 changes the size and never the agreement.

**A CONSUMER THAT WAS NOT A SCENE.** `PlanPinBubble` takes the mark's radius in SCREEN points so the
hover label clears it, and it was handed the constant. Correct while the constant WAS the screen
radius; silently wrong the moment it stopped being. At 16x on the test fixture the label would have
lifted by 37 points off a mark measuring 39, sitting inside the dot it names and worse the further
in somebody zoomed. No case in the file read its position.

**THE MUTATION RUN FOUND A VACUOUS PASS, WHICH IS WHAT IT IS FOR.** Three mutations were run against
the six new cases. Replacing the `max` with the floor term alone left the aspect-ratio case GREEN,
because two marks both sitting on the floor agree for a reason that has nothing to do with the
anchor. It gained a guard asserting the anchored term is the one in play. A mutation run that only
ever confirms a green is a mutation run nobody needed.

**AND A TEST TITLE OUTLIVED ITS RULE BY ONE RULING.** `AND IT NO LONGER DEPENDS ON HOW BIG THE PLAN
IS` was true under §11.168.2 and is half true under DR-183, so it now reads `AND BELOW THE CROSSOVER
IT DOES NOT DEPEND ...`. The case passes either way, which is the danger: a title that overclaims is
how a suite ends up asserting a defect, and nothing red ever announces it.
