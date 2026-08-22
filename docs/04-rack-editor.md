# Rack Editor

The Rack Editor is the elevation authoring view (`Ctrl+1`) where a user creates racks, sets `heightU`, and places occupants against the rails. It is the first surface a new project shows and the one an installer recognises fastest, but it is not where wiring happens, connections are created in the [Schematic](05-schematic-editor.md) in v1, and the Rack Editor's job is to signpost that (per CR-105) rather than grow a second wiring surface. What that signpost leads to is worth stating here so the handoff is not a surprise: the Schematic renders every `Link` as **a pair of net labels by default** (DR-001), and drawn wires appear when the user filters to one domain, `Alt`-hovers, or focuses, which is why the coach mark on that first switch teaches the domain filter (§9). This document specifies the screen layout, the canvas visual language, every placement gesture and its feedback, rack configuration including the shrink-below-occupancy dialog, the derived readouts, non-device occupants, designator assignment, the keymap, first-run states, and accessibility. Names are taken verbatim from canon §4; `bottomU`, `refDes`, `slot` and `Bay` do not appear here because they do not exist (CR-025, CR-040, CR-033).

---

## 1. Screen layout

Single window, one document (RJ-013). Three resizable regions between a fixed toolbar and a fixed status bar, with a collapsible validation drawer above the status bar.

```
┌──────────────────────────────────────────────────────────────────────────────────────────────┐
│ ≡  RackMate   Hillcrest Residence*            [Rack|Schematic|Schedule]  [Front|Rear|Both] ⚙ │ 44
├────────────┬───────────────────────────────────────────────────────────┬─────────────────────┤
│ PALETTE    │  RACK CANVAS                                              │ INSPECTOR           │
│ 280px      │  flex, min 480px                                          │ 320px               │
│ ┌────────┐ │                                                           │ ┌─────────────────┐ │
│ │⌕ /     │ │   ┌── RK-1 · Media Closet ───┐   ┌── RK-2 ─────┐          │ │ AMP-1           │ │
│ └────────┘ │   │ 24U · RU 15/24 · 148/200 │   │ 12U · 3/12  │          │ │ 16-ch amplifier │ │
│ ▾ Recent   │   │ lb · 1.24 kVA · 14/16 out│   │ ⚠0          │          │ ├─────────────────┤ │
│  ▪ 8×8 MTX │   ├──────────────────────────┤   ├─────────────┤          │ │ Identity        │ │
│  ▪ 24p PoE │   │24┊▭▭▭▭ BLK-1 ▭▭▭▭▭▭┊ o   │   │12┊         ┊│          │ │  Designator     │ │
│ ▾ Amplif.  │   │23┊                  ┊ o   │   │11┊ (empty) ┊│          │ │   AMP-1      🔒 │ │
│  ▪ 8-ch    │   │22┊████ SW-1 ████████┊ o ⚠ │   │10┊         ┊│          │ │  Name  LR Amp   │ │
│  ▪ 16-ch   │   │21┊████████████████████ o   │   │ 9┊         ┊│          │ │ ├───────────────┤ │
│ ▾ Network  │   │20┊                  ┊ o   │   │ …           │          │ │ Mounting        │ │
│  ▪ 24p sw  │   │19┊████ AMP-1 ──🔗0/12┊ o ↺ │   │ 1┊         ┊│          │ │  Face   Front   │ │
│ ▾ Power    │   │18┊████████████████████ o   │   └─────────────┘          │ │  ruIndex  19    │ │
│  ▪ 1U PDU  │   │ …                        │                             │ │  Width  Full ▾  │ │
│  ▪ 0U PDU  │   │ 1┊████ UPS-1 ────────┊ o   │                             │ │  Rotation Nrml ▾│ │
│ ▾ Panels   │   └──────────────────────────┘                             │ │  Depth   406 mm │ │
│ ▾ Structure│                                                             │ │  Weight  12.7 kg│ │
│            │   ┌ STAGING BIN (2) ────────────────────────┐               │ ├─────────────────┤ │
│            │   │ [STB-3 1U ↩RK-1 U21] [NAS-1 2U]         │               │ │ RK-1 VITALS     │ │
│            │   └─────────────────────────────────────────┘               │ │ ▓▓▓▓▓▓░░░ 62% RU│ │
├────────────┴───────────────────────────────────────────────────────────┴─────────────────────┤
│ ⚠ 2 warnings  ▸ RCK-013 AMP-1 on front ears only  ▸ PWR-001 Circuit A 14.2/16.0 A   [expand] │ 28
├──────────────────────────────────────────────────────────────────────────────────────────────┤
│ RK-1 · U19 · Front      │  zoom 100%  [−][100%][+]  │  2 selected  │  2 racks · 41 devices    │ 24
└──────────────────────────────────────────────────────────────────────────────────────────────┘
```

| Region | Default | Min / Max | Behaviour |
|---|---|---|---|
| Toolbar | 44 px | fixed | Never hides. Left group = view switch (`Ctrl+1..4`), showing **three tabs in v1**: Rack, Schematic, Schedule; right group = the face segmented control. |
| Palette | 280 px | 220 / 480 | 4 px splitter, 8 px hit slop. Collapses to a 40 px icon rail (`Ctrl+Alt+1`). **One palette widget, shared with the Schematic's library panel** (CR-104). |
| Canvas | flex | 480 px | Never collapses. Owns both scroll axes. |
| Inspector | 320 px | 280 / 520 | `Ctrl+Alt+2`. Selection section on top (scrolls); Rack Vitals pinned below, 200 px, collapsible. |
| Validation drawer | 28 px | 28 / 320 | Auto-expands to 180 px once, on the first *error* per session, never again. |
| Status bar | 24 px | fixed | Cursor context · zoom · selection rollup · project counts. |

**What the palette lists, and in what order** (DR-077 §11.76, M4-S). It lists what the **document** can place, not what the build ships: the newest version of every template in `RackDocument.templates`. Browsing shows a `This project` group pinned first when the project holds anything authored in the Device Builder, then the nine catalog categories in `kCatalogCategoryOrder`, then a trailing `Uncategorised` group for any template whose category is none of the nine, the empty string included. An authored template appears in **both** its category and the pinned group, badged in each. Searching flattens to one list across every group and shows each template **once**, still badged: a duplicate row in a result list makes the match count wrong and `Enter`-on-the-top-match (§3.2) ambiguous. The mockup's `▾ Recent` group is illustrative and is not built; smart folders and favourites are M4-O's.

Panels are collapsible and resizable but **not floatable or re-dockable** in v1; rejected alternative, a full dock manager, near-zero payoff for a three-panel app. Each panel sits behind a `PanelHost` keyed by `PanelId` so a dock manager is a swap, not a rewrite. Widths persist in app settings, never in the `.rmpj` file. Below 1080 logical px the shell collapses to the read-only tablet viewer (AC-056): canvas fills, inspector becomes a three-detent bottom sheet, palette is unavailable, and the app states that mobile is read-only rather than shipping a squeezed editor.

---

## 2. The rack canvas

### 2.1 Anatomy of one rack column

```
                 ┌───────────────────────────────────────┐
                 │ RK-1 · Media Closet         ⌄ 24U ⌃ ⋮ │  32px header, sticky
                 │ RU 15/24 · 148/200 lb · 1.24 kVA · 14/16 out · ⚠2 │  20px chip strip
  ╔══════════════╪═══════════════════════════════════════╪══════════════╗
  ║              │          ▲ 8px resize band ▲          │              ║
  ║              ├──┬──┬─────────────────────────┬──┬────┤              ║
  ║ 0U bar       │24│ o│                         │o │    │ 0U bar       ║
  ║ (rendered,   │  │ o│  ▭▭▭ BLK-1  1U ▭▭▭▭▭    │o │    │ inspector-   ║
  ║  not         ├──┤ o├─────────────────────────┤o │    │ edited       ║
  ║  draggable   │23│ o│  (free)                 │o │    │ in v1        ║
  ║  in v1)      ├──┤ o├─────────────────────────┤o │    │ (AC-044)     ║
  ║              │22│ o│ ┏━━━━━━━━━━━━━━━━━━━━━┓ │o │    │              ║
  ║              │  │ o│ ┃ SW-1                ┃ │o │    │              ║
  ║              ├──┤ o│ ┃ 24-port PoE switch  ┃ │o │    │              ║
  ║              │21│ o│ ┃           2U  ⚡14A  ┃ │o │    │              ║
  ║              │  │ o│ ┗━━━━━━━━━━━━━━━━━━━━━┛ │o │    │              ║
  ║              ├──┼──┴─────────────────────────┴──┤    │              ║
  ║              │  ▲ruler ▲rail  ▲ 450.85 mm opening ▲rail│            ║
  ╚══════════════╧═══════════════════════════════════════╧══════════════╝
                   28px  20px         ~180px @ z1.0      20px
                        └────────── 482.6 mm = 19 in ──────────┘
```

**Geometry.** One rack unit is `Len(44_450_000)` nm = 44.45 mm exactly (CR-001, CR-002). Screen geometry at zoom 1.0 is `1U = 22 px`, panel width 239 px. Nothing in the vertical axis rounds; the elevation X/Y of a device is **derived** from `(Placement, rail geometry, face)` and never persisted (CR-006).

**RU ruler**: 28 px, left of the left rail; in `Both` view the two elevations share one centre ruler.

- One label per U, right-aligned, 11 px tabular figures.
- `ruIndex` is **1-based with a bottom origin, always**: `ruIndex ∈ [1, heightU]` (CR-025). Rejected alternative: 0-based, which put the stored value one off the printed value and made every elevation-to-schedule comparison a trap. It is asserted at load.
- Division lines are drawn **at the U boundary**, which per EIA-310 falls at the midpoint of the 0.500 in gap, through the web between hole pairs, never through a hole. Hairline at 30 % opacity; every 5th boundary at 60 % with a bolder label.
- Numbering direction is `Rack.ruNumbering`, **per-rack, seeded by `ProjectSettings.defaultRuNumbering`** (CR-026). Rejected alternative: a project-only setting, which cannot express a retrofit rack labelled top-down by the previous integrator. Numbering is **display only** and never touches `ruIndex`.
- The ruler is the primary occupancy indicator: a 3 px left accent bar when that U is occupied front, a 3 px right bar plus hatch when occupied rear. Front/rear occupancy is legible without switching faces.

**Rails**: 20 px each at z1.0. Three holes per U at 0.25, 0.875 and 1.50 in from the boundary, drawn as real circles (or 3×3 squares) at zoom ≥ 0.75, and as a tiled cached dotted texture below it. `Rack.railType` is one of `tapped10_32 | tapped12_24 | squareCageNut | roundClearance | m6` (CR-037); it changes hole rendering and the hardware line in the [Equipment List](08-pdf-export.md), and **never gates placement**. Ear-mounted devices draw filled ear screws at the outer holes of their first and last U, the at-a-glance difference between an ear-mounted and a shelf-hosted device.

**Level of detail.** `lodLevel` is explicit in every scene-builder signature and every cache key.

| Zoom | Rails | Device body |
|---|---|---|
| < 0.40 | flat fill | solid block; designator only if ≥ 20 px wide |
| 0.40–0.74 | dotted texture | designator + U-height badge |
| 0.75–1.49 | holes + ear screws | designator + name + type + badges (⚡ amps, ⚠ findings, 🔗 port-count chip, 🔒 lock, ↺ reversed) |
| ≥ 1.50 | holes + edge highlight | adds rear port strip, weight microtext, PDU outlet map |

**The device body carries two more channels from M4-R, and they ship together (DR-059, DR-080, DR-083).** The body **fill** is the device's accent colour where one is set, resolved instance override first, then the template, then `palette.deviceFill`; the designator, name, type and badge take their ink from that fill's **WCAG relative luminance** rather than from a fixed `RackStyle` colour, because one of the eight shipped swatches is pure black. The **mark** is one of DR-059's seventeen silhouettes, drawn as geometry and never as a codepoint, riding the designator line ahead of the text at cap height with the text shifted right by a computed advance (DR-083 §11.82.1). It sits on that line because the line always draws: a mark placed anywhere else needs its own drop tier, and this body's drop tiers have gone wrong before. On a hatched passive body the mark is drawn over a knocked-out panel in the resolved fill, because suppressing it would make `blank` and `shelf` unreachable (§11.82.2). **Neither may ship without the other**: every device is one uniform fill today, so accents alone would make devices differ by hue and nothing else, which is the one thing CR-078 forbids.

### 2.2 Front, rear, and both

The face control (`Ctrl+Shift+F` cycles Front → Rear → Both; `F` and `Shift+F` are **unbound in this view** per CR-101) selects a coordinate, not a filter. Occupancy is `OccupancySide { front, rear, both, zeroUVertical, none }` (CR-036), so a 2U patch panel with `{frontU: 2, rearU: 2}` renders on both faces and a rear lace bar renders only on rear.

Rear is drawn **mirrored** when `Rack.mirrorRearElevation` is true, per-rack, default true, seeded by a project default (CR-035). When false, a persistent `NOT MIRRORED` chip sits in the rack header: a drawing must never lie about itself. `RailPlacement.chassisRotation: reversed` draws a ↺ badge and flips a port's effective face (`templateFace XOR reversed`), because reversing a chassis in a credenza rack is standard practice and was previously inexpressible (AC-023).

Switching face preserves both the selection and the insertion caret's U. Racks lay out left to right in a single row by `Rack.order` (a `FracIndex` per CR-027), bottoms aligned, 48 px gutter; wall-mounted racks are drawn offset upward above a hatched wall line.

---

## 3. Placement

All gestures are hand-rolled on `Listener` and expressed as `CanvasIntent{beginDrag, updateDrag, commitDrag, cancel}`, **no editor logic branches on `PointerDeviceKind`** (AC-016 #23), which is what keeps touch open without shipping a touch editor. `Draggable`/`DragTarget` are not used: they hand off in widget space and we need scene coordinates, live RU snapping, and a proper undo entry.

### 3.1 Drag from palette to rails

| # | Step | Feedback |
|---|---|---|
| 1 | **Arm**: pointer down on a palette row | Nothing until 4 px of movement, so a click still means "show details". |
| 2 | **Lift**: threshold crossed | Source row gets a 1 px accent inset outline and drops to 40 % opacity **in place**. A 180×40 px cursor card appears (icon, name, `2U` badge). Cursor `grabbing`. |
| 3 | **Enter canvas** | Cursor card cross-fades over 100 ms into a scene-accurate ghost at true rack width and true U height, fill `accent @ 12 %`, 1.5 px solid accent border. |
| 4 | **Snap**: always hard-quantised | 2 px accent line at the landing U boundary, extending 12 px into the ruler and 12 px past the far rail; the occupied ruler labels invert; a `U19–U20` chip pins to the ghost's top-right. The snap is instant, interpolating a quantised value reads as lag. |
| 5 | **Evaluate**: every frame, first failure wins | See the table below. |
| 6 | **Commit**: pointer up on a valid target | One `PlaceDeviceCommand`. The device animates in (120 ms scale 0.96→1.0), pulses an accent outline for 400 ms, becomes the sole selection, and the status bar announces `Placed AMP-2 at RK-1 U19–U20, front`, also fired as `SemanticsService.announce`. |

`ruIndex = clamp(round((cursorSceneY − ghostHeight/2 − rackOriginY) / kRackUnit), 1, heightU − heightU(device) + 1)`. There is no free-placement mode; racks are quantised by nature.

**Phase 5, and the ruling that reshapes it.** `design-ux-rack.md` blocked the drop on seven checks. CR-017 demotes all but two: *the gesture may hesitate, the document may not lie*, and only model-incoherence is illegal.

| Check | v1 outcome | Message |
|---|---|---|
| Front U range free on this face | **blocks** | `Occupied by AMP-1 (U19–U20)` |
| Fits within rack extent | **blocks** | `Needs 4U, only 2U free at top` |
| Opposite face occupied at these RU | advisory, **no `ruleId`** | `Rear blocked by PP-2 at U19`: a gesture-time hint that `RCK-012` will evaluate once depths are known |
| Depth interval fits: front + rear + 50 mm allowance ≤ `usableDepth` | error `RCK-012` | `18.0 in front + 8.0 in rear in a 25.75 in rack` |
| Clearance requested above/below | warning | `AMP-1 requests 1U above` |
| Mount method compatible | warning | `Shelf-only device — drop it on a shelf` |
| Half-rack on bare rails | advisory | `Half-rack: an ear kit is required` |

Depth is an **interval on the depth axis per (RU, face)**, not a boolean (AC-022), front and rear occupants fighting for the same air in a shallow rack is *the* residential failure mode, and checking the two faces independently could never catch it. `TemplateBody.bodyDepth` and `Rack.usableDepth` are both nullable and the depth checks **skip** when either is null, because a 2-post frame has no meaningful depth and an uncited body depth must never be estimated into one (AC-050/A1.3, CR-114/G4). Note that `RCK-012` is an **error** but a non-blocking one: only the first two rows are model-incoherence and stop the gesture. Severity governs the finding, not the drop.

**Blocked-drop rendering.** Ghost fill → `error @ 12 %`, border → 1.5 px dashed error, the conflicting occupant gets a 45° hatch at `error @ 25 %`, cursor → `forbidden`, and a 28 px reason chip states the message. Release while blocked is a no-op with a 120 ms shake and the chip persisting 1.2 s. Any drop that trips a non-blocking check (advisory, warning, or `RCK-012`'s error) **completes normally** and files a finding; heuristics never hold a deliverable hostage (G3).

**Escape hatches.** `Esc` cancels, ghost fades over 100 ms, palette row restores. Dragging outside any rack shows the ghost at 40 % with a `Release to add to Staging Bin` chip; dropping there creates a `StagedPlacement` (CR-031, CR-032).

### 3.2 The faster paths

Dragging is not the fastest route and must not be the only one. One insert command exists in every view; the **drop target decides the placement variant** (CR-104), a rack gives `RailPlacement`, the schematic canvas or no rack focus gives `StagedPlacement` plus a `SheetItem`.

1. `/` focuses palette search. Type, press `Enter` → the top match places **at the insertion caret**, or at the lowest fitting free U, and the caret advances past it. This makes populating a rack pure typing.
2. Double-click a palette row, identical to `Enter`.
3. Double-click an empty U → quick-insert popover anchored to that U: 240 px search field, arrow-key results, `Enter` places at exactly that `ruIndex`. The single fastest interaction in the editor.
4. `Ctrl+Alt+I` → `Insert device…` from anywhere.
5. Right-click an empty U → `Insert device…`, `Insert 1U blank`, `Insert vent panel`, `Insert shelf`, `Paste`.

### 3.3 Moving a placed device

1. Grab the body; 4 px threshold. The device drops to 30 % opacity **in place**, showing the vacated U, while a full-opacity ghost follows the cursor with the grab offset preserved.
2. Vertical motion is free within the rack. Horizontal motion is ignored until the cursor passes **60 px beyond a rail**, at which point the ghost jumps to the neighbouring rack, re-snaps to that rack's U grid and width, and a 2 px accent border pulses around the target rack.
3. Same checks and same blocked rendering as §3.1.
4. Pointer up commits one `MoveDeviceCommand`; `Esc` mid-drag reverts.
5. `Ctrl` at drag start → **duplicate**: the original stays opaque, the ghost is a copy, the designator increments on drop.
6. `Alt` at drop → **insert and push**: occupants above shift up by the device's height; the devices that will move are drawn with dashed outlines **at their destination positions** before commit. If pushing up overflows, RackMate tries pushing down; if neither fits, the drop is blocked with `Insert would overflow rack by 2U`.
7. `Ctrl+Shift` at drop over an equal-height device → **swap**, both showing a ↔ badge.

Face change is deliberately **not** a drag gesture, dragging between two mirrored columns in `Both` view is ambiguous. It is the inspector's Face field or the face action on the selection; `ruIndex` is preserved.

Lateral position is a `Width position` dropdown, `Full (0,12) | Left half (0,6) | Right half (6,6)`, writing `startTwelfth`/`spanTwelfths` (CR-030). Rejected alternative: a lateral drag axis, deferred to v1.2; the twelfths stay in the format now because retrofitting them is a migration touching every device (G5).

### 3.4 The insertion caret and keyboard nudge

The caret is a first-class object, a 2 px accent line at a U boundary with a 6 px triangle at each rail and the ruler label highlighted. It exists whenever the canvas has focus and nothing is selected, and it is what makes keyboard-only placement work.

Two amendments, both forced by the caret being invisible in practice for the whole of M1:

* **The palette filter counts as canvas focus, and only the palette filter.** Read literally, "whenever the canvas has focus" makes §3.2's own flow self-defeating: `/` moves focus to the filter, extinguishing the caret that the placement about to happen is aimed at. The caret must survive the hand-off it exists to serve. The widening names that one field, *not* the whole column, because the inspector's text fields are in the same `Row` and typing a rack name is not a placement gesture.
* **A device that was just quick-added does not count as a selection.** Every placement becomes the sole selection (§3.1 step 6), which switched the caret off at exactly the moment a keep-typing loop needs it to say where the *next* device goes. The transparency window the screen already computes for caret *targeting* applies to *activation* too.

**The caret must also be ON SCREEN, which is a separate claim and was the one that actually failed.** The viewport used to open at identity, and rack scene space is bottom-origin, `yBottomOfU(1) == rackHeight`, so on the default 42 U project U1 was drawn roughly 54 px below the visible canvas, along with the bottom of the rack. Two rules follow, and they are requirements on the *viewport*, not on the caret: U1 is visible on the first frame of any rack, and moving the caret pans the minimum distance needed to keep it inside.

**How the first of those two is satisfied changed under DR-066 (canon §11.65), and the second gained a guard.** A rack now arrives **framed and centred**: `fitToContent` over the whole rack, into the canvas minus the 84 px band the floating chrome occupies, then pushed down past it, so §4.1's top-edge grab band stays reachable. U1 is therefore on screen because *all* of the rack is, and the nudge that used to do the job is gone; zoom is whatever fits the window rather than §2.1's 1.0. A rack the session has already shown is **restored to the pan and zoom it was left at** instead, unless its height changed in the meantime, since a view remembered at 9 U describes nothing at 42 U. **The caret pan declines while the viewport still belongs to a different rack than the model does** (canon §11.65.4): during a switch the geometry is the incoming rack's and the matrix is still the outgoing one's, and a screen position computed across that gap describes neither.

| Key | With a selection | With no selection |
|---|---|---|
| `↑` / `↓` | nudge ±1U | move caret ±1U |
| `Shift+↑/↓` | extend selection to the adjacent **occupant** | — |
| `Ctrl+↑/↓` | jump to the next free slot, skipping occupied space | — |
| `Alt+↑/↓` | swap with the adjacent occupant; unequal heights re-pack from the lower position | — |
| `Home` / `End` | lowest / highest fitting position | caret to U1 / top |
| `PgUp` / `PgDn` | ±10U | ±10U |

Consecutive nudges on the same axis within 500 ms **coalesce into one undo entry**, so holding `↓` is one undo, not fourteen. A nudge that would collide never silently stops: the selection shakes 3 px and the status bar reads `Blocked by SW-1`. Silent no-ops are the most common source of "the app is broken".

### 3.5 Selection, duplicate, delete

- Click replaces; `Ctrl+click` toggles; `Shift+click` range-selects every occupant between the anchor and the target in that rack, inclusive.
- **Marquee is left-drag on empty canvas, in every view** (CR-102). Rejected alternative: right-drag, which double-books the context menu. CAD convention is kept: left→right selects fully contained (solid band, corner label `WINDOW`), right→left selects intersecting (dashed band, `CROSS`). `Shift` adds, `Alt` subtracts.
- `Ctrl+A` selects all in the focused rack; again for the whole project.
- Multi-select draws a 2 px outline per member plus a combined bracket in the ruler spanning the union of their U ranges; the status bar rolls up `3 selected · 5U · 62 lb · 780 VA`, with any unknown contributor counted rather than guessed (G4).
- Selection is the unit for move, nudge, delete, copy, duplicate, face change, lock (`Ctrl+L` → `Placement.locked`, CR-034) and inspector multi-edit, where differing values render `—` and an edit applies to all.

| Command | Behaviour |
|---|---|
| `Ctrl+C` | Internal clipboard **and** JSON to the system clipboard, so it pastes into another window and is diffable. Relative U offsets preserved. |
| `Ctrl+X` | Cut. Wiring rides on the clipboard and is restored on paste. A wired device gains a confirm (AC-058/D5). |
| `Ctrl+V` | Paste at the caret, else at the lowest region fitting the whole group. If the group cannot fit contiguously: `Place what fits (3 of 5) — remainder to Staging Bin`, in a toast with `Undo`. |
| `Ctrl+Shift+V` | Paste in place: same `ruIndex` values into the focused rack. Blocked if occupied; the toast names the blockers. |
| `Ctrl+D` | Duplicate immediately above the original if space exists, else nearest free above, else below, else Staging Bin. |
| `Del` | Zero connections → delete immediately with undo; never prompt for a consequence-free action. ≥ 1 connection → a **non-modal** confirm bar in the status area: `Delete AMP-1 and its 6 links? [Delete] [Cancel]`, `Enter`/`Esc` bound. |

Delete removes attached `Link`s, and undo restores device *and* links as one command. A wire is never orphaned. All of this runs on the one `Command`/`UndoStack` machinery scoped to `RackDocument` (CR-106).

### 3.6 Compaction

**Compact Down** and **Compact Up** ship; they never apply silently. Each opens a preview overlay, proposed positions as solid ghosts, current positions dimmed to 25 %, and a floating bar `Compact Up · 4 devices move · 3U freed [Apply] [Cancel]`. `Enter` applies as one undo entry, `Esc` cancels. Locked placements are immovable anchors. Rejected alternative: `Auto-arrange` with trade heuristics and `Fill gaps with blanks`, both deferred to v1.2 (AC-045), the design's own admission that "integrators have strong and differing opinions" about heavy-low and vent-above-heat is the argument for not shipping the opinion, not for shipping it with checkboxes. `Ctrl+B` is therefore **reserved and unbound** in v1.

---

## 4. Rack configuration

Three entry points to one `RackInspector`, which replaces the Selection section: click the rack header or its empty background, `Ctrl+Alt+U`, or `⋮ → Rack settings`.

```
┌ RK-1 ───────────────────────────────┐
│ Identity                            │
│  Name       [Media Closet        ]  │
│  Designator [RK-1     ]  ← the ONLY rack identifier (CR-040)
│  Location   [Basement ▾] + New…     │  ← project Locations panel (CR-112)
├─────────────────────────────────────┤
│ Form factor                         │
│  Preset  [Floor enclosure 24U    ▾] │
│  Height  [⌄] 24 [⌃] U   (1–60)      │
│  Width   [eia19 (482.6 mm)       ▾] │
│  Usable depth [654.05] mm  ⓘ  [—]   │  ← nullable; 2-post leaves it unset
│  Rail type    [tapped10_32       ▾] │
│  Weight cap.  [1134] kg  ·  Own [—] │
│  Mount   ( ) Floor  (•) Wall        │
│  Swing frame [x]   Hinge [Left ▾]   │
│  Ground bar present  [x]            │  ← prints a note on the elevation (m21)
├─────────────────────────────────────┤
│ Display                             │
│  RU numbering (•) Bottom-up ( ) Top │
│  Mirror rear elevation      [x]     │
├─────────────────────────────────────┤
│ Circuits (filtered by rackId)       │
│  ● Panel A / Br 14  20 A · 16 A cont│
│  ● Panel A / Br 16  15 A · 12 A cont│
│  [+ Add circuit]                    │
└─────────────────────────────────────┘
```

`heightU ∈ [1, 60]`, asserted as an invariant, advisory above 50 (CR-038). Rejected alternatives: 1–58 and a soft cap of 45, 58U and 60U products both exist, and 60 is the honest cap that matches the performance envelope. `Circuit` is flat on the document with an optional `rackId`; the inspector merely filters (CR-028). Circuit **membership is derived** by walking power `Link`s from device inlet → PDU outlet → PDU inlet → circuit; `Port.circuitId` survives only where the rack meets the building. `Rack.lineVoltage` is deleted, `Circuit.volts` is authoritative and `ProjectSettings.defaultLineVolts` seeds new circuits (CR-039).

Presets are the fast path and are seed data in the same editable format as device templates: `Wall box 6U/12 in`, `Swing gate 12U/18 in`, `Pivot cabinet 10U`, `Floor enclosure 18/21/27/35/44U`, `Open frame 4-post 44U`, `Credenza bay 8U`, `Data 42U/36 in`. Each carries height, depth, capacity, rail type and `RackFormFactor`, which also gates `RCK-004` and `RCK-007`, both v1.2 rules, and when they land, both **advisory and default off** for wall and credenza form factors where they would otherwise be permanent noise (CR-020, AC-034/m19). `RackFormFactor` itself is v1 data; only the two rules that read it defer.

### 4.1 Changing height, and the shrink-below-occupancy case

Three ways to set height, all producing one `ResizeRackCommand`: the header stepper (`⌄ 24U ⌃`, hold to repeat at 8/s after 400 ms), the inspector field (commits on blur or `Enter`), and dragging the rack's top edge (8 px band, snaps to whole U, a `24U (+3)` readout follows the cursor). While dragging *smaller*, any occupied U about to be removed is hatched in red **in real time**, so the collision is visible before release. Growing is always safe: new U appear at the top and existing `ruIndex` values are untouched.

If the requested height is below the highest occupied U, commit opens a modal. **Principle: never destroy, never silently move, always name the casualties.**

```
┌ Reduce RK-1 to 12U? ─────────────────────────────────────┐
│  3 occupants sit above U12 and cannot stay:              │
│    ▪ BLK-1  Blank panel 1U          U24                  │
│    ▪ SW-1   24-port PoE switch 2U   U21–U22    6 links   │
│    ▪ PP-1   24-port patch panel 2U  U17–U18   24 links   │
│  ┌────────────────────────────────────────────────────┐  │
│  │ (•) Compact first, then shrink                     │  │
│  │     Removes 6U of gaps. All 3 fit below U12.    ✓  │  │
│  │ ( ) Move the 3 above to the Staging Bin            │  │
│  │     Wiring and designators are preserved.          │  │
│  │ ( ) Keep rack at 18U (smallest that fits)          │  │
│  └────────────────────────────────────────────────────┘  │
│  Trim from:  (•) Top   ( ) Bottom                        │
│                                [ Cancel ]  [ Apply ]     │
└──────────────────────────────────────────────────────────┘
```

1. Option 1 appears only when compaction actually helps, and its label states the outcome. Partial success reads `2 of 3 fit — 1 goes to Staging Bin` and remains selectable.
2. Option 1 is preselected when it fully succeeds; otherwise option 2 is. Never preselect the lossy-feeling option when a clean one exists.
3. **Deletion is not offered.** Conflating "the rack got smaller" with "delete my equipment" is how tools lose data.
4. Link counts are shown, because that is the real cost signal, a 24-link patch panel losing its position matters more than a blank.
5. `Trim from: Bottom` shifts every occupant's `ruIndex` down by the removed count, which is what a changed base plinth actually does.
6. Apply is **one** undo entry covering the resize and every displacement.
7. Devices sent to the bin get `StagedPlacement{lastRackId, lastRuIndex, lastFace}`, so the chip offers `↩ Return to RK-1 U21` once space exists (CR-032). A non-empty bin is a legitimate intermediate state, so v1 files nothing for it at all; the `RCK-014` advisory that names it arrives with the v1.2 rules (CR-021).

### 4.2 Other geometry changes

Reducing `usableDepth` below a placed device's depth **displaces nothing**: it files `RCK-012` on each offending device. Depth is a fit problem discovered at install time; forcing displacement would be theatre. Changing width class likewise files findings on full-width occupants rather than moving them. Reducing weight capacity files `RCK-003` immediately.

---

## 5. Derived readouts

Two tiers on screen plus the validation drawer. The split follows AC-039 directly: the four numbers that decide whether a rack is buildable are always visible; every number that rests on a heuristic or an estimate is one click away, closed by default.

**Always-visible chip strip** (20 px, in the rack header):

```
RU 15/24 · 148/200 lb ⁽³⁾ · 1.24 kVA · outlets 14/16 · ⚠2
```

Each of the four rollups (RU, weight, VA, outlets) carries its **unknown count** where one exists, as a superscript that expands on hover to `Total weight 148 lb · 3 devices have no weight`. RU and outlets are counted from placement and port data and are rarely unknown; weight and VA frequently are, because the AC-052 provenance gate stops a template shipping with an uncited safety-adjacent field rather than inventing one. A rollup with nothing unknown shows no superscript.

**Collapsed advisory panel** (closed by default): BTU/hr, centre of gravity, thermal adjacency, deepest-device-vs-usable-depth, largest contiguous free run.

```
┌ RK-1 VITALS ──────────────────────────────┐
│ Space                                     │
│  Front  ▓▓▓▓▓▓▓▓▓▓▓▓░░░░░░░░  15/24 U     │
│  Rear   ▓▓▓▓▓▓▓░░░░░░░░░░░░░   9/24 U     │
│ Weight                        ⚠           │
│  ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓░░░░░  148 / 200 lb (74%) │
│  3 devices have no weight — not counted    │
│ Power              [nameplate | typical]  │
│  Panel A/Br 14  ▓▓▓▓▓▓▓▓▓░  14.2 / 16.0 A │
│  Outlets      14 used / 16 available      │
│ ▸ Advisory (BTU, centre of gravity, depth)│
└───────────────────────────────────────────┘
```

Rules that make these honest:

- **No fabricated numbers, ever** (G4, CR-114). `typicalWatts` does **not** default to half of nameplate, the rejected behaviour that made every derived figure suspect. Unknown is `null`, `null` renders `—`, and **every rollup states its unknown count** (`3 devices have no weight — not counted`). Estimated values carry a dotted underline on screen and italics in print.
- Front and rear RU are tracked separately, because "how much room is left" genuinely has two answers.
- Amps derive from `Circuit.volts`, never from a rack-level voltage. The continuous limit is 80% of the breaker, the figure NEC 210.19(A)(1) gives: 15 A → 12 A, 20 A → 16 A. **It is a planning estimate and the tooltip says so** (DR-079 §11.78.4): nothing here classifies a load as continuous, no demand factor is applied, and a person sizing a service still does a load calculation. Breaker math uses nameplate, thermal math uses typical, regardless of which the toggle displays, and the tooltip says that too.
- BTU/hr uses the single constant `kBtuPerWattHour = 3.412142` from `rackmate_core/units/thermal.dart`; heat is derived, never stored (CR-005).
- **No computed number blocks anything** (G3, CR-022). Errors gate only `ExportSpec.issuedForConstruction`, the stamp, never the bytes.

### 5.1 Findings and their surfacing

Severity is `error | warning | advisory | off` (CR-018), `info` is renamed `advisory` everywhere. Every finding, **including errors**, is acknowledgeable via one `AckedFinding{ruleId, targetFingerprint, reason, by, at, demotedTo}` at two scopes, reason required at project scope (CR-019, RJ-006); refusing a professional the right to override the tool's opinion about their own system is how the tool gets abandoned. Reasons print on sheet `T0.02`.

| Rule | v1? | Severity | Trigger |
|---|---|---|---|
| `RCK-001` | **v1** | error | RU overlap on the same face |
| `RCK-002` | **v1** | error | device extends past `heightU` |
| `RCK-003` | **v1** | warning (advisory at 85 %) | Σ weight > `weightCapacity` |
| `RCK-012` | **v1** | error | front + rear depth + 50 mm > `usableDepth` on overlapping RU |
| `RCK-013` | **v1** | warning | device over `maxUnsupportedMass` on front ears only, needs rear support or a shelf (AC-028) |
| `PWR-001` | **v1** | warning | Σ continuous amps > 80 % of breaker |
| `RCK-003b` | v1.2 | warning | wall-mount rack over 80 % of capacity |
| `RCK-004` / `RCK-007` | v1.2 | advisory, default off on wall & credenza | centre of gravity above 55 % · heat source with no vent above |
| `RCK-014` | v1.2 | advisory | devices present in the Staging Bin |
| `PWR-006` | v1.2 | warning | device draws power with no outlet assigned |

The `v1?` column is not decoration: the v1 catalogue is a **counted** set, and a table that shows an unmarked superset is how the count drifted in the first place. Only the six rules marked **v1** above are members of it; the v1.2 rows are deferred by [the rule catalogue](02-data-model.md#5-the-v1-validation-rule-catalogue--three-tiers) §5.3 and must not be tallied into it.

Rejected alternatives on severity: `RCK-003` and `RCK-012` as blocking errors, and "errors are not dismissible", a found over-spec install must be documentable (G2). The full **28-rule** catalogue lives in [the rule catalogue](02-data-model.md#5-the-v1-validation-rule-catalogue--three-tiers); a rule not in it does not exist (CR-021). Findings surface in three places at once: a 14×14 badge on the device (triangle/octagon/circle, **shape as well as colour**), the rack header's `⚠n` rollup, and the drawer, where each row selects and zooms to its subject. Recomputation is incremental per rack on a microtask, so a multi-device drag computes once; `F7` re-checks the project with progress and cancel (AC-058/D14).

---

## 6. Non-device occupants

**Occupancy is a property of the mount, not the class.** Blanks, vents, fans, cable managers, patch panels and shelves are ordinary `DeviceTemplate`s with a particular `OccupancySide` and port set, so the placement code stays uniform. Depth and weight are siblings on `TemplateBody`, not folded into an occupancy struct; they are per-model physical facts and do not vary with mounting (CR-036).

| Occupant | Occupancy | Editor notes |
|---|---|---|
| Blank panel 1/2/3/4U | `{front: n, rear: 0}` | Neutral fill, ridge texture. Excluded from active-device counts. |
| Vent panel | `{front: n, rear: 0}` | Perforation pattern at zoom ≥ 0.75; `openAreaPct` feeds the thermal advisory. |
| Fan panel | `{front: n, rear: 0}` | One power inlet; counts toward load; carries `cfm`, `dBA`. |
| Patch panel | `{front: n, rear: n}` | `PassthroughPairDef{frontKey, rearKey, sameNet}` (CR-057). Occupies rear U, the most common "why can't I place this", which is exactly why the ruler carries a rear accent bar. |
| PDU / UPS | `{front: 1..2, rear: 0..2}` | Outlet map at zoom ≥ 1.5, assigned outlets filled. UPS usually drives centre of gravity. |
| Rear lace bar | `{front: 0, rear: 1}` | Rear elevation only; a 6 px bar annotated with its depth offset. |
| 0U vertical PDU / lacer | `side: zeroUVertical` | `ZeroUPlacement{rackId, channelId, offsetFromChannelStart, orientation}`. |
| Shelf | `{front: n, rear: 0}` + container | §6.1. |

**0U occupants ship in the model and render as plain bars, but have no drag gesture in v1** (AC-044). They are created and edited from the inspector, channel, start U, span. Rejected alternative: modelling them as `OffRackPlacement`, which would corrupt every outlet-accounting number, since a 24-outlet 0U PDU is precisely why "outlets used/available" is worth showing. The 16 px gutters, rotated bars, drag-into-gutter, resize handles and the `G` gutter toggle all land in v1.1.

### 6.1 Shelves and hosted devices

A shelf is a container and its hosts consume **zero additional RU**. Containment is **child→parent only**: `ShelfPlacement{hostDeviceId, order: FracIndex, lateralOffset: Len?, locked}` (CR-029). Rejected alternative: `Shelf.hosts` as a parent-owned ordered list; that is simultaneously a second source of truth and positional identity, both forbidden by the data model. `shelf.hosts` exists as a **derived view** sorted by `order`, and `DeviceInstance.hostDeviceId` is deleted as redundant.

```
   ┌────────────────────────────────────────────────────────┐
U8 │ ╭─ SHF-1 · 2U vented shelf ── 375 mm ── 38/50 lb ────╮ │
   │ │┌──────────┐ ┌──────────┐ ┌───────────┐            │ │
U7 │ ││ STB-1    │ │ STB-2    │ │ ATV-1     │ ░ 104mm ░  │ │
   │ │└──────────┘ └──────────┘ └───────────┘  ░ free ░  │ │
   │ ╰────────────────────────────────────────────────────╯ │
   └────────────────────────────────────────────────────────┘
```

1. **Drop onto a shelf**: when the ghost enters the tray and the dragged template's `mountMethod` includes `hosted`, the tray lightens, a 2 px vertical caret appears at the nearest gap, and the ghost shrinks to the device's true lateral width. Drop inserts at that ordinal; the rest re-pack.
2. **Auto-pack left to right** is the v1 behaviour, driven entirely by `ShelfPlacement.order`. Reordering is a horizontal drag with a 120 ms slide. `lateralOffset` stays in the format because the free-position case is real; only its UI defers (AC-043).
3. **Leaving the shelf**: a vertical drag more than 20 px out of the tray converts the gesture back into a rack placement.
4. **Capacity is live during drag.** The shelf header shows `38/50 lb` with a 3 px bar showing the projected value under the hovering ghost. Exceeding capacity **does not block**; it files a warning and the header reads `62/50 lb ⚠`, because an integrator may be documenting an existing over-spec install.
5. **Lateral overflow does block**: the caret turns red, `Needs 178 mm, 104 mm free on shelf`.
6. **Hosted devices are full devices**: designator, ports, links, schedule rows, materials list. The only thing they lack is an independent `ruIndex`.
7. **Deleting a shelf** prompts `SHF-1 hosts 3 devices. [Delete all 4] [Move hosts to Staging Bin] [Cancel]`, defaulting to move-to-bin (AC-058/D5).

---

## 7. Naming and designators

Three distinct strings per device, and conflating them is what makes competitors' schedules useless. v1's default UI exposes exactly one of them on the authoring path (AC-047).

| Field | Example | Source | Edit |
|---|---|---|---|
| `designator` | `AMP-1` | allocated and **stored at creation** | `F2` inline |
| `name` | `Living Room Amp` | free text, need not be unique | `Ctrl+F2` |
| type name | `16-channel amplifier` | from the `TemplateSnapshot` | template only |

Format is `{TYPE_PREFIX}{SEP}{SEQ}` through the one format engine in `rackmate_core/idformat/` (CR-041, CR-045); `n` is the lowest unused positive integer for that prefix in scope. Per-rack scoping composes from `Rack.designator` directly, `RK-1-AMP-1`, because `refDesPrefix` is deleted and two identifiers for one rack is the exact failure the schedule exists to prevent (CR-040). Seed prefixes: `AMP · SW · RTR · MTX · AVR · DISP · PROJ · STB · MP · NVR · CAM · PP · PDU · UPS · PWR · CTL · KP · SHF · BLK · VNT · FAN · CM · LB`. Note that `STR` is **not** in this list, it collides in shipped data and the Structure device uses its own prefix (CR-043); see [Structure device](07-structure-device.md).

**Every designator is evaluated once at creation and stored** (CR-048). Nothing is recomputed at render time; changing a scheme offers a renumber with a diff, never a silent rewrite. A manual edit sets `DeviceInstance.designatorLocked` and draws a 🔒 in the designator chip. On a collision, the inline field turns red with `AMP-1 is used by Living Room Amp [Swap] [Go to]`, `Swap` exchanges the two values in one command, which is what the user wants most of the time.

`Ctrl+R` opens **Renumber**, always presented as a diff (`6 change · 12 unchanged · 3 locked`), because renumbering rewrites labels on schedules that may already be printed and cables that may already be physically labelled. It **refuses locked designators by default and reports how many it skipped** (CR-034). `Link.designatorLocked` is auto-set once `roughInStatus >= pulled`: sixty physically labelled cables renumbered by accident is a day of relabelling (AC-034/m22). One undo entry.

Locations come from the **project-level Locations panel** (`Project ▸ Locations…`), not from this editor and not from the Structure editor (CR-112). Racks carry `locationId`; devices inherit and may override. Renaming a location propagates to every label, schedule row and PDF callout in one undoable command.

---

## 8. Keymap

Rack-editor bindings only; the complete ~40-binding table is generated from the single `Intent` registry into `build/keymap.md` at build time so it cannot drift from the code, and the arbitrated bindings themselves are ruled in [canon §1.10](canonical-decisions.md#110-interaction) (CR-101). Three arbitration principles apply: view-switching and global keys beat view-local meanings; a key means the same thing everywhere or nothing; unmodified letters must not collide between views sharing the canvas.

| Key | Action | Scope |
|---|---|---|
| `Ctrl+1..4` | Rack · Schematic · Rear · Schedule | global |
| `Ctrl+0` / `Ctrl+9` / `Ctrl+Alt+0` | fit content · fit selection · zoom 100 % | global |
| `Ctrl+K` / `Ctrl+F` / `Ctrl+G` | command palette · find · go to designator | global |
| `Ctrl+P` / `Ctrl+E` | export/print · export other formats | global |
| `Ctrl+Shift+F` | cycle elevation face (Front → Rear → Both) | **rack only** |
| `Ctrl+Alt+I` · `/` | insert device · focus palette search | global · rack |
| `Enter` | place top result at caret, or quick-insert popover on a free U | rack |
| `↑ ↓` · `Shift+↑↓` · `Ctrl+↑↓` · `Alt+↑↓` | nudge · extend · next free · swap | rack |
| `Home` `End` `PgUp` `PgDn` | extremes · ±10U | rack |
| `←` `→` | move selection to the adjacent rack | rack |
| `Ctrl+L` | lock / unlock (position here, route in the schematic) | global |
| `Ctrl+R` | renumber, scoped to the selection kind | global |
| `Ctrl+D` · `Del` · `Ctrl+X/C/V` · `Ctrl+Shift+V` | duplicate · delete · cut/copy/paste · paste in place | rack |
| `G` / `L` | toggle grid · cycle label mode | global |
| `Ctrl+Shift+W` | toggle warning badges (`W` belongs to the schematic) | global |
| `F2` / `Ctrl+F2` | edit designator · edit name | rack |
| `Ctrl+Alt+U` / `Ctrl+Alt+N` | rack settings · new rack | rack |
| `U` | send selection to the Staging Bin | rack |
| `Ctrl+Alt+1/2/3` | palette · inspector · outline panel | global |
| `F7` / `F8` / `Shift+F8` | re-check · next issue · previous issue | global |
| `Space+drag`, `MMB` · `Ctrl+wheel` | pan · zoom about cursor | global |
| `Esc` | cancel drag, exit mode, clear selection | global |

**Every binding above is scoped, and "global" never means "including inside a text field."** A key pressed while a `TextField` holds focus belongs to that field, full stop. This is not a nicety: `RackCanvasScreen` mounts its `Shortcuts` above the whole palette + canvas + inspector `Row`, and Flutter dispatches key events **leaf → root** while `DefaultTextEditingShortcuts`, which is what turns `Backspace` into a character delete, is installed at the app root. A bare binding here is therefore consulted *before* text editing, not after, and swallows the key. For nine days that made the palette filter uncorrectable, and made `Backspace` in it delete the selected rack device instead.

Concretely, for any binding in this table that is a bare key or a `Ctrl`/`Alt` chord a text field may want (`Del`, `Backspace`, arrows, `Home`, `End`, `PgUp`, `PgDn`, `Esc`, `Enter`, `/`, `Ctrl+Z`, `Ctrl+Y`, `Ctrl+Alt+U`, `Ctrl+Alt+N`):

* it must be a real `Action` whose `isActionEnabled` is false when the key is not for it, a `CallbackAction` consumes its key regardless of what the body does, and `consumesKey => false` is **not** an equivalent escape hatch (it yields `skipRemainingHandlers`, which halts dispatch just as dead);
* canvas keys gate on canvas focus, document-global keys (`Ctrl+Z`/`Ctrl+Y`) gate only on "no text field has focus", so undo still works from the palette and the inspector;
* `Esc` inside a text field belongs to that field. In the palette filter it clears the query and returns focus to the canvas.

`Ctrl+Alt` is `AltGr` on Windows, so `Ctrl+Alt+U`/`Ctrl+Alt+N` will collide with printable characters on layouts where `AltGr+U`/`AltGr+N` produce one. Gating them off inside text fields removes the collision where a character could be typed; the collision remains when the canvas has focus, and is accepted.

**In v1 the tab strip shows three tabs: Rack, Schematic, Schedule.** `Ctrl+3` is reserved for the Rear Panel view and is an unbound no-op until v1.1 (CR-071); `Ctrl+4` is the Schedule in v1 and forever. Do not rebind the Schedule to `Ctrl+3`, `Ctrl+n` is a view identity, not an ordinal. The `Ctrl+1..4` row above is therefore written as the stable identity map, not as what the v1 strip renders.

Deleted bindings and why: `F`/`Shift+F` are unbound here (they mean Focus/Isolate in the schematic and rear views); `Ctrl+B` is reserved with `Fill gaps` (AC-045); `Ctrl+Shift+R` belongs to the schematic since auto-arrange defers; "Focus mode on this rack" is deleted as a distinct command; it is fit-selection with a rack selected, i.e. `Ctrl+9`.

---

## 9. Empty state, first run, accessibility

**First launch** shows a start card, not an empty canvas: `Blank project` plus the four starter projects, which are authored as **real `.rmpj` files** doing triple duty as goldens, perf fixtures and screenshot source (AC-052). A user who picks "Home theater" is editing a populated, finding-clean 24U rack in two seconds, which is a far lower-effort mode than creating one.

**New rack** is three fields (Name, Preset, Height) and `Enter` commits. The `Location` combobox is **removed from this dialog** (AC-048): an empty required-looking dropdown on field two of the very first dialog was the first cliff in the corpus, and location is set later from the rack inspector or the Locations panel.

**Empty rack** renders rails, holes and ruler at full fidelity, it should look like a rack immediately, with a 40 % hint card reading `Press / to search devices, or drag from the palette`, fading out permanently on the first pointer-down. The measured keyboard-only path from launch to a populated 8-device rack is nine `/ query ⏎` cycles, roughly 25 seconds. That works because `Enter` from palette search places at the caret and advances it; it is worth protecting in every future change. Eight further empty states (no racks, empty bin, no findings, empty schedule, no templates in a category, no search results, no circuits, no locations) are designed alongside it (AC-058/D4). Progressive disclosure is three one-time coach marks, not a tour: one on first placement, one on first finding, and one on the first rack→schematic switch (CR-104, AC-048). The third points at the **domain filter bar** and reads `Filter to a domain to draw the wires`, under DR-001 the filter is the primary way a user sees routed links, not a fallback for a crowded sheet, so it is taught the first time the Schematic is opened rather than discovered later.

**Accessibility.** `F6`/`Shift+F6` cycle focus regions; `Ctrl+F6` returns to canvas. Within the canvas focus has two levels, `Tab` moves between racks, `Enter` descends to the insertion caret at U1, `Esc` ascends. The caret **announces every U it passes**: `U14, free` / `U19 to U20, AMP-1, 16-channel amplifier`. Every keyboard action produces a spoken result via `SemanticsService.announce` on a polite live region, with vitals announcements throttled to one per 2 s and only on a threshold crossing. **No pointer-only affordance exists**: the header `⋮`, the resize band and shelf reordering all have keyboard equivalents.

Device bodies are real widgets, so they carry `Semantics` natively, a substantial argument for the hybrid render architecture over pure canvas. Rails and ruler are decorative and excluded; `shouldRebuildSemantics` compares a `topologyVersion` rather than delegating to `shouldRepaint`, or every pan rebuilds the tree. The **outline tree** (`Ctrl+Alt+3`) is the primary AT surface and the honest accessibility story for a canvas app: a real `TreeView` mirroring racks → U ranges → shelf hosts → 0U occupants → Staging Bin, fully editable, with bidirectional selection. Visually: no information by colour alone (severity uses shape, rear occupancy uses hatch); text ≥ 4.5:1 and outlines ≥ 3:1 in both themes; `MediaQuery.textScaler` honoured to 2.0 with bodies degrading to designator-only; `disableAnimations` replaces the invalid-drop shake with a persistent red border, since a motion cue with motion disabled communicates nothing; hit targets 24×24 px mouse, 44×44 px touch.

---

**See also:** [Data model](02-data-model.md) for `Placement`, `Rack` and `Circuit` · [Architecture](03-architecture.md) for the command stack and the render tiers · [Schematic editor](05-schematic-editor.md) for where links are actually created · [Device builder](06-device-builder.md) for `TemplateBody` and occupancy · [Decisions](10-decisions.md) for every `CR`/`AC` cited here.
