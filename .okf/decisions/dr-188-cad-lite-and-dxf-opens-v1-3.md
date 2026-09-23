---
type: Design Ruling
title: DR-188 · RackPal is CAD-lite, and DXF interchange opens v1.3
description: >-
  The product description said "not a CAD package", which was the author's sentence and undersold a
  tool that calibrates plans and draws exact elevations. Creates v1.3 as a release band for a DXF
  export, declines DWG on a licence collision, and finds the rack elevation blocker is a missing
  writer rather than a missing schema.
tags: [ruling, positioning, scope, dxf, export, roadmap, v1-3, dr-188, cr-086]
timestamp: 2026-09-23T00:00:00Z
ruling_id: DR-188
canon_section: "11.187"
status: ruled
---

Settled by the user on 2026-09-23, on reading docs/20's claim that the product *"is not a CAD
package"*.

# The positioning, and the reason is the user's

**RackPal is CAD-lite.** The reason is recorded in the user's own words because it is trade
knowledge rather than product opinion: it is *"nearly impossible in this industry to draw precise
technical drawings that won't get altered and/or ignored by the installers"*, since a television
shifts for the furniture and a back box moves because an electrician took the space first, and
documenting every change would be *"unbelievably tedious"*. **So the trade-off in precision is
negligible to the workflow.**

Precision is therefore spent where it survives contact with a site:

| Spent | Withheld |
|---|---|
| Calibrated floorplans, at real-world scale | Symbol positions |
| Rack elevations, exact because RU is discrete | Routing paths |
| Cable footage, a number you order from | Plan pin placement |

**The description this replaces was the author's and was never measured.** It was written to manage
a tester's expectations downward and checked against nothing. This ruling family has now produced
four clauses that were the author's sentences rather than the user's choices, and three of them were
refuted by their own build, which is why
[record the choice, not a manufactured reason](/practices/record-the-choice-not-a-manufactured-reason.md)
exists.

# v1.3 is created, and DXF opens it

A §8.3 amendment, and **the first release band added since the roadmap was written**. It was needed
because v2 is ruled to be *"the next product decision, not the next release"*, and an interchange
export is neither a fast follow nor a new product.

**DXF and not DWG, declined on a licence collision rather than on cost.** The open DWG writer is
GPL-3.0 and would have served; the commercial route is a paid membership and GPL-incompatible, so
native DWG would put the feature in conflict with the project's own licence
([DR-189](/decisions/dr-189-agplv3-and-the-cc0-vendor-door.md)). DXF is Autodesk's documented
interchange format and every CAD tool opens it.

**The ~400 line estimate in docs/08 was never the thing that changed**, and it looks right:
`DiagramCanvas` is an abstract interface with two production backends already, so this is a third,
which is what CR-086's one-display-list rule makes the natural shape. What moved is the VALUE, on
trade knowledge the table did not have when it was written.

# The rack elevation blocker is not what it looked like

The user raised elevations for a cabinetmaker or a GC, from real pain: *"a cabinet was too small for
a pull-out rack, or a closet was shaved down to make space for a mini bar and the rack no longer
fit"*. They expected this to need *"a future schema of the rack templates"* carrying physical
dimensions.

**Measured: that schema exists.** `Rack` declares `overallWidth`, `overallDepth`, `overallHeight`,
`ownWeight`, `hasFrontDoor`, `hasRearDoor`, `frontDoorClearance` and `rearDoorClearance`, and they
serialize.

**Five of the six appear only in `rack.dart` and `json_codec.dart`: no writer, no reader.** Only
`ownWeight` is read, by the rack inspector. So the deliverable is blocked on somewhere to type the
numbers, which is smaller than the export it gates, and it is **the fourth instance of the
`Placement.locked` shape**: a field with no writer is a rule nobody is following.

# What this does not rule

Whether rack elevations join the export, which waits on that writer. **Whether the product should
CHECK a rack against a room's dimensions rather than only draw it**, which is the thing that would
have caught the shaved closet before anybody built it. DWG, permanently or otherwise. DXF layer
names, units and block structure.
