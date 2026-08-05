# RackMate: PDF Export Design

**Status:** design spec, v1 target. Nothing implemented yet (`RackMate/` currently holds only `.editorconfig`, `.gitattributes`, `.gitignore`, and an empty `docs/`).

**The load-bearing decision in this document is §6.** Everything else is layout and policy that can be revised cheaply; the renderer boundary cannot. Read §6 first if you read nothing else.

---

## 0. Governing principles

Five rules that the rest of the design follows from. Each one is a constraint I'd enforce with a lint or a test, not a convention.

| # | Rule | Enforced by |
|---|---|---|
| P1 | **One renderer.** Every mark on a diagram sheet (traces, device blocks, symbols, borders, title block, zone grid, legend swatches) is produced by exactly one body of code targeting an abstract `DiagramCanvas`. | §6. Test: the PDF backend and the screen backend replay the same `DiagramScene`. |
| P2 | **True vector, always.** No `RepaintBoundary`, no `toImage`, no PNG-in-PDF for anything the user reads. Raster appears only as an embedded client logo and as a project-browser thumbnail. | §5.6 does the DPI math. |
| P3 | **The renderer must compile without Flutter.** `dart test` (not `flutter test`) must be able to import `scene_builder.dart` and build a full document. | §6.1. This single guardrail is what makes isolate export (§7.3) and any future server-side export possible. |
| P4 | **Colour is never the only encoding.** Every signal domain is encoded three ways (hue, dash pattern, text tag) so the document survives greyscale, photocopying, and colour-vision deficiency. | §2.5, §4.4. |
| P5 | **Emitted IDs are facts about the physical world.** Once a cable ID is rendered into a PDF that someone printed, it exists on a label in a wall. IDs are stored, not recomputed. | §3.6. |

---

## 1. Document structure

### 1.1 Sheet inventory

Sheet numbering follows the U.S. National CAD Standard Uniform Drawing System: `[Discipline][SheetType].[Sequence]`, discipline `T` (Telecommunications), sheet types `0` General, `2` Elevations, `5` Details, `6` Schedules and Diagrams. This is free, defensible, and immediately legible to any GC or architect who receives the set.

| Order | Sheet | No. | Default | Contents |
|---|---|---|---|---|
| 1 | **Cover & drawing index** | `T0.00` | **ON** | Project name, address, client, integrator block (firm, contact, licence no.), project number, issue date, current revision, scope narrative (1 paragraph, user-editable), **drawing index listing only the sheets actually emitted**, rack summary strip (per rack: designator, RU height, devices, populated RU, total weight, total draw). Optional client logo. |
| 2 | **Legend, symbols & general notes** | `T0.01` | **ON** | Signal-domain key rendered twice, colour and greyscale, each row showing the actual line as drawn (weight + dash) with tag prefix; connector symbol table; device-block anatomy callout; status hatching (new / existing / future / demo); reference-designator convention (`J`/`P`/`W`); cable-ID format in force with a worked example; abbreviations; general notes; revision-cloud convention. |
| 3 | **Rack elevation: front** | `T2.01` | **ON** | See §1.3. |
| 4 | **Rack elevation: rear** | `T2.02` | **ON** | Same frame, rear faces, connector fields drawn. This is the sheet installers actually hold. |
| 5..n | **Interconnect / signal-flow** | `T6.01`… | **ON** | One sheet per net partition (§5.4). Default partition: Video · Audio · Network · Control · Power · Structure. |
| n+1 | **Wiring schedule** | `T6.10` | **ON** | §2. |
| n+2 | **Structured wiring / drop schedule** | `T6.20` | **auto** | On iff a Structure device exists with ≥1 drop. |
| n+3 | **Equipment list / BOM** | `T6.30` | **ON** | Qty · Designator(s) · Manufacturer · Model · Description · RU · Rack · Location · Face · Weight · Draw · Status · Notes. Grouped by rack, then by RU descending. Footer: totals. |
| n+4 | **Power schedule** | `T6.40` | **auto** | On iff ≥1 PDU/UPS/sequencer with ≥1 power connection. |
| n+5 | **Network / IP schedule** | `T6.50` | **auto** | On iff ≥1 device has an assigned IP or MAC. |
| n+6 | **Plate, panel & pinout details** | `T5.01` | **auto** | On iff any custom plate or non-standard pinout (null-modem RS-232, IR pinout variant, Euroblock wiring) exists in the project. |
| n+7 | **Field pull sheet** |: | OFF | Wiring schedule filtered to rough-in runs, status/test/initials columns blank, zebra off, greyscale on. A separate deliverable, not part of the design set. |
| n+8 | **Datasheet appendix** |: | OFF | Concatenated PDFs attached to device templates. v2 (needs PDF merge; the `pdf` package writes, it doesn't import pages). |

### 1.2 Default-on vs optional: the actual argument

The static default/optional split is the wrong frame. Three better rules:

**(a) Auto-on when the data exists, off when it doesn't.** A power schedule with three rows is worse than no power schedule: it implies the power design was done when it wasn't. The trigger is "does this sheet have ≥N meaningful rows", not a checkbox default. `T6.20`, `T6.40`, `T6.50`, `T5.01` are all auto.

**(b) The index must never lie.** The drawing index on `T0.00` is generated *after* the sheet list is resolved. A set whose index references a sheet that isn't in the file is the fastest way to look amateur.

**(c) Ship presets, not a checkbox matrix.** The real user question is "who is this for":

| Preset | Sheets | Overrides |
|---|---|---|
| **Full set** (default) | all resolved sheets |: |
| **Installer set** | all + field pull sheet | greyscale ON, status/test columns ON, zebra OFF, rear elevation forced ON |
| **Client set** | cover, legend, front elevation, system-level interconnect (single sheet, blocks only, no port stubs), equipment list | colour ON, cable IDs hidden on diagram, notes column hidden |
| **Single sheet** | the sheet currently open | furniture unchanged |
| **As-built** | Full set | revision block auto-populated from project history, status columns ON, "AS BUILT" stamp, revision clouds on deltas since last issued rev |

Presets are the default UI; the per-sheet checkbox list is behind a disclosure triangle for people who want it.

**Hard rule from J-STD-710 §3.6.1:** every sheet that does not itself carry the legend must carry a note stating which sheet does. Implement as a fixed title-block field: `SYMBOL LEGEND: SEE SHEET T0.01`. Two lines of code, and it is exactly the kind of detail that signals the document was made by someone who has read the standards.

### 1.3 Rack elevation sheet: contents

Per rack, front and rear on separate sheets (side-by-side on one sheet only when both fit at ≥1:10, see §5.5).

**Frame:** RU ruler down both edges, numbered, **1 at the bottom counting up** (project setting; bottom-up default because that's how EIA-310 rails are punched). Rack designator centred above. Overall H×W×D dimension string beneath. Depth bar on the rear elevation.

**Per device block:** reference designator (mono, boxed, top-left of block) · device name · manufacturer + model (smaller, second line) · RU span shown by the block height and stated numerically at the right edge (`4U · 12–15`) · status via border style (new = solid, existing = solid grey 50%, future = dashed, demolish = dashed with X) · weight and draw in the right gutter.

**Rear elevation additionally:** connector fields drawn to scale where the template defines them, each port labelled with its designator and the ID of the cable landing on it. This is what makes the rear elevation the terminate-and-test sheet.

**Gutters:** running totals, cumulative weight from the bottom up (so you can see the load at any mounting point), total draw, total heat (BTU/hr = W × 3.412), and required airflow.

**Blank/vent/shelf** rows render as hatched RU bands, not device blocks.

---

## 2. Wiring schedule

### 2.1 Sheet setup

**ANSI A landscape** (792 × 612 pt) by default, the schedule is the sheet most likely to be reprinted, marked up, and faxed from a job site, and it must come out of an ordinary office printer without shrink-to-fit. Diagram sheets are ANSI B landscape (§5.2); mixed page sizes within one PDF are legal, universally supported, and correct here.

```
Page             792 × 612 pt
Margins          L 54 (0.75" binding)  R 36  T 36  B 36
Border inset     6 pt inside margin
Usable width     792 − 54 − 36 − 12 = 690 pt
Title strip      full-width, 43 pt tall, bottom (compact variant, §4.2)
Sheet header     18 pt
Table height     612 − 36 − 43 − 36 − 18 ≈ 479 pt
Row height       15 pt (1-line)  /  24 pt (2-line notes)
Header row       18 pt
Rows per page    ⌊(479 − 18) / 15⌋ = 30    (≈24 with heavy notes)
```

### 2.2 Columns: default set

Widths sum to exactly 690 pt.

| # | Header | Width | Just. | Font | Content |
|---|---|---|---|---|---|
| 1 | `CABLE ID` | 76 | left | mono 8 SemiBold | Stored ID (§3) |
| 2 | `TYPE` | 58 | left | sans 7 | **Chip** (§2.4) + tag |
| 3 | `FROM DEVICE` | 88 | left | sans 7.5 | `MTX-1` newline `8×8 HDMI Matrix` (2-line cells only when the row is already 2-line) |
| 4 | `FROM PORT` | 58 | left | mono 7.5 | `OUT 1` / `J14` |
| 5 | `TO DEVICE` | 88 | left | sans 7.5 | |
| 6 | `TO PORT` | 58 | left | mono 7.5 | |
| 7 | `CABLE / MEDIA` | 86 | left | sans 7 | `Cat6A F/UTP` |
| 8 | `LEN` | 32 | **right** | mono 7.5 | `78′`: right-justified because it's a magnitude you scan-compare |
| 9 | `REF` | 40 | centre | mono 7 | `6.01/B3`: sheet + zone |
| 10 | `NOTES` | 106 | left | sans 6.5 | wraps to 2 lines max, then ellipsis |

**Rule weights** (grouping without colspan, which `pw.Table` cannot do):

- 0.8 pt vertical rule between col 2|3, col 6|7, col 9|10, the block boundaries (identity ┃ from ┃ to ┃ spec ┃ ref ┃ notes)
- 0.35 pt between all other columns
- 0.35 pt horizontal between rows; 0.8 pt above and below the header
- No outer border on the table itself; the drawing border supplies it

Implemented via `TableHelper.cellDecoration: (col, data, row) => BoxDecoration(border: ...)` with `border: null` on the table.

### 2.3 Optional columns

Toggled per export. Widths are taken from `NOTES` first, then from `CABLE / MEDIA`.

| Header | Width | Just. | Enabled by |
|---|---|---|---|
| `#` | 22 | right | "Number rows": field ticking |
| `ROOM / ZONE` | 56 | left | any endpoint has a room |
| `BUNDLE` | 46 | left | any bundled drop |
| `TERM` | 54 | left | any non-default termination (T568A/B, LC/SC, punch) |
| `PATH` | 60 | left | any pathway assigned |
| `STATUS` | 48 | centre | Installer / As-built preset |
| `TEST` | 44 | centre | As-built preset |
| `INIT` | 34 | centre | Field pull sheet (blank box) |
| `☐` | 20 | centre | Field pull sheet (blank tick box) |

**Overflow rule:** if `Σ fixed widths > usable − 60`, promote the schedule to ANSI B landscape (usable 1128 pt) and emit a non-blocking notice in the export summary: *"Wiring schedule promoted to ANSI B (11×17), 14 columns selected."* Never silently shrink text below 6 pt.

### 2.4 The TYPE chip: how colour reads in greyscale

The chip is **not** a solid colour swatch. It is a 16 × 9 pt box containing a 1.5 pt horizontal line drawn with **the exact colour, weight and dash pattern used for that domain on the diagram sheets**, over an 18 % tint of the domain colour.

```
 ┌──────────────┐
 │ ━━━━━━━━━━━━ │   VID   solid, 1.0×, #0072B2
 └──────────────┘
 ┌──────────────┐
 │ ── ── ── ─── │   RF    long dash 12,4, #56B4E9
 └──────────────┘
 ┌──────────────┐
 │ ─ ─ ─ ─ ─ ─  │   AUD   dash 6,3, #E69F00
 └──────────────┘
 ┌──────────────┐
 │ ─ · ─ · ─ ·  │   DIG   dash-dot 6,3,1,3, #D55E00
 └──────────────┘
 ┌──────────────┐
 │ ━━━━━━━━━━━━ │   NET   solid, 1.5× weight, #009E73
 └──────────────┘
 ┌──────────────┐
 │ · · · · · ·  │   CTL   dot 1,3, #CC79A7
 └──────────────┘
 ┌──────────────┐
 │ ━ ·· ━ ·· ━  │   PWR   dash-dot-dot, 2× weight, #000000
 └──────────────┘
 ┌──────────────┐
 │ ─ ─ ─ ─ ─ ─  │   STR   dash 6,3, thin, #999999
 └──────────────┘
```

Three consequences:

1. **The schedule and the diagram cross-reference visually with no legend lookup.** You find `━━━` in the chip, you look for `━━━` on the drawing.
2. **Greyscale works by construction.** Drop the hue and the tint and the dash pattern still discriminates all eight domains. This matters: computing WCAG relative luminance on the Okabe-Ito palette shows Sky Blue (0.401) and Orange (0.416) are 1.5 % apart, *indistinguishable* in greyscale, and Vermillion/Green/Purple sit in a 0.07 band. The common claim that Okabe-Ito is greyscale-safe is false. The dash layer is load-bearing, not decoration.
3. **The tag text is the third layer** and never fails: `VID`, `AUD`, `NET`, `CTL`, `PWR`, `RF`, `DIG`, `STR`, with the specific type printed after it (`VID·HDMI`, `CTL·232`).

**Greyscale export mode** replaces the tint with white, the colour with black at domain-specific weight, and is the default for the Installer preset.

### 2.5 Sort and group

**Sort keys** (single-select, with a stable secondary sort on Cable ID):

| Key | Use |
|---|---|
| **Cable ID** (default) | Reference lookup; someone reads a label in a rack and wants the row |
| Signal domain, then type, then ID | Pull-by-trade: all the Cat6, then all the speaker wire |
| From device, then from port | Terminate one device at a time: the most common working order at the rack |
| To device, then to port | Terminate at the far end |
| Room / zone | Rough-in and trim by room |
| Length descending | Reel planning and cut lists |
| Status, then ID | Punch list |

**Grouping** is orthogonal to sorting: group by domain, by from-device, by room, or none. A group inserts a full-width band row:

```
▌ NETWORK — 24 runs ──────────────────────────────────────────  1,860′ total
```
14 pt tall, 12 % grey fill, 2 pt leading rule in the domain colour, bold sans 8, with a count and a length subtotal right-aligned. At a page break the band repeats with ` (cont.)` appended.

Group bands force **hand-rolled pagination** rather than letting `MultiPage` flow a single table (§2.6), which is fine, because you want that control anyway.

### 2.6 Pagination

Do **not** hand `MultiPage` one giant `pw.Table` and hope. Row heights in this schedule are deterministic (fixed column widths, notes capped at 2 lines), so paginate explicitly:

```dart
List<pw.Widget> buildSchedulePages(ScheduleModel m, ScheduleLayout L) {
  final pages = <pw.Widget>[];
  var page = <ScheduleRow>[];
  var y = 0.0;
  GroupBand? openBand;

  void flush() {
    if (page.isEmpty) return;
    pages.add(_pageTable(page, L, continued: openBand));
    page = [];
    y = 0;
  }

  for (final item in m.flattened) {           // bands interleaved with rows
    final h = item.height(L);                 // 14 | 15 | 24
    if (y + h > L.bodyHeight) {
      flush();
      if (openBand != null) {                 // re-emit the band, marked (cont.)
        page.add(openBand.continuation());
        y += openBand.height(L);
      }
    }
    if (item is GroupBand) openBand = item;
    page.add(item);
    y += h;
  }
  flush();
  return pages;
}
```

Each page becomes one `pw.Table` inside a `MultiPage`, separated by `pw.NewPage()`. Benefits:

- **Header repetition is explicit**: every page's table carries its own header row. This sidesteps the open question of whether `Table.headerCount` actually repeats per page fragment in `pdf` 3.13.0 (flagged as unverified in the research; not worth betting the schedule on).
- Group continuation bands work.
- `Widget won't fit into the page` overflow (dart_pdf #114) becomes structurally impossible.
- Deterministic row counts → the progress reporter can quote an exact page count up front.

**Set `maxPages` explicitly.** It defaults to 20 and throws beyond that (#128, #145, #290, #461). Use `maxPages: 2000`.

**Long-token protection.** Device model strings and cable IDs like `RK1-HDMI-OUT-07-TO-DISPLAY-MSTR-BR` are exactly the shape that overflows or *disappears* in `pw.Text` (#349, #397, #518). Sanitize on the way in:

```dart
/// Insert zero-width spaces after separators so long identifiers can wrap.
String breakable(String s) =>
    s.replaceAllMapped(RegExp(r'[-_/.:]'), (m) => '${m[0]}\u200B');
```

…and additionally hard-truncate with a measured ellipsis using `PdfFont.stringMetrics` (§6.7) rather than trusting the widget.

### 2.7 Rendered example

Realistic residential rack: Apple TV, 8×8 HDMI matrix, HDBaseT TX, AVR, 16-channel amp, 24-port PoE switch, control processor, PDU, patch panel, Structure.

Actual column layout at scale (ANSI A landscape, 690 pt usable):

```
┌────────────┬─────────┬──────────────┬─────────┬──────────────┬─────────┬─────────────┬─────┬──────┬──────────────────┐
│ CABLE ID   │ TYPE    ┃ FROM DEVICE  │ FROM PT │ TO DEVICE    │ TO PORT ┃ CABLE/MEDIA │ LEN ┃ REF  ┃ NOTES            │
├────────────┼─────────╀──────────────┼─────────┼──────────────┼─────────╀─────────────┼─────┼──────╀──────────────────┤
│ W001       │▤ VID·HDM┃ ATV-1        │ HDMI OUT│ MTX-1        │ IN 1    ┃ HDMI 2.1 48G│  6′ ┃6.01  ┃ 4K120 HDR10+;    │
│            │         ┃ Apple TV 4K  │         │ 8×8 Matrix   │         ┃ passive     │     ┃ B3   ┃ passive OK <4.5m │
│ W002       │▤ VID·HDM┃ MTX-1        │ OUT 1   │ TX-1         │ HDMI IN │ HDMI 2.0 18G│  3′ ┃6.01  ┃                  │
│ W014       │▤ VID·HBT┃ TX-1         │ LINK OUT│ PP-1         │ A03     ┃ Cat6A F/UTP │  4′ ┃6.01  ┃ NOT ETHERNET —   │
│            │         ┃ HDBaseT TX   │         │ Patch Pnl 24 │         ┃ solid       │     ┃ C1   ┃ do not patch to  │
│            │         ┃              │         │              │         ┃             │     ┃      ┃ SW-1. PoH 100W   │
│ W015       │▨ STR    ┃ PP-1         │ A03     │ STR-1        │ LR-TV-1 ┃ Cat6A F/UTP │ 78′ ┃6.06  ┃ home run; grade 2│
│            │         ┃              │         │ Structure    │         ┃ CMR         │     ┃ A2   ┃ bundle B-LR-01   │
│ W031       │▬ NET    ┃ SW-1         │ P07     │ PP-1         │ A07     ┃ Cat6 patch  │  1′ ┃6.03  ┃ VLAN 20; PoE Cl.4│
│ W040       │▥ AUD    ┃ AVR-1        │ ZONE2 PR│ AMP-1        │ IN 3/4  ┃ 2C shld 22AW│  4′ ┃6.02  ┃ balanced pair;   │
│            │         ┃ Denon AVR    │ OUT L/R │ 16ch Amp     │         ┃ G           │     ┃ B2   ┃ L=3 R=4          │
│ W041       │▥ AUD·SPK┃ AMP-1        │ CH 5 ±  │ STR-1        │ KIT-CLG-│ 16/2 CL3    │ 62′ ┃6.02  ┃ VERIFY POLARITY  │
│            │         ┃              │         │              │ 1       ┃             │     ┃ D3   ┃                  │
│ W055       │▪ CTL·232┃ CTL-1        │ COM 2   │ PROJ-1       │ RS-232  ┃ Cat6 + DB9  │ 41′ ┃6.04  ┃ NULL-MODEM       │
│            │         ┃ Processor    │ DB9-M   │ Projector    │ DB9-F   ┃ adapters    │     ┃ B1   ┃ 2↔3 4↔6 7↔8 5→5  │
│ W061       │▪ CTL·IR ┃ CTL-1        │ IR 3    │ ATV-1        │ IR EMIT ┃ 3.5mm MONO  │  8′ ┃6.04  ┃ Xantech pinout;  │
│            │         ┃              │         │              │         ┃ emitter     │     ┃ C1   ┃ NOT rcvr jack    │
│ W070       │▧ RF     ┃ STR-1        │ ANT-ROOF│ SPL-1        │ IN      ┃ RG6 quad    │ 44′ ┃6.01  ┃ OTA; preamp pwr  │
│            │         ┃              │         │ 4-way split  │         ┃ swept 3GHz  │     ┃ A4   ┃ injected at SPL-1│
│ W080       │█ PWR    ┃ PDU-1        │ C13 O4  │ AVR-1        │ IEC INLE│ C13→C14 1m  │  3′ ┃6.05  ┃ seq step 3 (+4s);│
│            │         ┃ Seq PDU      │         │              │ T       ┃ 15A         │     ┃ B2   ┃ UPS-backed       │
└────────────┴─────────┸──────────────┴─────────┴──────────────┴─────────┸─────────────┴─────┴──────┸──────────────────┘
▌ Σ 11 runs · 250′ ────────────────────────────────────────────────────────────  SHEET T6.10 · 1 OF 3
```

Same data as a plain table:

| CABLE ID | TYPE | FROM DEVICE | FROM PORT | TO DEVICE | TO PORT | CABLE / MEDIA | LEN | REF | NOTES |
|---|---|---|---|---|---|---|---|---|---|
| W001 | ▤ VID·HDMI | ATV-1 Apple TV 4K | HDMI OUT | MTX-1 8×8 Matrix | IN 1 | HDMI 2.1 48G passive | 6′ | 6.01/B3 | 4K120 HDR10+; passive OK <4.5 m |
| W002 | ▤ VID·HDMI | MTX-1 | OUT 1 | TX-1 HDBaseT TX | HDMI IN | HDMI 2.0 18G | 3′ | 6.01/B4 | |
| W014 | ▤ VID·HBT | TX-1 HDBaseT TX | LINK OUT | PP-1 Patch Panel 24 | A03 | Cat6A F/UTP solid | 4′ | 6.01/C1 | **NOT ETHERNET**: do not patch to SW-1. PoH 100 W |
| W015 | ▨ STR | PP-1 | A03 | STR-1 Structure | LR-TV-1 | Cat6A F/UTP CMR | 78′ | 6.06/A2 | home run; Grade 2 bundle B-LR-01 |
| W031 | ▬ NET | SW-1 24-pt PoE | P07 | PP-1 | A07 | Cat6 patch | 1′ | 6.03/C2 | VLAN 20; PoE Class 4 |
| W040 | ▥ AUD | AVR-1 Denon | ZONE2 PRE OUT L/R | AMP-1 16-ch Amp | IN 3/4 | 2C shielded 22 AWG | 4′ | 6.02/B2 | balanced pair; L=3 R=4 |
| W041 | ▥ AUD·SPK | AMP-1 | CH 5 ± | STR-1 Structure | KIT-CLG-1 | 16/2 CL3 | 62′ | 6.02/D3 | **VERIFY POLARITY** |
| W055 | ▪ CTL·232 | CTL-1 Processor | COM 2 (DB9-M, DTE) | PROJ-1 Projector | RS-232 (DB9-F, DTE) | Cat6 + DB9 adapters | 41′ | 6.04/B1 | **NULL-MODEM** 2↔3 4↔6 7↔8 5→5 |
| W061 | ▪ CTL·IR | CTL-1 | IR 3 | ATV-1 | IR EMIT | 3.5 mm **mono** emitter | 8′ | 6.04/C1 | Xantech pinout; do **not** use receiver jack |
| W070 | ▧ RF | STR-1 Structure | ANT-ROOF | SPL-1 4-way splitter | IN | RG6 quad, swept 3 GHz | 44′ | 6.01/A4 | OTA; preamp power injected at SPL-1 |
| W080 | █ PWR | PDU-1 Sequenced PDU | C13 OUT 4 | AVR-1 | IEC INLET | C13→C14 1 m 15 A | 3′ | 6.05/B2 | seq step 3 (+4 s); UPS-backed |

Note what the NOTES column is doing: it is carrying the output of the validation engine. `NOT ETHERNET`, `NULL-MODEM`, `VERIFY POLARITY`, `not receiver jack`; these are auto-generated from the port model, not typed by the user. That is the single highest-value thing this schedule does that a spreadsheet can't.

---

## 3. Cable ID scheme

### 3.1 The core decision

TIA-606-C is explicit: *the format is not mandated, but must be consistent and unique.* So RackMate ships an **identifier format engine**, a token template with presets, not a hardcoded scheme. Anything else will be wrong for half the userbase.

### 3.2 Token grammar

```
template  := segment*
segment   := literal | token | optional
token     := '{' name (':' pad)? (('|' filter))* '}'
optional  := '[' segment+ ']'          // collapses entirely if any token inside is empty
pad       := digits                    // zero-pad width
filter    := 'upper' | 'lower' | 'first' digits | 'nz'   // nz = strip leading zeros
```

| Token | Value | Example |
|---|---|---|
| `{PROJ}` | project code | `25-1183` |
| `{RACK}` | rack designator | `RK1` |
| `{DOM}` | signal domain code | `VID` `AUD` `NET` `CTL` `PWR` `RF` `DIG` `STR` |
| `{TYPE}` | signal type code | `HDMI` `HBT` `CAT6` `RG6` `SPK` `232` `IR` `IEC` |
| `{SRC}` `{DST}` | endpoint device designator | `MTX-1` |
| `{SRCPORT}` `{DSTPORT}` | endpoint port label | `OUT 3` |
| `{SRCIDX}` `{DSTIDX}` | device index within rack | `07` |
| `{SRCPORTIDX}` `{DSTPORTIDX}` | port ordinal on device | `03` |
| `{ROOM}` `{AREA}` `{DIR}` `{FLOOR}` | location fields | `LR` `BR3` `N` `2` |
| `{SPACE}` `{PANEL}` `{PORT}` | TIA-606 fields | `A` `A` `12` |
| `{N}` | global sequence | `042` |
| `{Nd}` `{Nt}` `{Ns}` `{Nr}` | per-domain / per-type / per-source-device / per-room sequence | |
| `{REV}` | revision in which added | `C` |

### 3.3 Presets

| Preset | Template | Output | Rationale |
|---|---|---|---|
| **Sequential** *(default)* | `W{N:3}` | `W001` `W042` `W113` | IEEE 315 / ASME Y14.44: `W` = cable/harness, `J` = jack, `P` = plug. Short, never collides, matches the designators on the diagram, and reads correctly to anyone who has ever opened a schematic. |
| **Domain sequential** | `{DOM}-{Nd:3}` | `VID-001` `NET-014` `PWR-006` | Installers pull by trade. Sorting by ID gives you the pull order for free. |
| **Rack-scoped** | `{RACK}-{DOM}{Nd:3}` | `RK1-VID001` | Multi-rack jobs; keeps racks independently renumberable. |
| **Endpoint descriptive** | `{SRC} {SRCPORT} > {DST} {DSTPORT}` | `MTX-1 OUT 3 > DISP-LR IN 1` | This is literally AVIXA F501.01's worked example (`VDA2 Out 3 to PROJ Input A`). It's what belongs on the *physical label*, because the label's job is to say where the cable goes. Long for a schedule column, perfect for a label file (§8.4). |
| **AV block numbering** | `{SRCIDX:2}{SRCPORTIDX:2}` | `2301`…`2316` inputs, `2401`…`2416` outputs | The widespread AV matrix convention. Its virtue is that it **reserves IDs for unpopulated ports**, so adding a source next year doesn't renumber the rack. Requires ports to be first-class entities with IDs whether connected or not, which the model already does. |
| **TIA-606-C horizontal link** | `{FLOOR}{SPACE}-{PANEL}{PORT:2}` | `2A-A12` | The standard's `fs-an` form verbatim: `f` floor, `s` space, `a` panel, `n` 2–4 digit port. Commercial jobs where a spec cites 606. |
| **TIA-606-C backbone** | `{FLOOR1}{SPACE1}/{FLOOR2}{SPACE2}-{N}` | `1A/3B-2` | `fs1/fs2-n`. |
| **Residential type-room-direction** | `{TYPE}-{ROOM}[-{DIR}][-{N}]` | `ET-FAM-W-11` `SP-FAM-SL` `DS-SUN-E` | The dominant residential prewire scheme. Room and type code tables are user-editable. |
| **Area-type-run** | `{AREA}-{TYPE}-{N}` | `B-5-1` `B-22-2` | Simplest scheme that survives rough-in in a house whose rooms don't have names yet. |

### 3.4 Configuration

```dart
class CableIdScheme {
  final String template;
  final String separator;          // substituted for '-' in the template
  final IdCase idCase;             // upper | lower | asEntered
  final int defaultPad;            // 3
  final CollisionPolicy collision; // suffixLetter | suffixNumber | error
  final List<IntRange> reserved;   // ranges the generator will not allocate
  final int startAt;               // 1
  final int step;                  // 1  (use 10 to leave gaps)
  final bool lockAfterStatus;      // true: never renumber a run past 'Pulled'
}
```

**Uniqueness** is validated project-wide on every mutation, not at export. A duplicate ID is a hard error that blocks export, with a "resolve duplicates" action that suffixes.

**Renumber** is an explicit command, never implicit. It shows a before/after diff and refuses to touch any run whose status is ≥ `Pulled` when `lockAfterStatus` is set, because that ID exists on a label in a wall (P5).

### 3.5 Two IDs per endpoint

The single most common on-site failure is a mismatch between what's written on the outlet plate in the bedroom and what's written on the patch panel port in the rack. So every structured-wiring endpoint stores **three** strings and the schedule prints all of them:

| Field | Example | Where it appears |
|---|---|---|
| `cableId` | `W015` | run identity, diagram trace tag, schedule col 1 |
| `fieldLabel` | `LR-TV-1` | printed on the outlet/faceplate; drop schedule |
| `panelPortLabel` | `PP-1 / A03` | printed at the patch panel; drop schedule + rear elevation |

The drop schedule (`T6.20`) has both `OUTLET ID` and `PANEL / PORT` columns side by side for exactly this reason.

### 3.6 Storage

IDs are **materialised onto the link at creation time** and stored in the `.rackmate` file. They are never recomputed from the template at render time. Changing the scheme offers to renumber; it does not silently renumber. A PDF exported yesterday and a PDF exported today from an unmodified project are byte-comparable except for the date field (§7.7).

---

## 4. Sheet furniture

All furniture is drawn through `DiagramCanvas` (P1), attached to the page via `pw.PageTheme(buildBackground:)` wrapping a `pw.FullPage(ignoreMargins: true, child: pw.CustomPaint(painter: ...))`. Consequences: it draws on *every* page including pages `MultiPage` creates by overflow, and it renders identically in the on-screen sheet preview.

> ⚠ Verify `PageTheme.buildBackground` / `buildForeground` parameter names against `pdf` 3.13.0 before writing against them.

### 4.1 Drawing border and zone grid

```
Sheet edge
  ├── 0.50" margin (0.75" on the binding edge)
  ├── outer rule      0.7 pt
  ├── 0.22" zone band ── letters left+right, numbers top+bottom, mono 7 pt
  ├── inner rule      1.0 pt
  └── drawing area
```

**Zone module** 4.25 in, minimum 2 × 2:

```dart
final cols = math.max(2, (usableW / (4.25 * 72)).round());
final rows = math.max(2, (usableH / (4.25 * 72)).round());
```

ANSI B landscape (17 × 11) → **4 × 2**: numbers `1`–`4`, letters `A`–`B`. ANSI D → 8 × 5.

Origin, numbering direction, and letter direction are a project setting; default **origin lower-right, numbers increasing right-to-left, letters increasing bottom-to-top**.

> ⚠ Both the lower-right and upper-right origin conventions are in live use and I would not swear to which ASME Y14.1 mandates. It is a two-line config constant — set the default, expose the toggle, and confirm against Y14.1 Table 1 before shipping.

Zone references are what the `REF` column in the schedule and the off-sheet connectors point at, so the assignment must be computed from the *final* placed geometry, after layout, see §5.4.

### 4.2 Title block

Bottom-right, **396 × 115 pt** (5.5 × 1.6 in) on ANSI B and larger. On ANSI A the compact variant is a full-width **690 × 43 pt** strip along the bottom, so the schedule table isn't notched.

```
┌────────────────────────────────────────────────────────────────────────────┐
│  SMITH RESIDENCE — MASTER EQUIPMENT RACK                       ┌─────────┐ │
│  1428 Alder Ct, Portland OR 97214                              │  LOGO   │ │
│  CLIENT  J. & M. Smith                                         └─────────┘ │
├──────────────────────────────────────────────────────────────────────────  ┤
│  RACK INTERCONNECT — VIDEO NETS                                            │
│  RK-1  MASTER RACK  ·  42U                                                 │
├──────────────┬──────────────┬──────────────┬──────────────┬────────────────┤
│ DRAWN   J.S. │ SCALE  1:8   │ SIZE   B     │ DATE 2026-07-18│ REV       C   │
│ CHK'D    —   │ PROJ  25-1183│ DISC   T     │ FILE smith.rackmate│SHEET 5 OF 14│
├──────────────┴──────────────┴──────────────┴──────────────┴────────────────┤
│  NBS INTEGRATION LLC  ·  (503) 555-0142  ·  OR CCB #219884                 │
│  SYMBOL LEGEND: SEE SHEET T0.01          SHEET NO.  T6.01                  │
└────────────────────────────────────────────────────────────────────────────┘
```

**Fields**, all resolved from project metadata, none hand-typed at export time:

| Field | Source | Fallback |
|---|---|---|
| Project name | `project.name` | required |
| Project address | `project.address` | blank line collapses |
| Client | `project.client` | collapses |
| Rack designator + name + RU | current rack | `—` on non-rack sheets |
| Sheet title | sheet definition | required |
| Sheet number | NCS assignment (§1.1) | required |
| Sheet n of m | `ctx.pageNumber` / `ctx.pagesCount` |: |
| Date | issue date (export-time or pinned revision date) | today |
| Revision | current revision letter | `—` |
| Drawn by | `project.drawnBy` | user initials from prefs |
| Checked by | `project.checkedBy` | `—` |
| Scale | computed per sheet, `1:8` or `NTS` | `NTS` |
| Size | page format short name |: |
| Discipline | `T` |: |
| Project number | `project.number` | collapses |
| File name | source filename |: |
| Integrator block | app preferences (firm, phone, licence) | collapses |
| Legend reference | fixed `SEE SHEET T0.01` | required by J-STD-710 §3.6.1 |

**Scale is computed, not typed.** Once §5.5 picks `k`, the title block reports the nearest standard ratio if `|k − 1/n| < 2 %` for `n ∈ {1,2,4,8,10,16,20,24,32,48,64,96}`, otherwise `NTS`. Never print `1:8` on a sheet drawn at 1:8.34; someone will scale off it.

### 4.3 Revision block

Directly above the title block, same 396 pt width, header row adjacent to the title block, entries stacking **upward** (newest on top). Row height 13 pt, max 8 visible; beyond that, `SEE SHEET T0.00 FOR FULL REVISION HISTORY`.

| REV | DATE | DESCRIPTION | BY |
|---|---|---|---|
| 30 pt, centre | 62 pt, centre | 268 pt, left | 36 pt, centre |

Because the data model already carries stable UUIDs and change-tracking-friendly structure, **the revision block is generated from project history**, not hand-entered. A firm re-issuing a rack drawing after a change order gets `C · 2026-07-18 · Added AMP-2, 4 speaker runs to Zone 3 · JS` automatically. That is a real differentiator over every diagramming tool in this space, and AVIXA D401.01 §6.1 makes a formal change record mandatory, so it also earns a conformance claim.

**Revision clouds** (v1.1): for `As-built` export, draw a scalloped closed path around the bounding box of every element whose `lastModifiedRev` equals the current revision, with a triangular delta tag carrying the rev letter. Cheap once you have `DiagramPath`, a cloud is an arc-chain along a rectangle's perimeter.

### 4.4 Legend sheet (`T0.01`)

Six blocks on one ANSI B landscape sheet:

1. **Signal domain key**: one row per domain: colour sample line (as drawn), *greyscale sample line beside it*, domain name, tag prefix, member signal types. Printing both renditions side by side is what makes the greyscale export trustworthy.
2. **Connector symbol table**: every connector glyph used in the set, at drawing scale, with name. Glyphs are the `DiagramPath` SVG `d` constants from `symbols.dart`, so the legend can never drift from the drawing.
3. **Device block anatomy**: one annotated example block: designator position, name, model, port stub, port label, RU span, status border.
4. **Status & convention key**: new / existing / future / demolish borders; junction dot vs. crossing hop; bus trunk vs. point-to-point; off-sheet connector flag; home-run vs. local tag shape (J-STD-710 sanctions this, *provided the rule is stated in the legend*, so state it).
5. **Cable ID format**: the active template, expanded, with a worked example decomposed field by field.
6. **Abbreviations & general notes**: user-editable free text with a seeded default list.

J-STD-710 geometry is worth honouring for the symbols: distinctive shapes fit inside a 3/8 in (10 mm) circle, circles 0.35 in (9 mm), squares 0.25 in (6.35 mm), **all line weights 0.014 in (0.35 mm / 1 pt)**, attribute text ≥ 3/32 in (2.5 mm). These become constants in `symbols.dart`.

---

## 5. Page setup

### 5.1 Supported sizes

`PdfPageFormat` ships only `a3, a4, a5, a6, letter, legal, roll57, roll80`. Everything else you define:

```dart
// export/sheets.dart
const _in = PdfPageFormat.inch;   // 72.0
const _mm = PdfPageFormat.mm;     // 2.8346…

// ANSI / ASME Y14.1
const ansiA = PdfPageFormat( 8.5*_in, 11*_in, marginAll: 0.5*_in); //  612 ×  792
const ansiB = PdfPageFormat(  11*_in, 17*_in, marginAll: 0.5*_in); //  792 × 1224
const ansiC = PdfPageFormat(  17*_in, 22*_in, marginAll: 0.5*_in); // 1224 × 1584
const ansiD = PdfPageFormat(  22*_in, 34*_in, marginAll: 0.5*_in); // 1584 × 2448
const ansiE = PdfPageFormat(  34*_in, 44*_in, marginAll: 0.5*_in); // 2448 × 3168

// ARCH
const archA = PdfPageFormat(   9*_in, 12*_in, marginAll: 0.5*_in); //  648 ×  864
const archB = PdfPageFormat(  12*_in, 18*_in, marginAll: 0.5*_in); //  864 × 1296
const archC = PdfPageFormat(  18*_in, 24*_in, marginAll: 0.5*_in); // 1296 × 1728
const archD = PdfPageFormat(  24*_in, 36*_in, marginAll: 0.5*_in); // 1728 × 2592
const archE = PdfPageFormat(  36*_in, 48*_in, marginAll: 0.5*_in); // 2592 × 3456

// ISO — a3/a4 ship, larger do not
const isoA2 = PdfPageFormat(420*_mm, 594*_mm, marginAll: 10*_mm);  // 1190 × 1684
const isoA1 = PdfPageFormat(594*_mm, 841*_mm, marginAll: 10*_mm);  // 1684 × 2384
const isoA0 = PdfPageFormat(841*_mm,1189*_mm, marginAll: 10*_mm);  // 2384 × 3370
```

Margins are then overridden per sheet role: `EdgeInsets.fromLTRB(54, 36, 36, 36)`, the wider left edge is the binding margin, and it is what makes a bound set readable.

### 5.2 Defaults

| Sheet role | Size | Orientation | Why |
|---|---|---|---|
| Cover, legend | ANSI B | landscape | matches the set |
| **Interconnect diagrams** | **ANSI B (11 × 17)** | **landscape** | Largest size that comes out of an ordinary office MFP, plots cheaply anywhere, **folds exactly to letter** for a job binder, and is the de facto residential-CI documentation size. |
| **Rack elevations** | **ANSI B** | **portrait** | A 45 RU rack is 45 × 1.75 = 78.75 in tall. At 1:8 that's 9.84 in, fits ANSI B portrait with room for the RU rulers and gutters. Elevations are tall; forcing them landscape wastes half the sheet. |
| **Schedules** | **ANSI A** | **landscape** | Reprinted and marked up on job-site printers. §2.1. |
| Details | ANSI B | landscape | |

Locale default: `A4/A3` substituted for `ANSI A/ANSI B` when the platform locale is non-US (`A3 landscape` is the 11×17 analogue). Mixed page sizes in one PDF are fine; the export dialog has a **"Uniform sheet size"** checkbox for people whose plotter workflow needs it.

### 5.3 The two options for an oversized schematic

**Option A: geometric tiling with match lines.** Split the diagram into an overlapping grid of windows, one per sheet.

```dart
final tileW   = sheet.availableWidth  / scale;      // diagram units per sheet
final tileH   = sheet.availableHeight / scale;
final overlap = 0.5 * _in / scale;                  // 0.5" physical overlap band
final cols = ((bounds.width  - overlap) / (tileW - overlap)).ceil();
final rows = ((bounds.height - overlap) / (tileH - overlap)).ceil();
```

Each sheet carries: `MATCH LINE — SEE SHEET T6.0n` along each shared edge, feature lines terminating exactly at the match line, and a **key plan** in the corner, a 1.5 in outline of the whole diagram with the current tile hatched. The key plan is what makes a tiled set navigable, and it is nearly free: replay the same `DiagramScene` at tiny scale with stroke-only specs into a 1.5 in box.

**Option B: partition by net / subsystem with off-sheet connectors.** Each sheet holds one signal domain at full scale; nets that leave a sheet terminate in a pentagon flag carrying the net name and a `→ T6.03 / C2` reference, with a mirrored inbound flag on the destination sheet pointing back.

### 5.4 Recommendation for v1: **Option B, net partition**

Reasons, in order of weight:

1. **It's what schematic capture actually does.** Altium, KiCad, OrCAD do not tile geometrically; they partition by subsystem and use off-sheet connectors. The stated design brief is "visual inspiration from electronics board diagrams and schematics." This *is* that idiom.
2. **Nothing shrinks.** Every sheet is drawn at full scale, so text never approaches the legibility floor and line weights stay honest. Tiling forces a global scale that must satisfy the worst sheet.
3. **It matches how installers work.** They pull all the Cat6, then all the speaker wire, then terminate. A sheet per domain is a work packet.
4. **It makes the colour coding an organising principle instead of a rainbow.** One dominant hue per sheet, with cross-domain nets appearing as flags, far more legible than eight interleaved colours on one sheet.
5. **The Structure device falls out naturally.** Home runs are, definitionally, signals arriving from off-sheet. Rendering the Structure device as a bank of off-sheet connector flags on the left edge of `T6.06` is both the schematic convention and the TIA-570-D reality. It also makes **unused home runs visually obvious**, which is a genuinely valuable deliverable.

Default partition, in sheet order:

| Sheet | Domain | Nets |
|---|---|---|
| `T6.01` | Video | HDMI, HDBaseT, DP, SDI, AV-over-IP, RF/coax, analog video |
| `T6.02` | Audio | analog line, balanced, speaker level, 70 V, S/PDIF, TOSLINK, AES3, Dante |
| `T6.03` | Network | Ethernet, PoE, fibre |
| `T6.04` | Control | IR, RS-232, RS-485, contact closure, 12 V trigger, Cresnet, DALI, KNX, DMX |
| `T6.05` | Power | branch circuits, PDU, UPS, sequencer, IEC |
| `T6.06` | Structure | all structured-wiring home runs, grouped by room |

The partition is user-editable, merge Audio+Video into "AV", split Control into "Control" and "Lighting", whatever the job wants. A net whose domain has zero connections produces no sheet.

**Off-sheet connector geometry:**

```
outbound                          inbound
       ╭───────────────╮      ╭───────────────╮
───────┤ HDMI-OUT-3    ╲      ╱ HDMI-OUT-3    ├───────
       │ →T6.03 / C2   ╱      ╲ ←T6.01 / B4   │
       ╰───────────────╯      ╰───────────────╯
        54 × 14 pt, pentagon; net name mono 7; ref mono 6
```

References are resolved in a **second pass**, after all sheets are laid out and zone assignment is known. The exporter therefore has three phases: build scenes → place and assign zones → resolve cross-references → emit. That phase split also gives the progress reporter its natural stages (§7.2).

**Option A stays in the codebase** as `TilingStrategy.geometric`, exposed for the user who insists on one continuous interconnect drawing, and used automatically for a single rack elevation of an over-tall rack (e.g. 50 RU at 1:6). It's ~80 lines given the transform stack, and match-line drawing is a `drawPolyline` with a label.

### 5.5 Scale-to-fit, and the automatic tiling trigger

```dart
double fitScale(Box content, Box avail) =>
    math.min(avail.width / content.width, avail.height / content.height);
```

Two things this must get right:

**Line weights must not scale.** A 0.5 pt hairline at k = 0.3 becomes 0.15 pt, below what most RIPs render meaningfully. `Stroke.hairlineFloor` tells the backend to divide the width by the current uniform scale so the mark holds a **0.25 pt floor**. Applied to: drawing border, zone grid, title block rules, key plan. *Not* applied to cable traces, which should scale, a de-emphasised trace at small scale is correct.

**Text must stay legible, and this is the tiling trigger, not a user decision.** The user's real question is "can I read this", not "how many sheets do I want":

```dart
const kMinPrintPt = 6.0;      // hard floor for print legibility
const kSoftPt     = 7.0;      // preferred

if (k * scene.minTextSizePt < kMinPrintPt) {
  // do not fit; escalate in this order:
  //  1. next larger sheet size, if the user allowed size escalation
  //  2. net partition into more sheets  (Option B — default)
  //  3. geometric tiling                (Option A — fallback)
}
```

Report the outcome in the export summary: *"Video nets exceeded one sheet at legible scale, split into T6.01 and T6.01a by source device."*

### 5.6 Why raster is disqualified: the arithmetic

For the record, so nobody proposes it again:

| Sheet | @300 dpi | Mpx | RGBA bytes |
|---|---|---|---|
| ANSI A | 2550 × 3300 | 8.4 | 33.7 MB |
| **ANSI B** | **3300 × 5100** | **16.8** | **67.3 MB** |
| ANSI B @600 (laser native) | 6600 × 10200 | 67.3 | 269 MB |
| ANSI D @300 | 6600 × 10200 | 67.3 | 269 MB |

- `pixelRatio` for 300 dpi is `300/72 = 4.167`.
- The decoded `ui.Image` is 64 MiB; PNG encoding needs a second buffer → **~135 MB peak for one sheet**, multiplied by sheet count.
- **5100 px exceeds the 4096 max texture dimension** on a large installed base (older Intel iGPUs, many Android devices). Flutter silently clamps, flutter/flutter #118024, #116957, #21269. You get a quietly blurry sheet with no error, which is the worst possible failure mode for a deliverable.
- 6 pt schematic text at 300 dpi is 25 px tall, antialiased into mush.
- **You lose text selection and search.** An installer who can't `Ctrl+F` a cable ID in a 3-page schedule has a materially worse document.
- Vector rack diagram ≈ 80–400 KB. 300 dpi PNG-in-PDF ≈ 3–15 MB **per sheet**.

Raster survives in exactly two places: the client logo in the title block (pre-scaled to 2× its final slot), and the project-browser thumbnail at 1×.

---

## 6. Renderer architecture

**This is the section that matters.** Everything above is policy; this is the thing that's expensive to change later.

There is no off-the-shelf abstraction over `dart:ui Canvas` and `PdfGraphics`. dart_pdf ships no Canvas facade; Syncfusion's `PdfGraphics` is a different, incompatible, commercially-licensed API. The answer is ~350 lines you write once.

### 6.1 Layering and the Flutter firewall

```
model/                          RackProject · Device · Port · PhysicalLink · LogicalSignal
  │                             pure Dart, JSON-serialisable, immutable
  ▼
diagram/scene_builder.dart      buildScene(project, style, measurer) → DiagramScene
  │                             THE renderer. Pure Dart. No dart:ui. No pdf.
  ▼
DiagramScene { List<DiagramOp> ops; Box bounds; List<HitRegion> hits; double minTextSizePt; }
  │
  ├─► FlutterDiagramCanvas   (dart:ui Canvas)     → CustomPainter → screen + preview
  ├─► PdfDiagramCanvas       (PdfGraphics)        → pw.CustomPaint → PDF          [pure Dart]
  ├─► SvgDiagramCanvas       (StringBuffer)       → .svg export                   [pure Dart]
  └─► BoundsCanvas           (accumulator)        → bounds + hit regions          [pure Dart]
```

**Everything under `diagram/` except `backends/flutter_canvas.dart` must import without Flutter.** Enforce it:

```yaml
# test/headless/headless_test.dart runs under `dart test`, not `flutter test`
```
```dart
// test/headless/headless_test.dart
import 'package:rackmate/diagram/scene_builder.dart';
import 'package:rackmate/export/document.dart';

void main() {
  test('full document builds with no Flutter binding', () async {
    final bytes = await buildDocument(fixtureProjectJson, fixtureAssets, defaultSheetSpec);
    expect(bytes.length, greaterThan(10000));
  });
}
```

If that test compiles and passes under `dart test`, then isolate export works (§7.3) *and* server-side export works later. If someone adds `import 'dart:ui'` to the scene builder, it stops compiling. That one guardrail protects the whole architecture, and it is why the geometry types below are hand-rolled instead of `ui.Offset`/`ui.Rect`.

**Unit convention: 1 diagram unit = 1 PDF point = 1/72 in.** Zero conversion on export, natural 1:1 default zoom on screen, and `k` is directly the drawing scale.

**Coordinate convention: top-left origin, Y increases downward, angles positive clockwise.** Matches screen intuition and every layout calculation you'll write; the PDF backend absorbs the flip once (§6.5).

### 6.2 Value types

```dart
// diagram/geometry.dart — pure Dart
final class Pt {
  final double x, y;
  const Pt(this.x, this.y);
  Pt operator +(Pt o) => Pt(x + o.x, y + o.y);
  Pt operator -(Pt o) => Pt(x - o.x, y - o.y);
  Pt operator *(double k) => Pt(x * k, y * k);
  @override bool operator ==(Object o) => o is Pt && o.x == x && o.y == y;
  @override int get hashCode => Object.hash(x, y);
}

final class Box {
  final double left, top, width, height;
  const Box(this.left, this.top, this.width, this.height);
  const Box.ltrb(double l, double t, double r, double b)
      : left = l, top = t, width = r - l, height = b - t;
  double get right  => left + width;
  double get bottom => top + height;
  Pt get center => Pt(left + width / 2, top + height / 2);
  Box inflate(double d) => Box(left - d, top - d, width + 2 * d, height + 2 * d);
  Box union(Box o) => Box.ltrb(math.min(left, o.left), math.min(top, o.top),
                               math.max(right, o.right), math.max(bottom, o.bottom));
  static const zero = Box(0, 0, 0, 0);
}

final class Radii {
  final double tl, tr, br, bl;
  const Radii.all(double r) : tl = r, tr = r, br = r, bl = r;
  const Radii(this.tl, this.tr, this.br, this.bl);
}
```

**Transform currency is `vector_math_64.Matrix4`**: pure Dart, already a transitive dependency of `pdf`, accepted directly by `PdfGraphics.setTransform(Matrix4)`, and `Matrix4.storage` is exactly the column-major `Float64List(16)` that `ui.Canvas.transform` wants. Zero conversion on either side. Do not hand-roll a `Mat3`.

```dart
// diagram/style.dart — pure Dart
enum StrokeCap  { butt, round, square }
enum StrokeJoin { miter, round, bevel }
enum FillRule   { nonZero, evenOdd }
enum FontRef    { body, bodyBold, mono, monoBold, condensed }

/// 12-way anchor. `baseline*` variants position by the text baseline,
/// which is what you want for anything aligned to a rule or a port stub.
enum TextAnchor {
  topLeft, topCenter, topRight,
  midLeft, midCenter, midRight,
  bottomLeft, bottomCenter, bottomRight,
  baselineLeft, baselineCenter, baselineRight,
}

final class Stroke {
  final int argb;                 // 0xAARRGGBB, sRGB
  final double widthPt;
  final List<double>? dash;       // null = solid; units = points
  final double dashPhase;
  final StrokeCap cap;
  final StrokeJoin join;
  final double miterLimit;        // 10.0 — matches the PDF default (§6.6)
  final bool hairlineFloor;       // divide width by current uniform scale

  const Stroke(this.argb, this.widthPt, {
    this.dash, this.dashPhase = 0,
    this.cap = StrokeCap.butt, this.join = StrokeJoin.miter,
    this.miterLimit = 10.0, this.hairlineFloor = false,
  });

  // Value equality is REQUIRED — it's what lets the graphics-state cache work (§6.9).
  @override bool operator ==(Object o) => o is Stroke
      && o.argb == argb && o.widthPt == widthPt && o.dashPhase == dashPhase
      && o.cap == cap && o.join == join && o.miterLimit == miterLimit
      && o.hairlineFloor == hairlineFloor && _listEq(o.dash, dash);
  @override int get hashCode => Object.hash(
      argb, widthPt, dashPhase, cap, join, miterLimit, hairlineFloor,
      dash == null ? 0 : Object.hashAll(dash!));
}

final class Fill {
  final int argb;
  final FillRule rule;
  const Fill(this.argb, {this.rule = FillRule.nonZero});
  @override bool operator ==(Object o) => o is Fill && o.argb == argb && o.rule == rule;
  @override int get hashCode => Object.hash(argb, rule);
}

final class TextStyleSpec {
  final FontRef font;
  final double sizePt;
  final int argb;
  final TextAnchor anchor;
  final double rotationRad;       // positive = clockwise in diagram space
  final double letterSpacing;     // points, added per glyph
  const TextStyleSpec({
    required this.font, required this.sizePt, required this.argb,
    this.anchor = TextAnchor.baselineLeft,
    this.rotationRad = 0, this.letterSpacing = 0,
  });
}

final class TextMetrics {
  final double advanceWidth, ascent, descent, capHeight, xHeight, lineHeight;
  const TextMetrics({...});
  double get height => ascent + descent;
}
```

**Immediate-mode value objects, not retained setters.** Colour, stroke width, and dash travel *with* the draw call rather than as canvas state. Three reasons: it's stateless and therefore trivially recordable; `Stroke`/`Fill` become hashable, which is what makes the state cache in §6.9 possible; and a recorder can't get out of sync with an interpreter. This is the same choice Flutter's `Paint` makes and for the same reasons.

### 6.3 Paths

Symbols need arcs and curves, not just polylines, and round-tripping through SVG `d` strings on every frame is both slow and lossy. So: a pure-Dart path builder that both backends replay verb-by-verb, with SVG parsing as an *authoring* convenience only.

```dart
// diagram/path.dart — pure Dart
enum _Verb { move, line, cubic, quad, close }

final class DiagramPath {
  final List<_Verb> verbs = [];
  final List<double> coords = [];

  void moveTo(double x, double y)  { verbs.add(_Verb.move); coords.addAll([x, y]); }
  void lineTo(double x, double y)  { verbs.add(_Verb.line); coords.addAll([x, y]); }
  void cubicTo(double x1, double y1, double x2, double y2, double x3, double y3)
      { verbs.add(_Verb.cubic); coords.addAll([x1,y1,x2,y2,x3,y3]); }
  void quadTo(double x1, double y1, double x2, double y2)
      { verbs.add(_Verb.quad); coords.addAll([x1,y1,x2,y2]); }
  void close()                     { verbs.add(_Verb.close); }

  void addRect(Box r) { moveTo(r.left, r.top); lineTo(r.right, r.top);
                        lineTo(r.right, r.bottom); lineTo(r.left, r.bottom); close(); }

  static const kappa = 0.5522847498307933;

  void addRoundRect(Box r, Radii q) {
    moveTo(r.left + q.tl, r.top);
    lineTo(r.right - q.tr, r.top);
    cubicTo(r.right - q.tr*(1-kappa), r.top,  r.right, r.top + q.tr*(1-kappa),
            r.right, r.top + q.tr);
    lineTo(r.right, r.bottom - q.br);
    cubicTo(r.right, r.bottom - q.br*(1-kappa), r.right - q.br*(1-kappa), r.bottom,
            r.right - q.br, r.bottom);
    lineTo(r.left + q.bl, r.bottom);
    cubicTo(r.left + q.bl*(1-kappa), r.bottom, r.left, r.bottom - q.bl*(1-kappa),
            r.left, r.bottom - q.bl);
    lineTo(r.left, r.top + q.tl);
    cubicTo(r.left, r.top + q.tl*(1-kappa), r.left + q.tl*(1-kappa), r.top,
            r.left + q.tl, r.top);
    close();
  }

  void addEllipse(Pt c, double rx, double ry) { /* four kappa cubics */ }

  /// Arc chain used for revision clouds and for schematic "hop" jumpers.
  void addArc(Pt c, double r, double startRad, double sweepRad) { /* … */ }

  /// Authoring convenience only — parse once into constants at startup,
  /// never per frame. Symbol library lives as `d` strings for readability.
  factory DiagramPath.fromSvg(String d) => _parseSvgPath(d);

  Box computeBounds() { /* control-point hull, tightened for cubics */ }
}
```

`symbols.dart` then holds the connector iconography as SVG `d` constants parsed once into `DiagramPath` at startup, legible in source, identical on both backends, and matching J-STD-710's geometry constants.

### 6.4 The interface

```dart
// diagram/canvas.dart — pure Dart, zero imports beyond geometry/style/path
abstract interface class DiagramCanvas {

  // ── state stack ───────────────────────────────────────────────────────────
  void save();
  void restore();
  int  get saveCount;

  // ── transform (all CONCATENATE onto the current CTM) ─────────────────────
  void translate(double dx, double dy);
  void scale(double sx, [double? sy]);          // sy defaults to sx
  void rotate(double radians);                  // positive = clockwise
  void transform(Matrix4 m);
  Matrix4 get currentTransform;                 // for hairlineFloor + hit-test

  // ── clip (intersective; undone only by restore()) ────────────────────────
  void clipRect(Box r);
  void clipPath(DiagramPath p, {FillRule rule = FillRule.nonZero});

  // ── primitives ────────────────────────────────────────────────────────────
  void drawLine(Pt a, Pt b, Stroke s);
  void drawPolyline(List<Pt> pts, Stroke s, {bool close = false});
  void drawPath(DiagramPath p, {Fill? fill, Stroke? stroke});
  void drawRect(Box r, {Fill? fill, Stroke? stroke});
  void drawRoundRect(Box r, Radii radii, {Fill? fill, Stroke? stroke});
  void drawCircle(Pt c, double radius, {Fill? fill, Stroke? stroke});
  void drawEllipse(Pt c, double rx, double ry, {Fill? fill, Stroke? stroke});
  void drawText(String text, Pt at, TextStyleSpec style);
  void drawImage(ImageRef image, Box dst, {double opacity = 1.0});

  // ── measurement — identical on every backend by construction (§6.7) ──────
  TextMetrics measureText(String text, TextStyleSpec style);

  // ── capability probe (for the SVG backend and future targets) ────────────
  RendererCaps get caps;
}

final class RendererCaps {
  final bool nativeDash;        // PDF true, Flutter false (synthesised)
  final bool nativeAlpha;       // PDF true only via ExtGState
  final bool nativeRoundRect;   // both false — built from cubics
  final bool textSelectable;    // PDF true, screen false
  const RendererCaps({...});
}
```

Notes on shape:

- **`fill` and `stroke` are both optional and both may be present.** `dart:ui` needs two passes with two `Paint`s; PDF needs the path built once and painted with `B` (fill-then-stroke), or, more portably given `PdfGraphics`'s API surface, built twice. The adapter absorbs this; callers never think about it.
- **`drawPolyline` is separate from `drawPath`** because orthogonal traces are the single hottest primitive in this app and they deserve a path that skips `DiagramPath` allocation entirely.
- **No gradients, no shadows, no blurs, no blend modes, no shaders.** `PdfGraphics` supports none of them meaningfully, and the schematic aesthetic doesn't want them. Constraining the visual language to flat fills, strokes, dashes and text is what makes the two backends agree *exactly* rather than approximately. This is a feature.

### 6.5 The Y-axis, and why the global flip wins

PDF user space is bottom-left origin, Y-up. Our diagram space is top-left, Y-down. Two strategies:

**(a) Per-coordinate flip**: `_y(y) => h - y` at every call site inside the adapter. Ten lines, no global transform, and text stays upright for free.

**(b) Global flip**: push `Matrix4(1,0,0,-1, 0,h)` once at the top; every subsequent coordinate passes through verbatim.

**Take (b).** The reason is that the interface exposes `rotate()` and `transform()`. Under (a), a caller's rotation composes with the flip incorrectly, `_y()` is applied to the *pre-transform* coordinates while the CTM is applied by PDF afterwards, so any non-translation transform silently produces mirrored or displaced geometry. That's an entire class of bug that appears only when someone finally rotates a label 90° for a vertical rack rail, and it will be diagnosed as "the PDF is wrong" three months after the code was written.

Under (b), transforms compose naturally and correctly, and the flip's only cost is that `drawString` renders mirrored, which is handled in **exactly one method**. Text already needs a `save`/`restore` for rotation anyway, so the marginal cost is a matrix multiply per text run, not a new q/Q pair.

The global flip also has a pleasant side effect: `PdfGraphics.drawRect(x, y, w, h)` normally wants the *bottom* edge, but under the flip, passing `(r.left, r.top, r.width, r.height)` produces a rectangle spanning `top … top+height` in flipped coordinates, i.e. exactly our `Box`, verbatim, with no `y' = H − top − height` arithmetic anywhere.

**One gotcha that will eat an afternoon if missed.** `pw.CustomPaint` pre-translates the canvas to the *widget box's bottom-left* before calling your painter:

```dart
// pdf/widgets/custom_paint.dart, paraphrased from source
final mat = Matrix4.identity()..translateByDouble(box!.left, box!.bottom, 0, 1);
context.canvas..saveContext()..setTransform(mat);
painter(canvas, size);
```

So the height you flip about is **`size.y`, the widget's height, not the page height.** Getting this wrong offsets every diagram vertically by the margin, and the result looks plausible enough to ship.

### 6.6 Divergences and how each is reconciled

| # | Concern | `dart:ui Canvas` | `PdfGraphics` | Reconciliation |
|---|---|---|---|---|
| 1 | Origin / Y sense | top-left, Y-down | bottom-left, Y-up | Global flip in the PDF adapter (§6.5). Diagram space is canonical. |
| 2 | Paint model | immutable `Paint` per call | stateful setters + `strokePath()` | Adapter owns the state; interface stays immediate-mode. |
| 3 | Path model | build `Path`, `drawPath(path, paint)` | stateful `moveTo`/`lineTo` + `fillPath()` | Adapter replays `DiagramPath` verbs into whichever shape the backend wants. |
| 4 | Fill **and** stroke | one `Paint`, two `drawPath` calls | build path twice, or `B` operator | Adapter emits the path twice. Costs bytes, not correctness; §6.9 mitigates. |
| 5 | **Dash** | **none: `dart:ui` has no dashing at all** | native `setLineDashPattern` | Flutter side synthesises with `path_drawing`'s `dashPath`. **Cache the dashed `ui.Path` per (geometry, dash) pair**: regenerating on every frame for a few hundred dashed traces is a real frame-budget problem. Keep `dashPhase` at 0 for parity: PDF's phase is an offset into the pattern, `dashPath` restarts per sub-path. |
| 6 | **Text metrics** | `TextPainter`, full shaping + kerning | `PdfFont.stringMetrics`, unkerned advances | **Use `PdfFont.stringMetrics` as the single source of truth on both backends** (§6.7). |
| 7 | **Kerning / ligatures** | Skia applies GPOS kerning and `liga` | dart_pdf applies neither | Disable them on the Flutter side: `fontFeatures: [FontFeature.disable('kern'), FontFeature.disable('liga')]`. Without this, screen text is 1–3 % narrower than print text and every leader line, callout box and collision-avoidance calculation disagrees between the two. |
| 8 | **Colour space** | `ui.Color`, sRGB, 8-bit ARGB | `PdfColor`, 4 × double 0…1, **DeviceRGB** | `PdfColor.fromInt(argb)`. DeviceRGB is unmanaged: most viewers assume sRGB, but a print house's RIP may shift it. Mitigations: (a) offer a **CMYK export** using `PdfColorCmyk` for offset/plotter work, with pure black as `0,0,0,1` not rich black; (b) offer greyscale export using explicit grey values, not luminance-converted RGB; (c) v1.1, embed an sRGB `OutputIntent`. For v1, DeviceRGB is correct and the palette is chosen to be robust to modest shifts. |
| 9 | **Alpha** | per-`Paint` alpha channel | no per-paint alpha; needs `ExtGState` | Adapter detects `argb >>> 24 != 0xFF` and emits `setGraphicState(PdfGraphicState(fillOpacity:, strokeOpacity:))`, bracketed by save/restore. **Better: don't use alpha in the diagram.** Use pre-composited tints (18 % of a colour over white, computed at palette definition time) instead. Alpha in PDF also interacts badly with some plotters. Reserve alpha for on-screen selection highlight only, which never reaches the PDF. ⚠ Verify `setGraphicState` / `PdfGraphicState` field names on 3.13.0. |
| 10 | **Line join & miter limit** | `StrokeJoin`, `strokeMiterLimit` default **4** | `setLineJoin`, PDF default miter limit **10**, and `PdfGraphics` may not expose a setter | Set `strokeMiterLimit = 10` on the Flutter side to match PDF's default rather than the reverse. In practice this is invisible for orthogonal traces (a 90° miter ratio is √2 ≈ 1.414, far below either limit) but symbol paths with acute angles will spike differently, and matching the defaults costs one line. |
| 11 | Line cap | `StrokeCap`, default butt | `setLineCap(PdfLineCap)`, default butt | 1:1. Note round caps + dashes change apparent dash length on both; keep butt for dashed traces. |
| 12 | Transform | `Canvas.transform(Float64List)` concatenates | `setTransform(Matrix4)` **concatenates** (emits `cm`) despite the name | 1:1: both concatenate. `Matrix4.storage` feeds `Canvas.transform` directly. Always bracket with save/restore. |
| 13 | Clip | part of save/restore, intersective | `clipPath()` consumes the *current path*, intersective, undone only by `restoreContext` | Adapter builds the path then calls `clipPath`. Semantics match; no "unclip" on either side. |
| 14 | Zero-width strokes | `strokeWidth = 0` → 1 device pixel hairline | width 0 → thinnest device line (invisible on a 2400 dpi imagesetter) | **Never emit width 0.** Clamp to 0.25 pt in `_applyStroke` on both backends. |
| 15 | Winding under flip |: | the global flip reverses winding direction | Only matters for `evenOdd` vs `nonZero` on nested subpaths. Symbol paths avoid nesting; `addEllipse` emits a consistent direction. Note it and move on. |
| 16 | Text wrapping | `TextPainter` wraps and shapes | `drawString` is single-line, baseline-origin, no wrap | The interface has no wrapping. Multi-line text is the caller's job: measure, split, emit N `drawText` calls at a computed leading. Correct, layout belongs in the scene builder, not the backend. |
| 17 | Images | `Canvas.drawImage`, full formats | `PdfImage`, JPEG/PNG, pre-decoded | `ImageRef` is an opaque handle resolved per backend from the same `Uint8List`. Only used for the logo. |
| 18 | Antialiasing | on by default | resolution-independent, N/A | No action. |

### 6.7 Text metrics: the single most important reconciliation

The trap: measure with `TextPainter` on screen and with `stringMetrics` in the PDF, and every measured width differs, so leader lines, callout boxes, port-label collision avoidance, and centred text all disagree between screen and print. It will be reported as "the PDF doesn't match the preview" and it will be miserable to chase.

**The fix is to eliminate `TextPainter` from the layout path entirely.**

`PdfFont` / `PdfTtfFont` is **pure Dart**: it lives in the `pdf` package, which has no Flutter dependency. So it can be loaded and queried on the screen side, in the scene builder, and inside an isolate, identically. Therefore:

1. Bundle the TTF once, as **both** a Flutter font asset **and** a raw asset (§9.3).
2. Load it into a `PdfTtfFont` in every context, main isolate, background isolate, screen renderer.
3. Inject a `TextMeasurer` into the scene builder, backed by `PdfFont.stringMetrics`.
4. `DiagramCanvas.measureText` delegates to that same measurer on **every** backend, including the Flutter one.
5. `FlutterDiagramCanvas.drawText` still uses `TextPainter` to *rasterise* the glyphs, Skia is far better at that than anything you'd write, but it **anchors using the injected metrics**, not `TextPainter`'s. Combined with kerning disabled (divergence #7), the two agree to sub-point.

```dart
// diagram/text.dart — pure Dart
abstract interface class TextMeasurer {
  TextMetrics measure(String text, FontRef font, double sizePt, double letterSpacing);
}

/// The one implementation. Used by both backends.
final class PdfFontMeasurer implements TextMeasurer {
  PdfFontMeasurer(this._fonts);
  final Map<FontRef, PdfFont> _fonts;
  final _cache = <(String, FontRef, double, double), TextMetrics>{};

  @override
  TextMetrics measure(String t, FontRef f, double size, double ls) =>
      _cache.putIfAbsent((t, f, size, ls), () {
        final font = _fonts[f]!;
        final m = font.stringMetrics(t) * size;   // ⚠ verify operator, §6.10
        return TextMetrics(
          advanceWidth: m.advanceWidth + ls * math.max(0, t.length - 1),
          ascent: m.ascent.abs() * size / size,   // stringMetrics already scaled
          descent: m.descent.abs(),
          capHeight: font.ascent * size * 0.72,
          xHeight:  font.ascent * size * 0.52,
          lineHeight: (font.ascent - font.descent) * size,
        );
      });
}
```

Cache aggressively, a rack sheet re-measures the same designators hundreds of times.

**Anchor resolution** (shared by both backends, so it lives in one pure-Dart helper):

```dart
Pt anchorOffset(TextAnchor a, TextMetrics m) {
  final w = m.advanceWidth;
  final dx = switch (a) {
    TextAnchor.topLeft || TextAnchor.midLeft || TextAnchor.bottomLeft
      || TextAnchor.baselineLeft => 0.0,
    TextAnchor.topCenter || TextAnchor.midCenter || TextAnchor.bottomCenter
      || TextAnchor.baselineCenter => -w / 2,
    _ => -w,
  };
  final dy = switch (a) {                       // returns offset to the BASELINE
    TextAnchor.topLeft || TextAnchor.topCenter || TextAnchor.topRight => m.ascent,
    TextAnchor.midLeft || TextAnchor.midCenter || TextAnchor.midRight
      => m.ascent - m.height / 2,
    TextAnchor.bottomLeft || TextAnchor.bottomCenter || TextAnchor.bottomRight
      => -m.descent,
    _ => 0.0,                                   // baseline* variants
  };
  return Pt(dx, dy);
}
```

Both `drawText` implementations call this and then position by baseline. Identical geometry, no duplicated logic.

### 6.8 Adapter implementations

#### 6.8.1 PDF backend

```dart
// diagram/backends/pdf_canvas.dart — PURE DART. Isolate-safe. No Flutter.
import 'dart:math' as math;
import 'package:pdf/pdf.dart';
import 'package:vector_math/vector_math_64.dart' show Matrix4;
import '../canvas.dart';
import '../geometry.dart';
import '../path.dart';
import '../style.dart';
import '../text.dart';

final class PdfDiagramCanvas implements DiagramCanvas {
  PdfDiagramCanvas({
    required PdfGraphics graphics,
    required double boxHeight,          // MUST be pw.CustomPaint's size.y — §6.5
    required Map<FontRef, PdfFont> fonts,
    required TextMeasurer measurer,
  })  : _g = graphics, _fonts = fonts, _measurer = measurer {
    // One global flip: diagram Y-down -> PDF Y-up. Everything after is verbatim.
    _g.saveContext();
    _g.setTransform(Matrix4.identity()
      ..setEntry(1, 3, boxHeight)       // translate y by boxHeight
      ..setEntry(1, 1, -1.0));          // scale y by -1
    _stack.add(Matrix4.identity());
  }

  final PdfGraphics _g;
  final Map<FontRef, PdfFont> _fonts;
  final TextMeasurer _measurer;
  final List<Matrix4> _stack = [];

  /// Call once when finished to balance the constructor's saveContext.
  void dispose() => _g.restoreContext();

  static const double _kMinStroke = 0.25;   // pt — divergence #14

  static PdfColor _col(int argb) => PdfColor.fromInt(argb);

  @override RendererCaps get caps => const RendererCaps(
      nativeDash: true, nativeAlpha: true, nativeRoundRect: false,
      textSelectable: true);

  @override Matrix4 get currentTransform => _stack.last.clone();

  // ── state ────────────────────────────────────────────────────────────────
  @override int get saveCount => _stack.length;
  @override void save()    { _g.saveContext(); _stack.add(_stack.last.clone()); }
  @override void restore() { _g.restoreContext(); _stack.removeLast(); }

  // ── transform (PDF `cm` concatenates — matches our contract) ─────────────
  @override void translate(double dx, double dy) => _apply(
      Matrix4.identity()..setEntry(0,3,dx)..setEntry(1,3,dy));
  @override void scale(double sx, [double? sy]) => _apply(
      Matrix4.identity()..setEntry(0,0,sx)..setEntry(1,1,sy ?? sx));
  @override void rotate(double r) => _apply(Matrix4.rotationZ(r));
  @override void transform(Matrix4 m) => _apply(m);

  void _apply(Matrix4 m) { _g.setTransform(m); _stack.last.multiply(m); }

  /// Uniform scale factor of the CTM — powers `hairlineFloor`.
  double get _uniformScale {
    final m = _stack.last;
    return math.sqrt((m.entry(0,0) * m.entry(1,1) - m.entry(0,1) * m.entry(1,0)).abs());
  }

  // ── clip ─────────────────────────────────────────────────────────────────
  @override void clipRect(Box r) {
    _g..drawRect(r.left, r.top, r.width, r.height)..clipPath();
  }
  @override void clipPath(DiagramPath p, {FillRule rule = FillRule.nonZero}) {
    _emitPath(p);
    _g.clipPath(evenOdd: rule == FillRule.evenOdd);
  }

  // ── paint state ──────────────────────────────────────────────────────────
  void _applyStroke(Stroke s) {
    final k = _uniformScale;
    var w = s.hairlineFloor ? s.widthPt / (k == 0 ? 1 : k) : s.widthPt;
    if (w * k < _kMinStroke) w = _kMinStroke / (k == 0 ? 1 : k);
    _g..setStrokeColor(_col(s.argb))
      ..setLineWidth(w)
      ..setLineCap(switch (s.cap) {
          StrokeCap.butt => PdfLineCap.butt,
          StrokeCap.round => PdfLineCap.round,
          StrokeCap.square => PdfLineCap.square })
      ..setLineJoin(switch (s.join) {
          StrokeJoin.miter => PdfLineJoin.miter,
          StrokeJoin.round => PdfLineJoin.round,
          StrokeJoin.bevel => PdfLineJoin.bevel })
      ..setLineDashPattern(s.dash ?? const <num>[], s.dashPhase.round());
    _maybeAlpha(s.argb, stroke: true);
  }

  void _applyFill(Fill f) {
    _g.setFillColor(_col(f.argb));
    _maybeAlpha(f.argb, stroke: false);
  }

  void _maybeAlpha(int argb, {required bool stroke}) {
    final a = (argb >>> 24) / 255.0;
    if (a >= 0.999) return;
    // ⚠ verify PdfGraphicState field names on 3.13.0
    _g.setGraphicState(stroke
        ? PdfGraphicState(strokeOpacity: a)
        : PdfGraphicState(fillOpacity: a));
  }

  // ── path emission ────────────────────────────────────────────────────────
  void _emitPath(DiagramPath p) {
    var i = 0;
    for (final v in p.verbs) {
      switch (v) {
        case _Verb.move:  _g.moveTo(p.coords[i], p.coords[i+1]); i += 2;
        case _Verb.line:  _g.lineTo(p.coords[i], p.coords[i+1]); i += 2;
        case _Verb.cubic: _g.curveTo(p.coords[i],   p.coords[i+1],
                                     p.coords[i+2], p.coords[i+3],
                                     p.coords[i+4], p.coords[i+5]); i += 6;
        case _Verb.quad:  // PDF has no quadratic — elevate to cubic
          final (x0, y0) = _current;
          final cx = p.coords[i], cy = p.coords[i+1];
          final x  = p.coords[i+2], y = p.coords[i+3];
          _g.curveTo(x0 + 2/3*(cx-x0), y0 + 2/3*(cy-y0),
                     x  + 2/3*(cx-x ), y  + 2/3*(cy-y ), x, y);
          i += 4;
        case _Verb.close: _g.closePath();
      }
    }
  }

  void _paint(DiagramPath p, Fill? fill, Stroke? stroke) {
    if (fill != null) {
      _g.saveContext(); _applyFill(fill); _emitPath(p);
      _g.fillPath(evenOdd: fill.rule == FillRule.evenOdd);
      _g.restoreContext();
    }
    if (stroke != null) {
      _g.saveContext(); _applyStroke(stroke); _emitPath(p);
      _g.strokePath(); _g.restoreContext();
    }
  }

  // ── primitives ───────────────────────────────────────────────────────────
  @override
  void drawLine(Pt a, Pt b, Stroke s) {
    _g.saveContext(); _applyStroke(s);
    _g..drawLine(a.x, a.y, b.x, b.y)..strokePath();
    _g.restoreContext();
  }

  @override
  void drawPolyline(List<Pt> pts, Stroke s, {bool close = false}) {
    if (pts.length < 2) return;
    _g.saveContext(); _applyStroke(s);
    _g.moveTo(pts.first.x, pts.first.y);
    for (var i = 1; i < pts.length; i++) _g.lineTo(pts[i].x, pts[i].y);
    _g.strokePath(close: close);
    _g.restoreContext();
  }

  @override
  void drawRect(Box r, {Fill? fill, Stroke? stroke}) {
    // Under the global flip, (left, top, w, h) is already correct — no y math.
    if (fill != null) {
      _g.saveContext(); _applyFill(fill);
      _g..drawRect(r.left, r.top, r.width, r.height)..fillPath();
      _g.restoreContext();
    }
    if (stroke != null) {
      _g.saveContext(); _applyStroke(stroke);
      _g..drawRect(r.left, r.top, r.width, r.height)..strokePath();
      _g.restoreContext();
    }
  }

  @override
  void drawRoundRect(Box r, Radii q, {Fill? fill, Stroke? stroke}) =>
      _paint(DiagramPath()..addRoundRect(r, q), fill, stroke);

  @override
  void drawCircle(Pt c, double radius, {Fill? fill, Stroke? stroke}) =>
      drawEllipse(c, radius, radius, fill: fill, stroke: stroke);

  @override
  void drawEllipse(Pt c, double rx, double ry, {Fill? fill, Stroke? stroke}) {
    if (fill != null) {
      _g.saveContext(); _applyFill(fill);
      _g..drawEllipse(c.x, c.y, rx, ry)..fillPath();
      _g.restoreContext();
    }
    if (stroke != null) {
      _g.saveContext(); _applyStroke(stroke);
      _g..drawEllipse(c.x, c.y, rx, ry)..strokePath();
      _g.restoreContext();
    }
  }

  @override
  void drawPath(DiagramPath p, {Fill? fill, Stroke? stroke}) =>
      _paint(p, fill, stroke);

  @override
  TextMetrics measureText(String t, TextStyleSpec s) =>
      _measurer.measure(t, s.font, s.sizePt, s.letterSpacing);

  @override
  void drawText(String text, Pt at, TextStyleSpec s) {
    final font = _fonts[s.font]!;
    final m    = measureText(text, s);
    final o    = anchorOffset(s.anchor, m);

    _g.saveContext();
    _applyFill(Fill(s.argb));
    // Counter-flip locally so glyphs are upright, then apply the caller's
    // rotation. Sign is negated because the local frame is now Y-up.
    _g.setTransform(Matrix4.identity()
      ..setEntry(0, 3, at.x)
      ..setEntry(1, 3, at.y)
      ..multiply(Matrix4.identity()..setEntry(1, 1, -1.0))
      ..multiply(Matrix4.rotationZ(-s.rotationRad)));
    _g.drawString(font, s.sizePt, text, o.x, -o.y,
                  charSpace: s.letterSpacing);
    _g.restoreContext();
  }

  @override
  void drawImage(ImageRef image, Box dst, {double opacity = 1.0}) {
    _g.saveContext();
    if (opacity < 0.999) _g.setGraphicState(PdfGraphicState(opacity: opacity));
    // Images are drawn in a locally unflipped frame, same trick as text.
    _g.setTransform(Matrix4.identity()
      ..setEntry(0, 3, dst.left)
      ..setEntry(1, 3, dst.bottom)
      ..multiply(Matrix4.identity()..setEntry(1, 1, -1.0)));
    _g.drawImage(image.asPdf, 0, 0, dst.width, dst.height);
    _g.restoreContext();
  }
}
```

Wiring it to a page:

```dart
doc.addPage(pw.Page(
  pageTheme: sheetTheme,                    // border + title block, §4
  build: (ctx) => pw.CustomPaint(
    size: PdfPoint(usableW, usableH),
    painter: (PdfGraphics g, PdfPoint size) {
      final c = PdfDiagramCanvas(
        graphics: g,
        boxHeight: size.y,                  // ← size.y, NOT page height (§6.5)
        fonts: fonts,
        measurer: measurer,
      );
      scene.replay(c);
      c.dispose();
    },
  ),
));
```

#### 6.8.2 Flutter backend

```dart
// diagram/backends/flutter_canvas.dart — the ONLY file under diagram/ that
// may import dart:ui. Everything else must build under `dart test`.
import 'dart:ui' as ui;
import 'package:flutter/painting.dart';
import 'package:path_drawing/path_drawing.dart';
import 'package:vector_math/vector_math_64.dart' show Matrix4;
import '../canvas.dart';
// … geometry, path, style, text

final class FlutterDiagramCanvas implements DiagramCanvas {
  FlutterDiagramCanvas(this._c, {required TextMeasurer measurer})
      : _measurer = measurer { _stack.add(Matrix4.identity()); }

  final ui.Canvas _c;
  final TextMeasurer _measurer;
  final List<Matrix4> _stack = [];

  static const double _kMinStroke = 0.25;
  static final _dashCache = <(_PathKey, _DashKey), ui.Path>{};

  @override RendererCaps get caps => const RendererCaps(
      nativeDash: false, nativeAlpha: true, nativeRoundRect: false,
      textSelectable: false);

  @override Matrix4 get currentTransform => _stack.last.clone();
  @override int get saveCount => _stack.length;
  @override void save()    { _c.save();    _stack.add(_stack.last.clone()); }
  @override void restore() { _c.restore(); _stack.removeLast(); }

  @override void translate(double dx, double dy) {
    _c.translate(dx, dy);
    _stack.last.multiply(Matrix4.identity()..setEntry(0,3,dx)..setEntry(1,3,dy));
  }
  @override void scale(double sx, [double? sy]) {
    _c.scale(sx, sy ?? sx);
    _stack.last.multiply(Matrix4.identity()..setEntry(0,0,sx)..setEntry(1,1,sy ?? sx));
  }
  @override void rotate(double r) { _c.rotate(r); _stack.last.multiply(Matrix4.rotationZ(r)); }
  @override void transform(Matrix4 m) { _c.transform(m.storage); _stack.last.multiply(m); }

  double get _uniformScale {
    final m = _stack.last;
    return math.sqrt((m.entry(0,0)*m.entry(1,1) - m.entry(0,1)*m.entry(1,0)).abs());
  }

  @override void clipRect(Box r) =>
      _c.clipRect(ui.Rect.fromLTWH(r.left, r.top, r.width, r.height));
  @override void clipPath(DiagramPath p, {FillRule rule = FillRule.nonZero}) =>
      _c.clipPath(_toUiPath(p, rule));

  ui.Paint _strokePaint(Stroke s) {
    final k = _uniformScale;
    var w = s.hairlineFloor ? s.widthPt / (k == 0 ? 1 : k) : s.widthPt;
    if (w * k < _kMinStroke) w = _kMinStroke / (k == 0 ? 1 : k);
    return ui.Paint()
      ..style = ui.PaintingStyle.stroke
      ..color = ui.Color(s.argb)
      ..strokeWidth = w
      ..strokeCap = switch (s.cap) {
          StrokeCap.butt => ui.StrokeCap.butt,
          StrokeCap.round => ui.StrokeCap.round,
          StrokeCap.square => ui.StrokeCap.square }
      ..strokeJoin = switch (s.join) {
          StrokeJoin.miter => ui.StrokeJoin.miter,
          StrokeJoin.round => ui.StrokeJoin.round,
          StrokeJoin.bevel => ui.StrokeJoin.bevel }
      ..strokeMiterLimit = s.miterLimit      // 10.0 to match PDF — divergence #10
      ..isAntiAlias = true;
  }

  ui.Paint _fillPaint(Fill f) => ui.Paint()
    ..style = ui.PaintingStyle.fill
    ..color = ui.Color(f.argb)
    ..isAntiAlias = true;

  /// dart:ui has NO dash support. Synthesise, and cache — regenerating a few
  /// hundred dashed traces every frame is a measurable frame-budget hit.
  ui.Path _dashed(ui.Path p, Stroke s) {
    if (s.dash == null) return p;
    return _dashCache.putIfAbsent((_PathKey(p), _DashKey(s.dash!)), () =>
        dashPath(p, dashArray: CircularIntervalList<double>(s.dash!)));
  }

  @override
  void drawLine(Pt a, Pt b, Stroke s) {
    if (s.dash == null) {
      _c.drawLine(ui.Offset(a.x, a.y), ui.Offset(b.x, b.y), _strokePaint(s));
    } else {
      final p = ui.Path()..moveTo(a.x, a.y)..lineTo(b.x, b.y);
      _c.drawPath(_dashed(p, s), _strokePaint(s));
    }
  }

  @override
  void drawPolyline(List<Pt> pts, Stroke s, {bool close = false}) {
    if (pts.length < 2) return;
    final p = ui.Path()..moveTo(pts.first.x, pts.first.y);
    for (var i = 1; i < pts.length; i++) p.lineTo(pts[i].x, pts[i].y);
    if (close) p.close();
    _c.drawPath(_dashed(p, s), _strokePaint(s));
  }

  @override
  void drawRect(Box r, {Fill? fill, Stroke? stroke}) {
    final rect = ui.Rect.fromLTWH(r.left, r.top, r.width, r.height);
    if (fill != null) _c.drawRect(rect, _fillPaint(fill));
    if (stroke != null) {
      if (stroke.dash == null) {
        _c.drawRect(rect, _strokePaint(stroke));
      } else {
        _c.drawPath(_dashed(ui.Path()..addRect(rect), stroke), _strokePaint(stroke));
      }
    }
  }

  @override
  void drawRoundRect(Box r, Radii q, {Fill? fill, Stroke? stroke}) {
    // Build from OUR path so the cubic control points match the PDF exactly.
    final p = _toUiPath(DiagramPath()..addRoundRect(r, q), FillRule.nonZero);
    if (fill != null) _c.drawPath(p, _fillPaint(fill));
    if (stroke != null) _c.drawPath(_dashed(p, stroke), _strokePaint(stroke));
  }

  @override
  void drawCircle(Pt c, double radius, {Fill? fill, Stroke? stroke}) {
    if (fill != null) _c.drawCircle(ui.Offset(c.x, c.y), radius, _fillPaint(fill));
    if (stroke != null) {
      if (stroke.dash == null) {
        _c.drawCircle(ui.Offset(c.x, c.y), radius, _strokePaint(stroke));
      } else {
        final p = ui.Path()..addOval(ui.Rect.fromCircle(
            center: ui.Offset(c.x, c.y), radius: radius));
        _c.drawPath(_dashed(p, stroke), _strokePaint(stroke));
      }
    }
  }

  @override void drawEllipse(Pt c, double rx, double ry, {Fill? fill, Stroke? stroke}) { /* … */ }

  @override
  void drawPath(DiagramPath p, {Fill? fill, Stroke? stroke}) {
    final ui.Path fillPathObj = _toUiPath(p, fill?.rule ?? FillRule.nonZero);
    if (fill != null) _c.drawPath(fillPathObj, _fillPaint(fill));
    if (stroke != null) _c.drawPath(_dashed(fillPathObj, stroke), _strokePaint(stroke));
  }

  @override
  TextMetrics measureText(String t, TextStyleSpec s) =>
      _measurer.measure(t, s.font, s.sizePt, s.letterSpacing);

  @override
  void drawText(String text, Pt at, TextStyleSpec s) {
    final m = measureText(text, s);                 // ← PDF metrics, not TextPainter's
    final o = anchorOffset(s.anchor, m);

    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(
        fontFamily: _familyFor(s.font),             // SAME TTF as the PDF (§9.3)
        fontSize: s.sizePt,
        color: ui.Color(s.argb),
        height: 1.0,
        leadingDistribution: TextLeadingDistribution.even,
        letterSpacing: s.letterSpacing,
        // Divergence #7: dart_pdf applies neither kerning nor ligatures.
        // Turn Skia's off so screen advances match PDF advances.
        fontFeatures: const [FontFeature.disable('kern'),
                             FontFeature.disable('liga'),
                             FontFeature.disable('clig')],
      )),
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.noScaling,             // never inherit OS text scale
    )..layout();

    _c.save();
    _c.translate(at.x, at.y);
    if (s.rotationRad != 0) _c.rotate(s.rotationRad);
    // Position by BASELINE, using our metrics — identical math to the PDF side.
    tp.paint(_c, ui.Offset(o.x, o.y - tp.computeDistanceToActualBaseline(
        TextBaseline.alphabetic)!));
    _c.restore();
  }

  @override
  void drawImage(ImageRef image, Box dst, {double opacity = 1.0}) {
    final paint = ui.Paint()..color = ui.Color.fromRGBO(0, 0, 0, opacity);
    _c.drawImageRect(image.asUi,
        ui.Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        ui.Rect.fromLTWH(dst.left, dst.top, dst.width, dst.height), paint);
  }

  ui.Path _toUiPath(DiagramPath p, FillRule rule) { /* verb replay, mirrors _emitPath */ }
}
```

Note `textScaler: TextScaler.noScaling`. Without it, a user with OS-level text scaling at 125 % sees a diagram whose labels are 25 % larger than the PDF's, and blames the PDF.

### 6.9 The display list: the fourth implementation, and why it earns its place

The interface is implemented twice for output. A third implementation, a **recorder**, costs ~60 lines and buys four things you need regardless:

```dart
// diagram/ops.dart — pure Dart
sealed class DiagramOp { void replay(DiagramCanvas c); }

final class OpLine extends DiagramOp {
  final Pt a, b; final Stroke s;
  const OpLine(this.a, this.b, this.s);
  @override void replay(DiagramCanvas c) => c.drawLine(a, b, s);
}
final class OpPolyline extends DiagramOp { /* … */ }
final class OpRect      extends DiagramOp { /* … */ }
final class OpRoundRect extends DiagramOp { /* … */ }
final class OpCircle    extends DiagramOp { /* … */ }
final class OpPath      extends DiagramOp { /* … */ }
final class OpText      extends DiagramOp { /* … */ }
final class OpImage     extends DiagramOp { /* … */ }
final class OpSave      extends DiagramOp { /* … */ }
final class OpRestore   extends DiagramOp { /* … */ }
final class OpTransform extends DiagramOp { /* … */ }
final class OpClipRect  extends DiagramOp { /* … */ }

final class SceneRecorder implements DiagramCanvas {
  final List<DiagramOp> ops = [];
  // …every method appends an op and (for text) forwards measurement
}

final class DiagramScene {
  final List<DiagramOp> ops;
  final Box bounds;                    // → scale-to-fit, tile counts, key plan
  final List<HitRegion> hits;          // → editor selection
  final double minTextSizePt;          // → the tiling trigger (§5.5)
  final Map<String, Box> anchors;      // → zone assignment for cross-refs (§5.4)
  void replay(DiagramCanvas c) { for (final op in ops) op.replay(c); }
}
```

1. **`bounds`**: you cannot compute scale-to-fit, tile counts, or a key plan without the diagram's true extent. A `BoundsCanvas` that only accumulates is another 40 lines.
2. **Hit-testing**: the editor needs to know what's under the cursor; a geometric op list gives it to you.
3. **Golden tests on pure data.** Assert on the op list with no Flutter binding, no PDF bytes, no pixel comparison. `expect(scene.ops.whereType<OpText>().map((o) => o.text), contains('RK-1'))`. This is an enormous testability win over golden-image diffing, which is flaky and platform-dependent.
4. **A fourth backend costs one file.** SVG export (§8.3) is ~120 lines on top of an architecture you already have.

### 6.10 Content-stream size, and the state cache

Every primitive above brackets itself in `saveContext`/`restoreContext`, emitting a `q`/`Q` pair per op plus a full set of `RG`/`w`/`d`/`J`/`j` operators. For a diagram with 10 000 ops that's real bloat, maybe 1.5 MB of content stream where 300 KB would do.

The fix, once you have value equality on `Stroke`/`Fill` (§6.2), is a graphics-state cache:

```dart
Stroke? _lastStroke;
Fill?   _lastFill;

void _applyStroke(Stroke s) {
  if (s == _lastStroke) return;
  _g..setStrokeColor(_col(s.argb))..setLineWidth(_resolvedWidth(s))
    ..setLineCap(...)..setLineJoin(...)
    ..setLineDashPattern(s.dash ?? const <num>[], s.dashPhase.round());
  _lastStroke = s;
}
```

…dropping the per-primitive `saveContext`/`restoreContext` and invalidating `_lastStroke`/`_lastFill` on `save`/`restore`. Then, in `scene_builder`, **sort the display list by style within each z-layer** and the state changes collapse to roughly one per unique style, under twenty for a typical sheet.

Premature for v1. Keep the hook (the equality operators, the `_last*` fields) so it's a one-day change later, and don't do it until a real project produces a file you'd be embarrassed to email.

### 6.11 Items to verify before writing against them

Cheap to confirm empirically, expensive to discover late. Write a 30-line spike that exercises all five and prints the results.

1. `PdfFont.stringMetrics(String)` exact signature, and whether the `PdfFontMetrics * double` operator exists in 3.13.0. Everything in §6.7 funnels through one wrapper method, so a fix is localised, but confirm before building on it.
2. Whether `Table.headerCount` actually repeats the header on each page fragment. §2.6 sidesteps this by paginating manually; confirm anyway so you know whether the workaround is necessary.
3. `PageTheme.buildBackground` / `buildForeground` parameter names on 3.13.0.
4. `PdfGraphics.setGraphicState` and `PdfGraphicState`'s field names (`opacity` / `fillOpacity` / `strokeOpacity`).
5. The rotation sign in `drawText`'s counter-flip matrix (§6.8.1). Render `drawText('ABC', Pt(100,100), rotationRad: pi/4)` on both backends, overlay them, and confirm they rotate the same way. Sign errors here are invisible until someone rotates a label.

---

## 7. Export UX

### 7.1 The dialog

Three columns: **What** (left), **How** (middle), **Preview** (right, live).

```
╔═══════════════════════════════════════════════════════════════════════════════════╗
║  Export PDF — Smith Residence                                                     ║
╠═══════════════════════╤═══════════════════════════════╤═══════════════════════════╣
║ PRESET                │ PAGE SETUP                    │  ┌─────────────────────┐  ║
║ ◉ Full set            │ Diagram sheets                │  │                     │  ║
║ ○ Installer set       │   [ANSI B (11×17) ▾] [Landsc▾]│  │   live sheet        │  ║
║ ○ Client set          │ Schedule sheets               │  │   preview           │  ║
║ ○ As-built            │   [ANSI A (8.5×11)▾][Landsc▾]│  │   (screen renderer) │  ║
║ ○ This sheet only     │   ☐ Match diagram size        │  │                     │  ║
║ ○ Custom…             │ Elevations   [Portrait ▾]     │  └─────────────────────┘  ║
║                       │ Units        [Imperial ▾]     │   ◀  3 / 14  ▶            ║
║ SHEETS       14 total │                               │   T6.01 Interconnect —    ║
║ ☑ T0.00 Cover & index │ DIAGRAM                       │   Video nets              ║
║ ☑ T0.01 Legend        │ Split  [By signal domain   ▾] │                           ║
║ ☑ T2.01 RK-1 front    │        · By signal domain     │   ⚠ 2 notices             ║
║ ☑ T2.02 RK-1 rear     │        · By rack              │   · Video nets split into ║
║ ☑ T6.01 Video   ⚠     │        · Single sheet (tile)  │     T6.01 and T6.01a to   ║
║ ☑ T6.02 Audio         │ Scale  [Fit to sheet       ▾] │     stay legible at 7 pt  ║
║ ☑ T6.03 Network       │        · 1:4  1:8  1:16  …    │   · W055 flagged: DTE↔DTE ║
║ ☑ T6.04 Control       │ ☑ Show cable IDs on traces    │     without null-modem    ║
║ ☑ T6.05 Power         │ ☑ Show port designators       │                           ║
║ ☑ T6.06 Structure     │ ☑ Off-sheet connectors        │                           ║
║ ☑ T6.10 Wiring sched. │ ☐ Revision clouds (since B)   │                           ║
║ ☑ T6.20 Drop schedule │                               │                           ║
║ ☑ T6.30 Equipment     │ SCHEDULE                      │                           ║
║ ☑ T6.40 Power sched.  │ Sort   [Cable ID           ▾] │                           ║
║ ☐ T6.50 Network/IP    │ Group  [Signal domain      ▾] │                           ║
║ ☐ T5.01 Plate details │ Columns  [ Choose… 10 of 19 ] │                           ║
║ ☐ Field pull sheet    │ ☑ Zebra striping              │                           ║
║                       │                               │                           ║
║ TITLE BLOCK           │ COLOUR                        │                           ║
║ Drawn by   [J.S.    ] │ ◉ Colour   ○ Greyscale        │                           ║
║ Checked by [        ] │ ○ CMYK (for plotter/print)    │                           ║
║ Revision   [C  ▾]     │ ☐ Embed .rackmate source      │                           ║
║ Issue date [2026-07-18]│ ☐ PDF/A-3b (archival)        │                           ║
╠═══════════════════════╧═══════════════════════════════╧═══════════════════════════╣
║  Est. 14 sheets · ~420 KB                       [ Preview ]  [ Cancel ]  [ Export ]║
╚═══════════════════════════════════════════════════════════════════════════════════╝
```

Design notes:

- **Presets first, checkboxes second.** Selecting a preset checks the sheets and flips the option switches; touching any switch moves the radio to `Custom…`.
- **Notices are surfaced before export, not after.** Validation warnings from the signal model (`DTE↔DTE without null-modem`, `passive HDMI 2.1 run > 4.5 m`, `Σ PoE draw > switch budget`) appear in the preview pane with a jump-to-sheet link. Exporting a drawing set with known errors is a choice the user should make deliberately.
- **The live preview is rendered by the screen backend, not by pdfium.** Same `DiagramScene`, same furniture, same fonts, same metrics, so it is pixel-faithful by construction, instant, and needs no native dependency. This is the payoff for §6 and it should be the headline preview.
- Size and page-count estimates come from a dry-run pass over the resolved sheet list; they cost ~10 ms.

### 7.2 Progress

An export is 3 phases; report weighted progress, not a spinner:

| Phase | Weight | Reportable unit |
|---|---|---|
| 1. Build scenes | 25 % | per sheet |
| 2. Place, assign zones, resolve cross-references | 10 % | one step |
| 3. Emit PDF (layout + serialise) | 65 % | per sheet, then a final "writing" step |

```
Exporting…  ████████████░░░░░░░░  58 %
Sheet 8 of 14 — T6.10 Wiring schedule (page 2 of 3)
                                                          [ Cancel ]
```

Show it inline in the dialog, not as a modal overlay. Under 400 ms, don't show it at all, flashing a progress bar for a 3-sheet export looks worse than a brief pause.

### 7.3 Isolate generation

`doc.save()` blocks, and so does the widget layout pass. `pdf` 3.11.0 moved *saving* to an isolate when available, but not layout. For a 14-sheet set with a 3-page schedule, run **the whole thing** off-thread.

**The constraint that catches everyone: a background isolate has no `rootBundle`, no plugins, no platform channels, no `BuildContext`.** Load every font and image to `Uint8List` on the main isolate first, then pass plain bytes.

```dart
// ── main isolate: gather everything Flutter-dependent ────────────────────────
final assets = ExportAssets(
  bodyTtf:     (await rootBundle.load('assets/fonts/IBMPlexSans-Regular.ttf')).buffer.asUint8List(),
  bodyBoldTtf: (await rootBundle.load('assets/fonts/IBMPlexSans-SemiBold.ttf')).buffer.asUint8List(),
  monoTtf:     (await rootBundle.load('assets/fonts/IBMPlexMono-Regular.ttf')).buffer.asUint8List(),
  monoBoldTtf: (await rootBundle.load('assets/fonts/IBMPlexMono-Bold.ttf')).buffer.asUint8List(),
  condTtf:     (await rootBundle.load('assets/fonts/IBMPlexSansCondensed-Regular.ttf')).buffer.asUint8List(),
  symbolTtf:   (await rootBundle.load('assets/fonts/NotoSansSymbols2-Regular.ttf')).buffer.asUint8List(),
  logoPng:     project.logoBytes,
);

final projectJson = jsonEncode(project.toJson());   // sendable, immutable
final specJson    = jsonEncode(spec.toJson());
```

**Progress out of the isolate.** `Isolate.run` returns a single value, but `SendPort` *is* sendable, so it can be captured in the closure:

```dart
final rx = ReceivePort();
rx.listen((msg) {
  if (msg is ExportProgress) controller.update(msg);
});
final tx = rx.sendPort;

final bytes = await Isolate.run(() =>
    buildDocument(projectJson, specJson, assets, onProgress: tx.send));
rx.close();
```

**Cancellation.** The PDF build is synchronous and never yields, so it cannot poll a `ReceivePort` for a cancel token. Use `Isolate.spawn` + `isolate.kill(priority: Isolate.immediate)` instead of `Isolate.run` when cancellation matters:

```dart
final iso = await Isolate.spawn(_exportEntry, _ExportRequest(tx, projectJson, specJson, assets));
_cancelButton.onPressed = () => iso.kill(priority: Isolate.immediate);
```

There is no partial-result recovery, an aborted export produces nothing, which is correct.

**Do not use `compute()` in a loop.** flutter/flutter #43623 documents leaks with repeated `compute` calls; one `Isolate.run`/`Isolate.spawn` per export is the right granularity, and don't pool.

**This works only because §6 kept the renderer free of `dart:ui` (P3).** The isolate requirement and the future server-side-export requirement point at the same architectural decision; make it once, up front, because retrofitting it means touching every drawing call site.

### 7.4 Preview before save

Two levels, both worth having:

1. **Sheet preview (primary)**: the screen backend replaying the same scenes with the same furniture. Instant, no native deps, hot-reloadable in dev, faithful by construction. This is what's in the dialog's right column and what most users will ever look at.
2. **Output verification (secondary)**: `PdfPreview(build: (format) => bytes)` from `printing`, rendering the *actual bytes*. Behind a "Verify output" button, because it needs pdfium and takes a moment.

> **pdfium build caveat:** `printing`'s `PdfPreview` and `Printing.raster` require pdfium on Windows and Linux, and the plugin's CMake downloads binaries at build time. The first `flutter build windows` on a fresh machine or a locked-down CI runner **will fail without network access**. Budget for it and consider vendoring the binaries into the repo.

Making the *primary* preview independent of pdfium means the core export flow has no native dependency at all, worth the design effort on its own.

### 7.5 Save and share

Use **`file_selector`**, not `file_picker`. `file_selector` is maintained by the Flutter team in `flutter/packages`, is federated, and is pure platform-channel; `file_picker` is third-party, bundles more native code, and has had desktop save regressions (e.g. `saveFile` silently not saving on Linux, #1907). For a desktop-first app, take the first-party option.

```dart
Future<void> save(Uint8List bytes, String suggested) async {
  const group = XTypeGroup(label: 'PDF', extensions: ['pdf'],
                           mimeTypes: ['application/pdf']);
  final loc = await getSaveLocation(
    suggestedName: suggested,
    acceptedTypeGroups: const [group],
    initialDirectory: prefs.lastExportDir,
  );
  if (loc == null) return;                    // cancelled
  await XFile.fromData(bytes, mimeType: 'application/pdf', name: suggested)
      .saveTo(loc.path);
  prefs.lastExportDir = p.dirname(loc.path);
}
```

Default filename: `{project-slug}_{rack-or-SET}_rev{REV}_{yyyy-MM-dd}.pdf` → `smith-residence_SET_revC_2026-07-18.pdf`. Revision in the filename is not optional; it is the only thing that stops the wrong PDF being on site.

| Target | Save | Print | Share |
|---|---|---|---|
| Windows / macOS / Linux | `getSaveLocation` + `XFile.saveTo` | `Printing.layoutPdf` | `Printing.sharePdf` (good on macOS, weak on Win/Linux) |
| iOS / Android | `Printing.sharePdf`, or `path_provider` + `share_plus` | `Printing.layoutPdf` | `Printing.sharePdf`: **`bounds:` is required in practice on iPad**; omit it and the popover misplaces or throws |
| Web | `Printing.sharePdf` → browser download; prefer a **Blob URL over a `data:` URL** for a multi-sheet set (data URLs hit length limits) | `Printing.layoutPdf` | download |

Other printing gotchas worth encoding now:

- `dynamicLayout: true` re-invokes `onLayout` whenever the user changes paper size in the print dialog, your callback must honour the `PdfPageFormat` it receives. §5.5's fit code already does. Set `false` to force your sheet size.
- **11×17 on Windows often needs `forceCustomPrintPaper: true`** to reach the driver correctly. Directly relevant here.
- `usePrinterSettings: true` takes paper size from the driver instead of your format, almost never what you want for a drawing set.
- Never silently write a deliverable to `getApplicationDocumentsDirectory()`. `path_provider` is for temp scratch only.
- **Web first-run is dramatically slower** (dart_pdf #748) from font/wasm warmup. Pre-warm on idle if you ship web.

### 7.6 After the export

A completion strip, not a modal: `Exported 14 sheets · 438 KB · 3.1 s` with **[Open] [Show in folder] [Print] [Copy path]**. `Show in folder` on Windows is `explorer /select,"<path>"`; on macOS `open -R`; on Linux try `dbus-send` to `org.freedesktop.FileManager1.ShowItems` then fall back to `xdg-open` on the directory.

### 7.7 Determinism

Two exports of an unmodified project should differ only in the date field. That means: stable iteration order everywhere (sort by UUID, never rely on `Map` order), no `DateTime.now()` outside the one date field, no random IDs in the PDF. It makes golden-file testing possible and it makes "did anything actually change between rev B and rev C?" answerable with `diff`.

Set the document metadata too, it populates Acrobat's Document Properties and makes the file findable in a client's DMS:

```dart
final doc = pw.Document(
  title:    'Smith Residence — RK-1 — Rev C',
  author:   'NBS Integration LLC',
  creator:  'RackMate 1.0',
  subject:  'A/V rack wiring plan and schedule',
  keywords: 'rack, wiring, schedule, RK-1, 25-1183',
);
```

**Embed the source.** With PDF/A-3b (supported since `pdf` 3.11.2) you can attach the `.rackmate` file inside the PDF. The drawing then carries its own editable source, hand a client or a successor integrator one file and they have both the deliverable and the project. That is a genuinely good feature and it costs almost nothing.

---

## 8. Non-PDF exports

| Export | Cost given §6 | Value | Ship in |
|---|---|---|---|
| **CSV: wiring schedule** | **trivial** | high | v1 |
| **CSV: drop schedule** | trivial | high | v1 |
| **CSV: BOM** | trivial | high | v1 |
| **CSV: cable label file** | trivial | **very high** | v1 |
| **SVG: one sheet** | ~120 lines (fourth backend) | high | v1.1 |
| **PNG: one sheet** | ~40 lines, with a size cap | medium | v1.1 |
| **XLSX: schedule + BOM** | one dependency, ~200 lines | medium | v1.1 |
| **JSON netlist** | trivial (it's the model) | medium | v1.1 |
| **DXF: rack elevation** | ~400 lines, new geometry mapping | low | not planned |

### 8.1 CSV

The schedule and BOM are already `List<List<String>>` by the time they reach `TableHelper` (§2). CSV is that same array with quoting. Genuinely a few dozen lines.

Two things to get right: emit a **UTF-8 BOM** (`\uFEFF`) so Excel on Windows doesn't mangle `Ω` and `′`, and **quote every field** rather than conditionally, device model strings contain commas.

### 8.2 CSV: cable label file

The highest value-per-line export in the list. Brady, DYMO Rhino, Brother P-touch, and Panduit label software all import CSV. Emit one row per **label**, not per cable, two labels per cable end, four per run, per residential practice (two labels 2–4 ft apart on each end so one survives re-termination):

```csv
label_text,line2,line3,cable_id,end,copy
"W014","TX-1 LINK OUT","→ PP-1 A03","W014","A",1
"W014","TX-1 LINK OUT","→ PP-1 A03","W014","A",2
"W014","PP-1 A03","← TX-1 LINK OUT","W014","B",1
"W014","PP-1 A03","← TX-1 LINK OUT","W014","B",2
```

Note line 2/3 follow AVIXA F501.01: the label states **where the cable connects**, not what it is. `OUT 1 Laptop`, not `HDMI cable`.

### 8.3 SVG

`SvgDiagramCanvas implements DiagramCanvas` writing to a `StringBuffer`. Pure Dart, isolate-safe, ~120 lines, mostly mechanical:

- `save`/`restore` → `<g>` open/close
- transforms → `transform="matrix(a,b,c,d,e,f)"` on the `<g>`
- `Stroke` → `stroke`, `stroke-width`, `stroke-dasharray`, `stroke-linecap`, `stroke-linejoin`, `stroke-miterlimit`
- `drawText` → `<text x y transform="rotate(…)" text-anchor="start|middle|end" dominant-baseline="…">`, and **use `textLength` with the measured advance width** so an SVG consumer with different font metrics doesn't reflow your labels
- `DiagramPath` → `<path d="…">` (the verb list serialises directly)
- **Y-down is native to SVG**, so there is no flip at all. It's the easiest of the three backends.

Genuinely useful: CI people want to drop a diagram into a proposal, or hand it to someone in Illustrator or Visio.

### 8.4 PNG

Not for deliverables (§5.6), but reasonable for a proposal image or a Slack message. Render the screen backend into a `ui.PictureRecorder`, `toImage`, encode:

```dart
Future<Uint8List> exportPng(DiagramScene scene, Box sheet, {double dpi = 150}) async {
  final ratio = dpi / 72.0;
  final w = (sheet.width * ratio).round(), h = (sheet.height * ratio).round();
  if (w > 4096 || h > 4096) {                       // GPU texture cap — §5.6
    throw ExportError('PNG would be ${w}×$h px; max 4096. Reduce DPI or use SVG.');
  }
  final rec = ui.PictureRecorder();
  final c = ui.Canvas(rec);
  c..scale(ratio)..drawRect(..., ui.Paint()..color = const ui.Color(0xFFFFFFFF));
  scene.replay(FlutterDiagramCanvas(c, measurer: measurer));
  final img = await rec.endRecording().toImage(w, h);
  return (await img.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
}
```

The 4096 check is not optional, Flutter silently clamps or fails above it on a large installed base, producing a quietly blurry image with no error.

Note this uses `PictureRecorder`, **not `RepaintBoundary`**: no widget tree, no layout pass, and it works at any scale independent of what's on screen.

### 8.5 XLSX

Needs a package (`excel`, or Syncfusion's commercially-licensed XlsIO). The honest assessment: CSV covers 90 % of the need at 2 % of the cost, and integrators live in Excel but open CSV in Excel without complaint. Ship CSV in v1. Add XLSX in v1.1 only if users ask, and when they do, what they'll actually want is *formatting* (frozen header, autofilter, colour-coded TYPE column, column widths), which is the part CSV can't do and the reason to bother.

### 8.6 What's cheap because of §6

Worth stating plainly, because it's the return on the architecture:

- **SVG export**: one file, no new geometry code, no new text handling.
- **PNG export**: the screen backend already exists.
- **Live preview**: free, and faithful by construction.
- **Key plans and thumbnails**: replay the same scene at a different scale.
- **Golden tests**: assert on `DiagramScene.ops`, no pixels involved.
- **Future: server-side export**: the renderer is already Flutter-free (P3).
- **Future: web export**: same, plus a canvas backend if you want client-side rendering.

None of that is free if the diagram is drawn twice.

---

## 9. Fonts

### 9.1 Why not the built-ins

The 14 standard Type1 fonts (Helvetica ×4, Times ×4, Courier ×4, Symbol, ZapfDingbats) embed nothing, zero file cost, but they are single-byte **WinAnsiEncoding**, and any codepoint outside Latin-1 throws:

```
Exception: Helvetica has no Unicode support
```

This is the single most-reported issue in dart_pdf (#76, #196, #252, #384, #405, #810, #1538), and **for RackMate it is not theoretical**. A/V documentation routinely contains `Ω` (speaker impedance), `°`, `±`, `µ`, `→`, `×`, `≈`, `Ø`, `′`/`″` (feet/inches), `—`, and smart quotes pasted out of a proposal, plus client and street names with accents. Never ship default Helvetica.

`PdfGoogleFonts` from `printing` is also out: it does a **network round-trip**, so it cannot run in a background isolate (§7.3) and fails offline, which is precisely the rack room with no Wi-Fi where someone re-exports a drawing.

### 9.2 Recommendation: **IBM Plex**

| Role | Font | Licence | File | Size |
|---|---|---|---|---|
| Body sans | **IBM Plex Sans Regular** | SIL OFL 1.1 | `IBMPlexSans-Regular.ttf` | ~150 KB |
| Body bold | **IBM Plex Sans SemiBold** | SIL OFL 1.1 | `IBMPlexSans-SemiBold.ttf` | ~150 KB |
| Dense tables | **IBM Plex Sans Condensed Regular** | SIL OFL 1.1 | `IBMPlexSansCondensed-Regular.ttf` | ~140 KB |
| Designators, IDs, ports | **IBM Plex Mono Regular** | SIL OFL 1.1 | `IBMPlexMono-Regular.ttf` | ~130 KB |
| Mono emphasis | **IBM Plex Mono Bold** | SIL OFL 1.1 | `IBMPlexMono-Bold.ttf` | ~130 KB |
| Symbol fallback | **Noto Sans Symbols 2 Regular** | SIL OFL 1.1 | `NotoSansSymbols2-Regular.ttf` | ~300 KB (subsettable to ~25 KB) |
| | | | **Total bundle** | **~1.0 MB** (~700 KB without the symbol fallback) |

Why IBM Plex specifically:

1. **SIL Open Font License 1.1**: free for commercial use, embeddable in PDFs without restriction, redistributable, no attribution required in the output document. The only OFL obligation that matters is that you can't sell the fonts themselves, which you aren't. Clean.
2. **One coherent superfamily.** Plex Sans, Plex Sans Condensed, and Plex Mono share design DNA, x-height and vertical metrics. A schedule mixing condensed sans headers with mono IDs looks designed rather than assembled.
3. **Plex Mono is a genuinely good technical mono**: unambiguous `0`/`O`, `1`/`l`/`I`, `5`/`S`, `8`/`B`. In a document whose entire purpose is transcribing identifiers correctly onto physical labels, that is a safety property, not an aesthetic one. `W014` vs `WO14` is a real failure mode.
4. **Plex Sans Condensed buys ~12 % column width** in the schedule, which is the difference between a 10-column and a 12-column table on ANSI A landscape.
5. **Coverage:** Latin, Greek (so `Ω`, `µ`, `Δ`), Cyrillic, and the common technical punctuation(`°`, `±`, `×`, `′`, `″`, `–`, `—`, `“”`). Arrows (`→`, `↔`) and box-drawing are **not** in Plex, hence the fallback.

6. **It is not Helvetica or Arial**, which read as "made in a word processor." Plex reads as engineering documentation, which is what this is.

Runner-up considered and rejected: **Inter** (OFL, excellent screen face, but no true condensed cut and its mono companion is a separate project with different metrics) and **Roboto / Roboto Condensed / Roboto Mono** (Apache-2.0, ubiquitous, but reads as Android UI rather than as a drawing set, and Roboto Condensed's metrics don't match Roboto's).

### 9.3 The two-declaration trap

Declaring a font under `fonts:` makes it available to Flutter's text engine but **not** to `rootBundle.load()`. `pw.Font.ttf` needs the latter. You need both entries or the PDF silently falls back and every metric diverges:

```yaml
flutter:
  fonts:
    - family: RackBody
      fonts:
        - asset: assets/fonts/IBMPlexSans-Regular.ttf
        - asset: assets/fonts/IBMPlexSans-SemiBold.ttf
          weight: 600
    - family: RackCond
      fonts:
        - asset: assets/fonts/IBMPlexSansCondensed-Regular.ttf
    - family: RackMono
      fonts:
        - asset: assets/fonts/IBMPlexMono-Regular.ttf
        - asset: assets/fonts/IBMPlexMono-Bold.ttf
          weight: 700
  assets:
    - assets/fonts/          # ← REQUIRED as well, for rootBundle.load()
```

`FontRef` maps to `RackBody` / `RackCond` / `RackMono` on the Flutter side and to the corresponding `PdfTtfFont` on the PDF side, **the same file both times** (§6.7).

### 9.4 Theme and fallback chain

```dart
final theme = pw.ThemeData.withFont(
  base:       plexSans,
  bold:       plexSansSemiBold,
  italic:     plexSans,           // no italic cut bundled; drawings don't use it
  boldItalic: plexSansSemiBold,
  fontFallback: [plexMono, notoSymbols2],
);
```

`fontFallback` is per-glyph and is the safety net for a stray `→` in a user's note field. Set it even when you're sure you don't need it, the cost is one line and the failure mode without it is a thrown exception mid-export.

Belt and braces, add a sanitiser on all user-supplied strings that maps unrepresentable codepoints to ASCII rather than throwing:

```dart
const _substitutions = {
  '→': '->', '←': '<-', '↔': '<->', '⇒': '=>',
  '≤': '<=', '≥': '>=', '≠': '!=', '≈': '~',
  '⌀': 'dia ', '☐': '[ ]', '✓': 'X',
};
String sanitizeForPdf(String s, PdfFont font, List<PdfFont> fallback) { /* … */ }
```

Run it in the scene builder, not in the backend, so the screen shows exactly what the PDF will show.

### 9.5 Size cost, honestly

- **App bundle:** ~1.0 MB for six TTFs. On desktop, irrelevant. On mobile (read-only review mode), still irrelevant next to the Flutter engine.
- **PDF cost:** dart_pdf **subsets** TrueType fonts to used glyphs. A rack drawing uses maybe 80 distinct glyphs across three faces, so the embedded contribution is **~8–25 KB total**, not 700 KB. A 14-sheet vector set lands at 300–500 KB.
- If the symbol fallback's 300 KB bothers you, subset Noto Sans Symbols 2 at build time with `fonttools pyftsubset` down to ~25 KB. Worth doing eventually; not worth doing first.

---

## 10. File layout

```
lib/
  model/                      # RackProject, Device, Port, PhysicalLink, LogicalSignal,
                              # CableType, Rack, Structure — pure Dart, JSON, immutable
  diagram/
    geometry.dart             # Pt, Box, Radii            (NO dart:ui)
    style.dart                # Stroke, Fill, TextStyleSpec, palette, dash table
    path.dart                 # DiagramPath + SVG parser
    text.dart                 # TextMeasurer, PdfFontMeasurer, anchorOffset
    canvas.dart               # abstract interface DiagramCanvas + RendererCaps
    ops.dart                  # sealed DiagramOp, SceneRecorder, DiagramScene
    symbols.dart              # connector glyphs as SVG 'd' constants (J-STD-710 geom)
    scene_builder.dart        # buildScene(project, style, measurer)  ← THE renderer
    elevation_builder.dart    # rack elevation scenes
    hit_test.dart             # walks DiagramScene.hits
    backends/
      pdf_canvas.dart         # PdfGraphics      — pure Dart, isolate-safe
      svg_canvas.dart         # StringBuffer     — pure Dart
      bounds_canvas.dart      # accumulator      — pure Dart
      flutter_canvas.dart     # dart:ui          — the ONLY Flutter-dependent file here
  export/
    sheets.dart               # ANSI/ARCH/ISO PdfPageFormat constants
    sheet_spec.dart           # ExportSpec, presets, sheet resolution
    furniture.dart            # border, zone grid, title block, revision block
    legend.dart               # T0.01 sheet
    schedule_table.dart       # pagination + pw.Table emission
    bom_table.dart
    layout.dart               # fit scale, net partition, tiling, match lines, key plan
    cross_refs.dart           # zone assignment, off-sheet connector resolution
    cable_id.dart             # token template engine
    document.dart             # assembles pw.Document; runs inside the isolate
    isolate_runner.dart       # ExportAssets, spawn, progress, cancel  (Flutter side)
    csv_export.dart
    label_export.dart
  ui/
    diagram_view.dart         # CustomPainter → FlutterDiagramCanvas
    sheet_preview.dart        # the export dialog's live preview
    export_dialog.dart
test/
  headless/                   # runs under `dart test` — the P3 guardrail
    document_build_test.dart
    scene_golden_test.dart    # asserts on DiagramScene.ops, no pixels
    cable_id_test.dart
  flutter/                    # runs under `flutter test`
    canvas_parity_test.dart   # same scene, both backends, compare measured geometry
```

---

## 11. Build order

Because the interesting risk is all in §6, front-load it.

| Step | Deliverable | Proves |
|---|---|---|
| 1 | The five verification spikes (§6.11) in a throwaway `bin/spike.dart` | The `pdf` API behaves as assumed |
| 2 | `geometry`, `style`, `path`, `text`, `canvas`, `ops` + `PdfDiagramCanvas` + a hardcoded 20-op scene → one PDF | The flip, the transform stack, text anchoring |
| 3 | `FlutterDiagramCanvas` + `canvas_parity_test` overlaying both backends' output for a fixture scene | **Screen/print parity**: the thing that's expensive to fix late |
| 4 | `furniture.dart` + `PageTheme.buildBackground` → a bordered, title-blocked blank sheet | Furniture path, `FullPage(ignoreMargins:)` |
| 5 | `headless/document_build_test.dart` under `dart test` | **P3**: isolate and future server export are possible |
| 6 | `scene_builder` for one interconnect sheet from a real fixture project | The renderer |
| 7 | `schedule_table` with manual pagination, 200-row fixture | Pagination, header repeat, long-token safety |
| 8 | `elevation_builder` | The tall-sheet case |
| 9 | `cable_id.dart` + presets | §3 |
| 10 | `layout.dart` net partition + `cross_refs.dart` | §5.4: needs steps 6 and 8 done |
| 11 | `isolate_runner` + progress + cancel | §7.3 |
| 12 | `export_dialog` + live preview | §7.1: trivially, because step 3 already gave you the preview renderer |
| 13 | CSV + label export | §8.1, §8.2 |
| 14 | `svg_canvas.dart` | §8.3: one file, on top of everything above |

Steps 1–5 are roughly a week and de-risk the entire feature. If step 3 doesn't produce parity, stop and fix it before writing a single scene builder, every hour spent on layout before parity is established is an hour that may need redoing.

---

## 12. Summary of the decisions

| # | Decision | Section |
|---|---|---|
| 1 | 8 sheet types default-on/auto, NCS `T`-discipline numbering, presets over checkboxes | §1 |
| 2 | 10 default + 9 optional schedule columns, ANSI A landscape, 30 rows/page, manual pagination | §2 |
| 3 | TYPE chip is a **sample of the actual drawn line**: colour + dash + tag, greyscale-safe by construction | §2.4 |
| 4 | Token-template cable ID engine, 9 presets, `W{N:3}` default, IDs materialised and locked past `Pulled` | §3 |
| 5 | Furniture drawn through the shared renderer, revision block generated from project history | §4 |
| 6 | ANSI B landscape diagrams / ANSI A landscape schedules / ANSI B portrait elevations | §5.2 |
| 7 | **Net partition + off-sheet connectors** for v1; geometric tiling as fallback | §5.4 |
| 8 | Legibility, not user preference, triggers multi-sheet: `k × minTextPt < 6.0` | §5.5 |
| 9 | **One `DiagramCanvas` interface, four implementations**, display list in between | §6 |
| 10 | Global Y-flip in the PDF adapter, not per-coordinate, because the interface exposes `rotate`/`transform` | §6.5 |
| 11 | **`PdfFont.stringMetrics` is the single source of truth for text metrics on both backends**, with Skia kerning disabled to match | §6.7 |
| 12 | No gradients, shadows, blurs, blend modes, or shaders, flat fills, strokes, dashes, text only | §6.4 |
| 13 | Whole export in an isolate; fonts pre-loaded to `Uint8List`; progress via captured `SendPort`; cancel via `Isolate.kill` | §7.3 |
| 14 | Primary preview uses the **screen** renderer, so the core flow has zero native dependencies | §7.4 |
| 15 | `file_selector`, not `file_picker` | §7.5 |
| 16 | CSV + label CSV in v1 (trivial); SVG in v1.1 (one file); XLSX only on demand; PNG capped at 4096 px | §8 |
| 17 | IBM Plex Sans / Sans Condensed / Mono, SIL OFL 1.1, ~1.0 MB bundled, ~8–25 KB embedded per PDF | §9 |
| 18 | Declare fonts under **both** `fonts:` and `assets:` in pubspec | §9.3 |

**The one thing to get right:** §6.7 and §6.11 item 5. Text metric parity and the text rotation sign are the two failures that produce a PDF which is subtly, unfixably different from the preview, and both are cheap to lock down with a parity test on day three and ruinous to chase on day ninety.