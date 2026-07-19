# M1 implementation log

This tracks *build* status against the *existing* spec — it does not redefine scope. The
governing documents remain [the rack editor spec](04-rack-editor.md) and
[the roadmap](09-roadmap.md); this file exists because M1 is being built across many separate
sessions and stages, and a checklist that only lives in chat history is exactly the kind of
thing that lets a "standard" feature quietly fall through the cracks. Update it at the end of
every M1 stage: move items from **Not started** to **Done**, and add anything a stage
deliberately deferred that isn't already listed below.

Status legend: **Done** (built and tested) · **Partial** (some of the cited behavior works) ·
**Not started**.

---

## 1. Against the roadmap's M1 checklist (docs/09-roadmap.md, line ~223)

| # | Item | Status |
|---|---|---|
| 1 | `ViewportController` with wheel/trackpad/pan/zoom and the grid painter | **Done** |
| 2 | `CanvasIntent` on top, no `PointerDeviceKind` branching | **Done** |
| 3 | Hybrid `RenderRackCanvas`, device widgets, RU snapping, front/rear elevations with per-rack mirroring | **Partial** — RU snapping and front/rear filtering done; **mirroring not done** |
| 4 | Quick-add by typing with the drop caret; the Staging Bin; shelves with auto-pack; 0U occupants from the inspector | **Partial** — quick-add by typing now places at the insertion caret (docs/04 §3.2/§3.4), see §3.2/§3.4 below; the Staging Bin, shelves-with-auto-pack, and 0U-from-the-inspector remain **not started** |
| 5 | Compact Up/Down with preview-then-accept, and the shrink-rack dialog; locks | **Not started** |
| 6 | The full seeded catalog (incl. 18 field devices, `sources.md` provenance, connector-footprint CI assertion) | **Partial** — 48-template seed catalog (30 rack-side + 18 field) with `assets/catalog/sources.md` provenance and the connector-footprint CI assertion all landed, plus a device palette panel wired into `RackCanvasScreen` (search + categories, **click-to-add** via double-click/Enter, **and now drag-from-palette-to-rails** — see §3.1 below); the 4 hand-built demo devices remain as the rack's starting contents alongside the catalog |
| 7 | Copy-on-place with `DeviceOverrides`; the chip strip (RU, weight, VA, outlets) with unknown counts | **Not started** |
| 8 | `DiagramCanvas` + `SceneBuilder` + both backends + the baseline-Y parity test | **Done** — mutation-tested twice |
| 9 | Minimal PDF exporter: front elevation, rear elevation, `T6.30`, title block, revision block | **Not started** |
| 10 | Atomic save, autosave, recovery, recents, close interception; the outline tree; four starter projects | **Not started** |

---

## 2. Against the rack editor spec (docs/04-rack-editor.md), section by section

### §1 Screen layout
- [x] Palette panel (280 px, search, categories) — **done** — collapsible
      per-category (not the whole panel) via `ExpansionTile`; panel-width
      persistence/resize handle not built
- [ ] Inspector panel (320 px, selection section + Rack Vitals) — **not started**
- [ ] Validation drawer (28 px, auto-expands on first error) — **not started**
- [ ] Status bar (cursor context, zoom, selection rollup, project counts) — **partial**: zoom HUD, plus
      a new minimal transient-message stub (`StatusMessageController`) for nudge-blocked / placement-
      confirmed feedback + `SemanticsService.announce` — NOT the full always-visible cursor-context/
      selection-rollup/project-counts bar, which stays not-started
- [x] Toolbar view switch (`Ctrl+1..4`) — **not started** (only one screen exists, no tab strip)
- [x] Face segmented control — **done** (Front/Rear toggle; "Both" view not built)
- [ ] Tablet collapse below 1080 px (read-only shell) — **not started**

### §2 The rack canvas
- [x] RU ruler with bottom-origin numbering, per-rack `ruNumbering` — **done**
- [ ] Real rail hole geometry + ear screws at zoom ≥ 0.75 — **not started** (flat placeholder fill)
- [x] LOD tiers below 0.75 (block / dotted-texture-placeholder) — **done**
- [ ] LOD tier ≥ 0.75 (holes, ear screws, port badges) and ≥ 1.50 (rear port strip, weight
      microtext, PDU outlet map) — **not started**
- [x] Front / Rear as a coordinate switch — **done**
- [ ] "Both" view (mirrored side-by-side) — **not started**
- [ ] Rear mirroring (`Rack.mirrorRearElevation`) + the "NOT MIRRORED" chip — **not started**
- [ ] `chassisRotation` reversed-face badge (↺) — **not started**
- [ ] Multiple racks laid out left-to-right by `Rack.order` — **not started** (one hardcoded rack)
- [ ] Wall-mounted rack offset/hatch rendering — **not started**

### §3 Placement
- [x] §3.1 Drag from palette to rails (arm/lift/enter-canvas/snap/evaluate/commit), incl. the
      seven-check drop evaluation table and blocked-drop rendering — **done for the two BLOCKING
      checks; the five advisory/warning checks are explicitly out of scope, see below** — hand-rolled
      entirely via `GestureBinding.instance.pointerRouter` (a global, pointer-id-keyed route
      subscribed the moment a palette row's pointer-down arms the gesture, since the drag starts
      in a sibling widget outside `CanvasIntentDetector`'s own subtree) + `Overlay`/`OverlayEntry`
      for the screen-space cursor card / RU-range chip / reason chip — **no `Draggable`/
      `DragTarget`**, per docs/04 §3's hard constraint. New `PaletteDragController`
      (`rackmate_ui/src/canvas/palette_drag_controller.dart`) is the observable phase machine
      (armed -> lifted -> dragging, plus a `releaseLingering` state for the 1.2s post-blocked-
      release chip persistence) — **since RENAMED to `DragPreviewController`
      (`drag_preview_controller.dart`) by §3.3 below**, once the move-a-placed-device gesture
      began sharing it; every symbol named in this §3.1 entry is listed with its new name in
      §3.3's own entry. `DevicePalettePanel`/`_PaletteRow` gained `onArmDrag` (an
      ADDITIONAL `Listener` wrapped around the existing double-tap/Enter subtree — composes
      safely, since `Listener` never enters the gesture arena) and `draggingCatalogId` (dims the
      source row to 40% opacity + a 1px accent inset outline once LIFTED, not merely armed).
      `EditingOverlayPainter` (extended, not forked) now paints the drag ghost (fill/border/
      snap-line, reusing the SAME `paintInsertionLine` routine the keyboard caret uses) — accent
      when valid, dashed error + a 45-degree hatch on the conflicting occupant when blocked —
      mutually exclusive with the caret per frame (`CaretController.recompute`'s `dragInProgress`
      input is now `PaletteDragController.isInProgress`, no longer hardcoded false).
      LIVE EVALUATION, every frame while inside the canvas widget's bounds, first-failure-wins in
      the SAME order `buildPlaceFromCatalogCommand`'s `explicitRuIndex` path checks them — NOT the
      CR-017 table's own listed order, a since-fixed bug where the two were briefly transposed:
      (1) fits within the rack extent — `ruIndex + deviceH - 1 > rack.heightU`; (2) front U range
      free on this face — reuses `findBlockingOccupant` (zero new core surface). The order must
      match the commit-time function's exactly, not just reuse the same check functions, because
      `RackGeometry.maxRuIndexFor` can clamp an over-tall candidate `ruIndex` into a range that ALSO
      happens to be occupied — checking occupancy first in that situation would show "Occupied by
      X" for the live drag while committing at that instant would actually fail with "Needs NU,
      only MU free at top", violating "the gesture must never disagree with what the document
      says". Not reachable with today's shipped catalog (max template 4U vs. the 12U demo rack —
      see the reachability note below) but a live, untested logic bug the moment either changes; no
      screen-level gesture test exercises this order directly today, only
      `rack_canvas_screen.dart`'s own doc comment and code-reading confirm the two now agree. A
      valid commit calls the SAME `buildPlaceFromCatalogCommand(..., explicitRuIndex: ...)`
      quick-add uses (one placement mechanism, two entry points) via a new shared
      `_finalizeCatalogPlacement` helper (the status-announce/sole-selection tail quick-add and
      drag-commit both now go through). A
      blocked release is a no-op with a 120ms ghost shake (`ShakeController`, reused via a fixed
      `kPaletteGhostShakeId` sentinel — "one animation implementation, two consumers", exactly the
      pattern the keyboard-nudge shake already established) and the reason chip persisting 1.2s.
      `Esc` mid-drag is handled via a RAW `HardwareKeyboard.instance.addHandler` hook (registered
      only while a drag is in flight) rather than the `Shortcuts`/`Actions` layer, since Flutter
      focus may be anywhere while the pointer that armed the gesture is still down. Exactly one
      palette drag can be in flight at a time — `_onPaletteArmDrag` rejects a second pointer-down
      outright while `_paletteDrag.phase != PaletteDragPhase.none` or `_armPointer != null` (a
      since-fixed bug: it used to overwrite the shared arm state unconditionally, leaking the
      first pointer's `pointerRouter` route). Arming a new drag also cancels any still-pending
      1.2s blocked-release `Timer` from a previous drag (another since-fixed bug: an uncancelled
      timer would fire later and force-reset the NEW drag's live state out from under it). Every
      method that can end a drag's lifecycle (commit/no-op, Esc-cancel, `dispose`) now routes
      through one idempotent `_removePaletteEscHandler` call made unconditionally at the top of
      each method, closing a leak where an early return (state already cleared by the bug above)
      used to skip past `HardwareKeyboard.instance.removeHandler` entirely, permanently silencing
      Esc app-wide.
      SCOPE DECISIONS carried over exactly as directed: the five advisory/warning CR-017 checks
      (opposite-face occupancy, depth-interval fit RCK-012, clearance above/below, mount-method
      compatibility, half-rack-on-bare-rails) are **not implemented, not even as inert stubs** — no
      validation/finding engine (`derived/validation.dart`) exists anywhere in this codebase, and
      building one is a separate, later M1 roadmap item ("chip strip + Rack Vitals + validation
      rules"). The Staging Bin / `StagedPlacement` the spec's escape-hatch text describes for
      "dragging outside any rack" does not exist (roadmap item 4: still **not started**) — releasing
      outside the canvas widget's bounds is simply a no-op (no shake: an expected outcome, not a
      violated attempt), with the cursor card showing a "no valid drop target" cursor rather than a
      scene ghost drawn somewhere off-canvas. Only rack-mountable templates (`frontU > 0 ||
      rearU > 0`) can arm a drag at all — a deliberate scope narrowing (docs/04 §3.1 is specifically
      "drag from palette to RAILS"); field/off-rack devices remain click/double-click-only,
      unchanged from the previous stage. **A verified discrepancy from the drag design's own
      claim**: the design assumed "several field/rack templates in the 48-entry seed catalog
      already exceed 12U" to justify testing the "fits within rack extent" check live — in fact the
      tallest seeded catalog template is 4U (`V03`), so that check is structurally UNREACHABLE via
      mouse-drag against the actual 12U demo rack + seeded catalog as they exist today (`RackGeometry
      .ruIndexForCursorY`'s own clamp means a candidate can never land outside `[1, heightU]` for any
      currently-seeded, ≤4U template). The check is still implemented correctly (its formula is
      identical to `buildPlaceFromCatalogCommand`'s own already-tested overflow branch) and will
      engage the moment a taller catalog template is added or the rack is shrunk below 4U, but this
      stage could not exercise it through a real screen-level gesture test for that reason — a
      stated, honest test-coverage gap, not a silent one. Deferred visual-polish niceties (matching
      this codebase's own established precedent, e.g. the caret's un-bolded ruler-number tint): the
      100ms cursor-card-to-ghost cross-fade, the 120ms scale-in + 400ms outline pulse on a
      successful commit, and "occupied ruler labels invert" during the drag are NOT implemented —
      the ghost/chip/status-announce still land instantly and unambiguously, satisfying the spec's
      real concern (silent/invisible feedback), just without the exact transition animations.
- [x] §3.2 Faster paths: `/` search-and-place, double-click palette row, double-click empty U
      quick-insert popover, `Ctrl+Alt+I` insert dialog, right-click empty-U menu — **partial** —
      `/` focuses palette search (done); double-click a palette row / row-focused `Enter` / the
      NEW search-box `Enter` all place at the **insertion caret** when one exists, else at the
      lowest fitting free U (done, this stage — `buildPlaceFromCatalogCommand`'s new
      `explicitRuIndex` parameter), with an idformat-allocated designator, and the caret
      **advances past** the newly placed device; the empty-U quick-insert popover, `Ctrl+Alt+I`,
      and the right-click menu remain **not started**. KNOWN GAP (stated in code and in the final
      report): because the newly-placed device becomes the sole selection immediately afterward
      (pre-existing §3.1-step-6 behaviour), back-to-back Enters with nothing in between (no click,
      no Delete) use the caret for only the FIRST placement — the second falls back to
      lowest-free-U, since a selection existing (even one this same call just created) is read as
      "no caret" per §3.4's own existence condition. True uninterrupted "type, Enter, type, Enter…"
      needs a keyboard deselect gesture this codebase still doesn't have (`Esc` is now wired, per
      §3.1 below, but only as the drag-cancel gesture — it is not a general deselect key and does
      not address this gap).
- [x] §3.3 Moving a placed device: grab, drag, commit `MoveDeviceCommand` — **done**, steps 1, 3
      and 4 (live feedback landed this stage; steps 2/5/6/7 remain deferred below)
  - [x] Step 1 grab + 4 px threshold + **30 % opacity in place** — **done, this stage**. Past the
        existing `_clickSlopPx` threshold the source device composites through ONE `saveLayer` at
        `RenderDeviceBox.dragSourceOpacity` (0.30), fading body AND hover/focus/selection chrome
        uniformly so a ghosted body can't end up ringed by a full-strength outline; it stays put,
        "showing the vacated U", while the ghost previews the target. The flag is pushed down as an
        ordinary `DeviceBox.dragSource` constructor argument exactly like `selected` — adding NO
        widget layer (which `RenderDeviceBox.shake`'s own doc comment warns breaks
        `allRenderObjects`' one-entry-per-device assumption) and costing one `setState` at drag
        start and one at drag end via the same coarse `_lastMoveDragSourceId` filter
        `_lastPaletteDragDimId` already established; per-frame evaluation never rebuilds.
        **DELIBERATE, STATED DEVIATION** from step 1's literal "a full-opacity ghost follows the
        cursor with the grab offset preserved": the ghost is drawn HARD-SNAPPED to the evaluated
        RU, not free-floating. Step 3 requires §3.1's rendering, and §3.1 step 4's ghost is
        explicitly hard-quantised ("Snap is instant"); a free-floating ghost would need a second
        ghost-painting path and could sit where the commit would never place the device. The grab
        offset is fully preserved as the SNAP INPUT (`_dragDeviceStartTopY + drag delta` through
        `RackGeometry.ruIndexForTopY`), so grabbing near a device's bottom edge still tracks
        differently from grabbing near its top.
  - [x] Step 3 same checks + same blocked rendering as §3.1 — **done, this stage**, and literally
        rather than approximately: `PaletteDragController` was **generalised into
        `DragPreviewController`** (`drag_preview_controller.dart`, renamed from
        `palette_drag_controller.dart`; `PaletteDragPhase`/`PaletteDragEvaluation`/
        `kPaletteGhostShakeId` → `DragPreviewPhase`/`DragPreviewEvaluation`/`kDragGhostShakeId`,
        `catalogId` → `subjectId`) and BOTH gestures now drive one instance each of that same
        type. Exactly one implementation survives of each of the three things that could have been
        duplicated: (i) the per-frame blocking evaluation — `_evaluateDrop`, extent-check-first
        then occupancy, the order `buildPlaceFromCatalogCommand`'s `explicitRuIndex` path uses,
        with a `Uuid? exceptId` as the ONLY per-gesture input; (ii) the ghost / snap-line / 45°
        hatch — `EditingOverlayPainter`, whose `paletteDrag` field became a
        `List<DragPreviewController> dragPreviews` it scans for the one reporting
        `isShowingGhost` (at most one can per frame), plus the RU-range/reason chips, whose
        `_PaletteDragOverlay` became `_DragPreviewOverlay` with a single `showCursorCard` knob
        (false for move-drag, which has no pre-canvas-entry stage to card); (iii) the "is this RU
        range free" query — core's `findBlockingOccupant`.
  - [x] `_rangeFreeOnFace` consolidated onto `findBlockingOccupant` — **done, this stage**, closing
        the duplicate flagged in the previous stage's review. `_handleMove` + `_rangeFreeOnFace`
        are **deleted**: occupancy was derived there from RENDERED SCENE LAYOUTS (inverting each
        `DeviceLayout`'s Y back into RU indices by hand — a second occupancy query AND a second
        inverse-Y derivation living beside core's own); it is now asked of the DOCUMENT MODEL
        through the one core function keyboard-nudge, quick-add and the palette drag already
        shared. The commit reads the SAME `DragPreviewEvaluation` object the ghost last drew,
        re-evaluated once at the exact release point (pointer-up's position need not equal the
        last move event's), so "the live preview and the commit never disagree" holds by
        construction, not by review.
  - [x] Blocked move release is no longer a **silent** refusal — **changed, this stage**: it is now
        a no-op with the 120 ms `ShakeController` ghost shake and the reason chip persisting 1.2 s,
        exactly as §3.1 step 5 specifies and §3.3 step 3 inherits (§3.4's "a nudge that would
        collide never silently stops" principle applied to drops). The GHOST shakes, not the
        device: the device never moved and returns to full opacity the instant the pointer lifts
        (`beginBlockedRelease` clears the phase, so `isSourceEngaged` goes false that same frame)
        while only the frozen verdict lingers. **BUG FOUND AND FIXED while wiring this**: a
        blocked-release `Timer` left pending from one move-drag would fire during a SECOND
        move-drag begun inside its 1.2 s window, `reset()`-ing the shared controller mid-gesture —
        clearing the live evaluation, dropping the chips, and (because the commit gates on
        `isDragging`) turning that second drag's release into a silent failed move. Arming now
        cancels it, mirroring the identical fix `_onPaletteArmDrag` already carried; regression
        test included.
  - [x] Step 4 `Esc` mid-drag reverts — **done, this stage**: the source returns to full opacity at
        its original U, ghost and chips vanish, and no command runs. **A STATED ASYMMETRY WITH
        §3.1**: this uses the ordinary `Shortcuts`/`Actions` layer (a new `_CancelDragIntent`),
        NOT the raw `HardwareKeyboard.instance.addHandler` hook the palette drag needs. That hook
        exists because a palette drag is armed from a sibling widget while Flutter focus may be
        anywhere; a move drag has the opposite guarantee — `_onBeginDrag` calls
        `_canvasFocus.requestFocus()` as its first statement — so the focus-scoped binding is
        provably sufficient and stays out of the handler-registration leak class. Because
        `CanvasIntentDetector` owns the gesture and cannot be un-routed mid-flight (unlike the
        palette's `pointerRouter` subscription, which `_cancelPaletteDrag` removes outright), a
        `_dragCancelled` latch makes the still-down pointer's remaining `updateDrag`/`commitDrag`
        callbacks no-ops. `Esc` is still NOT a general deselect key (see §3.2's known gap).
  - [ ] Step 2 — cross-rack move (drag past 60 px beyond a rail) — **not started**. Structurally
        untestable today regardless: `_buildDemoDocument` creates exactly ONE rack, so there is no
        neighbouring rack to jump to, re-snap against, or pulse a target border around.
  - [ ] Step 5 — `Ctrl` at drag start = duplicate — **not started** (needs duplicate + designator
        re-allocation on drop)
  - [ ] Step 6 — `Alt` at drop = insert-and-push (displaces occupants, push-up then push-down,
        else `Insert would overflow rack by NU`) — **not started** (needs re-pack logic)
  - [ ] Step 7 — `Ctrl+Shift` at drop over an equal-height device = swap (both showing a ↔ badge)
        — **not started** (needs swap logic)
  - [ ] Multi-device drag — **not started**, unchanged documented restriction: dragging one device
        while several are selected moves just that one (`_onBeginDrag`'s `_dragPlacement` gate),
        matching the keyboard nudge's own single-focused-device rule
  - [ ] Lateral `Width position` dropdown (Full/Left half/Right half) — **not started** (model
        already carries `startTwelfth`/`spanTwelfths`; no UI)
- [x] §3.4 Insertion caret (first-class object) + keyboard nudge (`↑↓`, `Shift`, `Ctrl`, `Alt`,
      `Home/End`, `PgUp/PgDn`), with 500 ms nudge coalescing — **partial, this stage** — the caret
      object (`CaretController`/`InsertionCaret`, `rackmate_ui`) exists whenever the canvas has
      focus and nothing is selected, seeded at the lowest free 1U slot, rendered as a 2px accent
      line + rail triangles + a ruler-label tint (`EditingOverlayPainter`); bare `↑↓`/`Home`/`End`/
      `PgUp`/`PgDn` move the caret when nothing is selected, and nudge the focused device (±1U for
      `↑↓`, ±10U for `PgUp`/`PgDn`, lowest/highest fitting for `Home`/`End`) when something is —
      reusing `MoveDeviceCommand`'s existing `mergeKey`/`mergeWith` through the **400ms**
      `UndoStack` window (docs/03-architecture.md §5.4 names this window's exact intended consumer
      as "arrow-key nudges" — the 400ms-vs-500ms discrepancy between that doc and this one is
      resolved in favour of the already-implemented, already-tested 400ms constant; see the final
      report for the full reasoning). A blocked nudge shakes the selection 3px
      (`ShakeController`) and reads "Blocked by DESIGNATOR" on a new minimal status line
      (`StatusMessageController`), never silently stopping. **Still not started**: `Shift+↑↓`
      (extend selection to the adjacent occupant — needs multi-select range semantics), `Alt+↑↓`
      (swap with the adjacent occupant, re-pack on unequal heights — needs re-pack logic),
      `Ctrl+↑↓` (jump to the next free slot, skipping occupied space — a directional occupancy
      search not built), and multi-device simultaneous nudge (acts on the single focused device
      only, matching drag-move's own existing single-device restriction — a multi-child
      `Transaction` per keypress could never coalesce, per `Transaction.mergeWith`'s
      single-child-only rule).
- [x] §3.5 Selection: click replaces, `Ctrl+click` toggles — **done**
  - [ ] `Shift+click` range-select within a rack — **not started**
  - [ ] Marquee (left-drag on empty canvas, window vs. crossing) — **not started**
  - [ ] `Ctrl+A` select-all (rack, then project) — **not started**
  - [ ] Multi-select combined ruler bracket + status-bar rollup — **not started**
  - [ ] `Ctrl+L` lock / unlock — **not started**
  - [x] Delete (zero-connection immediate; confirm bar for ≥1 connection not built since no
        Links exist yet) — **done** (immediate delete only; the confirm-bar case is unreachable
        until M2 wiring exists)
  - [ ] Copy/Cut/Paste/Paste-in-place/Duplicate (`Ctrl+C/X/V/Shift+V/D`) — **not started**
- [ ] §3.6 Compact Up / Compact Down with preview overlay — **not started**

### §4 Rack configuration
- [ ] `RackInspector` panel (name, designator, location, form factor, height, width, usable
      depth, rail type, weight cap, mount, swing frame, ground bar) — **not started**
- [ ] Three ways to change height (stepper / field / drag top edge) — **not started**
- [ ] Shrink-below-occupancy modal (compact-first / move-to-bin / keep-larger, trim
      from top/bottom) — **not started**
- [ ] Rack presets (wall box, swing gate, floor enclosure, etc.) — **not started**
- [ ] Circuits panel (flat, filtered by `rackId`) — **not started**

### §5 Derived readouts
- [ ] Always-visible chip strip (RU, weight, VA, outlets, each with an unknown-count
      superscript) — **not started**
- [ ] Collapsed Rack Vitals panel (space bars, weight bar, power bar, BTU/CG advisory) —
      **not started**
- [ ] Findings surfacing: device badge (shape+colour), rack-header `⚠n` rollup, validation
      drawer with select-and-zoom — **not started** (no validation rules run yet at all — that's
      `derived/validation.dart`, not built in any stage so far)

### §6 Non-device occupants
- [ ] Blanks, vents, fans, patch panels, PDU/UPS, rear lace bar as ordinary templates with
      `OccupancySide` — **not started** (occupancy side exists in the model; no such templates
      or palette to place them from)
- [ ] 0U vertical occupants (`ZeroUPlacement`, inspector-edited, no drag) — **not started**
- [ ] Shelves and hosted devices (drop-onto-shelf, auto-pack, capacity bar, leaving-shelf
      gesture, delete-shelf prompt) — **not started**

### §7 Naming and designators
- [x] `designator` and `name` exist as data fields — **done** (model only)
- [ ] `F2` inline designator edit / `Ctrl+F2` name edit — **not started**
- [x] Auto-assignment via the `idformat` engine on device creation (`{TYPE_PREFIX}{SEP}{SEQ}`)
      — **done** for catalog placement (`allocateDeviceDesignator` + `buildPlaceFromCatalogCommand`,
      `rackmate_core/src/idformat/designator_allocator.dart`); the 4 original hand-built demo
      devices still carry their original hand-typed designators (unchanged, pre-existing)
- [ ] Collision UI (`[Swap] [Go to]`) — **not started**
- [ ] `Ctrl+R` Renumber dialog with diff preview — **not started**
- [ ] Project-level Locations panel — **not started**

### §8 Keymap
- [x] `Del`/`Backspace` — **done**
- [x] `Ctrl+Z` / `Ctrl+Shift+Z` / `Ctrl+Y` — **done**
- [x] `/` (focus palette search) — **done** (earlier stage)
- [x] Bare `↑`/`↓`/`Home`/`End`/`PgUp`/`PgDn` (caret move / nudge, see §3.4) — **done, earlier stage**
- [x] `Esc` cancels an in-flight palette drag (see §3.1) — **done, this stage** — wired via a raw
      `HardwareKeyboard.instance.addHandler` hook, not the `Shortcuts`/`Actions` registry (Flutter
      focus may be anywhere while the pointer that armed the drag is still down); still NOT a
      general-purpose deselect/cancel key outside an in-flight drag (see §3.2's KNOWN GAP)
- [ ] Everything else in the ~40-binding table (`Ctrl+1..4`, `Ctrl+0/9/Alt+0`, `Ctrl+K/F/G`,
      `Ctrl+P/E`, `Ctrl+Shift+F`, `Enter` (search-box Enter now places at the caret, see §3.2; a
      NEW palette row's own Enter handler was already done earlier), `Shift/Ctrl/Alt+↑↓` (see
      §3.4's deferrals), `←→` cross-rack, `Ctrl+L`, `Ctrl+R`, `Ctrl+D`, `Ctrl+X/C/V/Shift+V`, `G`,
      `L`, `Ctrl+Shift+W`, `F2`/`Ctrl+F2`, `Ctrl+Alt+U/N`, `U`, `Ctrl+Alt+1/2/3`, `F7/F8/Shift+F8`)
      — **not started**.
      Generated `build/keymap.md` from one `Intent` registry (CR-101) is itself not started —
      today's shortcuts are wired ad hoc in `RackCanvasScreen`, not through a registry.

### §9 Empty state, first run, accessibility
- [ ] Start card + four starter projects (also needed as goldens/perf fixtures/screenshot
      source, per AC-052) — **not started**
- [ ] New-rack dialog (Name/Preset/Height) — **not started**
- [ ] Empty-rack hint card, other 7 empty states — **not started**
- [ ] Coach marks (first placement, first finding, first rack→schematic switch) — **not started**
- [x] Per-device `Semantics` label (designator + name + type) — **done**
- [ ] Outline tree (`Ctrl+Alt+3`), the primary AT surface — **not started**
- [ ] Full keyboard focus-region cycling (`F6`/`Shift+F6`/`Ctrl+F6`), spoken caret announcements,
      `disableAnimations` handling, hit-target sizing audit — **not started**

---

## 3. What M0/M1 has actually shipped so far (commit-level, for orientation)

Chronological, oldest first — see `git log --oneline` for the full history:

1. `chore: scaffold the five-package workspace (M0)`
2. `feat(core): implement rackmate_core through M0's command/undo system`
3. `feat(app): Windows desktop platform scaffolding; first build/run confirmed`
4. `feat(core): the shared DiagramCanvas drawing IR (M1, CR-086/CR-081)`
5. `feat(export): PdfDiagramCanvas and the concrete PdfFontMeasurer (M1)`
6. `feat(ui): FlutterDiagramCanvas, the on-screen backend (M1, CR-086)`
7. `test(app): the baseline-Y screen/print parity gate (M1, CR-081/CR-086)`
8. `feat(ui): ViewportController, grid painter, CanvasIntent (M1 walking skeleton)`
9. `feat(canvas): the rack scene builder and RenderRackCanvas (M1, CR-086)`
10. `style: swap the bundled font from IBM Plex Sans to Jost`
11. `feat(canvas): select, move, delete and undo -- routed through real commands`

288 tests passing across the workspace as of commit 11 (133 core + 42 ui + 13 app, plus the
rendering-spine packages' own suites).

UNCOMMITTED, as of this log update: THREE stacked, uncommitted stages sit on top of commit 11 —
(1) the insertion caret + keyboard nudge + quick-add-at-the-caret stage (§3.2/§3.4 above —
`CaretController`/`InsertionCaret`, `EditingOverlayPainter`, `ShakeController`,
`StatusMessageController`, `findBlockingOccupant`, `buildPlaceFromCatalogCommand`'s
`explicitRuIndex`), and (2), built directly on top of it, the drag-from-palette-to-rails stage
(§3.1 above — `PaletteDragController`, `EditingOverlayPainter`'s ghost/hatch/dashed-border
painting, `DevicePalettePanel`'s `onArmDrag`/`draggingCatalogId`, the raw `HardwareKeyboard`
Esc-cancel hook, and the shared `_finalizeCatalogPlacement` helper). 291 tests passing across the
workspace with BOTH stages in place, plus a subsequent adversarial-review fix pass (165 core + 113
ui + 13 app) — not yet committed, so not reflected in the numbered commit list above. The fix pass
closed two HIGH-severity bugs in the palette-drag gesture (concurrent-arm state corruption; a
stale blocked-release timer that could force-reset a later drag and permanently leak the Esc
keyboard hook), reordered the live drag evaluation to match `buildPlaceFromCatalogCommand`'s
extent-then-occupancy check order (see §3.1 above), and added a `MutableClock` test fixture
(`rackmate_core/src/commands/clock.dart`) plus real paint-content assertions for the blocked/valid
ghost styles — no scope changed, only correctness and test-coverage.

And (3), stacked on those, the move-drag live-feedback stage (§3.3 above): the spec gap where
dragging an EXISTING placed device had none of the ghost / snap-line / hatch / reason-chip
feedback the palette drag had, despite §3.3 step 3 saying it uses the "same blocked rendering as
§3.1". `PaletteDragController` was generalised to `DragPreviewController` and both gestures now
drive one instance each; `_handleMove`/`_rangeFreeOnFace` were deleted in favour of the shared
`_evaluateDrop` + core's `findBlockingOccupant`; `RenderDeviceBox` gained the 30%-opacity
`dragSource` state; `Esc` gained a `_CancelDragIntent` binding. 301 tests passing across the
workspace with all three stages in place (165 core + 123 ui + 13 app), `flutter analyze` clean at
the same 212 pre-existing style infos as before the stage, and `flutter build windows` succeeding.
One real bug was found and fixed while wiring it (a stale blocked-release `Timer` silently killing
a second move-drag begun inside the 1.2 s linger — see §3.3 above), with a regression test. Seven
deliberate mutations were run against the new tests (Esc revert removed, `exceptId` dropped,
`dragSource` never set, blocked release committing anyway, per-frame evaluation frozen, the
painter ignoring `isShowingGhost`, the 4 px threshold defeated, the stale-timer cancel removed);
all were killed, one of them only after the threshold test was strengthened from a vacuous
assertion into a real sub-slop move event.

---

## 4. Suggested next order

Roughly in the order that unblocks the most subsequent work, not a commitment:

1. **Seeded catalog + palette** (roadmap item 6) — replaces the 4 hand-built demo devices with
   real data and gives placement something to draw from. Blocks quick-add and drag-from-palette.
2. **Quick-add by typing + insertion caret + keyboard nudge** (roadmap item 4, §3.2/§3.4) — the
   fastest path to populating a rack and the one the exit criterion's "20 devices in under four
   minutes, keyboard only" is actually measuring. **Substantially done** (uncommitted as of this
   log update — see §2's §3.2/§3.4 rows above for exactly what shipped vs what's still deferred:
   Shift/Ctrl/Alt+↑↓, multi-device nudge, and the back-to-back-Enter known gap). **Drag from the
   palette to the rails (§3.1)** — the other half of roadmap item 6/this item's original scope —
   is now **done** for the two BLOCKING CR-017 checks (front U range free; fits within rack
   extent), built directly on top of this one's `CaretController`, `EditingOverlayPainter`,
   `ShakeController`, and `findBlockingOccupant` rather than duplicating any of them — see §3.1
   above for the full mechanism and what remains deferred (the five advisory/warning checks, the
   Staging Bin, and several visual-polish animations). **Moving an EXISTING placed device (§3.3)**
   now shares all of that machinery too — same evaluator, same ghost/hatch/chip rendering, same
   blocked-release behaviour — closing the gap where only the palette drag had live feedback; see
   §3.3 above for the four remaining deferred steps (cross-rack, duplicate, insert-and-push, swap).
3. **Rack configuration UI** (§4) — height changes, the shrink dialog, presets. Needed before a
   user can create a rack that isn't hardcoded.
4. **Chip strip + Rack Vitals + validation rules** (§5) — the first of the 27 v1 DRC rules
   (`derived/validation.dart` doesn't exist yet in any package).
5. **Non-device occupants + shelves + 0U** (§6).
6. **Compaction** (§3.6).
7. **Naming/designator UI + idformat wiring** (§7).
8. **Persistence wiring + starter projects** (roadmap item 10) — needed regardless of interaction
   completeness, since the exit criterion requires opening/saving real files.
9. **Minimal PDF exporter** (roadmap item 9) — the rendering spine already exists; this is sheet
   assembly on top of it.
10. **Remaining keymap + accessibility + empty states** (§8/§9) — can land incrementally
    alongside any of the above rather than as one dedicated pass.
