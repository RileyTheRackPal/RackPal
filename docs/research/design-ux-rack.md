# RackMate — Rack Elevation Editor Specification

**Document scope:** the view where a user creates racks, sets RU height, and places occupants. Wiring/schematic view is out of scope except where the elevation must expose connection state.

**Design constants used throughout.** Logical geometry is stored as integers (`int` U counts, `int` tenths-of-mm). Screen geometry at **zoom 1.0**: `1U = 22 device px`; `19 in panel width = 239 px`; therefore `12.571 px/in`. A 42U rack is 924 px tall at 100%, which is the number the whole layout is tuned around.

---

## 1. Screen layout

### 1.1 Desktop shell

```
┌──────────────────────────────────────────────────────────────────────────────────────────────┐
│ ≡  RackMate   Project: Hillcrest Residence*                          [Front|Rear|Both]  ⌕  ⚙ │ 44px  Toolbar
├────────────┬───────────────────────────────────────────────────────────┬─────────────────────┤
│ PALETTE    │  RACK CANVAS                                              │ INSPECTOR           │
│ 280px      │  flex                                                     │ 320px               │
│ ┌────────┐ │                                                           │ ┌─────────────────┐ │
│ │⌕ search│ │   ┌── RACK A ─ Media Closet ────┐   ┌── RACK B ─────┐     │ │ AMP-1           │ │
│ └────────┘ │   │ 24U · 61% · 148/200 lb  ⚠2 │   │ 12U · 25% ✓   │     │ │ 16-ch Amplifier │ │
│ ▾ Recent   │   ├────────────────────────────┤   ├───────────────┤     │ ├─────────────────┤ │
│  ▪ 8×8 MTX │   │24┊▭▭▭▭▭▭▭▭▭▭▭▭▭▭▭▭┊ BLK-1  │   │12┊           ┊│     │ │ Identity        │ │
│  ▪ 24p PoE │   │23┊                ┊        │   │11┊ (empty)   ┊│     │ │  RefDes  AMP-1  │ │
│ ▾ Amps     │   │22┊████ SW-1 ██████┊        │   │10┊           ┊│     │ │  Name    LR Amp │ │
│  ▪ 8-ch    │   │21┊████████████████┊        │   │ 9┊           ┊│     │ │  Location Media │ │
│  ▪ 16-ch   │   │20┊                ┊        │   │ 8┊           ┊│     │ ├─────────────────┤ │
│ ▾ Network  │   │19┊████ AMP-1 ─────┊ ⚠      │   │ 7┊           ┊│     │ │ Mounting        │ │
│  ▪ 24p sw  │   │18┊████████████████┊        │   │ 6┊           ┊│     │ │  Height   2 U   │ │
│  ▪ Router  │   │…                            │   │…              │     │ │  Face     Front │ │
│ ▾ Power    │   │ 2┊████ UPS-1 ─────┊        │   │ 1┊           ┊│     │ │  Rear U   2     │ │
│  ▪ 1U PDU  │   │ 1┊████████████████┊        │   └───────────────┘     │ │  Depth   16.0in │ │
│  ▪ 0U PDU  │   └────────────────────────────┘                          │ │  Weight   28 lb │ │
│ ▾ Panels   │                                                           │ ├─────────────────┤ │
│  ▪ Blank1U │   ┌ STAGING BIN (2) ──────────────────────────────┐       │ │ Electrical      │ │
│  ▪ Vent 2U │   │  [STB-3 1U]  [NAS-1 2U]          Place all ▸  │       │ │  Watts    420   │ │
│  ▪ Shelf1U │   └───────────────────────────────────────────────┘       │ │  Amps     3.5   │ │
│ ▾ Structure│                                                           │ │  PDU  PDU-1:o4  │ │
│  ▪ Rough-in│                                                           │ ├─────────────────┤ │
│            │                                                           │ │ RACK A VITALS   │ │
│            │                                                           │ │ ▓▓▓▓▓▓░░░░ 61%RU│ │
│            │                                                           │ │ ▓▓▓▓▓▓▓░░░ 74%wt│ │
│            │                                                           │ │ 1,240 W  4,231 B│ │
│            │                                                           │ └─────────────────┘ │
├────────────┴───────────────────────────────────────────────────────────┴─────────────────────┤
│ ⚠ 2 warnings   ▸ AMP-1 needs 1U clearance above  ▸ Circuit A at 14.2A of 16A       [expand]  │ 28px
├──────────────────────────────────────────────────────────────────────────────────────────────┤
│ Rack A · U19 · Front    │  zoom 100%  [−][100%][+]  │  2 selected  │  3 racks · 41 devices    │ 24px
└──────────────────────────────────────────────────────────────────────────────────────────────┘
```

**Regions, concretely:**

| Region | Default | Min / Max | Behaviour |
|---|---|---|---|
| Toolbar | 44 px | fixed | Never hides. Face selector is a 3-segment control, always visible. |
| Palette (left) | 280 px | 220 / 480 | Resizable via 4 px splitter (8 px hit slop, `resizeLeftRight`). Collapsible to a 40 px icon rail (`Ctrl+Alt+1`). |
| Canvas (center) | flex | 480 px min | Never collapses. Owns horizontal + vertical scroll. |
| Inspector (right) | 320 px | 280 / 520 | Resizable. Collapsible (`Ctrl+Alt+2`). Two stacked sections: **Selection** (top, scrolls) and **Rack Vitals** (bottom, pinned, 200 px, itself collapsible). |
| Validation drawer | 28 px collapsed | 28 / 320 | Drag its top edge to expand. Auto-expands to 180 px once on first *error* per session, never again. |
| Status bar | 24 px | fixed | Left = cursor context (rack/U/face), center = zoom, right = counts. |

**Docking policy (v1):** panels are **collapsible and resizable but not floatable or re-dockable**. Free-floating docks are a scope trap; the payoff is near zero for a two-panel app. Widths persist in app settings, not the project file. Reserve the option by putting each panel behind a `PanelHost` widget keyed by a `PanelId` so a future dock manager is a swap, not a rewrite.

### 1.2 Tablet / narrow collapse

v1 tablet is **read-only review**, so the collapse is a viewer, not a squeezed editor. Breakpoint at **< 1080 logical px width**.

```
┌────────────────────────────────────┐
│ ← Hillcrest Residence   [F|R]  ⋮   │ 52px
├────────────────────────────────────┤
│                                    │
│      ┌── RACK A ──────┐            │
│      │24┊▭▭▭ BLK-1 ▭▭┊│            │   Canvas fills.
│      │23┊            ┊│            │   Pinch zoom, one-finger pan.
│      │22┊███ SW-1 ███┊│            │   Tap device → bottom sheet.
│      │…               │            │
│      └────────────────┘            │
│                                    │
├────────────────────────────────────┤
│ ╭──────────────────────╮           │  Bottom sheet, 3 detents:
│ │ AMP-1 · 16-ch Amp    │  peek 88  │  peek 88 / half 45% / full
│ │ 2U · U19 · 28 lb     │           │
│ ╰──────────────────────╯           │
├────────────────────────────────────┤
│  [Racks] [Vitals] [Schedule] [⚠2]  │ 56px tab bar
└────────────────────────────────────┘
```

- Palette becomes a full-screen modal reached from `⋮ → Devices` (disabled in read-only).
- Inspector becomes the bottom sheet.
- Validation becomes the `⚠` tab with a badge count.
- **Architectural rule that keeps touch open:** every gesture handler in the canvas is registered against a `PointerDeviceKind`-agnostic intent layer (`CanvasIntent.beginDrag / updateDrag / commitDrag`). Mouse produces intents from `Listener`; touch produces the same intents from long-press-then-drag with a 44 px minimum target and a 250 ms hold. No editor logic branches on device kind.

---

## 2. The rack canvas

### 2.1 Anatomy of one rack column

```
                 ┌─────────────────────────────────────────┐
                 │ RACK A · Media Closet          ⌄ 24U ⌃ ⋮│  32px header (sticky on v-scroll)
                 │ RU 15/24 · 148/200 lb · 1.2kW · ⚠2      │  20px chip strip
  ╔══════════════╪═════════════════════════════════════════╪══════════════╗
  ║ 0U gutter L  │           ▲ 8px resize band ▲            │ 0U gutter R  ║
  ║   (16px)     ├──┬──┬───────────────────────────┬──┬─────┤   (16px)     ║
  ║ ┌──┐         │24│ o│                           │o │     │         ┌──┐ ║
  ║ │  │         │  │ o│   ▭▭▭ BLK-1  1U ▭▭▭▭▭     │o │     │         │  │ ║
  ║ │P │         ├──┤ o├───────────────────────────┤o │     │         │L │ ║
  ║ │D │         │23│ o│                           │o │     │         │A │ ║
  ║ │U │         │  │ o│   (free)                  │o │     │         │C │ ║
  ║ │- │         ├──┤ o├───────────────────────────┤o │     │         │E │ ║
  ║ │2 │         │22│ o│ ┏━━━━━━━━━━━━━━━━━━━━━━━┓ │o │     │         │  │ ║
  ║ │  │         │  │ o│ ┃ SW-1                  ┃ │o │     │         │  │ ║
  ║ │  │         ├──┤ o│ ┃ 24-port PoE switch    ┃ │o │     │         │  │ ║
  ║ │  │         │21│ o│ ┃              2U  ⚡14A ┃ │o │     │         │  │ ║
  ║ └──┘         │  │ o│ ┗━━━━━━━━━━━━━━━━━━━━━━━┛ │o │     │         └──┘ ║
  ║              ├──┼──┴───────────────────────────┴──┤     │              ║
  ║              │  ▲ruler  ▲rail   ▲ 17.75in opening ▲rail │              ║
  ╚══════════════╧═════════════════════════════════════════╧══════════════╝
      16px         28px  20px          ~180px @z1.0      20px       16px
                   └──────────── 239 px = 19 in ────────────┘
```

**The RU ruler** (28 px wide, left of the left rail; mirrored to the right side when `Both` view is active so the two elevations share a center ruler):

- One label per U, right-aligned, 11 px tabular-figure font, `onSurfaceVariant`.
- Division lines drawn **at the U boundary**, which per EIA-310 falls at the **midpoint of the 0.500 in gap** — i.e. through the narrow web between hole pairs, *not* through a hole. Boundary line = 1 px hairline at 30% opacity; every 5th U boundary = 1 px at 60% with a bolder label.
- Numbering direction is a per-rack setting, `uNumbering: bottomUp | topDown`, **default `bottomUp`** (U1 at bottom, EIA/NetBox convention). Top-down is offered because a meaningful slice of A/V integrators count from the top; the setting is on the rack, not the app, because a project can legitimately mix (a retrofit rack labelled by the previous integrator).
- The ruler is the **primary occupancy indicator**: a U's label cell gets a 3 px left accent bar when occupied front, a 3 px right bar when occupied rear. At a glance you can see front/rear occupancy without switching faces.

**The rails** (20 px each at z1.0):

- Rail body: 1 px border, fill `surfaceContainerHigh`.
- **Three holes per U**, centered at 0.25, 0.875, 1.50 in from the U boundary. At zoom ≥ 0.75 these are drawn as real circles (`r = 1.6 px` at z1.0, square 3×3 px for square-hole racks, per `rack.railType`). Below 0.75 the rail is drawn as a repeating 1 px dotted texture — a single cached `Picture` tiled, not 126 individual circles.
- Devices with rack ears draw **ear screws**: filled dots at the outer two hole positions of the device's first and last U, at zoom ≥ 0.75. This is the visual cue that separates an ear-mounted device from a shelf-hosted one at a glance.
- `railType` (`tapped10-32 | tapped12-24 | square | clearance`) changes hole rendering and appears in the BOM as required hardware. It does **not** gate placement.

**Rendering architecture** (per the canvas research): rails + holes + ruler are **Tier-1 cache** — one `ui.Picture` per rack, invalidated only on `(rackId, ru, railType, zoomDecade)`. At zoom < 0.5 the grid picture is additionally promoted with `Picture.toImageSync()` and re-baked per zoom decade. Device bodies are **real widgets** as children of `RenderRackCanvas`, laid out with tight constraints from their own model size so dragging one never dirties another's layout. Selection chrome, drag ghosts, snap indicators and the insertion caret are **Tier-3 overlay**, never cached.

### 2.2 Level of detail

| Zoom | Rails | Device body |
|---|---|---|
| < 0.40 | flat fill, no texture | solid block, category colour, RefDes only if ≥ 20 px wide |
| 0.40–0.74 | dotted texture | RefDes (bold 11 px) + U-height badge |
| 0.75–1.49 | real holes, ear screws | RefDes + name (truncate, `…`) + type + badges (⚡ amps, ⚠ warnings, 🔗 connection count) |
| ≥ 1.50 | holes + rail edge highlight | adds port strip along the body's inner edge (rear face only), weight microtext, PDU outlet map |

Text scale is **quantised to a ladder** `{0.5, 0.75, 1.0, 1.5, 2.0, 3.0}` with the residual applied as a local canvas scale, so the glyph atlas hits across continuous zoom. All `TextPainter`s live in a bounded LRU (2000 entries) keyed on `(text, style, maxWidth)` and are `dispose()`d on eviction.

### 2.3 Front vs rear

Three modes on the toolbar segmented control, plus `F` and `Shift+F`:

1. **Front** (default for layout work) — single column.
2. **Rear** — single column, drawn **mirrored** (left rail on screen = the rail that is on your left when standing behind the rack). Mirroring is physically honest and it is what an installer standing behind the rack sees. A per-project setting `mirrorRearElevation` (default `true`) can disable it, because some shops document rear elevations unmirrored to match front drawings; when disabled a persistent `NOT MIRRORED` chip appears in the rack header so the drawing never lies about itself.
3. **Both** — front and rear side by side, 16 px apart, sharing a single center ruler, each with a 16 px caption bar (`FRONT` / `REAR`). Rack cell width roughly doubles; the canvas auto-fits on mode change.

Face is **not** a filter, it is a coordinate. A device carries an occupancy struct, and a 2U patch panel with `{frontU: 2, rearU: 2}` renders in both. A rear-rail lace bar `{frontU: 0, rearU: 1}` renders only in rear. When you're in Front mode, rear-only occupants are shown as a **4 px hatched strip** in the ruler's right accent bar — present but not clickable — so you never place a device into a U that is rear-blocked without knowing.

Switching face **preserves selection** (a device selected in front stays selected in rear if it appears there) and **preserves the insertion caret's U**.

### 2.4 Multiple racks

Racks lay out **left to right in a single row**, in explicit `bayOrder`, with a 48 px gutter. Vertical alignment: bottoms aligned (racks sit on the floor). Wall-mount racks get a `mountHeightIn` field and are drawn offset upward with a hatched wall-line beneath — visually distinguishing a 12U wall box from a 12U floor rack matters when the drawing is handed to an installer.

- **Reorder racks:** drag the rack header horizontally; other racks slide with a 150 ms ease; a 3 px accent insertion bar shows the landing slot.
- **Bays:** select 2+ adjacent racks → `Group as bay`. A bay draws shared side rails, a bracket above with the bay name, and rolls up vitals for the whole bay. Purely organisational (the NetBox "bundles" precedent) — it does not change geometry or occupancy.
- **Focus mode** (`Ctrl+F`): dims all racks but the focused one to 25% and fits it to viewport. `Esc` exits.
- `Alt+1..9` jumps focus to rack N. `Tab` / `Shift+Tab` cycles racks.

**Staging Bin** — a persistent, per-project holding strip pinned below the rack row. It holds devices that exist in the project with full identity, RefDes and **all their wiring intact**, but have no rack position. It is fed by rack shrink (§4.3), by `Ctrl+X`-style "unrack", and by importing a device list. It renders as a horizontal chip strip with an amber left border. A non-empty bin always produces a validation **warning**, never an error — it is a legitimate intermediate state.

---

## 3. Placement interaction

### 3.1 Cursor and hover state table

| Target | Cursor | Visual on hover |
|---|---|---|
| Empty canvas | `basic` | — |
| Empty U inside a rack | `basic` | That U's ruler cell brightens to `surfaceContainerHighest`; 1 px dotted accent lines at both its boundaries; tooltip after 600 ms: `U14 — free (front) · 4U contiguous free above` |
| Placed device body | `grab` | 1.5 px accent outline inset 1 px; elevation shadow 2; badges fade in over 90 ms; tooltip after 700 ms with full vitals card |
| Placed device, `Ctrl` held | `copy` | outline turns to dashed accent — signals drag-to-duplicate |
| Locked device | `basic` + 🔒 badge | outline is 1.5 px `outline` colour, not accent |
| Rack top edge (8 px band) | `resizeUpDown` | 3 px accent bar spanning rail-to-rail; floating readout `24U` follows cursor |
| Rack header | `basic` | reveals `⌄ 24U ⌃` stepper and `⋮` menu button (hidden until hover to keep the header quiet) |
| 0U gutter | `basic` | gutter fill lightens; vertical channel dashed outline |
| Shelf interior | `basic` | tray lightens; lateral slot dividers appear |
| Splitter | `resizeLeftRight` | 2 px accent line after 120 ms delay |
| Space held, anywhere | `grabbing` | pan mode |

Hover hit-testing is **throttled to one query per frame** via a dirty flag on a `Ticker` — raw `onHover` fires far above frame rate on 1000 Hz mice and a spatial query per event is pure waste.

### 3.2 Drag from palette → drop

The whole gesture is hand-rolled on `Listener`. **`Draggable`/`DragTarget` are not used** — they hand off in widget space, and we need scene coordinates with live RU snapping and a proper undo entry.

**Phase 1 — arm (pointer down on palette item):** no visual change until the pointer moves 4 px (drag threshold), so a click still means "select template / show details".

**Phase 2 — lift:** the palette row gets a 1 px accent inset outline and drops to 40% opacity in place (it does not vanish — the source stays legible). A **cursor-attached card** appears: 180×40 px, 6 px radius, elevation 8, showing the type icon, name, and `2U` badge. Cursor `grabbing`.

**Phase 3 — enter canvas:** the cursor card cross-fades over 100 ms into a **scene-accurate ghost** — a rectangle at true rack width and true U height, fill `accent @ 12%`, border 1.5 px solid accent, with the device name centered. Because there is no grab offset from a palette drag, the ghost is centered vertically on the cursor.

**Phase 4 — snap.** Vertical position is **hard-quantised, always**. There is no free-placement mode; racks are quantised by nature and offering sub-U placement would only create invalid data.

```
bottomU = clamp(
  round((cursorSceneY − ghostHeight/2 − rackOriginY) / U_HEIGHT_TENTHS),
  0,
  rack.ru − device.heightU
)
```

Snap feedback, all in the Tier-3 overlay:
- A **2 px accent line** at the landing U boundary, extending from 12 px into the ruler gutter across to 12 px past the far rail.
- The ruler labels for the full occupied U range invert (accent fill, `onAccent` text).
- A **U-range chip** pinned to the ghost's top-right: `U19–U20`.
- The ghost snaps with no animation (instant), because interpolating a quantised value reads as lag.

**Phase 5 — validity.** Evaluated every frame, first failing reason wins:

| # | Check | Message |
|---|---|---|
| 1 | Front U range free | `Occupied by AMP-1 (U19–U20)` |
| 2 | Rear U range free | `Rear blocked by PP-2 at U19` |
| 3 | Fits within rack extent | `Needs 4U, only 2U free at top` |
| 4 | Device depth ≤ rack usable depth | `18.0 in device in a 12.0 in rack` |
| 5 | Clearance rule (`requiresClearanceAboveU/BelowU`) | *warning, not blocking* |
| 6 | Mount method compatible | `Shelf-only device — drop it on a shelf` |
| 7 | Width class fits (half-rack onto rails without a kit) | `Half-rack: needs an ear kit or a shelf` |

Checks 1–4 and 6–7 **block**. Check 5 permits the drop and files a warning — heuristics from trade guidance must never hard-block, and this is exactly where a tool earns or loses trust.

**Invalid-drop rendering:** ghost fill → `error @ 12%`, border → 1.5 px **dashed** error (4-4 dash), the conflicting occupant gets a 45° hatch overlay at 4 px pitch in `error @ 25%`, cursor → `forbidden`, and a **reason chip** (28 px tall, 8 px radius, `errorContainer`, offset +16/+16 from cursor) states the message. Releasing while invalid is a **no-op** with a 120 ms shake (±3 px horizontal, 2 cycles) and the reason chip persisting 1.2 s before fading.

**Phase 6 — commit:** on pointer-up over a valid target, one `PlaceDeviceCommand` is pushed to the undo stack. The new device animates in: 120 ms scale 0.96→1.0 + opacity 0→1, then a 400 ms accent outline pulse that decays. It becomes the sole selection, the inspector focuses its RefDes field's *label* (not editing), and the status bar announces `Placed AMP-2 at Rack A U19–U20` (also fired as a `SemanticsService.announce`).

**Escape hatches during drag:** `Esc` cancels (ghost fades over 100 ms, palette row restores). Dragging outside any rack shows the ghost at 40% with a `Release to add to Staging Bin` chip — dropping there is valid and creates an unracked device. This matters: it lets a user dump gear into the project fast and place it later.

### 3.3 Alternate placement paths (faster than dragging)

Dragging is not the fastest path and shouldn't be the only one.

- **Palette search + Enter.** `/` focuses the search box. Type `8x8`, press `Enter` → the top match is placed **at the insertion caret**, or if no caret, at the **lowest free U that fits** in the focused rack. The caret then advances past the new device. This makes populating a rack a pure typing exercise: `/ 8x8 ⏎ / 16ch ⏎ / 24p ⏎`.
- **Double-click a palette item** → same as Enter.
- **Double-click an empty U** in the canvas → opens a **quick-insert popover** anchored to that U: a 240 px search field with live results, arrow-key navigation, `Enter` places at that exact U. This is the single fastest interaction in the editor and it should be the one shown in onboarding.
- **Right-click empty U** → context menu: `Insert device…`, `Insert 1U blank`, `Insert vent panel`, `Insert shelf`, `Paste`, `Fill gap with blanks`.

### 3.4 Moving a placed device

- Grab anywhere on the body. Threshold 4 px. The device itself drops to 30% opacity **in place** (showing the vacated slot) and a full-opacity ghost follows the cursor with the original grab offset preserved.
- **Vertical motion is free within the rack; horizontal motion is ignored** until the cursor passes a **60 px threshold beyond a rail**, at which point the ghost jumps to the nearest neighbouring rack and snaps to that rack's U grid (and to that rack's width, which may differ). A 2 px accent border pulses around the target rack. If the ghost is over the Staging Bin, the bin's border brightens.
- Same validity rules and same invalid rendering as §3.2.
- Commit on pointer-up = one `MoveDeviceCommand`. `Esc` mid-drag reverts.
- **Modifiers during move:**
  - `Ctrl` (drag start) → **duplicate**: original stays at full opacity, ghost is a copy, RefDes auto-increments on drop.
  - `Alt` (held at drop) → **insert & push**: occupants above the drop point shift up by the device's height. If pushing overflows the rack top, RackMate tries pushing *down* instead; if neither fits, the drop is invalid with `Insert would overflow rack by 2U`. During `Alt`, the devices that will move are drawn with a 1 px dashed outline at their *destination* positions, so the consequence is visible before commit.
  - `Ctrl+Shift` (held at drop, over a device of identical U height) → **swap**: both devices show a ↔ badge and exchange positions.
- **Face change** is not a drag gesture (dragging between two mirrored columns in Both view is ambiguous and error-prone). It is `Shift+F` on the selection, or the Face field in the inspector. The device keeps its U.

### 3.5 Keyboard nudge and the insertion caret

The **insertion caret** is a first-class object: a 2 px accent line at a U boundary with a 6 px triangle at each rail and the U label highlighted in the ruler. It exists whenever the canvas has focus and nothing is selected. It is what makes keyboard-only placement work.

- `↑` / `↓` — with a selection: move selection by 1U. With no selection: move the caret by 1U.
- `Shift+↑/↓` — extend selection to the adjacent device (not by U — by occupant, which is what you mean).
- `Ctrl+↑/↓` — move selection to the **next free slot** in that direction, skipping over occupied space. This is the "get out of my way" nudge.
- `Alt+↑/↓` — **swap with the adjacent occupant**, regardless of relative heights (the two exchange, and if heights differ the stack re-packs from the lower of the two positions). This is the reorder gesture.
- `Home` / `End` — move to the lowest/highest position that fits.
- `PgUp` / `PgDn` — ±10U.
- Nudges **coalesce into one undo entry** if consecutive within 500 ms on the same axis, so holding `↓` and releasing is a single undo, not fourteen.
- A nudge that would collide **does not silently stop**. The selection shakes 3 px and the status bar reads `Blocked by SW-1`. Silent no-ops in a nudge are the most common source of "the app is broken" reports.

### 3.6 Selection

- Click = replace selection. `Ctrl/Cmd+click` = toggle. `Shift+click` = **range select by U** — every occupant between the anchor and the clicked device in that rack, inclusive.
- **Marquee** on empty canvas: press-drag draws a 1 px accent rect with `accent @ 8%` fill. Following CAD muscle memory: **left→right drag selects only fully-contained occupants; right→left selects anything intersecting**. The marquee border is solid for containment mode, dashed for intersection mode, and a tiny corner label reads `WINDOW` / `CROSS`. This costs one `if` and reads as expertise.
- `Shift` during marquee = add, `Alt` = subtract.
- `Ctrl+A` = select all in the focused rack; pressing again = select all in project.
- Multi-select visual: each member gets a 2 px accent outline; a **combined bracket** is drawn in the ruler gutter spanning the union of their U ranges; the status bar reads `3 selected · 5U · 62 lb · 780 W` — a rollup of the selection is genuinely useful when planning a move.
- Selection is the unit for: move, nudge, delete, copy, duplicate, face change, lock, and inspector multi-edit (fields with differing values show `—` and editing applies to all).

### 3.7 Copy / paste / duplicate / delete

| Command | Behaviour |
|---|---|
| `Ctrl+C` | Copies selection to an internal clipboard **and** as JSON to the system clipboard (so it pastes into another RackMate window, and is inspectable/diffable). Relative U offsets within the selection are preserved. |
| `Ctrl+X` | Cut. Removes from rack; **wiring is preserved on the clipboard** and restored on paste. |
| `Ctrl+V` | Pastes into the focused rack at the **insertion caret**, or if no caret, at the lowest free region that fits the whole group. If the group cannot fit contiguously, paste offers `Place what fits (3 of 5) — remainder to Staging Bin` in a toast with an `Undo` action. |
| `Ctrl+Shift+V` | **Paste in place** — same U positions as the source, into the focused rack. Invalid if occupied; the toast names the blockers. |
| `Ctrl+D` | Duplicate: places the copy **immediately above** the original if space exists, else the nearest free region above, else below, else Staging Bin. RefDes auto-increments. |
| `Del` / `Backspace` | Deletes. If the selection has ≥1 connection, a **non-modal confirm bar** slides into the status area: `Delete AMP-1 and its 6 connections?  [Delete] [Cancel]` with `Enter`/`Esc` bound. If zero connections, delete immediately (with undo) — never prompt for a consequence-free action. |

Delete always removes attached wires, and undo restores device *and* wires as one command. Never orphan a wire.

### 3.8 Auto-arrange (all of it is preview-then-accept)

Nothing in this group ever applies silently. Each opens a **preview overlay**: proposed positions drawn as solid ghosts, current positions dimmed to 25%, and a floating bar `Compact Up · 4 devices move · 3U freed   [Apply] [Cancel]`. `Enter` applies, `Esc` cancels. One undo entry.

| Command | Rule |
|---|---|
| **Compact Down** (`Ctrl+Shift+C`) | Remove all gaps, packing toward U1. Preserves relative order. Respects locked devices as immovable anchors. |
| **Compact Up** | Same, packing toward the top. |
| **Fill gaps with blanks** (`Ctrl+B`) | Every free front-U run gets blank panels chosen greedily from available sizes (4U, 3U, 2U, 1U) — a 7U gap becomes 4U+2U+1U, not seven 1U blanks. Vent panels are used instead of blanks for any gap **directly above a device whose `thermalClass` is `high`**. |
| **Insert blank** (`B`) | One blank matching the current selection's height, above the selection. |
| **Auto-arrange** | The opinionated one. Sorts by: heaviest to the bottom (CG rule — a top-mounted UPS is a documented rack-tipping failure), then thermally sensitive gear low, then high-heat gear with 1U spacing between units, then vent panels above heat sources, then patch panels and cable managers at the top. Reserves 15% spare RU. **Every rule it applies is listed in the preview bar** (`Applied: heavy-low, amp spacing, vent-above-heat`) with per-rule checkboxes, because these are trade heuristics, not standards, and integrators have strong and differing opinions about them. |

---

## 4. Rack configuration

### 4.1 Where it lives

Three entry points to the same `RackInspector` panel (which replaces the Selection section of the right dock):
1. Click the rack header, or the rack's empty background.
2. `Ctrl+Alt+U` with a rack focused.
3. `⋮ → Rack settings` in the header menu.

```
┌ RACK A ─────────────────────────────┐
│ Identity                            │
│  Name       [Media Closet        ]  │
│  RefDes     [R1        ] (prefix)   │
│  Location   [Basement ▾] + New…     │   ← bound to project Location vocabulary
│  Notes      [                    ]  │
├─────────────────────────────────────┤
│ Form factor                         │
│  Preset  [Floor enclosure 24U ▾  ]  │   ← sets the fields below; switching
│  Height  [⌄]  24  [⌃]  U            │      to any preset marks fields "from
│  Width   [19 in (482.6 mm)      ▾]  │      preset" until hand-edited
│  Usable depth  [25.75] in  ⓘ        │   ← ⓘ: "usable, not overall"
│  Rail type [10-32 tapped        ▾]  │
│  Weight capacity [2500] lb          │
│  Mount   ( ) Floor  (•) Wall        │
│  Mount height  [42] in AFF          │
│  Swing frame  [x]  Hinge [Left ▾]   │
├─────────────────────────────────────┤
│ Display                             │
│  U numbering  (•) Bottom-up ( ) Top │
│  Mirror rear elevation      [x]     │
├─────────────────────────────────────┤
│ Circuits                            │
│  ● Circuit A  20A · 16A cont · 14.2A│
│  ● Circuit B  15A · 12A cont ·  3.1A│
│  [+ Add circuit]                    │
└─────────────────────────────────────┘
```

**Presets** are the fast path. `Wall box 6U/12 in`, `Swing gate 12U/12 in`, `Swing gate 20U/18 in`, `Pivot cabinet 10U/17 in`, `Floor enclosure 18/21/27/35/44U`, `Open frame 4-post 44U`, `Credenza bay 8U`, `Data 42U/36 in`. Each carries height, depth, weight capacity, rail type and mount. Presets are seed data in the same editable format as device templates.

**Weight capacity is the field that matters most** and it is placed prominently, not buried. A 12U wall rack rated 100 lb hits its limit long before it runs out of RU, and this is the single most binding constraint in residential CI.

### 4.2 Setting RU height

Three ways, all producing one `ResizeRackCommand`:
1. **Stepper** in the header (`⌄ 24U ⌃`) — ±1U per click, hold to repeat at 8/s after 400 ms.
2. **Numeric field** in the inspector — commits on blur or `Enter`, range 1–58.
3. **Drag the rack's top edge** — 8 px grab band, `resizeUpDown` cursor, snaps to whole U, live readout chip follows the cursor showing `24U (+3)`. While dragging *smaller*, any U about to be removed that is occupied is drawn with a red 45° hatch **in real time**, so the user sees the collision building before they release.

Growing a rack is always safe: new U appear at the top (bottom-up numbering) or the numbering shifts (top-down), existing devices keep their physical position.

### 4.3 The shrink failure case — designed explicitly

**Principle: never destroy, never silently move, always name the casualties.**

If the requested height is below the highest occupied U, releasing the drag (or committing the field) opens a modal:

```
┌ Reduce Rack A to 12U? ──────────────────────────────────┐
│                                                          │
│  3 occupants sit above U12 and cannot stay:              │
│                                                          │
│    ▪ BLK-1   Blank panel 1U          U24                 │
│    ▪ SW-1    24-port PoE switch 2U   U21–U22   6 wires   │
│    ▪ PP-1    24-port patch panel 2U  U17–U18  24 wires   │
│                                                          │
│  ┌──────────────────────────────────────────────────┐    │
│  │ (•) Compact first, then shrink                   │    │
│  │     Removes 6U of gaps. All 3 fit below U12.  ✓  │    │
│  │                                                  │    │
│  │ ( ) Move the 3 above to the Staging Bin          │    │
│  │     Wiring and RefDes are preserved.             │    │
│  │                                                  │    │
│  │ ( ) Keep rack at 18U (smallest that fits)        │    │
│  └──────────────────────────────────────────────────┘    │
│                                                          │
│  Trim from:  (•) Top   ( ) Bottom                        │
│                                                          │
│                                [ Cancel ]  [ Apply ]     │
└──────────────────────────────────────────────────────────┘
```

Design notes on this dialog, because it is the most important error state in the editor:

- **Option 1 is offered only if compaction actually succeeds**, and its label states the result (`All 3 fit below U12 ✓`). If compaction gets you partway, the label reads `2 of 3 fit — 1 goes to Staging Bin` and option 1 is still selectable.
- **Option 1 is preselected when it fully succeeds; otherwise option 2 is preselected.** Never preselect the destructive-feeling one when a clean one exists.
- **Deletion is not an option in this dialog.** If the user wants those devices gone they can delete them explicitly; conflating "the rack got smaller" with "delete my equipment" is how tools lose data.
- **Wire counts are shown** because that is the real cost signal — losing a 24-wire patch panel's position is a bigger deal than losing a blank.
- **Trim from Top/Bottom** matters for retrofits: trimming from the bottom shifts every occupant down by the removed U count and renumbers, which is occasionally what you want when a rack's base plinth changes.
- Apply produces **one undo entry** covering the resize and every displacement. `Ctrl+Z` fully restores.
- A device sent to the Staging Bin keeps `lastRackId` and `lastBottomU`, so the bin chip offers `Return to Rack A U21` once space exists.

### 4.4 Other geometry changes

- **Reducing usable depth** below a placed device's depth does not displace anything — it files a **depth error** on each offending device (`SW-1 is 18.0 in in a 12.0 in rack`). Depth is a fit problem discovered at install time, so surfacing it as a persistent error is correct; forcing displacement would be theatre.
- **Changing width class** (19 in → 10 in) files errors on full-width occupants rather than moving them.
- **Reducing weight capacity** below current load files a weight warning immediately (§5).

---

## 5. Live derived readouts

### 5.1 Three tiers of visibility

**Tier A — rack header chip strip** (always visible, 20 px, no interaction required):

```
RU 15/24 · 148/200 lb · 1.24 kW · 4,231 BTU/h · ⚠2
```

Each chip turns amber at its warning threshold and red at its error threshold, with an icon change as well as a colour change (never colour alone). Clicking a chip scrolls the Vitals panel to that section.

**Tier B — Rack Vitals panel** (pinned bottom of the right dock, 200 px, collapsible):

```
┌ RACK A VITALS ────────────────────────────┐
│ Space                                     │
│  Front  ▓▓▓▓▓▓▓▓▓▓▓▓░░░░░░░░  15/24 U     │
│  Rear   ▓▓▓▓▓▓▓░░░░░░░░░░░░░   9/24 U     │
│  Largest contiguous free: 5U (U19–U23)    │
│                                           │
│ Weight                        ⚠           │
│  ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓░░░░░  148 / 200 lb (74%) │
│  Centre of gravity  ▁▃█▃▁  U9.2  (38%) ✓  │
│                                           │
│ Power              [nameplate | typical]  │
│  Watts   1,240 W    Amps @120V  10.3 A    │
│  Circuit A  ▓▓▓▓▓▓▓▓▓░  14.2 / 16.0 A ⚠   │
│  Circuit B  ▓▓░░░░░░░░   3.1 / 12.0 A     │
│  Outlets      14 used / 16 available      │
│                                           │
│ Thermal                                   │
│  4,231 BTU/hr    Vent panels: 2           │
│  Deepest device 18.0 in / 25.75 in usable │
└───────────────────────────────────────────┘
```

Specifics that matter:

- **Front and rear RU are tracked separately** and both shown. They genuinely differ (a 2U patch panel eats both; a rear lace bar eats only rear) and "how much room do I have left" has two answers.
- **Largest contiguous free** is more actionable than total free and integrators ask for it constantly.
- **Amps** = `watts / 120` by default; `rack.lineVoltage` supports 120/230/240.
- **BTU/hr** = `watts × 3.412`.
- **Nameplate vs typical toggle.** Devices carry both `nameplateWatts` and `typicalWatts` (default `typical = 0.5 × nameplate` if unspecified, flagged as estimated with a dotted underline). **Breaker math uses nameplate; thermal math uses typical.** The toggle switches the *display*; the validation rules always use the correct one regardless of what's shown, and a tooltip says so.
- **Circuits are first-class objects** on the rack. PDUs are assigned to a circuit; devices are assigned to a PDU outlet. Unassigned devices roll into a pseudo-circuit `Unassigned` shown in grey. Continuous-load limits are per NEC 210.19(A)(1): **15 A → 12 A, 20 A → 16 A**.
- **Centre of gravity** is a small sparkline of the weight distribution by U plus the CG height as both a U value and a % of rack height. It turns amber above 55%.

**Tier C — Validation drawer** (bottom, collapsible). The KiCad ERC pattern: a flat navigable list, grouped by severity, each row clickable to select and zoom-to the subject.

```
┌ VALIDATION ── [All ▾] [Errors 0] [Warnings 3] [Info 2] ── [Re-check] [×] ┐
│ ⚠  Circuit A at 14.2 A of 16.0 A continuous limit        Rack A          │
│ ⚠  AMP-1 requests 1U clearance above; SW-1 is adjacent   Rack A U21   ⓧ │
│ ⚠  2 devices in the Staging Bin are unplaced             Project        │
│ ℹ  Rack A has 9U spare (38%) — target is 15–25%          Rack A         │
│ ℹ  UPS-1 (62 lb) is the heaviest item and sits at U1  ✓  Rack A         │
└─────────────────────────────────────────────────────────────────────────┘
```

### 5.2 Severity model and the rule catalogue

Three levels, and the distinction is principled: **Error = the physical world says no. Warning = a code or a rating says no. Info = the trade says probably not.**

| Rule | Severity | Trigger |
|---|---|---|
| U range overlap | Error | two occupants share a front or rear U |
| Device deeper than rack usable depth | Error | `device.depth > rack.usableDepth` |
| Duplicate RefDes | Error | uniqueness violated in scope |
| Device extends past rack extent | Error | data-import case |
| Over weight capacity | **Warning** | `Σ weight > rack.capacity` — amber at 85%, red at 100% |
| Shelf over its weight capacity | Warning | `Σ hosted weight > shelf.capacity` |
| Circuit over continuous limit | Warning | `Σ nameplate amps > 0.8 × breaker` |
| Outlets oversubscribed | Warning | `Σ outletsConsumed > Σ outletsProvided` |
| Unplaced devices in Staging Bin | Warning | count > 0 |
| Clearance rule violated | Warning | `requiresClearanceAbove/BelowU` not satisfied |
| Device with no power source | Warning | `watts > 0` and no PDU outlet assigned |
| CG above 55% of rack height | Info | top-heavy heuristic |
| Heat source with no vent above | Info | `thermalClass: high` and next U up is solid |
| Adjacent high-heat devices | Info | two `thermalClass: high` in adjacent U |
| Spare RU outside 15–25% | Info | planning heuristic |
| Wall rack over 80% weight | Warning | wall mounts are the documented failure mode |

Every **Info** row has a per-rule `ⓧ` dismiss and a per-project "don't show this rule again" in settings. **Warnings are dismissible per-instance with a required reason note** (which then appears in the PDF export appendix — an integrator who overrides a circuit warning should have that override documented). **Errors are not dismissible.**

Recomputation is incremental: each rack keeps a `VitalsSnapshot` recomputed on any command touching that rack, on a microtask so a multi-device drag computes once. Full project re-check is `F7`.

### 5.3 Inline surfacing on the canvas

Warnings must be visible where the problem is, not only in a drawer:

- A device with any issue gets a **badge** on its top-right corner: 14×14 px, triangle for warning, octagon for error, circle for info. Hover shows the message.
- The rack header's `⚠2` chip is the rack rollup.
- The **clearance rule gets special rendering**: when a device declares `requiresClearanceAboveU: 1`, the U above it is drawn with a light diagonal hatch and a small `↑1U` marker whenever that device is selected or hovered — so the user sees the requested airspace as a spatial thing, not a text warning. If that U is occupied, the hatch turns amber.

---

## 6. Non-device occupants

**Core modelling rule: occupancy is a property of the mount, not the class.** Every occupant carries:

```dart
class Occupancy {
  final int frontU;         // 0 for rear-only and zero-U
  final int rearU;
  final MountSide side;     // front | rear | both | zeroUVertical
  final int depthTenthMm;
  final int weightGrams;
}
```

So blank panels, vent panels, fan panels, patch panels and shelves are **not special cases** — they are device templates with particular occupancy and port sets. This keeps the editor's placement code uniform.

| Occupant | Occupancy | Ports | Editor notes |
|---|---|---|---|
| Blank panel 1/2/3/4U | `{front:n, rear:0}` | none | Flat neutral fill, subtle horizontal ridge texture. Excluded from device counts and BOM "active device" totals. |
| Vent panel | `{front:n, rear:0}` | none | Perforation dot pattern at zoom ≥ 0.75; `openAreaPct` field (VT ≈ 64%). Feeds the thermal heuristic. |
| Fan panel | `{front:n, rear:0}` | 1 power inlet | Draws power, counts toward load, has `cfm` and `dBA`. |
| Horizontal cable manager | `{front:n, rear:0}` | none | Drawn as a finger-duct texture. |
| Patch panel | `{front:n, rear:n}` | paired front/rear, `passthrough: true` | Renders port grid at zoom ≥ 1.5 on both faces. Occupies rear U — this is the most common cause of a "why can't I place this" moment, hence the ruler's rear accent bar. |
| Rackmount PDU | `{front:1..2, rear:0..2}` | outlets | Outlet map rendered at zoom ≥ 1.5; assigned outlets filled, free hollow. |
| UPS | `{front:n, rear:n}` | inlet + outlets | Usually the heaviest item; drives CG. |
| **Rear lace bar (LBP)** | `{front:0, rear:1}` | none | Visible **only** in rear elevation, drawn as a 6 px bar with its offset depth annotated (`LBP-2A · 2 in`). In front elevation it appears only as the ruler's rear hatch. |
| **0U vertical PDU** | `{front:0, rear:0, side: zeroUVertical}` | outlets | Lives in the 0U gutter (§6.2). |
| Vertical lacer strip (LACE) | `{front:0, rear:0, side: zeroUVertical}` | none | 0U gutter. |
| **Shelf** | `{front:n, rear:0}` + container | none itself | §6.1. |

### 6.1 Shelves as containers — the three-devices-on-a-shelf case

A shelf is a **container**, and hosted devices consume **zero additional RU**.

```dart
class ShelfOccupant extends RackOccupant {
  final int weightCapacityGrams;
  final int usableDepthTenthMm;
  final int usableWidthTenthMm;      // 17.75 in opening, or less
  final List<HostedDevice> hosts;
}

class HostedDevice {
  final String deviceId;             // full device: RefDes, ports, wiring
  final int xOffsetTenthMm;          // lateral position on the tray, from left
  final int widthTenthMm;            // from widthClass or custom
  // NO rackU. Position is owned by the shelf.
}
```

**Rendering.** A 2U shelf hosting three devices at zoom ≥ 0.75:

```
   ┌──────────────────────────────────────────────────────────┐
U8 │ ╭─ SHF-1 · 2U vented shelf ─── 14.75 in ── 38/50 lb ──╮  │
   │ │┌──────────┐ ┌──────────┐ ┌────────────┐             │  │
   │ ││ STB-1    │ │ STB-2    │ │ ATV-1      │  ░░░░░░░░░  │  │
U7 │ ││ Cable box│ │ Cable box│ │ Apple TV   │  ░ 4.1in ░  │  │
   │ ││ 8.5in 12lb│ │ 8.5in 12lb│ │ 3.9in 1lb │  ░ free  ░  │  │
   │ │└──────────┘ └──────────┘ └────────────┘             │  │
   │ ╰──────────────────────────────────────────────────────╯  │
   └──────────────────────────────────────────────────────────┘
     ▲ tray outline: 1.5px solid, 4px radius, 2px inset from rails
       hosted device: 1px outline, 3px radius, category-tinted fill
       free lateral space: 3px diagonal hatch @ 15%
```

**Interactions:**

- **Dropping onto a shelf.** When a drag ghost enters a shelf's bounds and the dragged device's `mountMethod` includes `hosted`, the shelf tray lightens and a **vertical insertion caret** (2 px accent, full tray height) appears at the nearest gap between hosted devices. The ghost shrinks to the device's true lateral width. Drop inserts at that lateral index; subsequent devices shift right.
- **Lateral drag within a shelf.** Grab a hosted device, drag horizontally; the caret shows the reorder position; other hosts slide with a 120 ms ease. Vertical drag out of the tray beyond 20 px converts the gesture back to a rack-placement drag (the device leaves the shelf).
- **Free-position mode.** Default is auto-packed left-to-right with even gaps. `Alt`-drag within the shelf enables **free lateral positioning** (snapped to 1 mm), for representing a real install where a box sits centered. A shelf in free mode shows a small `↔ free` chip.
- **Capacity feedback, live during drag.** The shelf header shows `38/50 lb` and a 3 px capacity bar. As a ghost hovers, the bar shows the projected value in a lighter accent. Exceeding capacity **does not block the drop** — it files a warning — because an integrator may legitimately be documenting an existing install that's over spec. But the bar goes red immediately and the header reads `62/50 lb ⚠`.
- **Lateral overflow does block.** If the device's width exceeds remaining tray width, the caret turns red and the reason chip reads `Needs 7.0 in, 4.1 in free on shelf`.
- **Depth check per host:** `host.depth > shelf.usableDepth` → warning badge on that host (`10.4 in shelf, 12.0 in device — overhangs`). Overhang is common and survivable, so warning not error.
- **Hosted devices are full devices.** They get RefDes, appear in the outline tree indented under the shelf, appear in the BOM, their ports participate fully in the netlist and the wiring schedule, and their ports carry front/rear side. The only thing they lack is an independent rack U.
- **Deleting a shelf** prompts: `SHF-1 hosts 3 devices. [Delete all 4] [Move hosts to Staging Bin] [Cancel]`. Default is move-to-bin.
- **Selecting a shelf** selects the container; `Enter` or double-click **enters the shelf** (a focus mode where arrow keys move between hosts laterally); `Esc` exits.

### 6.2 Zero-U items and the 0U gutter

Each rack draws a **16 px gutter outside each rail**, present only in rear elevation (and in Both view, only on the rear column) since zero-U mounting is a rear-channel affair.

- A 0U occupant renders as a vertical bar in the gutter with rotated 90° text. It has a **vertical extent in U-equivalents** (`spanU`) and a `channel` (`leftRear | rightRear`), plus a `startU`.
- Dragging into the gutter: the gutter fill lightens, a vertical snap line appears, and the ghost becomes a vertical bar. Vertical position snaps to U; the bar can be resized by dragging either end (8 px grab bands, `resizeUpDown`).
- Two 0U items in the same channel with overlapping U ranges = **warning**, not error (real racks stack a lacer strip and a PDU in the same channel with offset brackets).
- 0U items contribute **weight, power, outlets and ports** to all rollups but **zero RU**. A 0U PDU providing 24 outlets is exactly why the "outlets used/available" readout is worth having.
- `G` toggles gutter visibility.

---

## 7. Annotation and labelling

### 7.1 The three name fields

Every occupant carries three distinct strings, and conflating them is the mistake that makes cable schedules useless:

| Field | Example | Source | Editable |
|---|---|---|---|
| `refDes` | `AMP-1` | auto-assigned, unique, project-scoped | yes, `F2` |
| `name` | `Living Room Amp` | user, free text, need not be unique | yes, `Ctrl+F2` |
| `typeName` | `16-channel amplifier` | from the device template | via template only |

`refDes` is the join key for every schedule row, label and diagram callout. **Uniqueness is enforced, not suggested** — this is the single loudest gap in the competing tools, where a rack with three identical amps cannot produce a correct cable schedule.

### 7.2 Auto-assignment

On placement, RefDes = `{prefix}-{n}` where `prefix` comes from the template's `refDesPrefix` and `n` is the lowest unused positive integer for that prefix in scope.

Seed prefixes: `AMP` amplifier · `SW` network switch · `RTR` router · `MTX` matrix switch · `AVR` receiver · `DISP` display · `PROJ` projector · `STB` set-top box · `MP` media player · `NVR` recorder · `CAM` camera · `PP` patch panel · `PDU` power distribution · `UPS` UPS · `PWR` power conditioner · `CTL` control processor · `KP` keypad · `SHF` shelf · `BLK` blank panel · `VNT` vent panel · `FAN` fan panel · `CM` cable manager · `LB` lace bar · `STR` structure.

**Scope** is a project setting:
- `project` (default) — `AMP-1`, `AMP-2` across all racks.
- `perRack` — `R1-AMP-1`, `R2-AMP-1`. Uses the rack's own `refDes` prefix (`R1`).

Changing scope opens the renumber preview (§7.4) rather than silently rewriting every label.

### 7.3 Overriding

- `F2` (or double-click the RefDes zone on the device body — the top-left 60×14 px region, which shows a text-edit cursor on hover) opens **inline editing**: the RefDes renders as an editable field in place, text pre-selected, monospace.
- Live validation as you type: a duplicate turns the field's border red with a chip `AMP-1 is used by Living Room Amp  [Swap] [Go to]`. **`Swap` is the good affordance here** — it exchanges the two RefDes values in one command, which is what the user wants 90% of the time they hit a collision.
- Empty is rejected; `Esc` reverts; `Enter` or blur commits.
- Committing a manual edit sets `refDesLocked = true` on that occupant. A small 🔒 appears in the RefDes chip's corner at zoom ≥ 1.0.

### 7.4 Renumber

`Ctrl+R` opens **Renumber**:

```
┌ Renumber reference designators ─────────────────────┐
│ Order by  (•) Position: rack order, then U top→down │
│           ( ) Position: rack order, then U bottom→up│
│           ( ) Current RefDes (alphanumeric)         │
│ Scope     (•) All racks   ( ) Rack A only           │
│ [ ] Include manually-locked designators (3)         │
│                                                     │
│  AMP-2  →  AMP-1     Living Room Amp     A U19      │
│  AMP-1  →  AMP-2     Theater Amp         B U4       │
│  SW-1   →  SW-1      Core switch         A U21   =  │
│  🔒 MTX-9  (locked, unchanged)                       │
│                                                     │
│  6 change · 12 unchanged · 3 locked                 │
│                          [ Cancel ]  [ Renumber ]   │
└─────────────────────────────────────────────────────┘
```

This is presented as a **diff**, because renumbering rewrites labels on schedules that may already be printed and cables that may already be physically labelled. One undo entry.

### 7.5 Location vocabulary

`Location` is not free text — it is a **project-level vocabulary** (`Locations: Basement, Media Closet, Living Room, Primary Bedroom…`) with a combobox that permits inline creation. Racks have a location; devices inherit their rack's location and can override; Structure ports carry a location per port group.

This directly addresses the documented failure where drawings say "Study", the homeowner says "Office", and the labels say "Room 3". **Renaming a location propagates everywhere** — every label, every schedule row, every PDF callout — in one undo-able command.

### 7.6 Body label rendering

The device body layout at zoom ≥ 0.75:

```
┌────────────────────────────────────────────────────────┐
│ AMP-1 🔒          Living Room Amp              2U  ⚠ ⚡ │  ← 14px line
│ ─────                                                  │
│ 16-channel amplifier · 28 lb · 420 W        🔗8        │  ← 11px line, ≥1.0 only
└────────────────────────────────────────────────────────┘
  ▲ RefDes chip: monospace 11px bold, accent-tinted pill, 60×14px hit target
```

A **Labels** toolbar cycle (`L`) rotates the primary label through `RefDes` → `Name` → `RefDes + Name` → `Type`, because different audiences need different drawings: the installer wants RefDes, the homeowner wants Name.

---

## 8. Keyboard shortcuts (desktop, complete)

`⌘` substitutes for `Ctrl` on macOS throughout via `SingleActivator(..., meta: isMac, control: !isMac)`.

### File and edit
| Key | Action |
|---|---|
| `Ctrl+N` | New project |
| `Ctrl+O` | Open `.rackmate` |
| `Ctrl+S` / `Ctrl+Shift+S` | Save / Save as |
| `Ctrl+P` | Export PDF (diagram + schedule) |
| `Ctrl+Z` | Undo |
| `Ctrl+Shift+Z` / `Ctrl+Y` | Redo |
| `Ctrl+X` / `Ctrl+C` / `Ctrl+V` | Cut / Copy / Paste at caret |
| `Ctrl+Shift+V` | Paste in place |
| `Ctrl+D` | Duplicate |
| `Del` / `Backspace` | Delete selection |
| `Ctrl+A` | Select all in focused rack (again: whole project) |
| `Ctrl+Shift+A` | Deselect all |
| `Esc` | Cancel drag / exit mode / clear selection |

### View and navigation
| Key | Action |
|---|---|
| `Ctrl+0` | Zoom to fit all racks |
| `Ctrl+1` | Zoom 100% |
| `Ctrl+9` | Zoom to fit focused rack |
| `Ctrl+=` / `Ctrl+-` | Zoom in / out about viewport center |
| `Ctrl+wheel` | Zoom about cursor |
| `wheel` | Pan vertical (preference: zoom — set on first run) |
| `Shift+wheel` | Pan horizontal |
| `Space+drag` / `MMB drag` | Pan |
| `F` | Flip face (Front ⇄ Rear) |
| `Shift+F` | Toggle Both-faces view |
| `Ctrl+F` | Focus mode on current rack |
| `Tab` / `Shift+Tab` | Next / previous rack |
| `Alt+1..9` | Focus rack N |
| `Ctrl+Alt+1` / `Ctrl+Alt+2` | Toggle palette / inspector |
| `Ctrl+'` | Toggle validation drawer |
| `G` | Toggle 0U gutters |
| `H` | Toggle rail hole rendering |
| `L` | Cycle label mode |
| `W` | Toggle warning badges |
| `/` | Focus palette search |
| `Ctrl+K` | Command palette |

### Placement and arrangement
| Key | Action |
|---|---|
| `Enter` (palette focused) | Place top result at caret / lowest free U |
| `Enter` (canvas, nothing selected) | Open quick-insert popover at caret |
| `↑` / `↓` | Move caret, or nudge selection ±1U |
| `Shift+↑/↓` | Extend selection to adjacent occupant |
| `Ctrl+↑/↓` | Move selection to next free slot |
| `Alt+↑/↓` | Swap with adjacent occupant |
| `Home` / `End` | Move to lowest / highest fitting position |
| `PgUp` / `PgDn` | ±10U |
| `←` / `→` | Move selection to adjacent rack (same U if free) |
| `Shift+F` (with selection) | Move selection to opposite face |
| `M` | Move to rack… (quick dialog) |
| `B` | Insert blank panel matching selection height |
| `Ctrl+B` | Fill all gaps with blanks/vents (preview) |
| `Ctrl+Shift+C` | Compact down (preview) |
| `Ctrl+Alt+Shift+C` | Compact up (preview) |
| `Ctrl+Shift+R` | Auto-arrange (preview) |
| `Ctrl+L` | Lock / unlock position |
| `U` | Send selection to Staging Bin |

### Naming and rack config
| Key | Action |
|---|---|
| `F2` | Edit RefDes inline |
| `Ctrl+F2` | Edit Name inline |
| `Ctrl+R` | Renumber dialog |
| `Ctrl+Alt+U` | Rack settings |
| `Ctrl+Alt+N` | New rack |
| `Ctrl+Alt+D` | Duplicate rack (with or without contents — asks) |

### Modifiers held during drag
| Modifier | Effect |
|---|---|
| `Ctrl` (at drag start) | Duplicate instead of move |
| `Alt` (at drop) | Insert & push occupants |
| `Ctrl+Shift` (at drop, equal height) | Swap positions |
| `Alt` (lateral drag in shelf) | Free lateral positioning |
| `Shift` (marquee) | Add to selection |
| `Alt` (marquee) | Subtract from selection |

### Validation
| Key | Action |
|---|---|
| `F7` | Full project re-check |
| `F8` / `Shift+F8` | Next / previous issue (selects + zooms to subject) |

All bindings go through `Shortcuts`/`Actions`/`Intent` with named `Intent` classes, which gets menu-bar integration and user remapping for free and keeps the shortcut table itself derivable from the registry (so this document can be generated, not maintained by hand).

---

## 9. Empty state and first run

### 9.1 First launch

No project. A centered start card, not an empty canvas:

```
┌──────────────────────────────────────────────────────────────┐
│                                                              │
│                      ▦  RackMate                             │
│              Design racks. Get a real schedule.              │
│                                                              │
│   ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │
│   │  Blank       │  │  Home        │  │  Network     │       │
│   │  project     │  │  theater     │  │  closet      │       │
│   │              │  │  24U · 9 dev │  │  12U · 6 dev │       │
│   └──────────────┘  └──────────────┘  └──────────────┘       │
│   ┌──────────────┐  ┌──────────────┐                         │
│   │  Conference  │  │  Open a      │                         │
│   │  room  12U   │  │  file…       │                         │
│   └──────────────┘  └──────────────┘                         │
│                                                              │
│   Recent:  Hillcrest Residence · 2h ago                      │
│            Maple St Conf Rm · yesterday                      │
└──────────────────────────────────────────────────────────────┘
```

**Starter projects are the fastest path and they should be first-class**, not a footnote. A user who picks "Home theater" is looking at a populated, warning-clean 24U rack in under two seconds, and can then edit rather than create — which is a far lower-effort mode.

### 9.2 New rack dialog

Blank project → one dialog, four fields, `Enter` commits:

```
┌ New rack ───────────────────────────────┐
│  Name      [Rack A            ]         │
│  Location  [                 ▾]         │
│  Preset    [Floor enclosure  ▾]         │
│  Height    [⌄]  24  [⌃]  U              │
│            ▁▁▁▁▁▁▁▁ preview thumbnail   │
│                    [Cancel]  [Create]   │
└─────────────────────────────────────────┘
```

Everything else (depth, capacity, rail type) comes from the preset and is tunable later. Four fields, not twelve.

### 9.3 Empty rack state

```
     ┌── RACK A · Media Closet ── 24U ──┐
     │24┊                             ┊ │
     │23┊                             ┊ │
     │  ┊    ╭───────────────────╮    ┊ │
     │  ┊    │  This rack is     │    ┊ │
     │  ┊    │  empty            │    ┊ │
     │12┊    │                   │    ┊ │
     │  ┊    │  Press  /  to     │    ┊ │
     │  ┊    │  search devices   │    ┊ │
     │  ┊    │                   │    ┊ │
     │  ┊    │  or drag from the │    ┊ │
     │  ┊    │  palette ←        │    ┊ │
     │ 3┊    ╰───────────────────╯    ┊ │
     │ 2┊                             ┊ │
     │ 1┊  ← insertion caret at U1    ┊ │
     └──────────────────────────────────┘
```

The rails, holes and ruler render at full fidelity even when empty — the rack should look like a rack immediately, so the user sees the tool understands the domain. The hint card sits at 40% opacity and fades out entirely on the first pointer-down anywhere in the rack.

### 9.4 The measured fastest path

Launch → populated 8-device rack, keyboard only:

```
Enter (Blank project)  →  Enter (New rack: defaults)  →  canvas, caret at U1
/ ups ⏎          UPS-1 at U1–U3
/ 16ch ⏎         AMP-1 at U4–U5
/ vent ⏎         VNT-1 at U6
/ 8x8 ⏎          MTX-1 at U7–U9
/ 24p poe ⏎      SW-1  at U10–U11
/ 24p patch ⏎    PP-1  at U12–U13
/ 1u pdu ⏎       PDU-1 at U14
/ shelf 2u ⏎     SHF-1 at U15–U16
Ctrl+B           fills remaining gaps with blanks (preview → ⏎)
```

**Nine search-and-enter cycles, roughly 25 seconds.** This works because `Enter` from palette search places at the caret and advances it — a single design decision that makes the whole editor keyboard-fluent. It is worth protecting in every future change.

### 9.5 Progressive disclosure

No tour, no modal walkthrough. Instead, three one-time contextual coach marks fired by the relevant event and dismissed permanently on interaction:
1. On first successful placement: `Drag to move · ↑↓ to nudge · F2 to rename` (anchored to the device, 4 s auto-dismiss).
2. On first warning: `Warnings live here — click to jump to the cause` (anchored to the validation drawer).
3. On first rack shrink attempt: nothing — the dialog explains itself.

---

## 10. Accessibility

### 10.1 Keyboard-only operation

The editor is fully operable without a pointer. This is not a compliance checkbox — it is the same mechanism that makes it fast for power users, which is why §9.4 works.

**Focus regions.** `F6` / `Shift+F6` cycle: Toolbar → Palette → Canvas → Inspector → Validation → Status. Each region shows a 2 px focus ring on its container. `Ctrl+F6` returns to canvas from anywhere.

**Within the canvas**, focus has two levels:
1. **Rack level** — `Tab`/`Shift+Tab` moves between racks. The focused rack gets a 2 px accent border and its header announces.
2. **Occupant level** — `Enter` descends into the focused rack, placing the **insertion caret** at U1. `↑`/`↓` move the caret one U at a time, and the caret **announces every U it passes**: `U14, free` / `U19 to U20, AMP-1, 16-channel amplifier`. `Esc` ascends back to rack level.

From the caret:
- `Enter` on a free U → quick-insert popover (a real `TextField` + `ListView`, fully AT-navigable).
- `Enter` on an occupant → selects it.
- With a selection, all of §8's placement keys apply.
- `Alt+Enter` → moves focus into the Inspector with the first field focused.
- Inside a shelf, `Enter` descends a third level; `←`/`→` move between hosted devices.

**Every keyboard action produces a spoken result**, via `SemanticsService.announce` on a polite live region:
- Success: `Placed AMP-2, 2U, Rack A, U19 to U20, front.`
- Blocked: `Cannot move down. U18 occupied by PP-1.`
- Derived change: `Rack A now 17 of 24 U used, 176 of 200 pounds.` (throttled to one vitals announcement per 2 s, and only when a threshold is crossed — not on every nudge).

**No pointer-only affordance exists.** Everything reachable by hover reveal (the header `⋮`, the rack resize band, the shelf lateral drag) has a keyboard equivalent: `Ctrl+Alt+U` for rack settings, the RU stepper field, `←`/`→` within a shelf.

### 10.2 Screen-reader semantics

Because device bodies are **real widgets** in the hybrid render architecture, they carry semantics natively — this is a substantial and under-appreciated argument for the hybrid over pure-canvas.

Each occupant widget:

```dart
Semantics(
  container: true,
  selected: isSelected,
  focusable: true,
  label: 'AMP-1, Living Room Amp, 16-channel amplifier',
  value: 'Rack A, U19 to U20, front, 2U, 28 pounds, 420 watts',
  hint: 'Press Enter to select. Arrow keys to move. F2 to rename.',
  // warnings appended to value so they are read, not just seen:
  //   ', warning: requests 1U clearance above, SW-1 is adjacent'
  onIncrease: () => nudge(1),      // maps to VoiceOver/NVDA increment
  onDecrease: () => nudge(-1),
  child: DeviceBody(...),
)
```

The rack container exposes `label: 'Rack A, Media Closet, 24U'`, `value: '15 of 24 U used, 2 warnings'`, and a `SemanticsSortKey` ordering children by U so AT traversal matches physical order (top-to-bottom or bottom-to-top per the rack's `uNumbering`).

For **canvas-painted** content (rails, ruler, 0U bars, snap overlays), `CustomPainter.semanticsBuilder` emits `CustomPainterSemantics` only for the 0U occupants and the insertion caret. Rails and the ruler are decorative and get `excludeSemantics`. Critically, `shouldRebuildSemantics` is overridden to compare a `topologyVersion` rather than delegating to `shouldRepaint` — otherwise every pan rebuilds the entire semantics tree for no reason.

### 10.3 The outline tree — the primary AT surface

A canvas is inherently visual, and heroic canvas semantics are a poor substitute for a real structure. RackMate ships a **Rack Outline** panel (`Ctrl+Alt+3`, a real Flutter `TreeView` of standard widgets) that is a complete, editable, screen-reader-native mirror of the model:

```
▾ Hillcrest Residence
  ▾ Rack A — Media Closet — 24U — 15/24 used — ⚠2
      U24  BLK-1   Blank panel 1U
      U23  (free)
    ▾ U21–U22  SW-1  24-port PoE switch  ⚠
         warning: adjacent to AMP-1, clearance requested
    ▾ U15–U16  SHF-1  2U vented shelf  38/50 lb
         STB-1  Cable box  8.5 in  12 lb
         STB-2  Cable box  8.5 in  12 lb
         ATV-1  Apple TV   3.9 in   1 lb
      U4–U5   AMP-1   16-channel amplifier
      U1–U3   UPS-1   1500VA UPS  62 lb
    ▾ 0U rear-left
         PDU-2  24-outlet vertical PDU  U1–U20
  ▸ Rack B — Equipment Room — 12U — 3/12 used
  ▾ Staging Bin (2)
      STB-3, NAS-1
```

Every editing command works from the tree. Selection is bidirectional with the canvas. For a screen-reader user this is a better experience than the canvas will ever be, and it costs little because the same tree is a genuinely useful power-user navigation panel for sighted users too. The same reasoning applies to the wiring schedule table in the wiring view.

### 10.4 Visual accessibility

- **No information is conveyed by colour alone.** Cable/category colours are always paired with a text label or an icon; warning severity uses shape (triangle / octagon / circle) as well as colour; the occupancy accent bars in the ruler are paired with the hatch pattern for rear.
- Contrast: all text ≥ 4.5:1 against its background in both themes; device outlines ≥ 3:1.
- **Respects `MediaQuery.textScaler`** up to 2.0. Device bodies clamp their internal text at large scales and drop to RefDes-only rather than overflowing; the ruler switches to labelling every 5th U.
- **Respects `MediaQuery.disableAnimations`** — all the eases, pulses and shakes described above become instant state changes. The shake-on-invalid-drop is replaced by a persistent red border, since a motion cue with motion disabled communicates nothing.
- **High contrast mode** thickens all outlines to 2 px and removes fills in favour of outlines + patterns.
- Minimum hit target is **24×24 px** for mouse and **44×44 px** for touch; the RefDes edit zone, the rack resize band and the stepper arrows are all explicitly padded to meet this even though their visual footprint is smaller.

---

## Appendix — model surface this editor requires

```dart
class Rack {
  final String id;                 // UUID, stable
  int  bayOrder;
  String name, locationId;
  String refDesPrefix;             // "R1"
  int  ru;
  RackWidthClass widthClass;
  int  usableDepthTenthMm;
  int  weightCapacityGrams;
  RailType railType;
  RackMount mount;                 // floor | wall
  int  mountHeightTenthMm;
  bool isSwingFrame; HingeSide hingeSide;
  UNumbering uNumbering;           // bottomUp (default) | topDown
  bool mirrorRearElevation;        // default true
  int  lineVoltage;                // 120 | 230 | 240
  List<Circuit> circuits;
}

class Placement {
  final String occupantId;
  final String? rackId;            // null => Staging Bin
  final int bottomU;               // 0-based from the rack's physical bottom
  final ZeroUChannel? channel;     // for zero-U occupants
  final int? spanU;                // for zero-U occupants
  final String? hostShelfId;       // set => hosted; rackId/bottomU ignored
  final int? xOffsetTenthMm;       // lateral position on the host shelf
  final bool locked;
  final String? lastRackId; final int? lastBottomU;  // for Staging Bin return
}
```

Two invariants worth asserting in code, because every subtle bug in this editor traces to one of them:

1. **`bottomU` is always physical**, measured from the rack's bottom regardless of `uNumbering`. Display numbering is a pure render-time transform. Storing display-relative positions makes flipping the numbering direction a data migration.
2. **Front and rear occupancy are independent index sets.** `rack.frontOccupancy` and `rack.rearOccupancy` are separate `List<String?>` of length `ru`, both rebuilt from placements. Every collision check, free-space query and vitals rollup reads from these two arrays and never re-derives from placements ad hoc.