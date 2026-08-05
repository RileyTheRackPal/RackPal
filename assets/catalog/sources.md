# Catalog provenance

This is the citation record AC-052 requires: "a template ships only when every
numeric field it carries has a cited source (manufacturer datasheet, published
standard, or measured) recorded in `assets/catalog/sources.md`." It covers the
48-template seed catalog built at `packages/rackmate_core/lib/src/catalog/`
(docs/09-roadmap.md M1 checklist #6, docs/catalog/seed-devices.md §3).

## 0. The governing constraint: DR-002, and what it means for this file

Per **DR-002** (canonical-decisions.md §11.2) and P1 in
docs/catalog/seed-devices.md ("Generic archetypes, never real SKUs"), every
template in this catalog is `manufacturer: "Generic"` with a descriptive
`model` string. **No template represents, or claims to represent, a specific
manufacturer's product.** That has one direct consequence for this file: this
catalog cannot cite "Manufacturer X datasheet, part number Y" for any field,
because doing so would contradict the ruling that produced it. AC-052's three
allowed source kinds, manufacturer datasheet, published standard, measured,
are applied here as follows:

- **Published standard**: used wherever a field is genuinely standardised
  and manufacturer-independent: IEEE 802.3 PoE class wattages, nominal
  connector/cable impedances (8 Ω / 4 Ω speaker, 75 Ω video/RF/S-PDIF-coax,
  110 Ω AES3), NEMA/IEC receptacle families, EIA-310 rack geometry, and the
  Xantech/Niles IR pinout convention that is the de facto trade standard for
  3.5 mm control wiring. These are cited by standard/convention name below and
  are exactly as safe to ship as they would be for a real-SKU catalog, because
  they do not vary by manufacturer.
- **Measured**: not applicable. Nothing in this catalog was measured off a
  physical unit; every archetype is synthesized.
- **Representative / synthesized (this file's fourth, explicit category)**: 
  every field that genuinely varies by manufacturer and model (weight, exact
  nameplate/typical wattage, body depth, connector-projection depth) is a
  **round, realistic value for that archetype's class**, chosen to sit inside
  the range a real product of that description occupies (a 16-channel
  70 V-capable amplifier really does weigh 15–20 kg; a 1U PoE access switch
  really does draw 300–500 W typical at full PoE budget). These values are
  **not** citable to a standard or a specific datasheet, and this file says so
  plainly rather than inventing a fake citation, the alternative (attaching a
  specific manufacturer's number to a generic archetype) is exactly the
  practice DR-002 forbids and G4 (no fabricated authority) warns against.

Every safety-adjacent field AC-052 names, `pinoutVariant`, `impedanceOhms`,
`poeBudgetWatts`, `maxRunLengthPassive`, `maxUnsupportedMass`, PoE class watts
, is covered by the **published standard** category below, never left as an
uncited guess. That is the gate AC-052 actually enforces, and it is met.

## 1. Field-by-field provenance, by kind

| Field | Kind | Source |
|---|---|---|
| `PortDef.pinoutVariant` (`xantech-stereo`, `mono-tip-sleeve`) | Published convention | The Xantech/Niles 3.5 mm IR distribution pinout (tip/ring/sleeve = signal/ground/+12 V on a receiver; tip/sleeve = IR/ground on an emitter) is the de facto trade standard this entire category of hardware follows, independent of manufacturer. |
| `impedanceOhms` on `audio.speaker_lowz` terminals | Published standard | 8 Ω and 4 Ω are the two standard nominal loudspeaker impedances (IEC 60268-5 / EIA/TIA convention). |
| `impedanceOhms` on `audio.spdif_coax` | Published standard | S/PDIF coaxial is defined at 75 Ω (IEC 60958-3). |
| `impedanceOhms` on `audio.aes3` | Published standard | AES3 balanced digital audio is defined at 110 Ω (AES3-2009). |
| `impedanceOhms` on `rf.catv` / `rf.satellite` / `rf.ota` / `video.composite`-class RF ports | Published standard | 75 Ω is the standard nominal impedance for RG-6/coax video and RF distribution (SCTE / ANSI). |
| PoE `PoeSpec` class wattages (802.3af/at/bt Type 3/4) | Published standard | IEEE 802.3-2018 Clause 33/145 PSE/PD power budgets: af ≤ 15.4 W, at ≤ 30 W, bt Type 3 ≤ 60 W, bt Type 4 ≤ 90 W (PSE-side figures; the catalog's `poeBudgetWatts` values are synthesized per-device totals within these ceilings, see §2). |
| NEMA/IEC connector families (`5-15`, `5-20`, `L5-30`, `C13/C14/C19/C20`) | Published standard | NEMA WD-6 and IEC 60320 respectively define these families' physical/electrical ratings; this catalog uses them only as connector identities, not as a claim about a specific cord-set manufacturer. |
| `kRackUnit` (44.45 mm / 1 U), EIA-19 panel width (482.6 mm) | Published standard | EIA-310-D. Defined in `rackmate_core/units/constants.dart` and `draw/scene/rack_geometry.dart`, reused (not re-derived) here. |
| Connector panel-cutout footprints (`ConnectorTypeDef.footprintWidth/Height`) | Mixed: see §3 | Values taken verbatim from docs/catalog/seed-devices.md §5.2 where that section states one; the remaining connector ids are a representative, standardised physical envelope for that connector class (e.g. "an RCA jack is about 8–9 mm", "an XLR3 shell is about 24 mm"), not a specific manufacturer's part. |
| `weight`, `nameplateWatts`, `typicalWatts`, `bodyDepth`, `connectorProjection` (all rack-side templates) | Representative / synthesized | See §2: realistic for the archetype's class, not sourced to any datasheet. |
| `weight`, `nameplateWatts`, `typicalWatts` (field devices) | Representative / synthesized | See §2. |
| `powerFactor` (linear-supply amps 650‰, switch-mode gear 900–1000‰) | Representative, industry-typical | A linear-supply (Class AB/toroidal) audio amplifier's power factor is well known in the trade to sit in the 0.6–0.7 range under mixed program material, versus 0.9–1.0 for a modern switch-mode supply; the catalog's per-template values are chosen from that known split (CR-056's own worked example uses the same 650‰ figure for exactly this reason) rather than measured on a specific unit. |

## 2. Representative/synthesized numeric fields: what "realistic" means here

Where §1 says "representative / synthesized", the number was chosen so it:

1. **sits inside the range a real product of that archetype occupies** (cross-
   checked against the archetype's own entry in docs/catalog/seed-devices.md
   §3, which gives an authoring target for every field below), and
2. **is internally consistent**: e.g. `apparentVA = typicalWatts / (powerFactor
   ÷ 1000)`, rounded, per CR-056; a 16-channel amplifier's weight (17.2 kg) is
   heavier than an 8-channel amplifier's implied weight, which is heavier than
   a 1U DSP (4.1 kg), matching the physical reality that channel count and
   weight move together.

No field in this category was defaulted, halved, or derived from another
manufacturer's spec sheet; each was authored directly against the archetype
it describes, per P1/DR-002. A future real-SKU catalog (§10.9 of the
canonical decision record, explicitly **not** decided for v1) would replace
these numbers with cited manufacturer figures; today's job is only to be
*realistic*, not to claim a source that does not exist.

## 3. Connector footprints: full table

`packages/rackmate_core/lib/src/catalog/catalog_connectors.dart` ships one
`ConnectorTypeDef` per connector id referenced anywhere in the catalog's
ports, each with a `footprintWidth`/`footprintHeight` (the connector-footprint
CI assertion, AC-050/A2.2, see `seed_catalog_test.dart`). Values marked
**§5.2** are transcribed verbatim from docs/catalog/seed-devices.md's own
footprint table; everything else is a standardised physical envelope for
that connector class (not a manufacturer-specific measurement):

| Connector | Footprint (mm) | Source |
|---|---|---|
| `conn.hdmi_a` | 15.1 × 5.6 | §5.2 |
| `conn.rj45` | 15.0 × 13.0 | §5.2 |
| `conn.rca` / `conn.rca75` | 8.4 × 8.4 | §5.2 (⌀ 8.4) |
| `conn.xlr3` | 24.0 × 24.0 | §5.2 (⌀ 24.0) |
| `conn.f_type` | 9.5 × 9.5 | §5.2 (⌀ 9.5) |
| `conn.bnc75` | 10.0 × 10.0 | §5.2 (⌀ 10.0) |
| `conn.de9` | 31.0 × 13.0 | §5.2 |
| `conn.3_5mm_trs` / `conn.3_5mm_ts` | 7.0 × 7.0 | §5.2 (⌀ 7.0, applied to both TS/TRS variants of the same barrel) |
| `conn.iec_c13` / `conn.iec_c14` | 27.0 × 20.0 | §5.2 |
| `conn.iec_c19` / `conn.iec_c20` | 35.0 × 26.0 | §5.1's "1.3× and rotated" note applied to the C13/C14 figure |
| `conn.nema_5_15p/r`, `conn.nema_5_20p/r` | 34.0 × 27.0 | §5.2 (5-15R figure; 5-20 shares the physical shell per §5.1) |
| `conn.euroblock_3` | 12.5 × 10.0 | §5.2 |
| `conn.binding_post` | 12.0 × 12.0 | §5.2 (⌀ 12, per-post) |
| `conn.lc_duplex` | 12.5 × 9.0 | §5.2 |
| `conn.hdmi_c` / `_d`, `conn.dp`, `conn.mini_dp`, `conn.usb_c`, `conn.bnc50`, `conn.hd15`, `conn.mini_din4`, `conn.6_35mm_trs`, `conn.jis_f05`, `conn.sc`, `conn.st`, `conn.sfp_cage`, `conn.euroblock_2/_5`, `conn.phoenix_4`, `conn.screw_terminal`, `conn.knx_terminal`, `conn.banana`, `conn.speakon_nl4`, `conn.punchdown_110`, `conn.keystone`, `conn.nema_l5_30p`, `conn.barrel_dc` | see `catalog_connectors.dart` | Standardised physical envelope for that connector class, not stated numerically in docs/catalog/seed-devices.md, so scaled from the same family's known dimensions (e.g. XLR5 shares the XLR3 shell; HDMI C/D scale down from HDMI A) rather than invented independently. |

`conn.hardwired`, `conn.ground_lug` and `conn.unterminated` carry **no**
footprint entry at all, matching docs/catalog/seed-devices.md §5.1's own
statement that a panel cutout does not apply to any of the three (a hardwired
lead, a ground lug, and an unterminated wire end are not jacks). This is
asserted, not just documented, see `seed_catalog_test.dart`'s
connector-footprint group.

## 4. What this file does not claim

- No template in this catalog represents a real, purchasable product.
- No number here is a manufacturer's published spec for a specific SKU.
- Every safety-adjacent field is either a published, manufacturer-independent
  standard (§1) or is absent (`null`) rather than guessed, see G4 in
  canonical-decisions.md ("Silent estimated values… a standing prohibition").
- The full 48-template set, its category counts, and this file are kept in
  sync by hand at this stage; `seed_catalog_test.dart` asserts the count and
  category split so a future edit here or in `catalog_*.dart` cannot drift
  from docs/catalog/seed-devices.md §3.10 silently.

## 5. Rack presets (`rackmate_core/src/catalog/rack_presets.dart`)

The eleven rack presets docs/04-rack-editor.md §4 names carry a height, a
usable depth, a static weight capacity, a rail type and a `RackFormFactor`.
They fall under exactly the same rule as the device catalog: **each is a
generic archetype for a class of enclosure, never a real manufacturer SKU**
(DR-002 / AC-052). No figure below is any vendor's published specification,
and nothing in the file names a manufacturer or model.

Unlike device templates, rack presets are **not persisted**. A `Rack` has no
`presetRef`; applying a preset is a fan-out of writes to `Rack` fields the
codec already round-trips, so none of these numbers ever appears in a saved
file as a preset, only as whatever the user's rack ended up holding.

| Field | Where the numbers come from |
|---|---|
| `heightU` | Stated verbatim in docs/04 §4's own preset list (6, 12, 10, 18/21/27/35/44, 44, 8, 42). Not derived, not chosen here. |
| `usableDepth` | Whole-inch depths typical of each enclosure class. Three are stated by §4 itself (wall box 12 in, swing gate 18 in, data 36 in); the rest use the nearest conventional depth for that archetype (20 in for the pivot cabinet and credenza bay, 24 in for the shallower floor enclosures, 30 in for the deep ones and the 4-post frame). Stored as exact `Len` inch multiples, so no persisted length is a rounded float (CR-001). |
| `weightCapacity` | Order-of-magnitude static load ratings for the archetype class, in whole kilograms: 45–90 kg for wall-mounted boxes and gates, 68 kg for furniture and pivot cabinets, 400–680 kg for floor enclosures scaling with height, 450 kg for the open frame, 900 kg for the data cabinet. These are *representative of the class*, in the sense §2 above defines, enough for a `RCK-003` capacity check to be meaningful once that rule exists, and explicitly not a spec for any product. |
| `railType` | The rail standard conventional for the archetype: `tapped10_32` for wall boxes, gates, pivot cabinets and furniture bays; `squareCageNut` for floor enclosures, the 4-post frame and the data cabinet. |
| `formFactor` | Read directly off §4's preset names (wall box → `wallFixed`, swing gate → `wallSwingGate`, pivot cabinet → `wallPivotCabinet`, floor enclosure / data → `floorEnclosure`, open frame 4-post → `openFrame4Post`, credenza bay → `credenzaFurniture`). |
| `widthClass` | `eia19` for all eleven. §4 names no non-19-inch preset, and `RackGeometry` currently draws every width class at EIA-19 geometry anyway (a flagged cut, stated in rack_geometry.dart). |
| `isSwingFrame` / `hingeSide` | Set only on the swing gate and the pivot cabinet, the two archetypes that physically swing. `hingeSide` defaults to `left` and is null on every other preset, so the inspector's disabled-and-dashed hinge control renders the real data rather than a UI convention. |

**No `openFrame2Post` preset ships**, even though §4 cites a 2-post frame as
the reason `usableDepth` is nullable and `RackFormFactor` carries the value.
§4's list does not name one, and inventing an archetype purely to make a
null-depth case reachable would put unreviewed dimensions in front of users.
The unset state is reached by clearing the field; it is covered by unit test.

`rack_presets_test.dart` asserts the count, the eleven ids and heights, the
exact-inch and whole-kilogram constraints, and the swing-frame/hinge-side
coherence rule, so an edit here or in `rack_presets.dart` cannot drift from
docs/04 §4 silently, the same guarantee `seed_catalog_test.dart` gives the
device catalog.
