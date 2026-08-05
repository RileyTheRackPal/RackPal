# Domain-Realism Review: RackMate
### Reviewer: 20 years racking A/V. I have pulled the wire. I have been the guy in the attic at 9pm with your PDF.

There is real domain knowledge in these documents. Whoever wrote them knows that HDBaseT into a switch port is the money bug, that IR emitter jacks and receiver jacks are not interchangeable, that a 24-port patch panel eats rear RU, that a 92 lb UPS kills a wall rack, that EIA-310 hole spacing is 0.25/0.875/1.50 within the U, and that the "Study/Office/Room 3" naming failure is what makes as-builts worthless. That is more than most of this category ships with.

It also reveals, repeatedly, that the authors have designed a **rack drawing tool** and mistaken it for a **job tool**. The rack is maybe 20% of the work. The findings below are ordered by how fast they'd make me close the app.

---

## BLOCKERS

### B1. You cannot produce a pull sheet before the design is finished. That is backwards from how the job runs.

**What's wrong.** `I-25` requires every conductor's endpoints to resolve to live ports on exactly two devices. `ux-schematic §2.3` states it explicitly: *"loose wires are prohibited by the system... Drop on empty canvas → revert to the original port."* So a cable cannot exist unless both ends terminate on a modeled port on a modeled device.

**The scenario.** It is February. Drywall goes up in three weeks. I have a floor plan, a rough scope, and a check. I do not have a matrix model, I do not know if the client is getting the 8×8 or the 16×16, and the AV designer has not picked speakers. What I need *today* is a pull sheet: 4 Cat6 to the living room, 2 RG6, 2 runs of 16/4 to the ceiling, one 22/4 to the keypad box, one Cat6 to the attic for an AP, six Cat6 to camera locations, one Cat6 to the projector location "somewhere on that beam." Half of those runs will terminate on gear that does not exist yet, and four of them will end up coiled in a J-hook forever.

Your model represents *some* of this via `StructureDrop`, but only for runs that originate at a Structure device. It cannot represent "pull a Cat6 from the rack to the projector shelf and leave a 15' service loop," because the projector is not a device with a port. It cannot represent a spare conduit pull string. It cannot represent the run to the gate operator that the low-voltage sub is pulling.

**Why this is a blocker and not a major.** The pull sheet is the *first* deliverable and the one that costs real money when it's wrong. A tool that requires a complete equipment list before it will emit a cable list is a tool I use at the *end* of the job, at which point I have already produced the same information in Excel and I am not going to re-key it.

**Fix.** Allow a `Link` endpoint to be an **unbound terminus**: `sealed class Endpoint { PortEndpoint | LocationEndpoint | FreeEndpoint }`. A `LocationEndpoint` carries a `locationId`, a free-text description ("proj shelf, beam 3"), an intended termination type, and a service-loop length. It schedules, it prints, it gets a W number and a label. When the device eventually exists, "bind this endpoint to a port" is a one-click command that preserves the ID, the length, and the test result. Add `LinkStatus.designIntent` distinct from `planned`. Your DRC then has something honest to say: `LNK-020 advisory: 14 links have unbound endpoints`, which is a checklist, not an error.

---

### B2. One physical home run is modeled twice, with two lengths, two statuses, and two test results.

**What's wrong.** `§3.8`: "Termination into the rack is a normal `Link`. `StructureDrop.terminatesAtPortId` is a denormalized convenience cache; the source of truth is a Link from the drop's Port to the patch panel's rear Port."

So the Cat6 from the living room to PP-1 R12 is: a `StructureDrop` carrying `media`, `jacket`, `gaugeAwg`, `actualLength`, `terminationRack`, `terminationField`, `status`, `test`, `reelId`, `polarity`, **and** a `Link` carrying `media`, `jacket`, `gaugeAwg`, `calculatedLength`, `cutLength`, `slackPercent`, `status`, `test`, `installedBy`, `terminatedAt`.

**The scenario.** My trim tech certifies the run: 78 ft, 4.2 dB headroom, cert FLK-0114-012. He enters it. On the drop, or on the link? Both? Now the drop schedule (sheet T6.03) says LR-TV-1A is 78 ft and the wiring schedule (T6.02) says W044 is 90 ft, because someone typed an estimate into the link three weeks ago. Which one does the GC bill against? Which one do I hand to the guy ordering cable?

This is not a theoretical divergence. It is guaranteed within one week of real use, and it is the exact failure that makes people stop trusting the document.

**Fix.** A home run is one object. Make `StructureDrop` **be** the Link, give `Link` an optional `structureOrigin` describing the field end (room, outlet, wall, height AFF, field label, field termination), and delete the `StructureDrop` entity. The `StructureBundle` stays as a grouping over Links. The Structure device's "port" becomes a rendering of the link's field endpoint, not a separate entity that owns a duplicate of the cable's physical facts. One row, one length, one cert, one status.

---

### B3. The power DRC will fire on every correctly designed theater rack and block export.

**What's wrong.** Three things compound:

1. `PWR-001` is an **error**: `Σ continuous nameplate amps on a circuit > 80% of breaker`.
2. `ux-rack §5.1`: *"Breaker math uses nameplate."*
3. `ProjectSettings.blockExportOnErrors` defaults **true**, and `ux-rack §5.2` says *"Errors are not dismissible."*
4. `power.isContinuousLoad` defaults **true** for anything in an A/V rack.

**The scenario.** Take your own catalog. A02 16-channel amp (800 W nameplate) + A08 stereo amp (900 W) + A03 AVR (750 W) + N02 switch (450 W) + V02 matrix (90 W) = 2,990 W = 24.9 A on 120 V. On a 20 A circuit the continuous limit is 16 A. I am 55% over. Your app says error, non-dismissible, no PDF.

That rack is fine. It has been fine in ten thousand houses. Amplifier nameplate is a thermal/UL rating that assumes all channels driven to clipping into rated loads simultaneously, which never happens and would be unlistenable if it did. Every integrator alive sizes AV circuits on typical draw with headroom, and every amp manufacturer publishes a "typical" figure precisely because nameplate is useless for this.

You already have `typicalWatts`. You explicitly chose not to use it for the number that matters.

**Compounding gap: there is no power factor or VA anywhere in the model.** `amps = watts / 120` appears in `ux-rack §5.1`. A linear-supply power amp runs PF 0.6–0.7. Your P07 UPS is described in prose as "1500 VA / 900 W" but the model has no VA field, so you cannot compute whether the amps will actually start on that UPS, and you will under-report current draw by 30–40% on exactly the gear where it matters. This is the classic way to trip a breaker on a system that "calculated fine."

**Fix.**
- Breaker math uses `typicalWatts` with a configurable diversity factor per category (amps default 0.35 of nameplate; switches 1.0; UPS 1.0). Nameplate becomes an *advisory* second line: "worst-case nameplate 24.9 A, verify with a clamp meter at commissioning."
- Add `apparentVA` and `powerFactor` to `PowerProfile`. Circuit loading uses VA. UPS capacity checks use VA against VA, not W against W.
- `PWR-001` becomes a **warning** with a mandatory acknowledgement note that prints. `blockExportOnErrors` defaults **false**. An integrator who cannot print a drawing because your heuristic disagrees with him will not use your tool; he will use Visio, and he will be right to.
- Resolve the contradiction: `data-model §3.5` says errors are acknowledgeable and only 5 rules block; `ux-rack §5.2` says errors are not dismissible. Pick the data-model version. It's correct.

---

### B4. The seeded catalog has no field devices. There is nothing to plug the other end into.

**What's wrong.** 62 templates. Every one of them lives in or near the rack. The catalog has zero: displays, projectors, screens, speakers (in-ceiling, in-wall, LCR, subwoofer, outdoor, 70 V pendant), cameras, NVRs, wireless access points, touchpanels, keypads, volume controls, IR receiver eyes, doorbell/intercom stations, gate operators, wall plates, floor boxes, bulkhead panels, ground blocks, OTA antennas, or, most conspicuously, **the ISP-furnished modem/ONT/gateway that is physically present in every single residential rack in North America.**

Your own `refdesPrefix` seed list in `ux-rack §7.2` names `DISP`, `PROJ`, `CAM`, `KP`. The designers knew. The catalog doesn't ship them.

**The scenario.** I drag in the A02 16-channel amp because that's the demo. It has 16 speaker outputs. Now I want to wire zone 1 to the living room ceiling pair. There is no speaker in the catalog. I go to the device builder, and building a two-terminal in-ceiling speaker requires me to fill in occupancy, mount method, width class, chassis depth, weight, thermal class, power profile, and clearance requirements, for a thing that hangs in a ceiling.

Worse: you wrote `ELE-004` (parallel low-Z below amp minimum impedance), `ELE-005` (70 V tap sum vs amp rating), and `ELE-006` (CV speaker on a low-Z output). **None of these rules can ever fire**, because the impedance and the tap wattage live on the speaker, and speakers don't exist in your model. You built the three most valuable audio rules in the product and then didn't ship the object they operate on.

**Fix.** Add a **Field Devices** category, ~25 templates, all `mountMethod: notInRack`, occupancy zero, with a *stripped* builder form (identity, ports, location, no RU, no rack depth, no thermal class). Minimum set: display, projector, projection screen (it has a trigger and a power feed), in-ceiling speaker pair, in-wall speaker, subwoofer (line + power), outdoor speaker, 70 V pendant/landscape speaker with a tap selector, IP camera, NVR, wireless AP, touchpanel, keypad, volume control, IR receiver eye, doorbell station, ISP gateway/ONT, OTA antenna, F-type ground block, wall plate (parametric: N keystones), floor box, structured media enclosure. Give the speaker templates real `impedanceOhms` and a `tapWatts` selector list so your own audio rules have something to chew on.

---

### B5. Patch cords will bury the wiring schedule.

**What's wrong.** Every `Link` is one schedule row with a `W###` designator, a media type, a jacket rating, a cut length, a slack percentage, a status, a test result, and an installer name. A 24-port patch panel patched to a 24-port switch is 24 rows. Add the second panel and the AV switch and you're at 60 rows of "6 in Cat6 patch cord, blue" before a single field cable appears.

**The scenario.** I hand the installer a 180-row schedule. 110 of those rows are factory patch cords out of a bag. He stops reading at row 20. The 70 rows that describe actual cable he has to pull are now indistinguishable from the noise.

Nobody schedules patch cords. Nobody labels patch cords with a W number. Patch cords are a BOM line item ("48 × 1 ft Cat6 patch, assorted colors"), not a cable schedule row.

**Fix.** Add `Link.class: fieldCable | jumper | powerCord | internal`. Default it from context: both endpoints in the same rack and length under 2 m and media is a factory assembly → `jumper`. The wiring schedule excludes `jumper` and `powerCord` by default (toggleable). Jumpers roll up into the BOM by media + length + color. The netlist and the trace path still include them, they're real, they just don't belong on the pull sheet. Same treatment for IEC power cords: PDU outlet assignments belong on the power schedule as an outlet map, not as 20 cable rows.

---

## MAJOR

### M6. One cable cannot carry more than one service. This is bread-and-butter CI.

**What's wrong.** `Link` has a single `media` and its `Net` has a single `signalFamily`. `StructureDrop` has a single `signalFamily`, and `I-37` enforces that it appear in the media's `supports` list. `Conductor` has a `role` string and a `pairNumber` but no signal family of its own.

**The scenario.** One Cat5e from the rack to the TV location carries, on separate pairs: an IR emitter run, a 12 V trigger, and an RS-232 to the display. This is completely routine, it's why people pull Cat5e to TV locations that already have HDBaseT. Another one: 16/4 to a ceiling location carrying one speaker pair plus a spare pair used later for a 12 V trigger to a motorized screen. Another: a spare pair in the 22/4 keypad run repurposed for a door contact.

Your model forces this to be three separate Links on one physical cable, which then produces three pull-sheet rows for one pull, three lengths to keep in sync, and a `TOP-002`/`I-25` fight when you try to give them the same designator.

**Fix.** Move `signalFamily` from `Link` down to `Conductor` (or to a `ConductorGroup` between them), and make `Link.signalFamily` a derived *dominant* value for coloring. Add `Link.services: List<{signalFamily, conductorRoles[], label}>`. The schedule row shows the cable once with a services sub-line: `W044 | Cat5e | 62 ft | LR-TV | IR (pr 3, wht/brn) · 12VTRG (pr 4, brn) · RS232 (pr 1-2)`. That sub-line is exactly what the trim tech needs and cannot get anywhere else. Same treatment on the Structure side, a drop is one cable that may carry several services.

---

### M7. Front and rear occupancy are checked independently, with no depth arbitration. That is physically wrong.

**What's wrong.** `I-20`: "No two devices overlap in (rackId, face, ruIndex range, twelfth range). Front and rear occupancy are computed independently." `RCK-005` checks a single device's depth against the rack. Nothing checks front-device depth *plus* rear-device depth against the rack depth.

**The scenario.** 20 in usable depth rack. A02 amp at U19–U21, front, 16 in deep plus connectors. I place a 1U rear-mount shelf or a rear-rail-mounted power supply tray at U20 rear, 8 in deep. Your model says fine, different faces. Physically the rear device is trying to occupy the same 4 in of air the amp's rear panel and its HDMI/speaker terminations already own. The devices touch. The rear door won't close.

This is *the* mistake in shallow racks, which is most residential racks. And you've built the data (`bodyDepth`, `connectorProjection`, `depthOffsetFromFront`, `usableDepth`) and then not written the rule.

**Fix.** `RCK-012 error: front device depth + rear device depth + 50 mm cable allowance > rack usable depth, for overlapping RU ranges.` Model depth occupancy as an interval on the depth axis per (RU, face), not a boolean. Also: `connectorProjection` auto-suggesting `depth + 75 mm` is optimistic. A molded HDMI plug with a bend is 100–125 mm; a compression-F on RG6 with a bend is ~100 mm; a Cat6a boot is ~50 mm. Derive the suggestion from the deepest connector type actually on the device's rear panel, which you already know.

---

### M8. A device mounted backwards is not expressible, and it's common.

**What's wrong.** `PortDef.face` is `front | rear` on the template, and `RailPlacement.face` is which rails the ears are screwed to. There is no notion of the chassis being rotated 180°.

**The scenario.** Credenza rack, 14 in deep, accessible from the front only. I mount the AVR and the switch **backwards** (ears on the front rails, rear panel facing out) so I can reach the connectors. This is standard practice in furniture racks and 2-post open frames. In your model the ports are still `face: rear`, so the rear-panel view (the one that gets printed and taped inside the door) shows them on the wrong side, and the schematic's "Go to Rear Panel" navigation lies. On a swing-gate rack where half the gear is mounted normally and half reversed, the drawing is now actively misleading.

**Fix.** `RailPlacement.chassisRotation: normal | reversed`. Port face resolves as `templateFace XOR reversed`. Draw a small ↺ badge on the elevation. The rear-panel view groups by *access side*, not by template face.

---

### M9. There is no plan view and no way to derive a length, so every length-based rule is decorative and the pull sheet has no footage.

**What's wrong.** `Link.calculatedLength` is documented as "from geometry / user estimate." There is no geometry in this product, the schematic is a diagram on a pitch, explicitly not to scale, and there is no floor plan. The fast entry paths for Structure (matrix mode, command mode) never ask for length. CSV import treats it as optional.

**The scenario.** I enter 62 drops in 90 seconds using your (genuinely excellent) matrix. Every one has a null length. I export. The drop schedule has an empty Length column, the BOM has no cable footage, and I still don't know whether to put two boxes of Cat6 or five on the truck. Meanwhile `LEN-001` (Ethernet > 100 m, error) never fires (not because the runs are fine, but because there's no data) which gives me false confidence that the app checked something.

**Fix, in order of cost:**
1. **Room-based estimation.** Give each `Location` an optional `estimatedRunLength` (from the rack). One number per room, entered once, applies to every drop in that room with a per-drop override. Ninety seconds of input turns 62 null lengths into 62 usable estimates. Flag them visually as estimates (italic) so nobody bills off them.
2. **Cable footage rollup** in the BOM, by media type, with a configurable waste factor: `Cat6: 2,140 ft estimated + 10% = 2,354 ft → 3 boxes (1000 ft)`. This is the number that gets a purchase order cut. It is missing entirely and it is the single most-used output of a takeoff.
3. Distinguish `routedLength` / `cutLength` / `terminatedLength` in the schedule, not one "Len" column. The pull sheet wants cut length; the as-built wants terminated length.
4. When a length is null, `LEN-*` rules must emit `advisory: length unknown, cannot verify` rather than silently passing. Silence reads as approval.

---

### M10. The wiring schedule is organized for the person drawing it, not the person holding the cable.

**What's wrong.** Your columns: `Tag | Domain | From | To | Type | Media | Len | Layer | Sheet/Zone | Bundle | Status`. `From` reads `MTX1:J09 OUT 1`.

**The scenario.** I'm behind the rack at 7pm. Your schedule tells me W044 goes from MTX1:J09 to HBT-GRT:J01. To find MTX1 I have to flip to the elevation sheet. To find out which physical jack J09 is, I have to flip to the rear-panel sheet. Zone 2/C5 tells me where it is on the *drawing*, which is worth nothing to me. There is no room name, no rack, no RU, no conductor colors, no termination detail, and no box to initial when I'm done.

**What's missing, concretely:**
- **Location on both ends.** `Rack 1 / U14 / rear` and `Great Room / TV wall / WP-1`. Not the schematic zone.
- **Both labels on both ends.** You correctly identified that a drop needs `fieldLabel` and `rackLabel` and that "the single most common on-site failure is a schedule that carries one and the technician needs the other." Then you only applied that insight to Structure drops. Every cable has this problem.
- **Termination detail.** T568A vs B. Punch position. Polarity on speaker pairs. Conductor color per role (`Conductor.colorCode` exists in the model and appears in no output). Torque on binding posts, if you're feeling generous.
- **A check-off column.** Every real pull sheet has `Pulled ☐ Terminated ☐ Tested ☐ Init ____`. Yours has a `Status` enum that only the drafter can change, in the office.
- **Sort order.** Default is by tag, which is design order. The pull sheet wants to be sorted by **room, then bundle**, because that's the order the tech walks the house. The termination sheet wants **panel, then port**. Ship both as presets, not as a grouping dropdown the user has to discover.

**Fix.** Split the deliverable. **Pull Sheet** (portrait, by room/bundle, with footage subtotals, check-offs, and jacket color, excluding jumpers) and **Termination Schedule** (by rack/panel/port, with pinout and conductor colors). One schedule cannot serve both and yours currently serves neither.

---

### M11. `Link` cannot span three devices. Real cables do.

**What's wrong.** `I-25`: "every conductor's endpoints resolve to live ports on exactly two distinct devices across the whole link. A link spanning three devices is corrupt."

**The scenario.** A dual-head IR emitter: one 3.5 mm plug at the IR block, two emitter heads on two components. One cable, one part number, one pull, three devices. Your model calls it corrupt. Commercial audio: a 25-pair or 12-pair snake from a DSP to a wall panel breaks out to N destinations at the far end, one cable, N devices. Your model calls it corrupt.

**Fix.** Relax `I-25` to "each `Conductor` spans exactly two ports; a `Link` may reference up to N devices." Add `Link.breakoutAt: List<{label, position}>` for fan-outs. The two-ended assumption is right for 95% of cables and wrong for the ones with the most confusing terminations, which is exactly where a schedule earns its money.

---

### M12. Two rules that fight correct designs.

**`BUS-006`: RS-485 star topology warning, suppressed only for Lutron QS and DALI.** Crestron explicitly supports Cresnet in daisy-chain, star, **and** home-run/branch topology; star from a Cresnet power supply is the recommended residential wiring approach precisely because it lets you home-run every keypad. Your rule will fire a warning on every correctly-wired Crestron job in the product's life. Add `ctl.cresnet` to the suppression list, and make the suppression list a registry field (`SignalFamilyDef.topologyFree: bool`) rather than a hard-coded exception array so users can extend it for proprietary buses.

**`ELE-003`: speaker polarity inverted between conductor ends, severity error, non-dismissible, blocks export.** The polarity data comes from user-entered `Conductor.role` strings. On a 16/4 with four roles per link across 8 zones, this rule will fire on typos roughly 100× more often than on real design errors, and each false positive blocks the PDF. Demote to warning. Better: make polarity a *derived* property of the port pairing rather than a free-text role, so a typo isn't possible.

---

### M13. Missing: low-voltage / line-voltage separation, and plenum jacket enforcement.

**What's wrong.** You model `JacketRating` (`cl3 | cmr | cmp | lszh | direct_burial`) on drops and links, and `conduitId` / `pathwayId` as opaque strings. You have no rule that uses either.

**The scenario, commercial.** A run shares a conduit with a 120 V branch circuit, NEC 725.136 violation, and a plan-check comment that costs me two weeks. Or: a Cat6 crosses a return-air plenum on CMR jacket instead of CMP, NEC 800.154, and the fire marshal red-tags the job at final. Both are things the drawing set is supposed to catch, and both are trivially checkable with data you already store.

**Fix.** Make `Pathway` a first-class entity with `kind: conduit | jhook | tray | plenumSpace | riser | directBury | exterior` and `containsLineVoltage: bool`. Two rules: `CODE-001 error: Class 2/3 conductor in a pathway carrying line-voltage circuits`, `CODE-002 error: pathway kind == plenumSpace and jacket != cmp/lszh`. These are two of maybe six checks in the whole product that protect the user from an actual code citation, and they cost you a hundred lines.

---

### M14. No rear support / unsupported-weight model.

**What's wrong.** `mountMethod: rackEars` and `Mass weight`, with no relationship between them.

**The scenario.** A 34 lb A08 stereo amp or a 48 lb 2U UPS hung on front ears only in a 4-post rack. It sags, it tears the rail threads, and eventually it comes out of the rack. Every install manual for heavy gear says "must be supported at the rear or on a shelf." Rack-shelf and rear-support-bracket line items are a standard part of a rack BOM and your BOM doesn't know they're needed.

**Fix.** `TemplateBody.maxUnsupportedMass` (default ~15 lb / 7 kg for `rackEars`). `RCK-013 warning: DEVICE (34 lb) mounted on front ears only; requires rear support or a shelf.` Auto-add the support hardware to the BOM. This is the kind of check that makes an integrator say "oh, this thing has actually been in a rack."

---

## MINOR

**m15. Auto rear-panel layout flows connectors across 482.6 mm.** That's the *panel* width including the rack ears. The chassis body is ~17.0–17.4 in (432–442 mm), and connectors live on the chassis. Your auto-layout will draw HDMI jacks out past the rails on the view that gets taped inside the rack door. Add `TemplateBody.chassisWidth` (default 432 mm for `widthClass: full`) and flow within that, centered on the panel.

**m16. Power sequencing has data but no rules.** You modeled `sequenceStep` and `sequenceDelayMs` and shipped a sequencer template. There is no rule enforcing the one thing sequencing exists for: **amplifiers must be on the last step up and the first step down**; sources and processors come up first. A reversed sequence thumps and blows drivers. `SEQ-001 warning: amplifier on sequencer step 1 of 4 — amps should be last on / first off.`

**m17. `Sheet.number` is hard-validated against `^[A-Z]{1,2}\d\.\d{2}$` (NCS).** A residential set is four pages. The first user who types "Page 2" gets a validation failure on a naming convention that exists for 200-sheet commercial construction documents. Make it a project-level scheme choice (`ncs | simple | custom`) and default residential projects to `simple`.

**m18. `I-41` blocks PDF export if any sheet lacks a legend location note.** Refusing to print because of a drafting-standard footnote is exactly the kind of nannying that makes people export to PNG and paste into Word. Warning, not blocker.

**m19. `RCK-008` (spare RU outside 15–25%) and `RCK-004` (CG above 50–55%) will be permanent noise.** Residential racks are built full, a 12U wall box in a closet has no spare U by design, and a 6U rack where the UPS won't fit at the bottom will always be top-heavy. Default both **off** for `formFactor: wallSwingGate | wallPivotCabinet | wallFixed | credenzaFurniture`, on for floor enclosures.

**m20. "Fill gaps with vent panels above high-heat devices."** Correct for open-frame and vented wall racks. Backwards for a sealed enclosure with a fan panel, where you want *blanks* to force air through the intended path and vents create a recirculation short-circuit. Gate the heuristic on `Rack.formFactor` and whether a fan panel is present.

**m21. Grounding is not modeled.** You correctly included the AVR's phono ground lug (nice catch). There is no rack ground bar, no bonding conductor to the service panel, no coax ground block, no TVSS. For commercial work the bonding detail is a required sheet. For residential, the coax ground block is a code item and an actual lightning-damage liability. At minimum: an `F-type ground block` template, a `power.bonding` signal family, and a `Rack.groundBarPresent` flag that feeds a note on the elevation.

**m22. `designator` locking.** The PDF spec says cable IDs are "materialised and locked past `Pulled`." The data model has no `designatorLocked` field on `Link`, and `designatorBlockSize` reserve allocation applies only to ports. Once 60 cables are physically labeled, an accidental renumber is a day of relabeling. Add `Link.designatorLocked: bool`, auto-set when `status >= pulled`, and make the renumber dialog refuse to touch locked IDs by default.

**m23. TIA-570-D grade presets as the primary Structure specification axis.** Grades 1/2/3 are a residential *standards* vocabulary that essentially no CI integrator speaks. We say "two Cat6 and two RG6 to every TV, one Cat6 per AP, 16/4 to every speaker pair." Keep the grades as presets, but make **user-defined outlet templates** the first-class thing in the UI ("TV location," "AP location," "Keypad," "Ceiling speaker pair," "Camera") with the grades as a secondary standards-compliance tag. Your matrix-mode entry screen already gets this right; the data model's `StructureGrade` enum with `custom` as an escape hatch has it backwards.

**m24. Speaker runs aren't outlets.** `StructureBundle` requires `wall` and `mountHeightAff`, meaningful for a wall plate, meaningless for a ceiling speaker pair or a landscape run. Make the outlet template drive which location fields are relevant, and add `ceiling | floor | soffit | exterior | inGround` handling that doesn't demand a wall compass direction.

---

## Cross-document contradictions that will produce field errors

These aren't style issues, each one changes a number that goes on a drawing.

| Concept | data-model | ux-rack | ux-schematic | architecture |
|---|---|---|---|---|
| Length unit | nanometres | tenths-mm | tenths-mm | **hundredths-mm** (and explicitly argues tenths is wrong: 44.45 mm ≠ integer tenths) |
| RU index origin | 1-based (`ruIndex ∈ [1, heightU]`) | **0-based** (`bottomU`, "0-based from the rack's physical bottom") |, |, |
| Circuit ownership | project-level entity with `locationId` | `List<Circuit>` on `Rack` |, |, |
| Wire geometry | persisted (`Link.waypointsBySheet`) |, | **never persisted** ("if you find yourself persisting a polyline, you have made an architectural error") |, |
| Rules that block creation | exactly 5 topology rules | "Errors are not dismissible" | large "Class A hard-invalid" list incl. HDBaseT-into-switch |: |
| Connection model | `Link` + `Conductor` + `Net` + `SignalRoute` |: | single `Connection(from, to, ...)` | `Connection` |

The RU off-by-one is the one that will actually hurt: a device at data-model `ruIndex: 7` and a device at ux-rack `bottomU: 7` are in different rack positions. Someone will implement the elevation from one document and the schedule from the other, and the drawing will say U7 while the label says U8. Pick one origin, write it in the file-format spec, and assert it.

The blocking-rules contradiction is second: `data-model §3.5` argues at length, correctly, that a model which cannot draw a mistake cannot document reality. `ux-schematic §2.2` then makes HDBaseT-into-a-switch physically unrepresentable, which means I cannot document the existing system I was called in to fix, which is the job. The data-model version wins.

---

## What the Structure device gets right, and what it doesn't

**Right, and better than anything shipping:** the three-level Body → Bundle → Drop hierarchy maps exactly onto how the work is specified, priced, pulled, and tested. `signal.undetermined` as a first-class state with retroactive validation is the correct insight, at rough-in a Cat6 is just a Cat6, and no competitor models it. Two labels per drop (field + rack) with both printed is the single most valuable line in these four documents. The **unused home runs page** is a deliverable nobody currently gets and integrators will pay for it. Multiple Structure instances (media panel / exterior / service entrance) matches reality. The matrix bulk-entry screen and the CSV synonym table are the best-designed thing in the whole package.

**Wrong:** the double-modeling in B2, the single-service-per-drop limit in M6, and the missing lengths in M9. Fix those three and the Structure device is the reason to buy this product.

---

## Verdict

The product is one honest revision away from being the tool. The revision is: **stop treating the rack elevation as the center of the model.** The rack is where the gear lives. The job is the cable, where it goes, how long it is, what's on both ends, and whether it passed. Every blocker above is the same mistake in a different costume: an assumption that the design is complete before the wire is pulled.

Ship B1 (unbound endpoints), B2 (one cable, one object), B3 (typical-watts + VA), B4 (field device catalog), and M9 (footage), and I'll use it on the next job. Ship it as written and I'll open it, try to enter my pull list before I have an equipment list, discover I can't, and go back to Excel.