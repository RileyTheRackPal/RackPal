---
type: Practice
title: A full-sized job finds what a fixture cannot
description: The first whole-house sample, built only from the seed catalogue and the product's own connect rules, found six defects that every gate had passed, and each one needed the job's SIZE or its COMPLETENESS to show. Four starters and thousands of tests are small, or they leave the field end unmodelled, and those are exactly the two conditions under which these defects hide.
tags: [practice, samples, fixtures, scale, rel-3, dr-225, dr-008, ac-031, ac-052]
timestamp: 2026-11-18T00:00:00Z
status: adopted
---

REL-3 (`#1292`) built a two-storey residence for the public repository's
screenshots: two racks, 68 devices, 98 cables, two calibrated floorplan pages.
Every cable went through `evaluateConnect` before it was written and none was
refused. The document then exported, and six defects came out of a tree whose
gates were green.

# Two conditions, and the starters meet neither

| Defect | What made it visible |
|---|---|
| `#1293`: a house-sized domain's interconnect sheet stacks every device in one column and prints at 0.65 pt | **Size.** The Digital Video sheet, with six devices, is excellent. Network, with twenty-odd, is unreadable |
| `#1295`: a cable to a placed field device is "class not determined" on the Pull Sheet | **Completeness.** The starters end their home runs at a room, never at the speaker, so the classifier's off-rack branch never ran on a real job |
| `#1296`: A01, "16-channel", drives four stereo rooms | **Completeness.** Nobody had wired eight rooms to it |
| `#1294`: the plan sheet's scale bar prints over its device schedule | **Size.** A schedule long enough to reach the bar |
| `#1297`: "1 runs" | A room with one run, which a dense starter never has |
| `#1298`: a fake content hash on the HDBaseT receiver | Placing a receiver by data rather than by the gesture's happy path |

A fixture is built to prove a mechanism, so it is as small as the mechanism
allows, and it stops where the mechanism stops: at the room, not at the speaker
in it. A product's worst defects live where the mechanisms meet at scale.

# The rule

**Build one job at the size and completeness of a real one, through the
product's own rules, and read every page it exports.** Read them as images, not
as text: four of the six were visible only in a rendered page or screen, and
the export's own notices named only one of them.

The sample is regenerable (`apps/rackpal/tool/generate_sample_residence.dart`),
so it can be rebuilt after a fix and read again. That rebuild is the check; the
first build was the census.

See also [a stated cost is a hypothesis](a-stated-cost-is-a-hypothesis.md): a
claim that a layout "scales" is a measurement nobody has made until a job of
that size exists.
