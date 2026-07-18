# The Schematic

The Schematic is the wiring authoring view (`Ctrl+2`) and **the only place a `Link` is created in v1** (per CR-105). This document specifies its visual language, its cable colour system, the connection-creation state machine, validation feedback, the layout and routing pipeline, and — at greatest length, because it is the feature the product lives or dies on — density management. It is normative for `rackmate_ui/canvas/` and for the scene builders in `rackmate_core/draw/` that both the screen and the PDF backends replay (per CR-086). Where it appears to disagree with [`docs/research/design-ux-schematic.md`](research/design-ux-schematic.md), that document is non-normative rationale and this one governs; where it appears to disagree with the [canonical decision record](canonical-decisions.md), the record governs.

---

## 1. Thesis, and what the Schematic is not

Three commitments, each of which is a ruling rather than a preference.

**1.1 — Connectivity is stored; geometry is derived.** The document stores `Link` → `Service` → `Conductor` and a stored `Net` (per CR-008, CR-010, CR-011). **Symbol placement is persisted** as `SheetItem.position`; **wire geometry is never persisted** (per CR-012). The router is a pure deterministic function of the model. `RouteWaypoint`, `waypointsBySheet` and `routeOverrides` do not exist — they are banned names. If a polyline is being written to a `.rackmate`, that is a defect.

> Rejected alternative: `design-ux-schematic.md §2.3`'s waypoints and pinned routes, which its own §0.1 forbids three pages earlier. Manual rerouting returns in v1.2 as `routeConstraintsBySheet` — an ordered list of grid points the router must pass through — never as geometry.

**1.2 — There is no free-line tool.** Every stroke on the canvas is a `Link`, a net label, an annotation `Note`, or chrome. The typed netlist is the entire wedge against Visio and draw.io; an arbitrary line between two arbitrary points makes RackMate a worse draw.io.

**1.3 — The Schematic is navigation; the Schedule is the deliverable** (G1). Any `Link` may be rendered as a drawn wire or as a pair of net labels — two renderings of one identical model object, switchable losslessly at any time. When the drawing gets dense, **the rendering degrades and the model does not**. The PDF ships both the drawing and the schedule (Requirement 7).

> Rejected alternative: `critique-ux-simplicity.md` cut #1 — delete the editable canvas and generate a read-only diagram — and its cut #2, "wire on the rack elevation". Both were rejected (RJ-001, RJ-002): Requirement 5 fixes the schematic idiom, and the rack elevation is a physical projection that cannot express logical signal order. The critique's *diagnosis* (effort was misallocated) is accepted in full and is why §11 of this document is the longest section.

---

## 2. Coordinate system, grid, and sheet

| Constant | Value | Ruling |
|---|---|---|
| Grid unit `gu` | `Len(2_500_000)` = 2.5 mm | CR-004 |
| Position type | `Pt{int gx, int gy}` — integers in `gu`, no sub-grid | CR-004 |
| Pin pitch | 2 gu (5.0 mm) | CR-004 — AV port labels need more room than KiCad's 100 mil |
| Pin stub length | 2 gu |  |
| Minimum body width | 20 gu (50 mm) |  |
| Body corner radius | 0 — square corners; rounded reads as "flowchart" |  |
| Track pitch (routing gutter) | 2 gu |  |
| Gutter clearance from body | 4 gu |  |
| Snap | 1 gu default; 4 gu with `Shift`. **No free positioning.** | CR-004 |
| Canvas boundary unit | 1 diagram unit = 1 PDF point = 1/72 in, `double`, converted in exactly one function in the scene builder | CR-007 |

Free 0.1 mm nudging is deleted (CR-004): it defeats the exact-integer routing the whole pipeline rests on and gives the user a way to author an unroutable drawing. If sub-grid annotation nudging is ever needed it arrives as `int sx, sy` in eighths of a gu — additive, no migration (v1.2).

**Grid rendering.** Dot grid at 4 gu, 15% ink in the light theme, 12% in dark. A line grid competes with orthogonal wires, which *are* lines. Suppressed entirely below 0.35× zoom. `G` toggles it.

**Sheet frame and zone grid.** One schematic `Sheet` exists per project in v1 (CR-073); the canvas is infinite but the sheet frame shows what will print, and content outside it is dimmed with a `3 items outside sheet bounds` chip. Border: 10 mm outer margin, 5 mm frame, zone marks every 40 mm — letters A–D vertically on both edges, numbers 1–8 horizontally on both. **The zone grid stays** even though off-sheet connectors were cut (CR-073): it is ~30 lines and the schedule's `REF` column is what lets an installer find a wire on a sheet.

Sheet numbering is `ProjectSettings.sheetNumbering: ncs | simple`, **default `simple`** (CR-066). `Sheet.scaleNumerator/Denominator` of `0/0` means NTS, which is what a schematic always is.

---

## 3. The device symbol

A symbol is a body rectangle with a header band and pins on its four edges. It is drawn by `symbol_layer.dart` in `rackmate_core/draw/` and replayed by both backends (CR-071, CR-086) — the symbol cannot be a widget-only artifact if it is to print.

```
 ┌ header band, height 6 gu ──────────────────────────┐
 │  DESIGNATOR  (3.5 mm cap, RackBody SemiBold, left) │
 │  instance name (2.5 mm, regular)   badges, right   │
 ├ hairline rule ─────────────────────────────────────┤
 │  pin field, height = (max(leftPins,rightPins)+1)×2gu│
 └────────────────────────────────────────────────────┘
```

**Header contents, fixed order:** `designator` (`MTX-1`, `AMP-12`, `STR-1` — stored at allocation, never recomputed, per CR-041/CR-048); instance name (free text, cosmetic); right-aligned metadata `2RU · U14–U15 · REAR` plus badges — 📌 `SheetItem.pinned`, ⚠/⛔ finding roll-up, 👁 partially filtered.

**Edge assignment.** Inputs left, outputs right, control and network **top**, AC power **bottom**. The top/bottom assignment is the opinionated part and it is right for this trade: control routes to a gutter above the signal plane and never tangles with A/V, and power falls to the PDU at the rack bottom as a single clean comb that never crosses a signal wire. Bidirectional ports sit on the side matching their dominant direction. Port *order within a side* is `FIXED_ORDER` — a device's ports are real hardware and you cannot reorder the XLR jacks on an amp to make a drawing prettier.

**Bank collapse is the density mechanism, and there is exactly one threshold.** `kBankCollapseThreshold = 8` (per CR-103). Any `Bank` of ≥ 2 ports may be collapsed by the user at any time; banks over 8 auto-collapse on first layout and in the Device Builder's symbol preview. A collapsed bank renders as one **vector pin** with a bus-weight stub and a bracketed label `IN[1..8]`; members remain individually routed in the schedule. The collapse is purely graphical.

> Rejected alternative: unit splitting (`MTX1:A/:B/:C`), cut from v1 per CR-070. One device rendered as three bodies is a confusion generator for an audience that has never read an FPGA schematic, and collapse covers the same ground. The 17-pin split threshold and the ≥ 4-port vector-pin threshold are both deleted into `kBankCollapseThreshold`.

`BankDef` (presentation — drives edges, brackets, collapse) and `PortSetDef` (electrical — Y/Pb/Pr, L/R, +/−, `atomicConnect`) are two distinct concepts and both ship in v1 (CR-055).

**Sizing.** `width = max(20gu, textWidth(designator + name) + 8gu, maxLeftLabel + maxRightLabel + 12gu)`, rounded up to 2 gu. `height = 6gu + (max(leftPins, rightPins) + 1) × 2gu`, minimum 16 gu. Top and bottom pins distribute across the width at 2 gu pitch, centred. All text measurement goes through the injected `TextMeasurer` returning `TextMetrics`, never a backend-local measure (CR-081, CR-087).

### 3.1 A 16-port symbol, drawn

`MTX-1`, an 8×8 HDMI matrix: 8 inputs left, 8 outputs right, control top, power bottom.

```
                                   ▭9 RS-232         ⌂ LAN
                                     J17               J18
                                      ▲                 ▲          control edge (top) —
                          ┌───────────┴─────────────────┴────────┐  routes to the control
                          │  MTX-1                      📌  ⚠    │  gutter, never crosses A/V
                          │  8×8 HDMI Matrix — Head End          │
                          │                      2 RU · U14 · REAR│
                          ├──────────────────────────────────────┤
       ┌ HDMI IN ┐        │                                      │      ┌ HDMI OUT ┐
  ◈────►─────────────────┤ J01  IN 1 ‹ATV-1›   ‹GreatRm› OUT 1  ├─────────────►────◈
  HDMI                    │                                      │               HDMI
  ◈────►─────────────────┤ J02  IN 2 ‹CBL-1›   ‹Master›  OUT 2  ├─────────────►────◈
  ◈────►─────────────────┤ J03  IN 3 ‹BDP-1›   ‹Theater› OUT 3  ├─────────────►────◈
  ◈────►─────────────────┤ J04  IN 4 ‹GAME-1›  ‹Kitchen› OUT 4  ├─────────────►────◈
  ◈────►─────────────────┤ J05  IN 5 ‹CAM-1›   ‹Patio›   OUT 5  ├─────────────►────◈
  ◈────►─────────────────┤ J06  IN 6 ‹ATV-2›   ‹Office›  OUT 6  ├─────────────►────◈
  ◈────►─────────────────┤ J07  IN 7 —         ‹Gym›     OUT 7  ├─────────────►────◈
  ◈────►─────────────────┤ J08  IN 8 —         ‹Bar›     OUT 8  ├═════════════►════⌂
       └─────────┘        │      J01..J08         J09..J16      │      └──────────┘ ▲
      ▲                   └──────────────────┬───────────────────┘                  │
      │                                      │                     HDBaseT: doubled RJ45
  sinks — arrowhead points INTO the body     ▼                     glyph, 1.25× weight
                                            ⊐ J20  IEC C14         power edge (bottom) —
                                                                   falls to PDU-1:J07

KEY   ◈ connector glyph, tinted by SignalDomainDef.color   ◎ RCA  ⌂ RJ45  ▭9 DE-9  ⊐ IEC C14
      ► direction arrow on the stub — into body = sink, away = source
      ═ 1.25×–2.00× stroke — HDBaseT, network, power
      ‹› the far-end device or room, auto-derived from the Link, never typed
      📌 SheetItem.pinned    ⚠ finding roll-up

COLLAPSED — the same device, both banks folded to vector pins (kBankCollapseThreshold = 8):
                    ┌────────────────────────────┐
        ◈═══════════┤ MTX-1  8×8 HDMI            ├═══════════◈
          IN[1..8]  │        2 RU · U14          │  OUT[1..8]
                    └────────────────────────────┘
```

**Level of detail.** `lodLevel` is explicit in every scene-builder signature and every cache key (AC-016/#13):

| Zoom | Rendering |
|---|---|
| ≥ 0.80× | full — glyphs, labels, port designators, bank brackets |
| 0.40–0.80× | glyphs + labels; port designators suppressed |
| 0.20–0.40× | pin = 3 px domain-coloured tick; header shows designator only |
| < 0.20× | body = filled block tinted by dominant domain; designator if it fits |

---

## 4. Ports and pins

A pin is three composed elements, outward from the body: **[body edge] — stub — [direction arrow] — [connector glyph]**. Port designators are `J{PORT_SEQ:2}` → `J01`, unique within the device (CR-042); cable runs are `W{SEQ:3}` → `W042` (ASME Y14.44). Adopting the ASME convention makes the drawing legible to anyone who has read a schematic and makes the schedule self-documenting.

**Direction**, five values, `i o b n p` (CR-060):

| `PortDirection` | Stub rendering |
|---|---|
| `source` | solid arrowhead at the stub's outer end, pointing away |
| `sink` | solid arrowhead at the body edge, pointing in |
| `bidirectional` | arrowheads at both ends |
| `busNode` (`n`) | short perpendicular tick at the outer end — the classic multi-drop stub |
| `passive` (`p`) | no arrow; plain line |

"Power inlet" and "power outlet" are **not directions** (CR-060): they are `sink`/`source` on a `power.*` family with `PortPowerSpec.role: inlet | outlet`. A return channel (eARC, DDC, ARC) renders as a hollow half-size counter-arrow offset 0.5 gu — one physical link, two logical `Service`s, and the drawing must say so.

**Connector glyphs** are line drawings at 2 gu nominal, drawn on the pin axis outboard of the arrow, and every one must be distinguishable at 8 device pixels and in 1-bit black and white. Each glyph is tinted with the **domain colour of the port's `signalFamily`**, so an RJ45 carrying `net.ethernet` is green and an RJ45 carrying `video.hdbaset` is blue *and* double-outlined. Those are the two most dangerous ports in the taxonomy and they are now impossible to confuse.

| `ConnectorTypeDef` | Glyph | Mnemonic |
|---|---|---|
| `conn.rca` / `conn.rca75` | ◎ concentric circle with centre dot | it is a concentric connector |
| `conn.bnc75` / `conn.bnc50` | ⊙ circle with bayonet ticks at 10 and 4 o'clock | the bayonet lugs |
| `conn.f_type` | ⬡ hexagon with centre dot | the nut |
| `conn.xlr3` / `conn.xlr5` | ○ circle with 3 / 5 dots | pin count distinguishes DMX at a glance |
| `conn.6_35mm_trs` / `conn.3_5mm_trs` | ▬ elongated bar, ring notches (TS = 1, TRS = 2); half length for 3.5 mm | the plug profile |
| `conn.rj45` | ⌂ keystone trapezoid, 8 ticks on the wide edge | latch + 8 contacts |
| `conn.rj45` carrying `video.hdbaset` | same trapezoid, **doubled outline** | must never read as Ethernet |
| `conn.hdmi_a` | flat asymmetric trapezoid, one chamfered corner | the actual shell |
| `conn.dp` / `conn.usb_c` | chamfered rectangle (opposite corner) / rounded stadium | |
| `conn.jis_f05` | ▢ square with an inset chevron | the light ray |
| `conn.euroblock_2/_3/_5` | ▭ rectangle, screw-slot ticks = pole count | |
| `conn.binding_post` | ⊕⊖ two filled circles, `+` above `−` | polarity is visible |
| `conn.speakon_nl4` | ○ circle with a keyed notch at 12 o'clock | |
| `conn.de9` | D-shaped shell, 5 dots over 4 | |
| `conn.iec_c13/_c14` · `_c19/_c20` | ⊐ rounded rect, flat bottom, 3 pin dots; wider and heavier for C19/C20 | |
| `conn.nema_5_15r` / `_5_20r` | rect, two parallel slots + round ground; 20 A slot is T-shaped | |
| `conn.sfp_cage` / `conn.lc_duplex` | two small rects side by side | |
| `conn.punchdown_110` / `conn.keystone` | fork / spade outline | structured-wiring rough-in |
| `conn.unterminated` | ◇ hollow diamond | `structure.undetermined` — not yet assigned |

**Gender** is encoded as glyph fill — **filled = female, hollow = male** — and **only where `ConnectorTypeDef.genderApplies` is true** (CR-059). The five-value enum containing two synonym pairs is deleted: `jack` and `plug` are gone, values are `male | female | genderless`, a jack is a female panel connector, and this fixes a concrete bug in `CON-002`, which never fired for `jack`+`jack`. Overloading fill on every connector costs more legibility than it buys.

**Pin labels.** Inside the body, 1.8 mm, 1 gu inboard of the edge, two columns per side: `J01  HDMI IN 1` left-aligned on the left edge, `OUT 3  J09` right-aligned on the right. Truncate with `…` at 40% of body width; full text in the tooltip and the inspector. A CI test asserts every `ConnectorTypeDef` referenced by a shipped template has a footprint entry (AC-050/A2.2) and that every registry glyph resolves in `RackBody` (IBM Plex Sans) or `Noto Sans Symbols 2` (CR-080) — a tofu box in an exported drawing is a defect this test exists to prevent.

---

## 5. Wire rendering

A drawn `Link` is an orthogonal polyline emitted by the router (§10), stroked with the `SignalDomainDef` of its **dominant service's** family. `Link.dominantSignalFamily` is derived and never serialized (CR-009, CR-115); colour resolves from `Service.signalFamily`, never from the `Link`.

**Stroke scaling** is a field, not a policy argument (CR-082). `Stroke.scaleWithGeometry` is true for cable traces, symbol outlines and rack rails; UI chrome, selection halos and hit slop are constant in screen pixels; sheet furniture uses `Stroke.hairlineFloor` with a 0.25 pt print floor. Minimum print stroke is 0.5 pt and **no stroke is ever emitted at 0**.

| Weight class | Screen (device px) | Print (pt) |
|---|---|---|
| 0.75× control / structure | 1.2 | 0.5 |
| 1.00× signal | 1.6 | 0.7 |
| 1.25× HDBaseT, HDMI 2.1 | 2.0 | 0.9 |
| 1.50× network, RF, digital audio networked | 2.4 | 1.0 |
| 2.00× power, speaker level, PoE | 3.2 | 1.4 |
| Selection halo | +5 px behind, `#F0E442` @ 55% | never prints |

**Arrowheads.** Filled triangle, 1.2 gu × 0.8 gu, at the **sink end only**, placed 0.5 gu before the target pin's own arrow so the two do not collide. A line with no arrowhead reads as bidirectional or as a bus, which is information, not an omission. Bidirectional links get arrowheads at both ends. A return channel gets a hollow half-size counter-arrow at 30% along the run.

**Junction dots** are drawn only at genuine multi-drop junctions — an RF splitter, a 70 V tap, an RS-485 spur, an IR connecting block. Radius = 2× local stroke width, minimum 4 device px, filled in the wire colour. **The geometry emitter forbids 4-way junctions**: a 4-way dot that loses its dot in a photocopy silently becomes a crossover, and vice versa, so junctions are always staggered into two T-junctions ≥ 2 gu apart. This is modern drafting practice and it costs one line in the emitter.

**Crossing hops** are semicircular arcs, radius 1.2 gu, always drawn on the **horizontal** segment (consistency matters more than which axis). Default ON: IEEE drafting practice prefers straight crossovers with dot-only disambiguation, but the reader here is an AV installer, and hops remove the "did the dot survive the photocopy?" failure entirely. Preference: `Hops: arc | gap | none`. **Hops are suppressed on dashed domains — control and structure** — because dash phase diverges across an arc, and those are the two domains where hops matter least (per AC-016/#17; recorded normatively in `docs/visual-language.md`). Wire bends take a 0.6 gu fillet; square corners read harsh at screen resolution and anything larger reads as a flowchart.

**Crossings and hops are computed at paint time, scoped to the visible viewport — never at commit** (per CR-013 as amended by `critique-feasibility.md #20`). This is what keeps the commit budget honest.

**Tag pills.** Every drawn run carries a tag pill at **both ends** — 2 gu outboard of the source pin, 2 gu inboard of the sink pin:

```
 ┤W042│HDMI│25'├
```

Rounded 1 gu capsule, 1.6 mm `RackCond`, wire colour as a 0.5 px outline, paper-coloured fill so it knocks out the grid. Content: `{tag} · {type} · {length}` by default, `{tag}` only in dense mode, `{tag} · {SRC_REFDES}:{SRC_PORT} → {DST_REFDES}:{DST_PORT}` verbose. **The tag pill is mandatory, not decorative** (canon §6.2.1): it is the one encoding channel that survives CVD, greyscale, a third-generation photocopy, and a bad phone photo taken in an attic. A length rendered from an estimate rather than a measurement is rendered distinctly (AC-024, G4) — the pill never presents a guess as a fact.

**Domain glyph at the run midpoint.** ▲ digital video, ▽ RF, ● analog audio, ◆ digital audio, ■ network, ✚ control, ⬢ power, ★ structure. This is the fourth encoding channel (canon §6.2.4). Shape encodes domain; **fill encodes tier** — filled = the domain's native carrier, hollow = the transported, extended or networked variant. It is deliberately not a per-family discriminator; there is no set of 50 shapes legible at 6 pt, and that job belongs to the tag pill.

**Buses are not in v1.** Graphical bus trunks with 45° entries land in v1.2 (per RJ-001 as scheduled in §7.4). Vector pins on collapsed banks (§3) carry the v1 need, and `Ctrl+B` therefore remains "fill gaps with blanks" in the Rack Editor with no schematic meaning (CR-101). Hyperedges — one source to many sinks, as in an IR emitter bus or a 70 V tap chain — are modelled as one `Net` with one source and N sinks and render as a trunk with perpendicular stubs and junction dots, which is visually distinct from point-to-point regardless of colour.

---

## 6. The cable colour palette

### 6.1 Why hue encodes domain and not cable type

There are ~50 signal families in the registry. **No categorical palette is colour-vision-deficiency-safe past 8–9 categories** — the Okabe–Ito authors stopped at eight, having verified their set under protanopia, deuteranopia and tritanopia simulation. A hue per cable type does not produce a colour-coded drawing; it produces an unreadable one, and it fails hardest for the ~8% of male installers with a CVD who are the exact audience.

So RackMate uses **four independent encoding channels**, and hue is never one of them alone (per CR-078, AC-054):

| Channel | Encodes | Survives CVD | Survives greyscale | Survives photocopy |
|---|---|---|---|---|
| **Hue** | domain (8) | ✅ Okabe–Ito | ❌ | ❌ |
| **Dash pattern** | type-within-domain | ✅ | ✅ | ✅ |
| **Line weight** | domain tier, 0.75×–2.00× | ✅ | ✅ | ✅ |
| **Glyph + tag pill** | exact family | ✅ | ✅ | ✅ |

> Rejected alternative: `SignalFamilyDef.color` per family — 43+ palette entries, which `design-data-model.md` simultaneously carried and argued against. `SignalDomainDef` was created in CR-078 to own the visual language; `SignalFamilyDef` keeps `domain` (FK), `shortTag`, and an optional `colorOverride` for the rare deliberate exception.

### 6.2 The eight domains — verbatim from canon §6.2.5

`SignalDomainDef{id, displayName, tagPrefix, color, colorDark, dashPattern, lineWeightPermille, glyph, glyphAlt}`.

| `id` | Display name | Light hex | Dark hex | Base dash (pt) | Weight | Glyph native / transported | Rel. lum. | Greyscale export |
|---|---|---|---|---|---|---|---|---|
| `video.digital` | Digital Video | `#0072B2` | `#4DA6DD` | solid | 1.00× | ▲ / △ | 0.151 | black, solid, 1.00× |
| `video.analog` | Analog Video & RF | `#56B4E9` | `#8ACFF5` | `12,4` | 1.00× | ▼ / ▽ | 0.401 | black, `12,4`, 1.00× |
| `audio.analog` | Analog Audio | `#E69F00` | `#F0B443` | `6,3` | 1.00× | ● / ◐ / ○ | 0.416 | black, `6,3`, 1.00× |
| `audio.digital` | Digital Audio | `#D55E00` | `#F07A33` | `6,3,1,3` | 1.00× | ◆ / ◇ | 0.222 | black, dash-dot, 1.00× |
| `net` | Network | `#009E73` | `#2FC79A` | solid | 1.50× | ■ / □ | 0.257 | black, solid, 1.50× |
| `ctl` | Control | `#CC79A7` | `#E29CC3` | `1.5,3` | 0.75× | ✚ / ✳ | 0.293 | black, fine dot, 0.75× |
| `pwr` | Power | `#000000` | `#E8E8E8` *(inverted — black is invisible on dark)* | `8,3,1.5,3,1.5,3` | 2.00× | ⬢ / ⬡ / ⏚ | 0.000 | black, dash-dot-dot, 2.00× |
| `str` | Structure | `#999999` | `#A8A8A8` | `4,4` | 0.75× | ★ / ☆ | 0.319 | black, `4,4`, 0.75× |
| *(reserved)* | Selection / focus | `#F0E442` | `#F5E76B` | — | — | — | 0.744 | never printed |

Dash patterns, weights, glyphs and tags are **identical across themes**. Only hue moves, and the theme is a UI preference never persisted in the document.

`str`'s base dash is `4,4` rather than the design document's `6,3`: at 0.75× against analog audio's `6,3` at 1.00× it would violate PAL-1 in greyscale (identical dash class, weight ratio only 1.33×). An even dash is unambiguous against a 2:1 dash and is unique in the set.

### 6.3 The honest greyscale caveat, and the rule it generates

Several sources claim Okabe–Ito "has distinct luminance values so it works in greyscale." **Computing WCAG relative luminance shows that claim is false**, and RackMate does not repeat it. Two collision bands exist in the shipped palette:

- **Sky Blue `#56B4E9` (L 0.401) vs Orange `#E69F00` (L 0.416)** — 1.5% apart, indistinguishable in greyscale. These are analog video and analog audio.
- **Vermillion `#D55E00` (0.222) / Bluish Green `#009E73` (0.257) / Reddish Purple `#CC79A7` (0.293)** — a crowded 0.07 band. These are digital audio, network and control.

The collisions are placed **deliberately**, not accepted. Each colliding pair is separated maximally on the other three channels, and that is promoted from a hope to a checkable rule:

> **PAL-1** — Within any greyscale luminance band narrower than 0.10, no two domains may share a dash class, and their line weights must differ by a factor of ≥ 1.4.

| Collision band | Domains | Dash class | Weight | Verdict |
|---|---|---|---|---|
| L ≈ 0.40 | Analog video/RF · Analog audio | long dash `12,4` vs short dash `6,3` | 1.0× vs 1.0× | ✅ dash class differs; glyphs ▼ vs ● |
| L ≈ 0.22–0.29 | Digital audio · Network · Control | dash-dot vs **solid** vs fine dot | 1.0× · 1.5× · 0.75× | ✅ 2.0× spread across the band |

> **PAL-2** — Yellow `#F0E442` is reserved for selection and focus and is **never a cable**. At L 0.744 it is illegible as a thin line on white paper.

> **PAL-3** — **The screen theme never affects the export.** Export palette is `ExportSpec.palette: colour | greyscale | cmyk`, default `colour`, default `greyscale` in the Installer preset, never inherited from the UI theme (CR-077). Greyscale export drops hue entirely and renders every domain in black at its own dash and weight — which the table above proves is sufficient. `ProjectSettings.greyscaleSafeExport` is deleted: it is an export option, not a property of the design.

**Units and storage** (CR-079): dash patterns are in **points (1/72 in)**, stated once in `docs/visual-language.md`, stored as `List<int>` of permille-points so the file stays integral — `6,3` is `[6000, 3000]`. The screen backend divides by the zoom scale so a dash is zoom-invariant; the PDF backend passes them through. **Every shipped dash period is ≥ 4.5 pt (1.59 mm)**, above the 1.5 mm floor below which a dash blurs to solid at 300 dpi; the control domain's `1,3` dot from the design document had a 4.0 pt period and is corrected to `1.5,3`.

### 6.4 Requirement 4 coverage — colour-coding by cable type

Requirement 4 names ten cable types and demands the plan be colour-coded by them. The resolution (AC-054): **hue = domain; dash + weight + glyph + tag = type**; the `T0.01` legend prints one row per named type in colour and greyscale side by side.

| Named in requirement 4 | Canonical family (or media) | Effective hue | Dash | Wt | Glyph | Tag |
|---|---|---|---|---|---|---|
| **Analog RCA** | `audio.line_unbal` | `#E69F00` | `6,3` | 1.00× | ● | `AUD` |
| **HDMI** | `video.hdmi.2_0` / `2_1` / `1_4` | `#0072B2` | solid | 1.00× / 1.25× | ▲ | `HD20` `HD21` `HD14` |
| **Network** | `net.ethernet` (+ `net.poe`) | `#009E73` | solid | 1.50× / 2.00× | ■ | `NET` `PoE` |
| **IR** | `ctl.ir_emitter` (+ `ctl.ir_receiver`) | `#CC79A7` | `1.5,3` | 0.75× | ✚ | `IR` `IRRX` |
| **RS-232** | `ctl.rs232` | `#CC79A7` | `6,3,1.5,3` | 0.75× | ✚ | `232` |
| **RG6** | `media.rg6` carrying `rf.catv` / `rf.satellite` / `rf.ota` | `#56B4E9` | `12,4` / `12,4,3,4` / `16,4` | 1.50× / 1.50× / 1.00× | ▽ | `RF` `SAT` `OTA` |
| **S/PDIF** | `audio.spdif_coax` | `#D55E00` | `6,3,1,3` | 1.00× | ◆ | `SPD` |
| **TOSLINK** | `audio.spdif_optical` | `#D55E00` | `2,3` | 1.00× | ◇ | `OPT` |
| **Speaker level** | `audio.speaker_lowz` (+ `audio.speaker_cv`) | `#E69F00` | `6,3` / `10,3,2,3` | **2.00×** | ◐ / ○ | `SPK` `70V` |
| **Power** | `power.ac_branch` / `power.ac_iec` | `#000000` | `8,3,1.5,3,1.5,3` / `8,3,1.5,3` | 2.00× | ⬢ | `PWR` `IEC` |

The two within-domain collisions the requirement would have produced are both resolved off the hue channel and both survive a greyscale photocopy:

- **Analog RCA vs speaker level** (both `#E69F00`): identical dash, but **1.00× vs 2.00×** stroke and ● vs ◐. A 2× weight difference is the single most legible mono discriminator available.
- **S/PDIF vs TOSLINK** (both `#D55E00`): `6,3,1,3` dash-dot vs `2,3` fine dot, and ◆ vs ◇. This pair also carries real consequence — TOSLINK cannot carry lossless multichannel.

RG6 is correctly a **medium**, not a signal, so it is colour-coded by what it carries; its legend row shows all three families, which is more informative than one "RG6" swatch. `ProjectSettings.familyColorOverrides` lets a user override any hue in v1 (AC-054).

**Acceptance is on hardware, not in simulation** (canon §6.7): the legend is rendered under protanopia and deuteranopia simulation with every domain pair distinguishable; and the same legend is printed on a real greyscale office laser at ANSI B and photocopied once, with all ten requirement-4 types remaining identifiable. PAL-1, the ≥ 4.25 pt dash floor, and glyph font coverage are each unit tests.

### 6.5 Themes

**Light is the first-run default; dark ships and is one click away** (CR-076). The moment that decides whether a user trusts the tool is comparing the screen to the printed sheet, and that comparison must succeed on first run (G1).

| Element | Light | Dark |
|---|---|---|
| Canvas | `#FAFAF7` on screen, `#FFFFFF` for print | `#12161A` |
| Sheet | `#FFFFFF` | `#1A1F26` |
| Ink | `#1A1A1A` | `#E6E9EC` |
| Symbol body fill | `#FFFFFF`, 1.2 px `#1A1A1A` outline | `#232A33` |
| Header band | `#F0F0EC` | `#2C343E` |
| Grid dots | `#1A1A1A` @ 15% | `#E6E9EC` @ 12% |

Symbol bodies must stay **lighter** than the canvas in dark theme; inverting to dark-on-dark makes symbols vanish. The 3% warm tint on the light screen canvas reads as "paper" and is less fatiguing than pure white over a long editing session. `theme` is a UI preference and is never persisted in the document.

---

## 7. Creating a `Link` — the state machine

Drag-to-connect and click-click ("sticky") share one state machine; the drag threshold decides the sub-mode, and releasing over the origin port converts drag into sticky. This is the pen-tool convention and users already have the muscle memory. Every state below names its feedback, because a state with no feedback is a state the user experiences as a freeze.

```
                       ┌──────────────────────────────────────────┐
                       │                 IDLE                     │
                       │  feedback: default cursor; hovering a    │
                       │  port shows the connect cursor           │
                       └───┬──────────────────────────────────┬───┘
      pointerDown on port  │                                  │ hover port
                           ▼                                  ▼
                    ┌──────────────────┐            ┌────────────────────────┐
                    │  ARMED           │            │  PORT_HOVER            │
                    │  btn held, <4 px │            │  fb: glyph pulses to   │
                    │  fb: glyph scales│            │  1.10×, tooltip after  │
                    │  1.15×, no band  │            │  400 ms: designator,   │
                    └──┬────────────┬──┘            │  family, connector,    │
       move ≥ 4 px     │            │ pointerUp     │  gender, far end if    │
                       │            │ (no drag)     │  already connected     │
                       ▼            ▼               └────────────────────────┘
             ┌──────────────┐   ┌────────────────────┐
             │  WIRE_DRAG   │   │  WIRE_STICKY       │
             │  btn held    │◄──┤  btn free, band    │
             │              │   │  follows cursor    │
             └──┬────────┬──┘   └──┬──────────┬──────┘
   pointerUp on │        │         │          │  Esc / right-click / click empty
   ORIGIN port ─┘        │         │          └──────────────► IDLE
   → WIRE_STICKY         │         │  click on target            (no model change,
                         │         │                              no undo entry)
       pointerUp on target▼        ▼
                 ┌──────────────────────────────────┐
                 │            RESOLVE               │
                 │  classify(srcPort, dstPort)      │
                 │  fb: status bar shows the full   │
                 │  resolution + verdict, live      │
                 └──┬──────────────┬────────────┬───┘
      model-legal   │              │            │  model-ILLEGAL (TOP-001..005)
      + no finding  │   model-legal│            │
                    │   + finding  │            │
                    ▼              ▼            ▼
          ┌───────────────┐ ┌──────────────┐ ┌────────────────────────────────┐
          │   COMMIT      │ │ COMMIT +     │ │  SPRING_BACK                   │
          │ fb: wire snaps│ │ FINDING BADGE│ │  fb: 120 ms easeOutBack, target│
          │ in, tag pills │ │ fb: as COMMIT│ │  flashes `#D55E00` ×2 @ 90 ms, │
          │ fade in over  │ │ + ⚠/⛔ badge │ │  reason chip anchored at the   │
          │ 120 ms, one   │ │ at midpoint, │ │  target with remedies AND      │
          │ undo entry    │ │ DRC panel    │ │  [ Connect anyway ]            │
          └───────┬───────┘ │ count ticks  │ └───────────────┬────────────────┘
                  │         └──────┬───────┘   [Connect anyway] │
                  │                │                            │
                  └────────────────┴────────────────────────────┘
                                   ▼
                    IDLE, or WIRE_STICKY re-armed from the committed
                    sink if Shift is held (chain-draw)
```

**The binding frame is CR-017: _the gesture may hesitate; the document may not lie._**

- **Model-level illegality** is only `TOP-001..005` — self-connection, duplicate ordered pair on one link, exceeding `maxConnections`, dangling endpoint, container cycle. These are states in which the model *means nothing*, not states the world disallows.
- Everything the design document called **"Class A — refused at drag time, cannot exist in the document"** is deleted as a category. It becomes **spring-back with a reason chip**, and **every chip carries `[ Connect anyway ]` next to its remedies**. A model that cannot draw a mistake cannot document reality, cannot plan a remediation, and cannot import an as-found survey (G2).
- Two former Class-A members — "Dante endpoints with no network path" and "AVB traversing a non-TSN switch" — are **logically unevaluatable at drag time**, because the link being drawn may be the one that completes the path. They are demoted to post-hoc findings unconditionally.

> Rejected alternative: `design-ux-schematic.md §2.2`'s nine hard-invalid rules with no override. The remedy chips it designed are excellent and are kept exactly as designed; only the finality goes.

**Live feedback during `WIRE_DRAG` / `WIRE_STICKY`:**

1. **The canvas dims.** Non-port content drops to 35% alpha, **baked into `Paint.color`, never an opacity layer.** `saveLayer` is banned in the hot path — it costs ~1 ms and three of them blow a third of the 16.6 ms frame budget.
2. **Compatible ports illuminate** — a 3 gu ring in `#F0E442` with a 900 ms breathing pulse (0.6 → 1.0 alpha). "Compatible" means the connector × signal-family matrix admits the pair and no spring-back rule fires.
3. **Ports that would spring back** get the same ring in amber `#E69F00`, no pulse. They remain droppable — the chip and `[ Connect anyway ]` are what handles them.
4. **Ports with no legal relationship** hold at 35% with no ring. Not red: red at 40 simultaneous ports is noise, and absence-of-affordance is the clearer signal.
5. **Rubber band** renders in the source domain's colour, weight and dash, as a live two-bend orthogonal staple — preview what you will get, not a straight line.
6. **Magnetic snap.** Within 12 screen px the band locks to a port's glyph centre and the glyph scales to 1.15×. Snap is **type-weighted**: an HDMI band prefers an HDMI port even if an RJ45 port is 3 px nearer. This is the single biggest usability win in the editor.
7. **Auto-pan** within 40 px of the viewport edge, up to 800 px/s, ramped quadratically by proximity.
8. **Hovering a collapsed bank** auto-expands it after 400 ms so a specific member can be targeted.
9. **Status bar** shows the live resolution: `MTX-1:J09 HDMI OUT 3 → AVR-1:J03 HDMI IN 2 · OK · est. 12'`.

**Chain-draw.** Holding `Shift` on commit re-arms `WIRE_STICKY` from the sink device's matching output. `ATV-1 → MTX-1 IN1`, `MTX-1 OUT1 → DA-1 IN`, `DA-1 OUT1 → TV` is three gestures with no round trip through IDLE. Highest-throughput gesture in the editor; build it first.

**Multi-draw.** With N ports selected in one bank, dragging to a target bank creates N `Link`s in rank order under **one undo entry** — the "wire the 8×8 matrix to eight zone amps" gesture. Live preview shows all N bands. This is the demo moment.

**Atomic sets.** A `PortSetDef` with `atomicConnect: true` — component video Y/Pb/Pr, a stereo pair, a 16/4 speaker run — connects in **one gesture producing one `Link` with N `Conductor`s** (AC-053). Hand-authoring an arbitrary conductor map is v1.1; `atomicConnect` covers the cases the decision exists for.

**Cancel** is `Esc`, right-click, or a click on empty canvas. All three abort with no model mutation and no undo entry. Right-drag is **not** marquee — it is the context menu (CR-102); marquee is left-drag on empty canvas in every view, left→right selecting fully contained (solid band) and right→left selecting intersecting (dashed band).

**Keyboard path.** A fully specified keyboard route to create a `Link` is a v1 requirement (AC-058/D11), not an accessibility afterthought: `Tab` to a port, `W` to begin a wire, `Tab`/arrow to a candidate port with the same illumination feedback spoken through `Semantics`, `Enter` to commit, `Esc` to cancel. The outline tree (`Ctrl+Alt+3`) is the navigation surface that makes this complete.

---

## 8. Validation feedback

Severity is `error | warning | advisory | off` (CR-018); "info" is renamed `advisory` everywhere and "Class A" does not exist. `Finding` is computed and **never stored**. v1 ships **22 rules**, listed once in `docs/rules.md`; a rule not in that catalogue does not exist (CR-021, AC-040). No rule ships without a known-bad fixture and a known-good near-miss (AC-051).

**Rendering.** Marks are drawn *over* the wire so the cable's own colour, dash and weight stay readable underneath:

| Severity | Mark |
|---|---|
| `error` | `#D55E00` chevron-hatch stroked along the run at 0.5× weight, plus a ⛔ badge at the run midpoint |
| `warning` | `#E69F00` 0.6 px dotted parallel line offset 1 gu below the run, plus a △ badge |
| `advisory` | badge only, ⓘ, at the midpoint |
| acknowledged | the badge renders hollow, and the acknowledgement reason is in the tooltip |

Badges are click targets: clicking selects the `Link` and scrolls the DRC panel to the entry. A device with any marked link carries a ⚠/⛔ roll-up chip in its header, so problems remain findable at LOD levels where the wire badge is invisible.

**Acknowledgement is one mechanism at two scopes** (CR-019). An `AckedFinding` carries `{ruleId, targetFingerprint, reason, by, at, demotedTo}`; `targetFingerprint == "*"` is a project-wide mute and its reason is **required**. **Errors are acknowledgeable.** Refusing to let a professional override the tool's opinion about their own system is how the tool gets abandoned.

**Nothing blocks export** (CR-022, G3). `blockExportOnErrors` is deleted. Errors gate exactly one thing — the `ISSUED FOR CONSTRUCTION` stamp and the revision block's `issued` flag, via `ExportSpec.issuedForConstruction`. Every export emits sheet **`T0.02 — Exceptions & Acknowledgements`** listing open findings and every acknowledgement with its reason, author and date. That sheet is where the three documents' promise that "the reason prints" is actually discharged.

Be honest in the copy, as KiCad is: **this catches class errors, not intent errors.** No rule can detect a correctly typed connection to the wrong device.

---

## 9. Selecting, editing, re-terminating, deleting

**Hit-testing** is split by concern (CR-084): the *geometric* test — `DiagramScene.hits`, point-to-segment distance, nearest-hit selection — lives in `rackmate_core/draw/hit_test.dart`, pure and synchronously testable and reusable by the read-only mobile shell; the *pointer plumbing* — one query per frame, spatial hash, cursor policy, hover throttle — lives in `rackmate_ui/canvas/input/`.

- **Nearest hit wins, not first hit.** At a crossing — constant in a schematic — first-hit picks arbitrarily and feels broken.
- Tolerance is 6 screen px, converted to scene units as `6 / viewport.scale`.
- Use closed-form point-to-segment distance against the router's emitted polyline. `Path.contains()` only works on closed paths and a stroked polyline is not closed; Flutter exposes no stroke-to-fill API; `PathMetrics` sampling is both slower and approximate. Start brute-force with an AABB reject — `if (!bounds.inflate(tol).contains(p)) continue` kills ~95% of candidates, and 800 wires × 4 segments is ~64 µs. Add a uniform spatial hash only if hover shows in the timeline.
- Click a wire selects the `Link`; a symbol body or header selects the `DeviceInstance`; a pin selects the `Port`. `Shift+click` adds, `Alt+click` subtracts, `Ctrl+click` a wire selects the whole `Net`.
- Selected wire: `#F0E442` halo at +5 px *behind* the stroke, square handles at both endpoints. **No waypoint handles and no insertable-midpoint diamonds in v1** — there is no route geometry to handle (CR-012).

**Rerouting, in v1, is not a user operation.** Because route geometry is not persisted and the router is deterministic, there is no such thing as a stale route and nothing to clear. Segment-dragging, waypoint insertion, `Pin Route` and `Clear Route` are all removed from the v1 context menu. What the user *can* pin is a **symbol**: any manual move sets `SheetItem.pinned = true` and auto-layout never moves a pinned symbol (CR-068). `Ctrl+L` locks/unlocks the selection — in the Schematic that is `SheetItem.pinned`; `Ctrl+Shift+U` unpins. Manual routing returns in v1.1 as `routeConstraintsBySheet`, stored as ordered grid points the router must pass through, never as a polyline.

> Rejected alternative: `design-ux-schematic.md §2.3`'s full waypoint editing model. It is a good design for a product with persisted geometry, and this is not one. The itch it scratches is aesthetic; the router is deterministic, so the drawing cannot rot.

**Re-terminating.** Drag an endpoint square handle: this re-enters `WIRE_DRAG` with full port illumination. Dropping on empty canvas **reverts to the original port** rather than creating a loose end — but note this is a *gesture* rule, not a model rule. The model deliberately supports an unbound end through `PlaceEndpoint` and `OpenEndpoint` (AC-018), which is what makes a home run to a wall plate with no device yet expressible, and `LifecycleStatus.designIntent` is what labels it. The gesture simply has no way to ask which kind of open end you meant, so it declines to guess.

**Deleting.** `Del`/`Backspace`. Deleting a device deletes its links, with a confirm above five — `Delete AVR-1 and its 14 cables?` — as one undo entry. Deletion writes a `Tombstone`; tombstones ship in v1 even though sync does not (CR-095, G5).

**Context menus** are native platform menus, not Material popups.

| Target | Items (v1) |
|---|---|
| Wire | Signal family ▸ · Media ▸ · Reverse direction (`Ctrl+Shift+R`) · Convert to net label (`L`) · Assign pathway ▸ · Set lengths… · Select net · Properties · Delete |
| Port | Connect from here (`W`) · Collapse / expand bank · Properties |
| Device | Focus (`F`) · Isolate (`Shift+F`) · Pin / unpin symbol (`Ctrl+L`) · Align ▸ · Go to rack position · Reveal in schedule · Duplicate · Properties · Delete |
| Empty | Paste · Insert device… (`Ctrl+Alt+I`) · Add note · Tidy sheet · Fit content (`Ctrl+0`) · Sheet setup… |

`Trace`, `Add to bundle`, `Split into units`, `Create bus` and `Clear route` are absent from v1 by CR-070, CR-101, RJ-001 and AC-040 respectively.

**Undo.** One `Command`/`Transaction`/`UndoStack` machinery, three stacks (CR-106): the document stack; a template-scoped stack owned by the [Device Builder](06-device-builder.md), discarded on close without save; and no stack at all for settings and library operations, which must therefore be individually confirmable or trivially reversible.

---

## 10. Layout and routing

### 10.1 The structural insight

Rack devices are ordered along one axis at discrete integer RU positions. That is a gift, and the pipeline extracts it twice:

1. **As the initial order and the tie-break within each Sugiyama layer** — which frees the layout from arbitrariness *and* makes the schematic read roughly top-to-bottom in rack order, so cross-referencing between the elevation and the Schematic is near-automatic.
2. **As the reason the routing region contains no obstacles.** Once devices are in layers, every inter-layer gutter is an empty vertical channel. Routing through an empty channel is not graph search — it is **interval-graph colouring**, solved optimally in 1971.

**Ruling: Sugiyama layering plus interval-graph channel routing, full deterministic recompute** (CR-013). The interval-graph argument is the strongest single technical insight in the corpus and it eliminates invalidation machinery entirely.

> Rejected alternative: `design-architecture.md §5.2`'s obstacle-avoiding orthogonal router with an `ObstacleField`, a `RouteCache` and per-link incremental invalidation. `ObstacleField`, `RouteCache` and the phrase "obstacle-aware" are deleted names. libavoid measures **2,007 ms** on a 305-node/413-edge diagram; the pipeline below is sub-millisecond at N = 300 *and* provably optimal in track count, because it exploits the structure instead of discarding it. A Dart port of libavoid was also assessed and rejected: stages 1 and 2 are easy, but stage 3 (nudging) needs pseudo-direction propagation with split points plus a working VPSC solver, which is the hard 80% and is where all the visual quality lives.

### 10.2 The v1 pipeline

**Input** `(devices, links, pinnedSheetItems, domainFilter, lifecycleFilter)` → **output** `(symbolPositions, List<Polyline>, junctions, labelAnchors)`. Crossings and hop arcs are *not* produced here; see phase 5.

**Phase 0 — Cycle breaking.** Greedy (Eades et al.) over the directed signal graph, DFS order seeded by `ruIndex` then UUID. Reversed edges are flagged and still render their arrowhead at the true sink. AV signal graphs are near-acyclic; the real cycles are AVR↔display eARC and matrix loop-throughs, so bias the heuristic to reverse edges whose family declares a return channel. `O(D + N)`.

**Phase 1 — Layer assignment.** Longest-path layering on the DAG, ~15 lines. Constraints: the **Structure device is forced to layer 0** (or layer N when `StructureBody.sheetEdge == right`, per CR-072), rendered as a bank of off-page flags on that edge — which is what makes it visually obvious in the PDF which home runs are **unused**, a valuable deliverable in its own right. Off-rack destinations — displays, speakers, keypads — are forced to the final layer. Pinned symbols take the layer nearest their pinned `gx`. `O(D + N)`.

**Phase 2 — Within-layer ordering.** Barycentre sweep with median tie-break, forward and backward until crossings stop decreasing, capped at 8 iterations. **Initial order and final tie-break are `ruIndex`, then UUID.** Barycentre empirically beats median despite median's provable 3-approximation, so run barycentre, break ties with median, break those with rack order. Ports are `FIXED_ORDER`. `O(k · N log N)`, `k ≤ 8`.

**Phase 3 — Coordinate assignment.** Insert dummy nodes for every edge spanning more than one layer, so that **every edge crosses exactly one gutter**. Then Sugiyama's priority method, 3 iterations, priority = degree. Pinned symbols contribute fixed coordinates and are excluded from relaxation. `O(3N)`.

**Phase 4 — Channel routing, per gutter.** Each inter-layer gutter is an independent channel. Every edge crossing it becomes an **interval** on the y-axis, `I(e) = [min(ySrc, yDst), max(ySrc, yDst)]`. Two edges may share a vertical track iff their intervals are disjoint. Therefore **track assignment ≡ interval-graph colouring**; interval graphs are perfect; greedy-by-left-endpoint achieves the chromatic number *exactly*. Minimum track count equals maximum overlap depth. No heuristic gap, no NP-hardness, no search.

```dart
/// One gutter. Returns the track count, which IS the channel density
/// and IS provably optimal for this side assignment.
int assignTracks(List<RouteEdge> edges) {
  edges.sort(byIntervalTop.then(byIntervalBottom).then(byUuid)); // total order
  final free = MinHeap<({int availableFrom, int track})>();
  var next = 0;
  for (final e in edges) {
    final int k;
    if (free.isNotEmpty && free.peek().availableFrom <= e.interval.top) {
      k = free.removeMin().track;            // reuse a retired track
    } else {
      k = next++;                            // open a new one
    }
    e.track = k;
    free.add((availableFrom: e.interval.bottom + kMinGap, track: k));
  }
  return next;
}

/// Track INDICES are just labels; permuting which x each maps to is always
/// feasible and free. This is where crossing reduction actually lives.
void orderTracks(List<Track> tracks, int gutterX) {
  tracks.sort(byMaxSpanDesc.then(byMinTop).then(byUuid));
  for (var i = 0; i < tracks.length; i++) {
    tracks[i].x = gutterX + kGutterPad + i * kTrackPitch;   // short jumpers
  }                                                        // hug the layer;
}                                                          // long runs outboard
```

Each route is emitted as the two-bend staple `[(srcPin), (trackX, srcY), (trackX, dstY), (dstPin)]`, collapsing to a straight line when `srcY == dstY`. Sorting dominates: `O(N log N)`.

**Phase 5 — Decoration, at paint time only.** Orthogonal Bentley–Ottmann sweep for crossings, junction dots at genuine multi-drop nodes, 4-way staggering, hop arcs on horizontals (suppressed on `ctl` and `str`). **This phase does not run at commit; it runs during paint, scoped to the visible viewport** (CR-013 as amended, AC-016/#20). `O((N + X) log N)` over the visible set.

**Phase 6 — Labels. Do not solve edge-label placement.** ELP is NP-hard and the industrial answer is to avoid the problem in the layout phase rather than solve it afterwards. Because tracks sit on a known discrete grid, label slots are **collision-free by construction**: reserve 6 gu at the top and bottom of each gutter as label bands and anchor each tag pill at the top of its own track. This is a genuine architectural payoff of choosing channel routing. `O(N)`.

### 10.3 Complexity and budget

Let N = links (50–300 typical), D = devices (10–30), T = tracks per gutter (5–15), X = crossings in the viewport.

| Phase | Cost | When |
|---|---|---|
| 0 cycle break | `O(D + N)` | commit |
| 1 layering | `O(D + N)` | commit |
| 2 crossing minimisation | `O(k · N log N)`, k ≤ 8 | commit |
| 3 coordinates | `O(3N)` | commit |
| 4 track assignment | **`O(N log N)`** — sort dominates | commit |
| 6 labels | `O(N)` | commit |
| 5 crossings, hops, dots | `O((N + X) log N)` | **paint, viewport-scoped** |
| **Total at commit** | **`O(N log N)`** — sub-millisecond at N = 300 in Dart | |

Full recompute on every edit. No route cache, no invalidation logic, no incremental bugs. The wire-layer *rebuild* — re-recording the `ui.Picture` — is the real cost at commit and is budgeted separately (AC-008); during a drag, re-record only the wires attached to the moving symbol and replay the cached Picture for everything else. That is the whole ballgame for drag smoothness.

**Stability comes free**, and it had two causes that needed two fixes. *Arbitrary tie-breaking* is fixed by making the router a pure function with every sort key terminating in a stable UUID. *Genuine global re-optimisation* largely evaporates: a monotone greedy sweep means a small input change produces a small output change, by construction. Moving one device changes only the intervals of its own links.

**Keep the router behind `List<Polyline> route(WiringModel)` from day one**, so every v2 upgrade stays a one-file swap.

### 10.4 v2 upgrades, in priority order

| # | Upgrade | Payoff | Size |
|---|---|---|---|
| 1 | Brandes–Köpf coordinate assignment (four-pass median alignment + balancing) replacing the priority method | visibly straighter long chains | ~400 lines |
| 2 | Nudging pass — order shared segments so crossings occur only at bundle entry/exit, never mid-bundle (libavoid Theorem 3) | fewer perceived crossings; because tracks are already discrete, **ordering *is* placement**, so no VPSC solver is needed | moderate |
| 3 | Network-simplex layering replacing longest-path | tighter on wide fan-outs | moderate |
| 4 | Hyperedge geometry improvement — the shift-segments heuristic, horizontal pass then vertical, topology preserved unless the user asks | better splitter and 70 V tap trees | moderate |
| 5 | Free-placement escape hatch — if pinning breaks the layered structure, fall back to a **1-bend visibility graph** router for the affected edges only: `O(n)` nodes rather than `O(n²)`, empirically 3–4 A\* steps versus 28–34 | correctness under adversarial pinning | ~700 lines |

If a general router is ever needed, reimplement against MSAGL's rectilinear package rather than libavoid's C++, or bind libavoid through an ELK-style subprocess. **VERIFY:** libavoid is LGPL 2.1+ with a commercial licence available; confirm the licence and the linking model before depending on it.

---

## 11. Density management

This is the make-or-break section. A house with 80–150 cable runs is not unusual and 300 is reachable, and every mechanism below exists to answer one sentence: *I can't see anything.*

### 11.1 The arithmetic, stated out loud

ANSI B landscape is 432 × 279 mm. Subtract a 10 mm margin, a 5 mm frame and a 180 × 50 mm title block and the usable area is roughly 400 × 250 mm ≈ 100,000 mm². At this document's own sizing rules a modest symbol — 20 gu minimum width, header plus eight pins a side — is about 60 × 70 mm ≈ 4,200 mm². **Twenty symbols consume ~84% of the sheet before a single wire is drawn.**

Two consequences follow, and both are rulings.

1. **The "SYSTEM OVERVIEW — all devices" sheet is deleted** (CR-074). There is no legible all-devices sheet at target scale, and shipping one sets an expectation the product cannot meet. The cover sheet's rack summary strip serves the "what is this system" purpose honestly.
2. **Degradation is the primary path, not the fallback.** Every mechanism below is a rendering choice over an unchanged model, so none of them can lose data, and the Schedule is complete regardless of what the drawing shows.

| Links | Strategy |
|---|---|
| 0–40 | one sheet, draw everything |
| 40–80 | collapse high-port banks; auto net-label degradation above the layer-span threshold |
| 80–150 | domain filter becomes the primary navigation; the exporter emits 3–4 domain sheets |
| 150–300 | full domain sheet set; focus and isolate are how the drawing is read |
| 300+ | the **Schedule** is the artefact; the drawing is navigation (G1) |

### 11.2 Domain filter bar — the load-bearing mechanism

A persistent strip below the toolbar: eight chips, each a `SignalDomainDef` swatch plus name plus a live count.

```
 [▲ Digital Video 34] [▽ Analog Video 6] [● Analog Audio 22] [◆ Digital Audio 8]
 [■ Network 41] [✚ Control 19] [⬢ Power 28] [★ Structure 12]           [All] [None]
```

- **Click** solos a domain; `Ctrl+click` toggles; `1`–`8` solo by index; `` ` `` shows all.
- Filtered-out wires **ghost**, and the ghost alpha is **baked into `Paint.color`, never an opacity layer** — the `saveLayer` ban applies here more than anywhere, because this is a per-frame path.
- **VERIFY:** the design document's 8% ghost alpha is below a legible floor. AC-058/D11 requires the filtered-wire alpha to be raised to a *tested* value against both themes; the number is set once in `docs/visual-language.md`, not here.
- Preference **Ghost** (default) versus **Hide**. Ghost preserves spatial context so the reader still sees that *something* runs there; Hide is for reading a single domain cleanly.
- Devices with zero visible links dim to 25% and their pins drop to ticks.

The view filter is **transient and per-view**, never persisted in the document. Its persisted counterpart is `Sheet.domainFilter`, which is part of the sheet's definition (CR-067).

### 11.3 Lifecycle filter — the useful half of layers

`Sheet.lifecycleFilter: Set<LifecycleStatus>` (default all) filters on `existing · new · future · removed · designIntent`. `LifecycleStatus` sits on **both** `DeviceInstance` and `Link` and is the design-intent axis, orthogonal to `RoughInStatus` (the field-progress axis). Between them they cover the demolition and phasing conventions a drawing set actually needs: `future` renders at 50% saturation with a `2,2` dash regardless of domain, which is the standard "not yet installed" drafting convention, and `removed` renders in the demolition convention.

> Rejected alternative: user-named layers with per-layer `visible/locked/prints` flags, cut from v1 per CR-064 and AC-038. They are real for commercial retrofit, absent from the residential first job, and they multiply every filter and every print flag. `Layer` and `layerId` are banned names; they are **not** reserved, because the additive-only rule makes reservation unnecessary. Layers return in v2 as a pure addition.

### 11.4 Focus, isolate, and `Alt`-hover

- **`F` — Focus.** With a device selected, everything more than N hops away dims to 10% and desaturates; the focused subgraph keeps full colour. N defaults to 1. HUD chip: `Focus: AVR-1 · 1 hop · 14 devices, 31 cables`. `F` again or `Esc` exits. This is "show me everything connected to this AVR" and it is the mode users live in.
- **`Shift+F` — Isolate.** Same selection, non-members **hidden**, and the router re-runs on the subgraph — a clean minimal diagram, effectively a temporary sheet. `Esc` restores. Isolate plus `Ctrl+P` is how a one-device commissioning sheet gets produced.
- **`Alt`+hover — transient focus.** No click, no mode, no state: whatever is under the cursor lights its subgraph and everything else recedes. It is the cheapest possible answer to "what is this connected to" and it is the single best idea in the source design document.

`F` and `Shift+F` are bound in the Schematic and the Rear Panel view only and are **unbound in the Rack Editor** (CR-101) — "focus mode on this rack" is deleted as a distinct command, because it is fit-selection with a rack selected, which is `Ctrl+9`.

> Rejected alternative: `T` — Trace through pass-throughs. Deferred to v1.1 and `T` is **unbound in v1** (CR-101, AC-040). It requires modelling continuity through patch panels, switch VLANs, matrix crosspoints, RF splitters and baluns, and it is navigation rather than correctness.

### 11.5 Net-label mode — the highest legibility-per-line mechanism

Any `Link` renders either as a drawn wire or as a pair of directional pennants at its two ports:

```
source end:   J09 ├──⟩ HDMI_MTX1_OUT3        sink end:   HDMI_MTX1_OUT3 ⟨──┤ J03
```

A right-pointing chevron is a signal leaving, left-pointing is arriving; both flags of a net show the identical string and highlight together on hover. Fill is the domain colour at 12% with a full-strength outline.

**The argument for when to draw and when to label.** Draw when the connection is *local and topologically informative* — the reader learns something from seeing the path. Label when the wire would be long, cross many others, or contort so badly that following it is harder than reading a name. A wire in that condition has **negative information value**: it costs the reader time and it costs every *other* wire its legibility. Above a certain density a labelled net is not a compromise, it is strictly the better drawing.

```text
render as drawn wire  iff  layerSpan(link) <= K          (K default 3)
                      and  gutterDensity(link) <= D      (D default 12 tracks)
                      and  link.renderMode != forceLabel
else render as net label
```

Both thresholds are tunable with live preview. The toolbar carries a three-way global toggle — **Draw all / Auto / Label all** — and `L` cycles it (CR-101 binds `L` to "cycle label mode" in every view). Per-link override lives in the context menu and the Schedule. Auto-degraded links show a small ⟩ badge so the user knows the rule fired and can override it. Changing render mode is an ordinary undoable edit that **never touches connectivity**.

**Net names are generated, never typed** (CR-049). Default template `{DOMAIN}_{SRC_REFDES}_{SRC_PORT}` → `HDMI_MTX1_OUT3`; the alternate `{ROOM}_{DEVICE}_{N}` makes the on-diagram label match the physical label the installer will find on the cable, which is the entire point of labelling. Names are editable and **never load-bearing**: membership is the foreign key `Service.netId`, not the string (CR-011). Name-carried membership is precisely the KiCad failure mode — "typos can prevent signals from being connected" — and a GUI tool with a device library has no excuse for it. Renaming a `Location` propagates to every label, schedule row and callout in one transaction, which is what fixes the `Study / Office / Room 3` failure that makes as-builts useless.

### 11.6 Symbol collapse

Any symbol collapses (`-`, or the header chevron) to a compact block showing designator, name and one vector-pin stub per bank. A 48-port patch panel becomes roughly 60 × 30 mm. `SheetItem.collapsed` is per-sheet-item, so a device can be detailed on one sheet and collapsed on another once multi-sheet lands. Banks over `kBankCollapseThreshold = 8` auto-collapse on first layout (CR-103).

### 11.7 Multi-sheet — and why it costs almost nothing

**v1 has exactly one schematic `Sheet` in the document; the exporter partitions by domain** (CR-073). `Sheet` exists in the model from v1 so the format never migrates, and the PDF exporter emits N domain sheets by filtering that one sheet's contents.

The decisive observation:

> A cable belongs to exactly one signal domain, therefore a **domain partition produces zero cross-sheet connections by construction.**

The video sheet contains every video cable, whole. Nothing continues onto another sheet. So **off-sheet connectors and cross-reference resolution are not built in v1** — paired pentagon flags, the second placement pass, min-cut cost functions, match lines and key plans all disappear. Devices simply repeat across sheets, labelled with their designator; a repeated device is just a device. The zone grid stays because the schedule's `REF` column is genuinely useful for finding a wire on a sheet.

> Rejected alternative: `design-ux-schematic.md §4.5`'s `Layout → Split to Sheets…` with a domain partition, a graph min-cut alternative and a by-rack alternative. Geometric tiling and min-cut partitioning are cut; `TilingStrategy.geometric` survives only for a single over-tall rack elevation. Multi-sheet as a *document* feature is v1.2, partitioned by domain only, gated on real projects showing which partition users want.

### 11.8 What the composite strategy buys

The mechanisms are orthogonal and they compose: a filtered domain, with high-port banks collapsed, with long runs auto-degraded to net labels, with `Alt`-hover for local questions, is a legible drawing at 150 links on one ANSI B sheet. And when it is not, the Schedule is complete, correct, and already open in the next tab.

---

## 12. The Rack Editor and the Schematic

They are two projections of one model, and their **positions are deliberately not linked**.

| Change | Rack Editor | Schematic | Rear elevation | Schedule |
|---|---|---|---|---|
| Rename a device, change its designator | ✅ | ✅ | ✅ | ✅ |
| Add, remove or retype a port | ✅ | ✅ | ✅ | ✅ |
| Create, delete or retype a `Link` | ✅ | ✅ | ✅ | ✅ |
| Change location, lifecycle, label, length | ✅ | ✅ | ✅ | ✅ |
| Selection | ↔ | ↔ | ↔ | ↔ |
| **Move a device to a different RU** | ✅ | ⚠️ **the symbol does not move** | ✅ reorders | ✅ |
| **Move a schematic symbol** | ❌ no effect | ✅ | ❌ | ❌ |

**Why positions are not linked.** Rack position is physical: thermal management, weight distribution, service access, cable reach. Schematic position is logical: signal order, sources left, sinks right, readability. An AVR sits at U14 for heat and belongs mid-chain logically; a UPS sits at U1 physically and is a leaf node logically. Slaving one to the other means every thermal decision destroys the reader's mental map of the signal flow — and the failure is *silent*. A user arranges a schematic for twenty minutes, then reorders three devices because the installer called about heat, and the schematic scrambles. No undo affordance makes that acceptable.

**What rack order does do:** it seeds and tie-breaks within-layer ordering on first layout and on any explicit `Tidy sheet` (§10.2 phase 2). A freshly laid-out schematic therefore mirrors rack order top-to-bottom, and when the user *wants* the schematic to follow the rack, one command gives it to them. When they do not, nothing moves. **Auto-layout never fires as a side effect of an unrelated edit.** After a rack reorder, affected symbols get a subtle chip and the toolbar shows `Rack order changed · Tidy sheet` — staleness *signalling*, never staleness *fixing*.

**The v1 layout command surface is one command.** First layout is automatic; any manual move pins; `Ctrl+Shift+U` unpins; a single **Tidy sheet** behind a plain confirm lays out all unpinned symbols (CR-068).

> Rejected alternative: four escalating tidy/re-flow scopes, preview-diff with ghost symbols and motion arrows, and `Tab` variant cycling. Deferred to v1.3. The preview-diff is a genuinely good design — it is the mechanism that converts auto-layout from a thing users fear into a thing they invoke — and it is not what v1 is short of.

**Signposting, because the Rack Editor has no wiring surface** (CR-105). Two cheap mitigations ship in v1: a device with unconnected ports shows a port-count chip (`🔗 0/12`) in the elevation, and clicking it switches to the Schematic with that device selected; and the Schedule is the **second tab in the app**, reachable from an empty project and filling live as links are made, so the deliverable is visible from minute one rather than discovered at export. Both exist to close the "I have a full rack and no way to wire it" cliff the friction inventory found at the 4:00 mark of a first session.

**Adding a device is one command with one palette** (CR-104): `Insert device…` (`Ctrl+Alt+I`, `/` search, double-click, or drag) exists in every view. Dropping on a rack produces a `RailPlacement`; dropping on the schematic canvas, or inserting with no rack focused, produces a `StagedPlacement` plus a `SheetItem` at the drop point. The Schematic's separate `+ New device` button is deleted and its LIBRARY panel is the same palette widget.

**Adapters** split on one mechanical test — *does an installer pull two separate cables to it?* (CR-015). A passive in-line adapter with no independent cable on either side (barrel, gender changer, null-modem shell) is an `InlineAdapter` value on the `Link`, rendered as a small lozenge on the wire. An HDBaseT TX/RX pair, a balun pair, an RF splitter, an IR connecting block or a DA is a real `DeviceInstance` with `mountMethod: notInRack` and two or more `Link`s, and gets a full symbol. The `[ Insert HDBaseT receiver ]` remedy chip therefore inserts a device, correctly, and creates both links in one undo step.

---

## 13. The cable table

The Schedule (`Ctrl+4`) is a real Flutter data table, not canvas-painted — which makes it **screen-reader navigable for free**, and an accessible wiring schedule is better accessibility than any amount of heroic `CustomPainterSemantics` on the canvas. It is the second tab in the app and it populates from an empty project (CR-105, AC-035). A dockable version of the same table sits below the canvas in the Schematic.

One row per **cable**, with a services sub-line when a `Link` carries more than one `Service` (CR-010). A single-service cable never shows the concept.

| `CABLE` | `DOMAIN` | `FROM` | `TO` | `FAMILY` | `MEDIA` | `LEN` | `LIFECYCLE` | `ROUGH-IN` | `REF` | `PATHWAY` | `ISSUES` |
|---|---|---|---|---|---|---|---|---|---|---|---|
| W021 | ▲ D.Video | ATV-1:J01 HDMI OUT | MTX-1:J01 HDMI IN 1 | HDMI 2.1 | `media.hdmi_passive` | 6′ | new | pulled | 2/C3 | — | — |
| W044 | ▲ D.Video | MTX-1:J09 OUT 1 | HBT-GRT:J01 IN | HDBaseT | `media.cat6a_futp` | 90′ | new | planned | 2/C5 | B03 | ⚠ 1 |
| W101 | ⬢ Power | PDU-1:J07 | MTX-1:J20 AC IN | IEC device power | `media.iec_cordage` | 3′ | existing | terminated | 6/A2 | — | — |

Column rulings that are not negotiable:

- **`Status` is never a bare column header** (CR-065). The three axes that were colliding under it are separated: `LIFECYCLE` (design intent, on devices and links), `ROUGH-IN` (field progress, links only, `planned · pulled · dressed · terminated · tested`), and `ISSUES` (DRC state). *In use* and *spare* are **derived** from whether both endpoints are bound and are not stored. `issued` is deleted from `RoughInStatus` — it is a revision-block concept, not a cable state.
- **Three length columns exist in the model** — `routedLength`, `cutLength`, `terminatedLength` (AC-024) — and `LEN` shows the most authoritative one present, rendering an estimate distinctly from a measurement. `calculatedLength` is a banned name.
- **Both labels always print** on every cable: `StructureOrigin.fieldLabel` (required, unique) and `rackLabel` (optional, unique when set), per CR-044 and AC-047.
- `Link.linkClass` auto-classifies as `fieldCable | jumper | powerCord | internal`, and the Pull Sheet **excludes jumpers and power cords by default** (AC-026) — patch cords would otherwise bury the schedule. Power cords appear instead as an outlet map on the power schedule.

Behaviour: bidirectional selection sync (clicking a row pans and flashes the wire; clicking a wire scrolls the row into view); in-place editing of lengths, labels, media, lifecycle, rough-in, pathway and notes; **endpoints and family are read-only here in v1** because structural changes belong on the canvas where the validation feedback lives — editing endpoints from the Schedule and the Rear Panel view lands in v1.1 (CR-105); grouping by domain, source device, destination device, pathway, location or sheet with roll-ups; natural sorting on designators so `AMP-2` precedes `AMP-10`; bulk edit across N selected rows in one transaction; CSV export. See [PDF export](08-pdf-export.md) for the Pull Sheet and Termination Schedule presets that derive from this table.

---

## 14. Keyboard

The keymap is **generated from a single `Intent` registry** so the table cannot drift from the code, and `docs/keymap.md` is that generated table (CR-101). The shipped surface is ~40 bindings, not the ~170 the two source documents defined between them with 16 collisions. Three arbitration principles: view-switching and global commands beat every view-local meaning; a key means the same thing in every view or it means nothing; unmodified single letters are view-local tools and must not collide between views that share the canvas.

| Key | Action | Scope |
|---|---|---|
| `Ctrl+1` … `Ctrl+4` | Rack Editor · **Schematic** · Rear Panel · Schedule | global |
| `Ctrl+0` / `Ctrl+9` / `Ctrl+Alt+0` | Fit content · fit selection · zoom 100% | every view |
| `Ctrl+P` / `Ctrl+E` | Export / Print dialog · Export other formats… | every view |
| `Ctrl+K` | Command palette | every view |
| `Ctrl+F` / `Ctrl+G` | Find · Go to designator | every view |
| `Ctrl+Alt+3` | Outline panel | global |
| `Ctrl+Alt+I` | Insert device… | every view |
| `Ctrl+Z` / `Ctrl+Shift+Z` | Undo · redo | global |
| `W` | Begin wire from the selected port | **Schematic** |
| `Shift` held at commit | Chain-draw — re-arm from the sink | Schematic |
| `Ctrl` held during draw | Suppress magnetic snap | Schematic |
| `F` / `Shift+F` | Focus · Isolate | Schematic, Rear Panel — **unbound in the Rack Editor** |
| `Alt`+hover | Transient focus, no click, no mode | Schematic |
| `1` … `8` / `` ` `` | Solo domain by index · show all | Schematic |
| `-` / `=` | Collapse · expand the selected symbol | Schematic |
| `L` | Cycle label mode (Draw all / Auto / Label all) | every view |
| `G` | Toggle grid | every view |
| `Ctrl+L` | Lock / unlock — `SheetItem.pinned` here, `Placement.locked` in the rack | every view |
| `Ctrl+Shift+U` | Unpin selection | Schematic |
| `Ctrl+Shift+R` | Reverse link direction | Schematic |
| `Ctrl+R` | Renumber…, scoped to the selection kind | every view |
| `Ctrl+Shift+W` | Toggle finding badges | every view |
| `Del` / `Esc` | Delete selection · cancel the current operation | every view |
| `Ctrl+B` | Fill gaps with blanks | **Rack Editor only** |
| `Ctrl+Shift+F` | Cycle elevation face | **Rack Editor only** |
| `T` | **unbound in v1** — Trace defers | — |

**Pan and zoom.** Do not use `InteractiveViewer`: it cannot receive scroll-wheel `PointerSignal` events, so zoom-to-cursor is impossible; it installs its own `ScaleGestureRecognizer` that fights marquee and wire-draw; and its `boundaryMargin` is the wrong model for infinite-canvas-with-fit. Middle-drag and `Space`+drag pan; `Ctrl`+wheel zooms at the cursor; trackpad pan and pinch are handled through `PointerPanZoomUpdateEvent`. Zoom is `scale *= exp(-delta * 0.002)` — multiplicatively symmetric, so three notches up then three down lands exactly where you started — clamped to `[0.05, 32.0]`. Pan deltas arrive in screen space and must be **left-multiplied**; the zoom pivot is right-multiplied in scene space. Getting that backwards produces pan that accelerates with zoom, the classic hand-rolled-viewport bug.

All input goes through `CanvasIntent{beginDrag, updateDrag, commitDrag, cancel}`, built first, and **no editor logic branches on `PointerDeviceKind`** (AC-016/#23) — that is what keeps the touch door open without shipping a squeezed mobile editor.

---

## 15. Open items

| # | Item | Status |
|---|---|---|
| 1 | Filtered-wire ghost alpha | **VERIFY** — must be measured against both themes and fixed in `docs/visual-language.md` (AC-058/D11). The design document's 8% is a placeholder. |
| 2 | Focus-radius adjustment binding (`[` / `]`) | Not in the arbitrated ~40. **VERIFY** against the generated `docs/keymap.md` before implementing. |
| 3 | Bare-wheel behaviour — pan versus zoom | Ship the preference on day one; complaints arrive either way. |
| 4 | Hop rendering default | Specified ON with arcs, suppressed on `ctl` and `str`. Confirm against the print test matrix (AC-058/D13). |
| 5 | libavoid licence and linking model | **VERIFY** before any v2 dependency. LGPL 2.1+ with a commercial option is believed correct but is not verified here. |
| 6 | Impeller on Windows | Not default at time of writing; budget frame costs against Skia and re-benchmark when it lands. `saveLayer` and path-stroking numbers will move. |

---

## Related documents

[Overview](00-overview.md) · [Domain](01-domain.md) · [Data model](02-data-model.md) · [Architecture](03-architecture.md) · [Rack editor](04-rack-editor.md) · [Device builder](06-device-builder.md) · [Structure device](07-structure-device.md) · [PDF export](08-pdf-export.md) · [Roadmap](09-roadmap.md) · [Decisions](10-decisions.md) · [Testing and quality](11-testing-and-quality.md) · [Seed catalog](catalog/seed-devices.md)
