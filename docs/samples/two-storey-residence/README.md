# Two-storey residence: a worked sample

A whole-house job built in RackPal from the seed catalogue: two racks, 68
devices, 98 cables, two calibrated floorplan pages and the PDF sheet set it
exports. It exists to show what a finished project looks like, to give the
README its screenshots, and to find out what the catalogue cannot yet express
(REL-3, `#1292`; DR-259, AC-052).

| File | What it is |
|---|---|
| `two-storey-residence.rppj` | The project. Open it with `File` ▸ `Open…` |
| `two-storey-residence.pdf` | The sheet set, exactly as `File` ▸ `Export PDF…` writes it |

## The brief

- **Living room:** 5.1 surround and a TV with an HDBaseT receiver on the front
  wall, wired back to a living room rack (RK-2) holding the HDBaseT
  transmitter, an AV receiver, a streaming player, a Blu-ray player, a small
  switch and a smart home controller.
- **Distributed audio** from the primary rack's amplifier: a pair each in the
  dining room, kitchen, upper terrace, primary terrace and all three bedrooms,
  and a dual voice coil speaker in the laundry. Eight stereo zones.
- **Bedrooms:** a streaming player, a touchscreen, and an audio balun back to
  the audio matrix, so each bedroom's player is a source for the whole house.
  A touchscreen in the kitchen too.
- **Primary rack (RK-1), Equipment Room:** modem, router, primary switch,
  patch panel, smart home controller, audio streamers, audio matrix,
  distribution amplifier, power manager, PDU and UPS.
- **Three access points:** the primary closet, the bedroom 3 closet and the
  dining room.

## How it was built

`apps/rackpal/tool/generate_sample_residence.dart` builds it through the
application's own code rather than around it:

- every cable is checked with `evaluateConnect`, the test the schematic's drag
  gesture runs, before it is written, so nothing in the file is a connection
  the application would refuse;
- the findings it prints are the validation drawer's (`evaluateDocument`);
- the PDF comes from `buildExportDocument`, the function behind the export.

**Every speaker is its own device and its own run**, labelled by room
(`KIT-SPK-1`, `KIT-SPK-2`, `LIV-SPK-SL`), because a plan needs one location per
speaker. **Speakers, access points, touchscreens and baluns have no wall
plate**: they are wired straight into the device, so their home runs are
boxless and only the device is pinned. The five plates left (the TV location,
the sub's RCA plate and three streamer keystones) are pinned exactly under the
device each serves, one marker carrying both labels.

Ids are deterministic, so regenerating writes the same bytes:

```bash
python tools/samples/draw_residence_plans.py
```

```bash
cd apps/rackpal && dart run tool/generate_sample_residence.dart
```

The first command is only needed when `residence_geometry.json` changes.

### The floorplans are drawn for this sample

The room layout follows a published reference plan whose own title block
forbids republishing it. Nothing from that plan is in this repository: the two
pages the project imports are block plans drawn from room positions alone by
`tools/samples/draw_residence_plans.py`, one outline and one name per room. The
same geometry file gives the builder its room outlines and pin positions, so
the picture and the model cannot disagree.

## What it found

**Validation:** five open findings, all of them true. Four `RCK-013`: the UPS,
amplifier, power manager and primary switch are too heavy for front ears alone
and need rear rail support, which the equipment list prints as hardware to
order. One `PLN-003`: the upper floor has no rack pinned on it, so its run
lengths are typed rather than worked out from the plan.

**Defects in the application,** each on the board:

| Item | What |
|---|---|
| `#1293` | Interconnect sheets for a house-sized domain stack every device in one column; Network prints at 0.65 pt |
| `#1294` | The Device Location Plan's scale bar prints over the device schedule's heading |
| `#1295` | Needs a ruling: cables to a placed field device are "class not determined" on the Pull Sheet |
| `#1296` | A01 is named 16-channel and has eight speaker outputs |
| `#1297` | Schedule room bands read "1 runs" |
| `#1298` | The HDBaseT receiver path stamps a fake content hash |

**Catalogue gaps** (`#1299`), each forked in this project as a project
template from the archetype seed-devices §3.10 names:

| Project template | Forked from | Why |
|---|---|---|
| In-Ceiling Speaker | F05 | The only ceiling speaker shipped is a pair (F04): one device, so one pin |
| Streaming Media Player | S01 | Not shipped (§3.10) |
| UHD Blu-ray Player | S01 | Not shipped (§3.10) |
| In-Ceiling Speaker, dual voice coil | F04 | No single-location stereo speaker |
| Audio Balun, wall plate and receiver | F11, V06 | No balun |
| Audio Matrix Switcher, 8x8 stereo | A03 | A03 is mono and balanced |
| Multi-Zone Amplifier, 8 stereo zones | A01 | A01 drives four stereo rooms (`#1296`) |
| PoE Switch, 8-port | N01 | Only the 48-port configuration is placeable |

Two more are worked around rather than forked: the terraces use F07, a
landscape speaker, where a surface-mount outdoor speaker belongs, and the modem
(F16) hangs on the wall beside RK-1 because it cannot sit on a rack shelf.

Every cable's class is locked by hand, as a person can (DR-008 §11.8.2),
because of `#1295`.
