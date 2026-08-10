# M1 implementation log

This tracks *build* status against the *existing* spec; it does not redefine scope. The
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
| 3 | Hybrid `RenderRackCanvas`, device widgets, RU snapping, front/rear elevations with per-rack mirroring | **Done**: RU snapping and front/rear filtering shipped earlier; **per-rack mirroring shipped in the PDF exporter's pass 2** and is in `RackGeometry.deviceRect`, so BOTH backends get it, the rear canvas mirrors on screen exactly as the rear sheet does (`rack_mirror_test.dart`). It is a LAYOUT reflection of the twelfth span, never a canvas `scale(-1, 1)`, which would print every designator backwards; a test asserts no `OpTransform` in a rear scene carries a negative X scale. See §3e |
| 4 | Quick-add by typing with the drop caret; the Staging Bin; shelves with auto-pack; 0U occupants from the inspector | **Partial**: quick-add by typing now places at the insertion caret (docs/04 §3.2/§3.4), see §3.2/§3.4 below; the Staging Bin, shelves-with-auto-pack, and 0U-from-the-inspector remain **not started**. §3.1's "release outside any rack" now shows an HONEST chip and reports its refusal instead of silently doing nothing, but it still creates no `StagedPlacement`, see §3c |
| 5 | Compact Up/Down with preview-then-accept, and the shrink-rack dialog; locks | **Partial**: Compact Up/Down ship COMPLETE (planner + preview overlay + floating Apply/Cancel bar + `Enter`/`Esc`, see §3.6); the shrink-rack dialog is planner-only (see §4.1) and its modal is pass 3; locks are honoured as immovable anchors by the planner but there is still no `Ctrl+L` UI to SET one |
| 6 | The full seeded catalog (incl. 18 field devices, `sources.md` provenance, connector-footprint CI assertion) | **Partial**, 48-template seed catalog (30 rack-side + 18 field) with `assets/catalog/sources.md` provenance and the connector-footprint CI assertion all landed, plus a device palette panel wired into `RackCanvasScreen` (search + categories, **click-to-add** via double-click/Enter, **and now drag-from-palette-to-rails**, see §3.1 below); the 4 hand-built demo devices remain as the rack's starting contents alongside the catalog |
| 7 | Copy-on-place with `DeviceOverrides`; the chip strip (RU, weight, VA, outlets) with unknown counts | **Partial**: the **chip strip ships complete**, including the unknown counts (`rackmate_core/derived/totals.dart` + `rackmate_ui/canvas/rack_metrics_row.dart`, 54 new tests, see §5 below). Copy-on-place with `DeviceOverrides` remains **not started**: the rollup READS `DeviceOverrides.weight` where one exists, but nothing writes one |
| 8 | `DiagramCanvas` + `SceneBuilder` + both backends + the baseline-Y parity test | **Done**: mutation-tested twice |
| 9 | Minimal PDF exporter: front elevation, rear elevation, `T6.30`, title block, revision block | **Done**: both passes ship. Pass 1: ANSI page sizes, the drawing-scale engine with the honest `1:n`/`NTS` report, the border, the title block and the revision block (§3d). Pass 2: `T2.01` front and `T2.02` rear elevations rendering the EXISTING `buildRackScene` through `PdfDiagramCanvas`, `T6.30` equipment list with §3.7 pagination, and `File ▸ Export PDF…` wired into the app over the shipped save surface (§3e). The elevations are asserted DIMENSIONALLY CORRECT against the emitted PDF bytes in PDF user space, with every expectation computed from `44_450_000` / `25_400_000` / `72.0` literals and the ratio read back out of the sheet's own SCALE field |
| 10 | Atomic save, autosave, recovery, recents, close interception; the outline tree; four starter projects | **Done, except the outline tree**: CORRECTED, this row was stale: `apps/rackmate/lib/src/storage/` (atomic save with `AtomicWriter`/`SavePaths`, autosave, crash recovery, the enumerated `SaveError` surface), `lib/src/session/` (recents, close interception, the native save dialog) and the four starter projects at `assets/starters/*.rackmate` all shipped in the persistence stage, with 624 app tests covering them. The **outline tree** remains not started |

---

## 2. Against the rack editor spec (docs/04-rack-editor.md), section by section

### §1 Screen layout
- [x] Palette panel (280 px, search, categories), **done**, collapsible
      per-category (not the whole panel) via `ExpansionTile`; panel-width
      persistence/resize handle not built
- [x] Inspector panel (320 px, selection section + Rack Vitals), **partial, this stage
      (pass 2)**: the 320px FOURTH COLUMN now exists
      (`rackmate_ui/src/inspector/inspector_panel.dart`), so the layout is finally
      `Row(palette 280 | divider | canvas | divider | inspector 320)`. It hosts either the full
      `RackInspector` (§4) or a MINIMAL selection summary (count + the focused device's
      designator/name). The summary is deliberately NOT a device inspector: device property
      editing is its own body of work (§3's Width position dropdown, §6's shelf capacity, §7's
      `F2` rename, copy-on-place `DeviceOverrides`), none of it in this stage. **Rack Vitals
      stays not-started** (§5, needs the validation engine).
- [x] Rack header bar, **new, this stage (pass 2)**, not previously listed here because
      nothing in the spec's §1 layout list names it separately: a screen-space
      `RackHeaderBar` (`rackmate_ui/src/canvas/rack_header_bar.dart`) showing designator +
      name + a read-only height badge, with an overflow menu carrying Compact Down / Compact
      Up / Rack settings…. Screen-space (a `Positioned` in the canvas `Stack`, sibling to the
      zoom HUD) rather than scene-space, because it hosts real Flutter controls a
      `CustomPainter` cannot and must not scale with zoom. The height STEPPER and the `⚠n`
      findings rollup are both absent, pass 3 and the validation stage respectively.
- [ ] Validation drawer (28 px, auto-expands on first error), **not started**
- [ ] Status bar (cursor context, zoom, selection rollup, project counts), **partial**: zoom HUD, plus
      a new minimal transient-message stub (`StatusMessageController`) for nudge-blocked / placement-
      confirmed feedback + `SemanticsService.announce`, NOT the full always-visible cursor-context/
      selection-rollup/project-counts bar, which stays not-started
- [x] Toolbar view switch (`Ctrl+1..4`), **not started** (only one screen exists, no tab strip)
- [x] Face segmented control, **done** (Front/Rear toggle; "Both" view not built)
- [ ] Tablet collapse below 1080 px (read-only shell), **not started**

### §2 The rack canvas
- [x] RU ruler with bottom-origin numbering, per-rack `ruNumbering`, **done**
- [ ] Real rail hole geometry + ear screws at zoom ≥ 0.75, **not started** (flat placeholder fill)
- [x] LOD tiers below 0.75 (block / dotted-texture-placeholder), **done**
- [ ] LOD tier ≥ 0.75 (holes, ear screws, port badges) and ≥ 1.50 (rear port strip, weight
      microtext, PDU outlet map), **not started**
- [x] Front / Rear as a coordinate switch, **done**
- [ ] "Both" view (mirrored side-by-side), **not started**
- [x] Rear mirroring (`Rack.mirrorRearElevation`), **done** in `RackGeometry.deviceRect`, so the
      rear CANVAS and the rear SHEET mirror identically (§3e). A LAYOUT reflection of the twelfth
      span, never a canvas `scale(-1, 1)`; that would print every designator backwards, and a test
      asserts no `OpTransform` in a rear scene carries a negative X scale
- [x] The `NOT MIRRORED` chip (CR-035), **done ON THE PDF SHEET** (`T2.02` carries
      `REAR VIEW — MIRRORED` or `NOT MIRRORED`, because a reader cannot tell the conventions apart
      by looking). **NOT on the on-screen canvas**: the chip is sheet furniture and the rack canvas
      has no chip surface yet; recorded rather than claimed
- [ ] `chassisRotation` reversed-face badge (↺), **not started**
- [ ] Multiple racks laid out left-to-right by `Rack.order`, **not started** (one hardcoded rack)
- [ ] Wall-mounted rack offset/hatch rendering, **not started**

### §3 Placement
- [x] §3.1 Drag from palette to rails (arm/lift/enter-canvas/snap/evaluate/commit), incl. the
      seven-check drop evaluation table and blocked-drop rendering, **done for the two BLOCKING
      checks; the five advisory/warning checks are explicitly out of scope, see below**, hand-rolled
      entirely via `GestureBinding.instance.pointerRouter` (a global, pointer-id-keyed route
      subscribed the moment a palette row's pointer-down arms the gesture, since the drag starts
      in a sibling widget outside `CanvasIntentDetector`'s own subtree) + `Overlay`/`OverlayEntry`
      for the screen-space cursor card / RU-range chip / reason chip, **no `Draggable`/
      `DragTarget`**, per docs/04 §3's hard constraint. New `PaletteDragController`
      (`rackmate_ui/src/canvas/palette_drag_controller.dart`) is the observable phase machine
      (armed -> lifted -> dragging, plus a `releaseLingering` state for the 1.2s post-blocked-
      release chip persistence), **since RENAMED to `DragPreviewController`
      (`drag_preview_controller.dart`) by §3.3 below**, once the move-a-placed-device gesture
      began sharing it; every symbol named in this §3.1 entry is listed with its new name in
      §3.3's own entry. `DevicePalettePanel`/`_PaletteRow` gained `onArmDrag` (an
      ADDITIONAL `Listener` wrapped around the existing double-tap/Enter subtree, composes
      safely, since `Listener` never enters the gesture arena) and `draggingCatalogId` (dims the
      source row to 40% opacity + a 1px accent inset outline once LIFTED, not merely armed).
      `EditingOverlayPainter` (extended, not forked) now paints the drag ghost (fill/border/
      snap-line, reusing the SAME `paintInsertionLine` routine the keyboard caret uses), accent
      when valid, dashed error + a 45-degree hatch on the conflicting occupant when blocked,
      mutually exclusive with the caret per frame (`CaretController.recompute`'s `dragInProgress`
      input is now `PaletteDragController.isInProgress`, no longer hardcoded false).
      LIVE EVALUATION, every frame while inside the canvas widget's bounds, first-failure-wins in
      the SAME order `buildPlaceFromCatalogCommand`'s `explicitRuIndex` path checks them, NOT the
      CR-017 table's own listed order, a since-fixed bug where the two were briefly transposed:
      (1) fits within the rack extent, `ruIndex + deviceH - 1 > rack.heightU`; (2) front U range
      free on this face, reuses `findBlockingOccupant` (zero new core surface). The order must
      match the commit-time function's exactly, not just reuse the same check functions, because
      `RackGeometry.maxRuIndexFor` can clamp an over-tall candidate `ruIndex` into a range that ALSO
      happens to be occupied, checking occupancy first in that situation would show "Occupied by
      X" for the live drag while committing at that instant would actually fail with "Needs NU,
      only MU free at top", violating "the gesture must never disagree with what the document
      says". Not reachable with today's shipped catalog (max template 4U vs. the 12U demo rack,
      see the reachability note below) but a live, untested logic bug the moment either changes; no
      screen-level gesture test exercises this order directly today, only
      `rack_canvas_screen.dart`'s own doc comment and code-reading confirm the two now agree. A
      valid commit calls the SAME `buildPlaceFromCatalogCommand(..., explicitRuIndex: ...)`
      quick-add uses (one placement mechanism, two entry points) via a new shared
      `_finalizeCatalogPlacement` helper (the status-announce/sole-selection tail quick-add and
      drag-commit both now go through). A
      blocked release is a no-op with a 120ms ghost shake (`ShakeController`, reused via a fixed
      `kPaletteGhostShakeId` sentinel, "one animation implementation, two consumers", exactly the
      pattern the keyboard-nudge shake already established) and the reason chip persisting 1.2s.
      `Esc` mid-drag is handled via a RAW `HardwareKeyboard.instance.addHandler` hook (registered
      only while a drag is in flight) rather than the `Shortcuts`/`Actions` layer, since Flutter
      focus may be anywhere while the pointer that armed the gesture is still down. Exactly one
      palette drag can be in flight at a time, `_onPaletteArmDrag` rejects a second pointer-down
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
      compatibility, half-rack-on-bare-rails) are **not implemented, not even as inert stubs**: no
      validation/finding engine (`derived/validation.dart`) exists anywhere in this codebase, and
      building one is a separate, later M1 roadmap item ("chip strip + Rack Vitals + validation
      rules"). The Staging Bin / `StagedPlacement` the spec's escape-hatch text describes for
      "dragging outside any rack" does not exist (roadmap item 4: still **not started**), releasing
      outside the canvas widget's bounds is simply a no-op (no shake: an expected outcome, not a
      violated attempt), with the cursor card showing a "no valid drop target" cursor rather than a
      scene ghost drawn somewhere off-canvas. Only rack-mountable templates (`frontU > 0 ||
      rearU > 0`) can arm a drag at all, a deliberate scope narrowing (docs/04 §3.1 is specifically
      "drag from palette to RAILS"); field/off-rack devices remain click/double-click-only,
      unchanged from the previous stage. **A verified discrepancy from the drag design's own
      claim**: the design assumed "several field/rack templates in the 48-entry seed catalog
      already exceed 12U" to justify testing the "fits within rack extent" check live, in fact the
      tallest seeded catalog template is 4U (`V03`), so that check is structurally UNREACHABLE via
      mouse-drag against the actual 12U demo rack + seeded catalog as they exist today (`RackGeometry
      .ruIndexForCursorY`'s own clamp means a candidate can never land outside `[1, heightU]` for any
      currently-seeded, ≤4U template). The check is still implemented correctly (its formula is
      identical to `buildPlaceFromCatalogCommand`'s own already-tested overflow branch) and will
      engage the moment a taller catalog template is added or the rack is shrunk below 4U, but this
      stage could not exercise it through a real screen-level gesture test for that reason, a
      stated, honest test-coverage gap, not a silent one. Deferred visual-polish niceties (matching
      this codebase's own established precedent, e.g. the caret's un-bolded ruler-number tint): the
      100ms cursor-card-to-ghost cross-fade, the 120ms scale-in + 400ms outline pulse on a
      successful commit, and "occupied ruler labels invert" during the drag are NOT implemented,
      the ghost/chip/status-announce still land instantly and unambiguously, satisfying the spec's
      real concern (silent/invisible feedback), just without the exact transition animations.
- [x] §3.2 Faster paths: `/` search-and-place, double-click palette row, double-click empty U
      quick-insert popover, `Ctrl+Alt+I` insert dialog, right-click empty-U menu, **partial**,
      `/` focuses palette search (done); double-click a palette row / row-focused `Enter` / the
      NEW search-box `Enter` all place at the **insertion caret** when one exists, else at the
      lowest fitting free U (done, this stage, `buildPlaceFromCatalogCommand`'s new
      `explicitRuIndex` parameter), with an idformat-allocated designator, and the caret
      **advances past** the newly placed device; the empty-U quick-insert popover, `Ctrl+Alt+I`,
      and the right-click menu remain **not started**. KNOWN GAP (stated in code and in the final
      report): because the newly-placed device becomes the sole selection immediately afterward
      (pre-existing §3.1-step-6 behaviour), back-to-back Enters with nothing in between (no click,
      no Delete) use the caret for only the FIRST placement, the second falls back to
      lowest-free-U, since a selection existing (even one this same call just created) is read as
      "no caret" per §3.4's own existence condition. True uninterrupted "type, Enter, type, Enter…"
      needs a keyboard deselect gesture this codebase still doesn't have (`Esc` is now wired, per
      §3.1 below, but only as the drag-cancel gesture; it is not a general deselect key and does
      not address this gap).
- [x] §3.3 Moving a placed device: grab, drag, commit `MoveDeviceCommand`, **done**, steps 1, 3
      and 4 (live feedback landed this stage; steps 2/5/6/7 remain deferred below)
  - [x] Step 1 grab + 4 px threshold + **30 % opacity in place**: **done, this stage**. Past the
        existing `_clickSlopPx` threshold the source device composites through ONE `saveLayer` at
        `RenderDeviceBox.dragSourceOpacity` (0.30), fading body AND hover/focus/selection chrome
        uniformly so a ghosted body can't end up ringed by a full-strength outline; it stays put,
        "showing the vacated U", while the ghost previews the target. The flag is pushed down as an
        ordinary `DeviceBox.dragSource` constructor argument exactly like `selected`, adding NO
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
  - [x] Step 3 same checks + same blocked rendering as §3.1, **done, this stage**, and literally
        rather than approximately: `PaletteDragController` was **generalised into
        `DragPreviewController`** (`drag_preview_controller.dart`, renamed from
        `palette_drag_controller.dart`; `PaletteDragPhase`/`PaletteDragEvaluation`/
        `kPaletteGhostShakeId` → `DragPreviewPhase`/`DragPreviewEvaluation`/`kDragGhostShakeId`,
        `catalogId` → `subjectId`) and BOTH gestures now drive one instance each of that same
        type. Exactly one implementation survives of each of the three things that could have been
        duplicated: (i) the per-frame blocking evaluation, `_evaluateDrop`, extent-check-first
        then occupancy, the order `buildPlaceFromCatalogCommand`'s `explicitRuIndex` path uses,
        with a `Uuid? exceptId` as the ONLY per-gesture input; (ii) the ghost / snap-line / 45°
        hatch, `EditingOverlayPainter`, whose `paletteDrag` field became a
        `List<DragPreviewController> dragPreviews` it scans for the one reporting
        `isShowingGhost` (at most one can per frame), plus the RU-range/reason chips, whose
        `_PaletteDragOverlay` became `_DragPreviewOverlay` with a single `showCursorCard` knob
        (false for move-drag, which has no pre-canvas-entry stage to card); (iii) the "is this RU
        range free" query, core's `findBlockingOccupant`.
  - [x] `_rangeFreeOnFace` consolidated onto `findBlockingOccupant`, **done, this stage**, closing
        the duplicate flagged in the previous stage's review. `_handleMove` + `_rangeFreeOnFace`
        are **deleted**: occupancy was derived there from RENDERED SCENE LAYOUTS (inverting each
        `DeviceLayout`'s Y back into RU indices by hand, a second occupancy query AND a second
        inverse-Y derivation living beside core's own); it is now asked of the DOCUMENT MODEL
        through the one core function keyboard-nudge, quick-add and the palette drag already
        shared. The commit reads the SAME `DragPreviewEvaluation` object the ghost last drew,
        re-evaluated once at the exact release point (pointer-up's position need not equal the
        last move event's), so "the live preview and the commit never disagree" holds by
        construction, not by review.
  - [x] Blocked move release is no longer a **silent** refusal, **changed, this stage**: it is now
        a no-op with the 120 ms `ShakeController` ghost shake and the reason chip persisting 1.2 s,
        exactly as §3.1 step 5 specifies and §3.3 step 3 inherits (§3.4's "a nudge that would
        collide never silently stops" principle applied to drops). The GHOST shakes, not the
        device: the device never moved and returns to full opacity the instant the pointer lifts
        (`beginBlockedRelease` clears the phase, so `isSourceEngaged` goes false that same frame)
        while only the frozen verdict lingers. **BUG FOUND AND FIXED while wiring this**: a
        blocked-release `Timer` left pending from one move-drag would fire during a SECOND
        move-drag begun inside its 1.2 s window, `reset()`-ing the shared controller mid-gesture,
        clearing the live evaluation, dropping the chips, and (because the commit gates on
        `isDragging`) turning that second drag's release into a silent failed move. Arming now
        cancels it, mirroring the identical fix `_onPaletteArmDrag` already carried; regression
        test included.
  - [x] Step 4 `Esc` mid-drag reverts, **done, this stage**: the source returns to full opacity at
        its original U, ghost and chips vanish, and no command runs. **A STATED ASYMMETRY WITH
        §3.1**: this uses the ordinary `Shortcuts`/`Actions` layer (a new `_CancelDragIntent`),
        NOT the raw `HardwareKeyboard.instance.addHandler` hook the palette drag needs. That hook
        exists because a palette drag is armed from a sibling widget while Flutter focus may be
        anywhere; a move drag has the opposite guarantee (`_onBeginDrag` calls
        `_canvasFocus.requestFocus()` as its first statement) so the focus-scoped binding is
        provably sufficient and stays out of the handler-registration leak class. Because
        `CanvasIntentDetector` owns the gesture and cannot be un-routed mid-flight (unlike the
        palette's `pointerRouter` subscription, which `_cancelPaletteDrag` removes outright), a
        `_dragCancelled` latch makes the still-down pointer's remaining `updateDrag`/`commitDrag`
        callbacks no-ops. `Esc` is still NOT a general deselect key (see §3.2's known gap).
  - [ ] Step 2, cross-rack move (drag past 60 px beyond a rail), **not started**. Structurally
        untestable today regardless: `_buildDemoDocument` creates exactly ONE rack, so there is no
        neighbouring rack to jump to, re-snap against, or pulse a target border around.
  - [ ] Step 5, `Ctrl` at drag start = duplicate, **not started** (needs duplicate + designator
        re-allocation on drop)
  - [ ] Step 6, `Alt` at drop = insert-and-push (displaces occupants, push-up then push-down,
        else `Insert would overflow rack by NU`), **not started** (needs re-pack logic)
  - [ ] Step 7, `Ctrl+Shift` at drop over an equal-height device = swap (both showing a ↔ badge)
, **not started** (needs swap logic)
  - [ ] Multi-device drag, **not started**, unchanged documented restriction: dragging one device
        while several are selected moves just that one (`_onBeginDrag`'s `_dragPlacement` gate),
        matching the keyboard nudge's own single-focused-device rule
  - [ ] Lateral `Width position` dropdown (Full/Left half/Right half), **not started** (model
        already carries `startTwelfth`/`spanTwelfths`; no UI)
- [x] §3.4 Insertion caret (first-class object) + keyboard nudge (`↑↓`, `Shift`, `Ctrl`, `Alt`,
      `Home/End`, `PgUp/PgDn`), with 500 ms nudge coalescing (**partial, this stage**) the caret
      object (`CaretController`/`InsertionCaret`, `rackmate_ui`) exists whenever the canvas has
      focus and nothing is selected, seeded at the lowest free 1U slot, rendered as a 2px accent
      line + rail triangles + a ruler-label tint (`EditingOverlayPainter`); bare `↑↓`/`Home`/`End`/
      `PgUp`/`PgDn` move the caret when nothing is selected, and nudge the focused device (±1U for
      `↑↓`, ±10U for `PgUp`/`PgDn`, lowest/highest fitting for `Home`/`End`) when something is, 
      reusing `MoveDeviceCommand`'s existing `mergeKey`/`mergeWith` through the **400ms**
      `UndoStack` window (docs/03-architecture.md §5.4 names this window's exact intended consumer
      as "arrow-key nudges", the 400ms-vs-500ms discrepancy between that doc and this one is
      resolved in favour of the already-implemented, already-tested 400ms constant; see the final
      report for the full reasoning). A blocked nudge shakes the selection 3px
      (`ShakeController`) and reads "Blocked by DESIGNATOR" on a new minimal status line
      (`StatusMessageController`), never silently stopping. **Still not started**: `Shift+↑↓`
      (extend selection to the adjacent occupant, needs multi-select range semantics), `Alt+↑↓`
      (swap with the adjacent occupant, re-pack on unequal heights, needs re-pack logic),
      `Ctrl+↑↓` (jump to the next free slot, skipping occupied space, a directional occupancy
      search not built), and multi-device simultaneous nudge (acts on the single focused device
      only, matching drag-move's own existing single-device restriction, a multi-child
      `Transaction` per keypress could never coalesce, per `Transaction.mergeWith`'s
      single-child-only rule).
- [x] §3.5 Selection: click replaces, `Ctrl+click` toggles, **done**
  - [ ] `Shift+click` range-select within a rack, **not started**
  - [ ] Marquee (left-drag on empty canvas, window vs. crossing), **not started**
  - [ ] `Ctrl+A` select-all (rack, then project), **not started**
  - [ ] Multi-select combined ruler bracket + status-bar rollup, **not started**
  - [ ] `Ctrl+L` lock / unlock, **not started**
  - [x] Delete (zero-connection immediate; confirm bar for ≥1 connection not built since no
        Links exist yet), **done** (immediate delete only; the confirm-bar case is unreachable
        until M2 wiring exists)
  - [ ] Copy/Cut/Paste/Paste-in-place/Duplicate (`Ctrl+C/X/V/Shift+V/D`), **not started**
- [x] §3.6 Compact Up / Compact Down with preview overlay, **DONE, across passes 1 and 2.**
      Pass 2 added everything the §3.6 sentence asks for on top of pass 1's planner:
      **proposed positions as solid ghosts** (`EditingOverlayPainter` gained an optional
      `compaction` source; one ghost box per move at its `toRuIndex`, reusing the ghost
      fill+border extracted out of `_paintGhost` into a shared `_paintGhostBox`);
      **current positions dimmed to 25%** (`RenderDeviceBox`'s boolean `dragSource` flag
      generalised to a nullable `fadeOpacity`, so ONE `saveLayer` implementation serves both
      §3.3's 30% move-drag fade and §3.6's 25%, two booleans would have needed a precedence
      rule for a combination that cannot occur); and the **floating bar** reading exactly
      "Compact Up, 4 devices move, 3U freed [Apply] [Cancel]"
      (`compaction_preview_bar.dart`, a `Positioned` rather than an `OverlayEntry` because,
      unlike the drag chips, it does not follow a pointer and must accept clicks).
      **`Enter` applies as one undo entry; `Esc` cancels**, both through the existing
      `Shortcuts`/`Actions` map. Only the movers dim, a device that stays put is not part of
      the proposal.
      **THE AFFORDANCE IS THE RACK HEADER'S OVERFLOW MENU**, chosen because §3.6/AC-045 keep
      `Ctrl+B` RESERVED AND UNBOUND (it is bound nowhere) while still requiring the two
      commands to ship, and because compaction is a per-rack operation that belongs on the
      rack's own chrome. A global toolbar does not exist in this app and would have to invent
      a target-rack concept the moment a second rack lands.
      **`Enter` NEEDED A REAL `Action` SUBCLASS, not a `CallbackAction`**: it is bound BARE,
      inside the same `Shortcuts` subtree as the palette search box and every focusable
      palette row, and `ShortcutManager` consults `isActionEnabled`, NOT the callback's
      return value. A `CallbackAction` returning null would have reported the key HANDLED and
      silently eaten `Enter` app-wide. `_ApplyCompactionAction.isActionEnabled` returns false
      when no preview is open, so the key falls through. (The test for this had to be
      rewritten after a mutation survived, see the mutation note at the end of §3.)
      **STALE-PLAN GUARD, and it is load-bearing.** A plan holds `fromRuIndex` values captured
      at plan time and then waits for a human. If the document moves underneath (Ctrl+Z, a
      palette placement, a nudge), applying it would issue `MoveDeviceCommand`s whose "from"
      is a fabrication, and `revert()` would faithfully restore devices to positions they
      were never in, so the corruption would SURVIVE an undo. The screen therefore subscribes
      to `epochs.sequence` (bumped by every commit/undo/redo, CR-094) and cancels the preview
      on any bump it did not itself cause, with a status message. Same bug class as the two
      stale-`Timer` bugs this file was already bitten by; same treatment, with a regression
      test.
      **PREVIEW EXCLUSIVITY is a screen-level invariant, not an emergent property of paint
      order.** Three preview-then-commit interactions now coexist (palette drag, move drag,
      compaction). Opening a compaction cancels any in-flight drag; beginning either drag
      cancels an open compaction. The painter's precedence chain (compaction → drag ghost →
      caret) is the belt to that brace, preserving the file's existing exactly-one-source-
      per-frame property.
      Pass 1's pure-Dart PLANNER, unchanged and still fully tested
      (`rackmate_core/src/commands/compaction.dart`): `planCompaction()` returns an immutable
      `CompactionPlan` of `CompactionMove`s for one face in either direction, mutating nothing,
      and `compactionCommands()` turns an accepted plan into existing `MoveDeviceCommand`s for
      the caller to wrap in one `Transaction`. Locked placements are immovable anchors (CR-034).
      Two decisions §3.6 does not make, made explicitly in the planner and stated here:
      (1) **compaction preserves relative order**: devices only ever close the gap ahead of
      them and never leapfrog a neighbour into a lower run that would "fit better", because
      greedy best-fit packs marginally tighter while silently REORDERING the user's rack, which
      is a much larger edit than a button labelled Compact Down offers; §3.6 parking
      "Auto-arrange with trade heuristics" in v1.2 draws the same line.
      (2) **`freedU` is the contiguous run gained at the direction's far end**
      (`highestOccupiedBefore - highestOccupiedAfter` for Down, mirrored for Up), NOT the sum of
      gaps closed, the number on the bar has to be the U the user can actually spend.
      A `heightUOverride` parameter that the stage's own design called for was **built and then
      removed**: its only intended caller (the shrink modal's option 1) is actively harmed by it,
      since constraining the packer to a smaller height makes it refuse to relocate a device that
      would not fully fit, stranding an over-tall device at the top and making the shrink planner
      report a reachable height of U23 where the compacted layout plainly reaches U8. The shrink
      planner compacts against the real height and evaluates the result against the target
      instead. Caught by a unit test, not by review.

### §4 Rack configuration

This section is being built across THREE passes. **Passes 1 (core and plumbing) and 2
(inspector + compaction preview) have landed; pass 3 has not.** Pass 1 deliberately shipped no
UI at all. Pass 2 shipped the inspector, the header bar, the compaction preview, and the two
`rack_canvas_screen.dart` prerequisites pass 1's brief had forbidden it from making (see the
coordination note below).

- [x] `RackInspector` panel (name, designator, location, form factor, height, width, usable
      depth, rail type, weight cap, mount, swing frame, ground bar), **DONE, pass 2**
      (`rackmate_ui/src/inspector/rack_inspector_panel.dart`), on top of pass 1's command
      layer. All four sections render; Identity, Form factor and Display are fully editable
      and **every field routes through a real Command, so every field undoes**: asserted
      field-by-field by `rack_inspector_panel_test.dart`, which changes a value and then
      undoes it for each one.
      THE THREE ENTRY POINTS §4 NAMES ALL WORK, plus the bonus fourth: clicking the rack
      HEADER; clicking the rack's EMPTY BACKGROUND (tested against the existing `_geo` extent,
      inside the rack body opens the inspector, outside is just a deselect, and
      `rack_layer.dart` emits no hit regions of its own so there was nothing else to ask);
      `Ctrl+Alt+U` (a new `_RackSettingsIntent`, which also focuses the panel's first field so
      the keyboard path lands somewhere useful); and the overflow menu's "Rack settings…".
      Clicking a DEVICE puts the column back on the selection summary, that pair is how §4's
      "REPLACES the Selection section" is honoured, given there was no Selection section to
      replace (see the §1 row).
      COMMIT DISCIPLINE, one rule for the whole panel: text and numeric fields commit on blur
      or Enter (§4.1 states this for height; applying it uniformly means a user never has to
      remember which box behaves which way), dropdowns/radios/checkboxes commit on change, and
      `Esc` in a focused field reverts the buffer WITHOUT running a command. Refusals are never
      silent (§3.4): an empty designator, an unparseable depth or capacity, and an
      out-of-range height each revert the buffer AND report on the status line.
      NOTABLE FIELD DECISIONS. **Usable depth and weight capacity are nullable with an explicit
      unset state**: empty string means null, hinted `—` rather than `0`, with a clear button
      that writes null explicitly (CR-114: null means unknown, never zero; a 0 mm depth is a
      claim about the rack, an empty field is the absence of one). **Own weight is read-only
      and renders `—` when unknown**, never "0.0 kg". **Mount is a two-way Floor/Wall radio
      over the eight-value `RackFormFactor`**, and the mapping, which the spec does not
      make, PRESERVES the existing subtype: Wall→Floor→Wall on a pivot cabinet lands back on
      a pivot cabinet, and only a genuine cross-category move picks the category's generic
      member. Explicitly unit-tested, because a lossy default here would let two clicks
      silently destroy a fact a preset put there. **Hinge side is disabled and dashed while
      Swing frame is off.** **The Preset dropdown is write-only in the honest sense**: a
      `Rack` has no `presetRef`, so the displayed preset is DERIVED by exact value match and
      reads "Custom" the moment the user diverges, continuing to claim "Floor enclosure 18U"
      after the rail type changed would be the UI telling a story the document does not.
      **Applying a preset is ONE `Transaction`** (N `SetRackPropertyCommand`s + one
      `SetRackHeightCommand`), and it is ATOMIC OR NOTHING: a preset whose height would
      displace occupants is refused WHOLE rather than landing eight fields and quietly
      skipping the ninth, which would leave a rack claiming to be a "Wall box 6U" at 12U.
      **The Location dropdown is REAL, enabled and command-backed** over `doc.locations`, with
      a leading "(none)" mapping to null; `_buildDemoDocument` now seeds three demo Locations
      so the control is genuinely exercisable (demo data only, the `Location` model,
      `doc.locations` and the codec all predate this stage; only instances were missing). The
      "+ New…" item is OMITTED because the project Locations panel (CR-112) is out of scope
      and a menu item opening nothing is the dead affordance §3.4 forbids.
      Its command layer, from pass 1, is unchanged: One generic, type-safe `SetRackPropertyCommand<T>` driven
      by a `RackField<T>` accessor table covers the twelve editable scalar properties
      (`designator`, `locationId`, `ruNumbering`, `mirrorRearElevation`, `widthClass`,
      `railType`, `formFactor`, `usableDepth`, `weightCapacity`, `isSwingFrame`, `hingeSide`,
      `groundBarPresent`), each with its own `EpochMask` and its own `mergeKey` so inspector
      typing coalesces PER PROPERTY. One class rather than twelve, following
      `rename_entity_command.dart`'s own precedent; typed via the accessor table rather than an
      `Object?` payload, so the inspector's call sites keep static typing. `name` reuses the
      existing `RenameEntityCommand`; `heightU` reuses the existing `SetRackHeightCommand`
      (deliberately NOT renamed to §4.1's "ResizeRackCommand" spelling).
- [ ] Three ways to change height (stepper / field / drag top edge), **one of three built
      (pass 2); the other two are pass 3.**
      **WAY TWO, the inspector field, SHIPS**, committing on blur or Enter, clamping to
      CR-038's [1, 60] with a status message when it clamps, and carrying §4's "advisory above
      50" as helper text. It calls a NAMED FUNNEL, `_requestHeight`, rather than inlining the
      logic in its callback, precisely so ways one and three can call the same method in pass
      3 and §4.1's "ALL producing one ResizeRackCommand" stays literally true. Growing is
      always safe and never reaches the guard below.
      **THE SHRINK-BELOW-OCCUPANCY CASE IS GUARDED, NOT HANDLED, IN THIS PASS, read this
      before assuming it was forgotten.** §4.1 requires a modal here; that modal is pass 3.
      Until it exists `_requestHeight` REFUSES the shrink and names the casualties on the
      status line, plus the lossless height that would work ("Cannot shrink RK-1 to 6U: SW-1,
      PP-1 would lose their U. 9U is the smallest that fits."). That honours the principle's
      first two clauses exactly (nothing destroyed, nothing moved) and its third as far as one
      status line can. It is deliberately NOT a silent clamp to `smallestFittingHeightU`:
      quietly handing the user a different height than they typed is precisely the "silently
      move" §4.1 forbids. **Pass 3 replaces this one branch with the real modal**: the funnel,
      the `planRackShrink` call and the casualty list are already in place; only the dialog is
      missing.
      The one piece of core geometry all three need is **done**:
      `RackGeometry.heightForTopEdgeY()`, the drag-the-top-edge inverse, which
      `ruIndexForTopY` could not serve because it clamps to the current `heightU`: the very
      quantity the gesture solves for. `RackGeometry` also gained value `==`/`hashCode`, without
      which every `geo != old.geo` repaint check becomes unconditionally true the moment
      `heightU` starts changing.
- [ ] Shrink-below-occupancy modal (compact-first / move-to-bin / keep-larger, trim
      from top/bottom), **not started (UI)**; the PLANNER behind it is **done**
      (`rackmate_core/src/commands/rack_shrink.dart`). `planRackShrink()` returns, without
      mutating anything: every doomed occupant with designator, description, U range and REAL
      link count (rule 4, via `linkCountForDevice`, a true 0 today, not a stub); the uniform
      downward `shiftMoves` a Trim-from-Bottom requires (rule 5); `smallestFittingHeightU`
      (option 3); and a nullable `CompactionRescue` (option 1) that is null precisely when
      compaction rescues nobody, enforcing rule 1's "appears ONLY when compaction actually
      helps" in the planner rather than leaving the modal to remember it.
      **Trim direction is recomputed, not cosmetic**: Top and Bottom produce genuinely
      DIFFERENT casualty sets, different rescue directions (Compact Down vs Compact Up) and
      different `smallestFittingHeightU` values. §4.1's own mockup implies one static list
      beside the radio; that is a spec simplification, corrected here.
      **On partial rescue, option 1 composes with option 3**: rather than shipping §4.1's
      literal "2 of 3 fit, 1 goes to Staging Bin" label (unbuildable, and shipping it would
      silently drop a device), the rescue reports an `achievableHeightU`, the smallest height
      the compacted layout permits losslessly, so option 1 remains selectable per rule 1 and
      NOTHING is ever displaced out of the rack under any option. Rule 3's "DELETION IS NOT
      OFFERED" holds structurally: no code path in the planner removes a device, asserted by a
      purity test that sweeps every height in both trim directions.
- [x] Rack presets (wall box, swing gate, floor enclosure, etc.), **done (data)**,
      `rackmate_core/src/catalog/rack_presets.dart`, in the same `build*()`-returning-a-keyed-Map
      idiom as the 48-template device catalog, with provenance appended to
      `assets/catalog/sources.md` §5 under the same generic-archetype-never-a-real-SKU rule
      (DR-002/AC-052). **ELEVEN presets, not twelve**: the stage's design brief said twelve, but
      §4's own enumerated list ("Wall box 6U/12in, Swing gate 12U/18in, Pivot cabinet 10U, Floor
      enclosure 18/21/27/35/44U, Open frame 4-post 44U, Credenza bay 8U, Data 42U/36in") counts
      1+1+1+5+1+1+1 = 11. No `openFrame2Post` preset ships even though §4 cites a 2-post frame as
      the reason `usableDepth` is nullable: §4 does not name one, and inventing an archetype to
      make a null-depth case reachable would put unreviewed dimensions in front of users.
      **No codec work was needed and none was done**: presets are not persisted (a `Rack` has no
      `presetRef`), so applying one is a fan-out of writes to fields `json_codec.dart` already
      round-trips. CR-117's invariants are untouched and `byte_roundtrip_test.dart` needed no new
      fixture.
      **The preset-apply Transaction landed in PASS 2, not pass 3 as originally planned**,
      because `_requestHeight` (the height funnel it must route through) also landed in pass 2
      alongside the inspector's height field. It is one `Transaction` labelled
      `applyRackPreset`, and it is atomic or nothing: "Wall box 6U" on the occupied 12U demo
      rack is refused WHOLE with a status message, rather than applying eight fields and
      silently skipping the height. Pass 3 swaps that refusal for §4.1's modal.
- [x] Circuits panel (flat, filtered by `rackId`), **done, pass 2**, as far as it honestly
      can go. Verified state of the world, unchanged: the `Circuit` model, the `doc.circuits`
      map and full codec support all exist; there are ZERO `Circuit` instances, ZERO commands
      and ZERO UI anywhere in the codebase. The section therefore ships a READ-ONLY list
      filtered by `c.rackId == rack.id` (each row rendering the designator, `breakerAmps` and
      the derived `continuousLimitAmps`, CR-048), a real empty state, "No circuits on
      RK-1.", and **NO `[+ Add circuit]` button**, because no command anywhere creates a
      `Circuit` and a rendered-but-inert button is exactly the "silently does nothing" trap
      §3.4 forbids. One caption line says circuit creation arrives with the power stage.
      Membership-by-walking-power-`Link`s (CR-028's other half) is untouched: the inspector
      merely filters, which is all CR-028 asks of it.

### §5 Derived readouts
- [x] Always-visible chip strip (RU, weight, VA, outlets, each with an unknown-count
      superscript), **done, this stage**. `computeRackRollups` in
      `rackmate_core/lib/src/derived/totals.dart` (the first file in `derived/`) is the pure
      derivation; `rackmate_ui/canvas/rack_metrics_row.dart` renders it at §5's 20 px, in the
      rack header, directly under `RackHeaderBar`. Reads
      `RU front 5/12 · — lb⁽⁴⁾ · — VA⁽⁴⁾ · outlets 0/0` on the demo rack.
      **What is deliberately different from §5's literal line, and why:**
      * The RU chip **names its face** (`RU front 5/12`, not `RU 15/24`). §5's own rules track
        front and rear separately "because 'how much room is left' genuinely has two answers",
        and its Vitals panel shows two bars, so an unlabelled figure would change meaning
        silently when the user flips the elevation. RU is per-face; weight, VA and outlets are
        rack-wide (a device loads the frame whichever way it is bolted in), which is the same
        split §5's Vitals panel draws.
      * The trailing **`⚠2` findings rollup is absent**, not stubbed. No validation engine
        exists (see the third bullet), so there is nothing to count and an inert `⚠0` would be
        the fabricated number G4/CR-114 forbids.
      * `PowerProfile.outletsProvided`/`outletsConsumed` are **non-nullable `int`s**, so
        "unknown outlets" is structurally inexpressible today: only an unresolvable
        `TemplateSnapshot` can make that rollup unknown. The unknown count is carried anyway,
        so the chip starts telling the truth the moment those fields become nullable, which
        they should, since a template nobody has authored outlets for is not a template that
        provides none.
      * VA sums `PowerProfile.apparentVA` **only** (CR-056/AC-020: circuit loading is computed
        in VA). It is never derived from `typicalWatts`, AC-039's rejected "half of
        nameplate" behaviour, restated as a test.
- [ ] Collapsed Rack Vitals panel (space bars, weight bar, power bar, BTU/CG advisory), 
      **not started**. The derivation the panel needs now exists (`RackRollups` carries the
      per-face RU split and the weight/VA/outlet rollups); what is missing is the panel.
- [ ] Findings surfacing: device badge (shape+colour), rack-header `⚠n` rollup, validation
      drawer with select-and-zoom, **not started** (no validation rules run yet at all, that's
      `derived/validation.dart`, not built in any stage so far)

### §6 Non-device occupants
- [ ] Blanks, vents, fans, patch panels, PDU/UPS, rear lace bar as ordinary templates with
      `OccupancySide`, **not started** (occupancy side exists in the model; no such templates
      or palette to place them from)
- [ ] 0U vertical occupants (`ZeroUPlacement`, inspector-edited, no drag), **not started**
- [ ] Shelves and hosted devices (drop-onto-shelf, auto-pack, capacity bar, leaving-shelf
      gesture, delete-shelf prompt), **not started**

### §7 Naming and designators
- [x] `designator` and `name` exist as data fields, **done** (model only)
- [ ] `F2` inline designator edit / `Ctrl+F2` name edit, **not started**
- [x] Auto-assignment via the `idformat` engine on device creation (`{TYPE_PREFIX}{SEP}{SEQ}`)
, **done** for catalog placement (`allocateDeviceDesignator` + `buildPlaceFromCatalogCommand`,
      `rackmate_core/src/idformat/designator_allocator.dart`); the 4 original hand-built demo
      devices still carry their original hand-typed designators (unchanged, pre-existing)
- [ ] Collision UI (`[Swap] [Go to]`), **not started**
- [ ] `Ctrl+R` Renumber dialog with diff preview, **not started**
- [ ] Project-level Locations panel, **not started**

### §8 Keymap
- [x] `Del`/`Backspace`, **done**
- [x] `Ctrl+Z` / `Ctrl+Shift+Z` / `Ctrl+Y`, **done**
- [x] `/` (focus palette search), **done** (earlier stage)
- [x] Bare `↑`/`↓`/`Home`/`End`/`PgUp`/`PgDn` (caret move / nudge, see §3.4), **done, earlier stage**
- [x] `Ctrl+Alt+U` (open the RackInspector), **done, §4 pass 2** (`_RackSettingsIntent`); it
      also focuses the panel's first field
- [x] Bare `Enter` applies an open compaction preview, **done, §3.6 pass 2**, via a real
      `Action` subclass whose `isActionEnabled` is false when no preview is open, so the key
      falls through to the palette's own `Enter` handlers rather than being swallowed
- [x] Bare `Esc` also cancels an open compaction preview, **done, §3.6 pass 2**, extending
      the existing `_CancelDragIntent`
- [ ] `Ctrl+B`, **deliberately RESERVED AND UNBOUND** (§3.6/AC-045). Bound nowhere. Compact
      Up/Down are reachable from the rack header's overflow menu instead
- [x] `Esc` cancels an in-flight palette drag (see §3.1) (**done, this stage**) wired via a raw
      `HardwareKeyboard.instance.addHandler` hook, not the `Shortcuts`/`Actions` registry (Flutter
      focus may be anywhere while the pointer that armed the drag is still down); still NOT a
      general-purpose deselect/cancel key outside an in-flight drag (see §3.2's KNOWN GAP)
- [ ] Everything else in the ~40-binding table (`Ctrl+1..4`, `Ctrl+0/9/Alt+0`, `Ctrl+K/F/G`,
      `Ctrl+P/E`, `Ctrl+Shift+F`, `Enter` (search-box Enter now places at the caret, see §3.2; a
      NEW palette row's own Enter handler was already done earlier), `Shift/Ctrl/Alt+↑↓` (see
      §3.4's deferrals), `←→` cross-rack, `Ctrl+L`, `Ctrl+R`, `Ctrl+D`, `Ctrl+X/C/V/Shift+V`, `G`,
      `L`, `Ctrl+Shift+W`, `F2`/`Ctrl+F2`, `Ctrl+Alt+U/N`, `U`, `Ctrl+Alt+1/2/3`, `F7/F8/Shift+F8`),
      **not started**.
      Generated `build/keymap.md` from one `Intent` registry (CR-101) is itself not started,
      today's shortcuts are wired ad hoc in `RackCanvasScreen`, not through a registry.

### §9 Empty state, first run, accessibility
- [ ] Start card + four starter projects (also needed as goldens/perf fixtures/screenshot
      source, per AC-052), **not started**
- [ ] New-rack dialog (Name/Preset/Height), **not started**
- [ ] Empty-rack hint card, other 7 empty states, **not started**
- [ ] Coach marks (first placement, first finding, first rack→schematic switch), **not started**
- [x] Per-device `Semantics` label (designator + name + type), **done**
- [ ] Outline tree (`Ctrl+Alt+3`), the primary AT surface, **not started**
- [ ] Full keyboard focus-region cycling (`F6`/`Shift+F6`/`Ctrl+F6`), spoken caret announcements,
      `disableAnimations` handling, hit-target sizing audit, **not started**

---

## 3. What M0/M1 has actually shipped so far (commit-level, for orientation)

Chronological, oldest first, see `git log --oneline` for the full history:

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

UNCOMMITTED, as of this log update: THREE stacked, uncommitted stages sit on top of commit 11, 
(1) the insertion caret + keyboard nudge + quick-add-at-the-caret stage (§3.2/§3.4 above,
`CaretController`/`InsertionCaret`, `EditingOverlayPainter`, `ShakeController`,
`StatusMessageController`, `findBlockingOccupant`, `buildPlaceFromCatalogCommand`'s
`explicitRuIndex`), and (2), built directly on top of it, the drag-from-palette-to-rails stage
(§3.1 above, `PaletteDragController`, `EditingOverlayPainter`'s ghost/hatch/dashed-border
painting, `DevicePalettePanel`'s `onArmDrag`/`draggingCatalogId`, the raw `HardwareKeyboard`
Esc-cancel hook, and the shared `_finalizeCatalogPlacement` helper). 291 tests passing across the
workspace with BOTH stages in place, plus a subsequent adversarial-review fix pass (165 core + 113
ui + 13 app), not yet committed, so not reflected in the numbered commit list above. The fix pass
closed two HIGH-severity bugs in the palette-drag gesture (concurrent-arm state corruption; a
stale blocked-release timer that could force-reset a later drag and permanently leak the Esc
keyboard hook), reordered the live drag evaluation to match `buildPlaceFromCatalogCommand`'s
extent-then-occupancy check order (see §3.1 above), and added a `MutableClock` test fixture
(`rackmate_core/src/commands/clock.dart`) plus real paint-content assertions for the blocked/valid
ghost styles, no scope changed, only correctness and test-coverage.

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
a second move-drag begun inside the 1.2 s linger, see §3.3 above), with a regression test. Seven
deliberate mutations were run against the new tests (Esc revert removed, `exceptId` dropped,
`dragSource` never set, blocked release committing anyway, per-frame evaluation frozen, the
painter ignoring `isShowingGhost`, the 4 px threshold defeated, the stale-timer cancel removed);
all were killed, one of them only after the threshold test was strengthened from a vacuous
assertion into a real sub-slop move event.

And (4), stacked on those, the RACK CONFIGURATION stage (§3.6 and §4), built across three
passes. **Passes 1 and 2 have landed; pass 3 has not.**

*Pass 1 (core and plumbing, no UI):* `compaction.dart`, `rack_shrink.dart`,
`set_rack_property_command.dart` (`RackField<T>` + the generic `SetRackPropertyCommand<T>`),
`rack_presets.dart`, `link_count.dart`; `railOccupantsOnFace` exposed out of
`catalog_placement.dart` as the ONE occupancy scan; the AC-013 twelve-field `@internal` retrofit
plus the `heightU` setter assert in `rack.dart`; `RackGeometry.heightForTopEdgeY` and value
`==`/`hashCode`; four new `LabelKey` values; the `internal_setter_grep_test` extension to scan
`rackmate_ui/lib`. 165 → 277 core tests.

*Pass 2 (inspector + compaction preview):* the 320px inspector column
(`inspector_panel.dart` + `rack_inspector_panel.dart`), the screen-space `RackHeaderBar`,
`CompactionPreviewController` + `CompactionPreviewBar`, `EditingOverlayPainter`'s compaction
ghosts (with the shared `_paintGhostBox` extracted out of `_paintGhost`), `RenderDeviceBox`'s
`dragSource` → `fadeOpacity` generalisation, the `Ctrl+Alt+U` / `Enter` / `Esc` bindings, and the
two `rack_canvas_screen.dart` prerequisites pass 1 could not make (the memoised `_geo` and the
first-ever `epochs.rack` subscription). 124 → 175 UI tests. `flutter analyze` sits at the same
211 infos pass 1 left it at, with zero errors and zero warnings; `flutter build windows` succeeds.
**Twelve deliberate mutations were run against pass 2's new tests**: compaction applying
immediately instead of previewing, ghosts drawn at the current rather than the proposed U, the
stale-plan guard defeated, the apply split into N transactions instead of one, the shrink guard
removed, a preset applying partially after a refused height, every device dimmed rather than only
the movers, the empty-background click ignoring the rack bounds, the `Enter` action always
enabled, designator validation dropped, compaction ghosts painted in the BLOCKED (dashed/error)
vocabulary, and an empty plan shown as a preview. **Eleven were killed on the first pass; ONE
survived.** Making `_ApplyCompactionAction.isActionEnabled` return `true` unconditionally did not
fail the "Enter is not stolen from the palette" test, because that test drove the palette flow
through `testTextInput.receiveAction`, the TEXT INPUT channel, which never touches the key-event
path the `Shortcuts` layer lives on. The assertion was true but vacuous about the property it
claimed to protect. It was rewritten to wrap the screen in an ANCESTOR `Focus` that counts
`Enter`: key events propagate upward, so the ancestor sees the key exactly when the screen's
`Shortcuts` layer declines it, which makes handled-vs-ignored directly observable. The mutation is
now killed, and the original end-to-end palette assertion was kept alongside it (renamed honestly)
because it still guards the user-visible behaviour even though it cannot discriminate the
mechanism.

One INCIDENTAL change worth flagging, since it touches files this stage otherwise had no business
in: `rack_canvas_screen_test.dart`, `rack_compaction_test.dart`,
`rack_inspector_panel_test.dart` and `apps/rackmate/test/widget_test.dart` now set a
1600x1000 test surface in `setUp`. The screen's layout is four columns as of this stage, so the
default 800x600 surface leaves the canvas ~198 logical pixels, narrower than the rack's own
267-unit scene width, and narrow enough that the floating chrome overlaps itself and that
`_focusCanvas`'s click at (300, 400) lands on the INSPECTOR. docs/04 §1 already treats anything
under 1080px as the (unbuilt) tablet-collapse case, so 800x600 was never a supported size for
this screen; the tests now say so explicitly rather than depending on a default that happened to
work while there were only two columns.

---

## 3a. Rack configuration (§4): what is DELIBERATELY out of scope

Recorded here rather than only in a session report, because every item below is something a
future reader could reasonably assume was forgotten. None of it was.

**Not built in ANY of the three passes of this stage:**

1. **Multi-rack canvas layout and the new-rack dialog.** There is exactly ONE hardcoded demo
   rack; `rack_canvas_screen.dart` holds a single `_rack` field and a single `RackGeometry`.
   Supporting N racks touches the scene builder, hit-testing, drag targeting and the caret
   simultaneously, its own stage, paired with persistence and the four starter projects. This
   stage configures the rack that already exists. **No `AddRackCommand` or `RemoveRackCommand`
   was added.**
1a. **The full shrink-below-occupancy MODAL, as of pass 2 only.** Not a permanent deferral, 
   it is pass 3 of this same stage, but recorded here because pass 2 ships a REFUSAL in its
   place and a reader could mistake that for the finished behaviour. See §4.1's row above for
   exactly what the refusal does and why it is a refusal rather than a silent clamp.
1b. **The header height stepper and the drag-the-top-edge gesture.** Also pass 3. The
   inspector's height field ships in pass 2, so height IS editable today; the other two of
   §4.1's "three ways" are not built, and are absent rather than present-and-inert.
2. **Shrink-modal option 2 (Move to Staging Bin) and all `StagedPlacement` handling.** Correcting
   a premise this log itself previously implied: `StagedPlacement` **does** exist in full
   (`placement.dart`) and **is** fully codec-round-tripped. What is missing is any UI, any
   command that produces one, the return-to-rack chip, and any query surface. Shipping option 2
   later is therefore purely additive with no migration. Pass 3 renders option 2 DISABLED with
   its reason stated, and substitutes option 3 as the fallback preselection, see the note on
   rule 2 below.
3. **§4.2 finding filings (`RCK-012` usable depth, `RCK-003` weight capacity) and every other
   validation rule.** No validation or finding engine exists in any package: there is no
   `derived/validation.dart`. Depth, width class and weight capacity are fully EDITABLE and
   undoable as of pass 1's command layer; they simply file nothing yet. Changing them displaces
   no occupant, per §4.2.
4. **The project Locations panel (CR-112) and the Location dropdown's "+ New…" flow.** Correcting
   a second premise: the `Location` model, `LocationKind`, the `doc.locations` map and full codec
   round-trip ALL exist, and `Rack.locationId` is already encoded and decoded. Only the panel and
   any instances are missing. Pass 1 wired `RackField.locationId` to a real command; pass 2 ships
   a real, enabled dropdown over `doc.locations` (minus "+ New…").
5. **Circuit creation and editing.** See §4's Circuits row above.
6. **`Ctrl+B` stays RESERVED AND UNBOUND** per §3.6 and AC-045. Auto-arrange with trade
   heuristics and Fill-gaps-with-blanks remain deferred to v1.2.
7. **Rack Vitals, the chip strip and the rack-header `⚠n` rollup**: they belong with the
   validation stage (§5).
8. **Compaction across both faces from the toolbar.** The toolbar action compacts the currently
   displayed face only; the shrink path unions both faces. A deliberate asymmetry, stated in
   `compaction.dart`'s header: a previewed toolbar operation acts on the elevation you are
   looking at, while a shrink is a physical change to the whole rack.

**How the missing Staging Bin changes §4.1's numbered rule 2.** Rule 2 says option 1 is
preselected on full success, "otherwise option 2". Option 2 does not exist, so **option 3 becomes
the fallback preselection**. The rule's actual intent is "never preselect the lossy-feeling option
when a clean one exists"; with the bin gone, option 3 is the only always-available option that
loses nothing at all, so preselecting it honours the rule's intent even though it inverts its
letter. Option-1-partial is deliberately NOT preselected, because it is a compromise the user
should choose deliberately. **Nothing is silently dropped under any selection**: rule 3's
no-deletion holds trivially, since no option removes a device.

**Pass 1 coordination note: RESOLVED IN PASS 2.** The stage's design assigned two
`rack_canvas_screen.dart` prerequisites to pass 1, making `_geo` non-`late final` so it
recomputes on a height change, and adding the first-ever `epochs.rack` subscription. Pass 1's own
task brief forbade touching that file, so both were deferred. **Pass 2 landed both**, and they
were exactly as load-bearing as flagged:

* `_geo` became a MEMOISED GETTER (`_geoCache`, keyed on `_rack.heightU`) rather than a field
  re-assigned from the epoch listener. A getter cannot go stale by construction (there is no
  ordering to get wrong between "the command mutated `heightU`" and "somebody read `_geo`") and
  because `RackGeometry` is an immutable single-`int` value type, the cache exists purely to keep
  IDENTITY stable within a height, which is what stops `EditingOverlayPainter.shouldRepaint`'s
  `geo != old.geo` from being pointlessly true on every build. (Pass 1's `==`/`hashCode` addition
  means that comparison would be correct either way; the cache just avoids the allocation.)
* The screen now subscribes to `epochs.rack` (height + every rack property), `epochs.meta`
  (designator/name, which the header and inspector both display), and `epochs.sequence` (the
  compaction preview's stale-plan guard) alongside the pre-existing `epochs.structure`. Without
  the first of those, a height change would have mutated the document and repainted nothing.

**Pass 2 coordination note, for whoever picks up pass 3.**

* `_requestHeight(int target)` is the height funnel, and it already exists. Ways one (header
  stepper) and three (drag the top edge) must call IT, not `SetRackHeightCommand` directly.
* `_requestHeight`'s shrink branch currently calls `_status.show(_shrinkRefusal(plan))` and
  returns false. That single branch is where `ShrinkRackDialog` goes; `planRackShrink` is already
  being called there and its `RackShrinkPlan` is already in hand.
* `_applyPreset` refuses whole on that same branch. Once the modal exists, it should get the same
  treatment rather than a second, parallel path.
* `EditingOverlayPainter.paint`'s precedence chain is currently `compaction -> drag ghost ->
  caret`, an if/else chain preserving the file's exactly-one-source-per-frame property. Pass 3's
  resize preview inserts at the FRONT. **Re-read that block rather than assuming its shape.**
* Preview exclusivity is a screen-level invariant (`_beginCompaction` cancels both drags;
  `_onBeginDrag` and `_onPaletteArmDrag` cancel the compaction). A resize preview must join that
  set in both directions, with a test; it is not something to leave to paint order.
* `RackHeaderBar` deliberately has NO stepper yet, only a read-only height badge. Replacing the
  badge with the hold-repeat stepper is pass 3's job; the widget is otherwise complete.
* The modal-storm problem the design flagged (a held stepper ratcheting down through occupied
  territory opening one modal per tick) is still unaddressed, because there is no stepper yet.

---

## 3b. The Schematic and Schedule tabs: DELETED, and what stands in their place

An off-discipline stage built an M2 schematic and schedule ahead of the roadmap, with **zero
tests across 2 608 inserted lines**. This section records what was removed, what replaced it,
and, because it is the part a future reader will otherwise re-litigate, the doc conflict the
replacement resolves.

**Deleted outright** (`git rm`, recoverable from history; nothing imported any of them except
`apps/rackmate/lib/main.dart`):

| File | Why |
|---|---|
| `rackmate_ui/canvas/schematic/schematic_canvas_screen.dart` (707 L) | Could only ever draw ONE anonymous placeholder box. See the two root causes below. |
| `rackmate_ui/canvas/schematic/sugiyama.dart` (324 L) | Dead and crashing: `_phase1LayerAssign` mutates `queue` inside `for (final node in queue)`, so it throws `ConcurrentModificationError` on any graph with an edge. |
| `rackmate_ui/canvas/schematic/wire_drawing.dart` | `WireConnection` is a stand-in for `Link`/`Service`/`Conductor`, which M2 defines properly (CR-008/010/011). Relocating a stand-in into `rackmate_core` would have inverted the discipline. |
| `rackmate_ui/schedule/schedule_screen.dart` | Renders `document.links`, and no code path can create a `Link`. Its `_EmptyState` told the user to "Create links in the Schematic tab", a tab that cannot create one. |

**Relocated instead of deleted** (with 72 new tests, in the same stage, see
`rackmate_core/test/symbol_layer_test.dart`, `symbol_hit_test_test.dart` and
`rackmate_export/test/symbol_layer_pdf_test.dart`): `symbol.dart` →
`rackmate_core/draw/scene/symbol_layer.dart` and `hit_test.dart` → `symbol_hit_test.dart`, per
CR-071 and docs/05 §3's "drawn by `symbol_layer.dart` in `rackmate_core/draw/` and replayed by
both backends". They are the only part of the deleted work that had salvage value, and the
export-side test is the one that could not have been written before the move.

**THE TWO ROOT CAUSES, recorded so nobody re-debugs them.** Twelve consecutive `fix:` commits
went at this and none of them touched either path.

1. *One placeholder symbol.* The document never reached the schematic. `main.dart` constructed
   the scene inline with `fragments: {}` and `rackId: ''`, both hardcoded; there is no
   app-level document, because `RackCanvasScreen` seeds and owns the only one privately.
   `_autolayoutSymbols()` then branched on `scene.fragments.isEmpty` and MANUFACTURED a single
   `RenderedSymbol` with dummy `in1`/`out1` ports, which `symbol.dart` drew as `'P${port.id}'`,
   the literal `Pin1` / `Pout1` on screen. The else-branch was no better: it skipped keys
   matching `startsWith('rack-')`, a prefix that matches nothing the scene builder emits, and
   emitted the same dummy box for everything else. There was no code path in that file capable
   of rendering a real device, so wiring a real scene in would still have shown grey boxes.
2. *No toolbar.* `_RenderSchematicCanvas.paint(context, offset)` filled its background with
   `DBox.fromLtwh(0, 0, size.width, size.height)`, ignoring `offset`, while threading it into
   the symbol draw two lines later. The object opts out of its own layer
   (`isRepaintBoundary => false`), so `context.canvas` is in the enclosing layer's space; the
   `Column` paints the toolbar first and the canvas second at `offset ≈ (0, 48)`, and the grey
   rect landed on top of the toolbar band. `render_rack_canvas.dart:225` has always done this
   correctly, by pushing `Matrix4.translationValues(offset.dx, offset.dy, 0)` first.

   Neither was a constraints problem, which is why `LayoutBuilder` wrapping and repeated
   `setState` never converged. (`updateRenderObject` was also a structural no-op: every setter
   guarded on `identical()` against the same instance the State passed on every build.)

**What the tabs show now.** `UnbuiltView` (`rackmate_ui/src/shell/unbuilt_view.dart`), a
milestone badge, `Schematic — not built` / `Schedule — not built`, a sentence on what is
absent, a sentence on why the tab is in the strip, and the governing docs. **No control of any
kind**, enforced by two independent tests rather than by review.

**THE DOC CONFLICT, and the ruling taken.** docs/09 M1 says "an empty Schedule tab that
explains it is coming is a lie, so the tab does not exist yet"; docs/05 §12 line 780 says "The
v1 tab strip shows three tabs: Rack, Schematic, Schedule". Read strictly against each other,
one removes the tabs and the other requires them. **The strip keeps three tabs and the two
unbuilt ones say they are not built.** The reasoning: what M1 forbids is a view that LOOKS
finished and is empty, a zero-row schedule table asserts "you have not wired anything", which
is false when the truth is "this build cannot wire anything". A tab whose first line is *not
built* asserts nothing untrue. If the owner reads M1 strictly, the two tabs come out of the
strip entirely and `UnbuiltView` goes with them; that is a one-line change in `main.dart` and
the tests would need re-pointing, so it is worth an explicit ruling rather than a silent
default.

**Debug cruft removed in the same pass:** 8 `print()` calls (6 under `schematic/`, 2 in
`main.dart`), the uncommitted `Container` wrapping `SchematicToolbar` commented "Debug border
to verify toolbar visibility", its amber/orange decoration, and
`print('LayoutBuilder received constraints: …')`. Two source-level gates now hold that line,
`packages/rackmate_ui/test/no_print_test.dart` and `apps/rackmate/test/no_print_test.dart`, in
the same shape as `rackmate_core`'s `no_flutter_import_test.dart`. `avoid_print` DID fire on
all eight; it fires at INFO in a project that carries ~210 of those by design, so it was
invisible.

**Deliberately NOT done here, and honest about it:**

* **The schematic does not render devices, and this stage did not try.** It cannot until an
  app-level `DocumentController` exists that sibling tabs can read, and that belongs with
  roadmap item #10 (atomic save, autosave, recovery, recents, the outline tree), the stage
  that follows. Doing it here would duplicate or pre-empt that work.
* **`Ctrl+1` / `Ctrl+2` and the reserved `Ctrl+3` (docs/05 §12) are unbound.** No view-switching
  keymap exists in this app in any view; binding two of three would read as a whole keymap.
  Lands with §8's keymap pass.
* **docs/05 §3's gu-denominated sizing is still not implemented** in `symbol_layer.dart`, the
  20 gu minimum width, 6 gu header, 2 gu pin pitch and `kBankCollapseThreshold = 8`. The shape
  of the formulas is honoured in caller-supplied units; converting `kGridUnit` to diagram
  points needs a schematic scene builder's scale anchor, which does not exist. Flagged in that
  file's header.
* **`.clinerules/editing.md`** (added by the off-discipline stage, commit `6db8131`) still
  instructs whoever reads it to "Make a commit after every task … just commit to the main
  branch." It is almost certainly how 19 commits including 12 thrashing `fix:` commits landed
  directly on `main`. It was not acted on and was not removed; that is the repo owner's call,
  but it should be made.

**Mutation testing, scoped honestly.** Deleting a file cannot be mutation-tested, so the
discipline applies only to the honest-panel behaviour that replaced it. Ten mutations were run
against it and **all ten were killed on the first pass**; the two worth recording are that
drawing a single circle inside `UnbuiltView` fails
`paintsExactlyCountTimes(#drawCircle, 0)` (proving that assertion is live rather than vacuous),
and that a button wrapped in `ExcludeSemantics` is caught ONLY by the widget-subtree check,
which is why both that check and the semantics check exist.

---

## 3c. The chip strip, the Staging Bin chip, and one repaired test

Same off-discipline stage as §3b, different files: three M1 features that were worth keeping
and shipped untested. All three now have tests; all three had real defects.

### The chip strip (§5, roadmap item 7): the number was never computed

`RackMetricsRow` displayed `12/12U · 0 free` on a 12 U rack holding 5 U. The widget was not
miscomputing: **its one call site passed the numbers as literals**, 
`ruFree: 0, // TODO(M1): wire to actual computed free RU`, and the same for weight, VA and
outlets, and the widget derived USED from the FREE it was handed, so `ruFree: 0` printed the
rack as completely full. Nothing anywhere computed free RU.

What shipped instead:

* **`rackmate_core/lib/src/derived/totals.dart`**: `computeRackRollups(rack, devices,
  templates, face) -> RackRollups`, the first file in the `derived/` directory
  docs/03-architecture.md reserves for it. Pure, argument-driven rather than
  `RackDocument`-driven, so the persistence stage's `DocumentController` can arrive without
  touching it. Counts DISTINCT occupied RU (overlapping placements, an `RCK-001` state the
  model permits, count once) clamped to `[1, heightU]` (a device hanging past the top
  contributes only the slots that exist). Membership follows shelf-host chains with a visited
  set, so a corrupt file's cycle terminates instead of hanging the UI thread.
* **`Rollup<T>`** carries `value` (`null` = unknown), `knownCount` and `unknownCount`. The rule,
  in one place for all four rollups: a total is `null` **iff** at least one device contributed
  and none supplied a value; a rack with no contributors at all reports a genuine zero, because
  an empty rack really does weigh nothing extra. `T` is unbounded rather than `T extends Object`
  because `Mass` is an extension type and its only supertype is `Object?`.
* **`MassFormatting.toPoundsValue`/`toKilogramsValue`** (units/unit_formatter.dart), the
  unit-less forms, so the strip's `148/200 lb` does not re-derive the µg conversion. The
  suffixed forms now delegate to them, so the two spellings cannot drift.
* The strip **moved into the rack header**, per §5's "20 px, in the rack header" and §2.1's
  "32 px header, sticky / 20 px chip strip". It was a `Positioned.fill` + `Align.bottomCenter`
  36 px OPAQUE bar over the bottom of the canvas (absorbing every pointer event aimed at the
  lowest RUs, which no test covered) and it had pushed the status-message stub from
  `bottom: 12` to `bottom: 48` to get out of its way. Both undone. It is a SIBLING of
  `RackHeaderBar` in the same `Positioned`, not a child of it, because that widget is flagged
  mid-rework above and a fifth concern threaded through it would collide with the pending
  `⚠n` rollup.
* The widget now takes the whole `RackRollups` rather than four loose scalars. That is the
  structural half of the fix: a widget that accepts loose numbers invites a call site to
  invent them, which is exactly what happened.
* Fixed on the way: every chip's text used `colorScheme.onPrimaryContainer` regardless of its
  background, and any chip whose value was `0` was HIDDEN, so "this rack draws no power" and
  "nobody has measured this rack" rendered identically.

**Deviations from §5's literal line are listed in §2's §5 entry above**, not here, so they sit
next to the requirement they depart from.

### The Staging Bin chip (§3.1's escape hatch, roadmap item 4): three defects, and a lie

docs/04 §3.1 wants "Dragging outside any rack shows the ghost at 40 % with a `Release to add to
Staging Bin` chip; dropping there creates a `StagedPlacement`". The overlay that shipped showed
that chip. **Releasing there does nothing**, and still does: `StagedPlacement` is fully modelled
and codec-round-tripped, but no command produces one and no surface lists the bin, so a device
dropped there would vanish with no way to retrieve it, strictly worse than a refusal. Building
the bin properly (a command, a query surface, the `↩ Return to RK-1 U21` chip of CR-032, and the
shrink modal's option 2) is its own stage and was not in this one's scope.

So the ruling for this stage is the same one §3b applies to the tabs: **mark it unfinished
rather than half-fake it.** The chip now reads `Staging Bin — not in this build` /
`Releasing here will not place <device>.`, and release reports the same refusal through
`StatusMessageController` instead of silently doing nothing. **The shrink dialog's Staging Bin
option stays DISABLED with its existing honest reason**: nothing about this stage makes it
deliverable, and enabling it would re-introduce exactly the promise this chip stopped making.

The three mechanical defects, all now tested:

1. **A leaked `OverlayEntry`.** `RackCanvasScreen.dispose()` removed the palette-drag, move-drag
   and resize overlays and not this one, the exact bug class the three comments beside them
   were written to prevent. `_cancelPaletteDrag` (the `Esc` path) had the same hole. Note that
   an assertion about the CHIP cannot catch the second one: `Esc` resets the controller, which
   alone makes the builder return an empty box, so the test asserts `find.byType(
   StagingBinOverlay)` is gone, the entry, not merely its output. The first version of that
   test SURVIVED its mutation for precisely that reason and was strengthened.
2. **No `Positioned`.** It was inserted into the root overlay unpositioned, so its `Material`
   stretched to fill the window, a full-screen elevated panel flashing over the app on every
   drag that left the canvas. The two constants meant to place it (`anchorX`/`anchorY`) were
   computed and never used; the analyzer reported both. It is now anchored to the drag cursor,
   below the `_CursorCard`.
3. `Key? key`/`super(key: key)` instead of `super.key`.

### The one test regression, repaired by SCOPING

`rack_canvas_screen_test.dart`'s "the cursor card floats at the pointer before canvas entry"
asserted `find.text('Blank Panel, 1U')` found exactly 2 widgets and found 3, because the new
Staging Bin chip rendered `controller.displayName` a third time. Relaxing the count to 3 would
have "fixed" it while proving strictly less: a bare count says nothing about WHICH widgets carry
the name, and passes just as happily when the cursor card stops showing it and some fourth
surface starts. Each copy the step actually claims is now asserted where it lives (one inside
the palette `ListTile`, one inside the cursor card, located by the new public
`kDragCursorCardKey`) plus the position assertion the test's own name promised and never made.
The Staging Bin chip is asserted separately, in its own file, through
`StagingBinOverlay.chipKey`.

`rackmate_ui.dart` gained export lines for `rack_metrics_row.dart` and
`staging_bin_overlay.dart`; both were previously reachable only by deep-importing
`package:rackmate_ui/src/...`.

### Test counts and mutation testing

| Package | before | after |
|---|---|---|
| `rackmate_core` | 369 | 397 (+27 `derived/totals_test.dart`, +1 `units_test.dart`) |
| `rackmate_ui` | 242 pass / **1 fail** | +27 `rack_metrics_row_test.dart`, +9 `staging_bin_overlay_test.dart`, the failure repaired |

**26 mutations, 26 killed.** Two attempts were invalid rather than surviving and were replaced
(one mutated a `Set` key in a way that still deduplicated; one renamed a constant the test
imports, so it changed nothing). **One test genuinely survived its first pass and was
strengthened**: the `Esc` case in defect 1 above. The mutations that matter most: `ruUsed` →
`ruFree` in the RU chip (the original bug, killed by six assertions); unknown weight rendering
`0` instead of `—`; a superscript on a fully known rollup; VA falling back to `typicalWatts`;
`StagedPlacement` counted as loading a rack; the shelf-host chain not followed; removing the
`_removeStagingBinOverlay()` call from `dispose` and from `_cancelPaletteDrag`; dropping the
chip's `Positioned`; removing the release-refusal status message; and the cursor card losing
either its name or its scoping key.

---

## 3d. The PDF exporter, pass 1 of 2: the sheet frame and furniture (roadmap item 9)

Roadmap item 9 was built in two passes. **Pass 1, described here, is the sheet FRAME and
FURNITURE**: page setup, the scale engine, the border, the title block and the revision block.
**Pass 2 builds the three sheets on top** (`T2.01` front elevation, `T2.02` rear elevation and
`T6.30` equipment list) and has since SHIPPED; see §3e, which also records the two things pass 1
flagged and pass 2 had to act on (the 5.73 pt print-floor breach, and `Stroke.scaleWithGeometry`
having no readers).

### Where the code went, and why not where docs/08 §7.1 says

docs/08 §7.1 puts "sheets, furniture, tables" in `rackmate_export`. **That is unimplementable as
filed**, and the conflict is inside the same document: §5 requires furniture to "render
identically in the on-screen preview", §8.1 note 3 makes the preview the SCREEN backend, and
`rackmate_ui` may not import `rackmate_export` (docs/03 §7.1). Furniture living in the export
package is furniture the preview can never draw.

So **all sheet layout is pure core**, under `rackmate_core/lib/src/draw/sheet/`, and
`rackmate_export` keeps only what genuinely needs `package:pdf`:

| File | Package | Contents |
|---|---|---|
| `units/print_units.dart` | core | `kPdfPointsPerInch`, `pointsForLen`, `kFoot`. Nothing else may hardcode 72 or 126 |
| `draw/sheet/drawing_scale.dart` | core | `SceneFactor`, `PhysicalRatio`, `DrawingScale`, `fitSceneFactor`, the graphic scale bar, the §6.2 legibility check |
| `draw/sheet/sheet_def.dart` | core | `SheetSize`, `SheetRole`, `SheetDef`, `SheetSet` (the dry run), NCS validation |
| `draw/sheet/sheet_frame.dart` | core | `SheetMargins`, `SheetGeometry`, `SheetLayout`, `SheetPalette`, `SheetTextSizes`, the §5.1 border |
| `draw/sheet/title_block.dart` | core | `TitleBlockFields.resolve` + the §5.2 layout |
| `draw/sheet/revision_block.dart` | core | the §5.3 block |
| `draw/sheet/text_fit.dart` | core | measured truncation, optional-fragment joining, the one date format |
| `draw/sheet/sheet_furniture.dart` | core | composes the above into one `DiagramScene` and reports the drawing area |
| `sheets/page_sizes.dart` | export | the ANSI `PdfPageFormat`s `PdfPageFormat` does not ship |
| `sheets/sheet_page.dart` | export | `buildSheetPage`: the one `pw.Page` + `FullPage` + `CustomPaint` wiring |

### The scale property, and the two numbers that are not the same number

CR-007's "1 diagram unit = 1 PDF point" is true at the `DiagramCanvas` boundary and **false of the
rack scene**: `RackGeometry.unitsPerRu` is 22 while one RU is `pointsForLen(kRackUnit) = 126.0` pt
of paper, so `buildRackScene` output arrives already reduced by 22:126. §6.2's `fitScale` therefore
returns a SCENE factor while §5.2's `k` is a PHYSICAL ratio, and they differ by 5.7273x. Feeding one
into the other prints `1:1.4` on a sheet drawn at 1:8. They are now two distinct extension types,
`SceneFactor` and `PhysicalRatio`, and neither is assignable to the other or from a bare `double`.

§5.2's `|k − 1/n| < 2%` is implemented as a **relative** tolerance. The absolute reading is refuted
by the doc's own counter-example: `1/8.34 = 0.11990` against `1/8 = 0.125` is 0.0051 absolute, 
comfortably under 0.02, so an absolute reading would print the `1:8` the same sentence forbids.

The scale is **chosen, not measured**: `elevation_sheet.dart`'s `_fitElevation` takes the largest
scale (smallest `n`) from `{1,2,4,8,10,16,20,24,32,48,64,96}` that fits both axes, so `k` is exactly
`1/n` and the label is true at 0% error. There is exactly ONE such walk, a `chooseDrawingScale`
helper in `drawing_scale.dart` did the same thing against a FIXED content box, had no production
caller (an elevation's content changes with the candidate ratio, because annotation is inflated as
the drawing shrinks), and was deleted along with the seven tests that guarded it, two of which
asserted a fit the shipped path does not produce. The 2% predicate survives as a guard that forces `NTS` if anything upstream
ever hands the block a non-standard ratio. **Note on the stage brief's wording:** it said "the
largest `n` … for which the elevation fits", which under monotonicity is always 96 (the tiniest
drawing); the intended and implemented reading is the largest SCALE.

### What is DEFERRED, and why: stated, not silently dropped

- **The three sheets themselves** (`T2.01`, `T2.02`, `T6.30`), pass 2.
- **The zone grid (§5.1).** Its only v1 consumer is the schedule's `REF` column, which needs
  `Link`s, which do not exist until M2. The 0.22 in zone band is not drawn, and the gap between the
  outer and inner rules is §3.2's 6 pt, the figure that reproduces the doc's own stated usable
  widths (510 portrait / 690 landscape). §5.1 and §3.2 disagree on this; §3.2's arithmetic wins.
- **Revision clouds and the revision triangle (§5.3, DR-005).** A cloud encircles "each element
  changed since the last issued revision". `RevisionEntry` EXISTS
  (`model/rack_document.dart`, round-trips through `json_codec.dart`) but **no generator does**:
  a repo-wide search finds no writer outside the codec and the starter-authoring tool. With no
  history there is no such set. **This is a stated DR-005 deviation.** The exporter renders whatever
  real entries exist and, when there are none, the normal case in this build, prints one row
  reading `NO REVISIONS RECORDED`. It never fabricates an entry and never falls back to
  `RackDocument.sequence`, which is the sync cursor (CR-094); a test asserts that against the source.
- **The symbol-legend cross-reference** (`SYMBOL LEGEND: SEE SHEET …`). `T0.01` is not in this
  sheet set, and pointing a reader at a sheet the file does not contain is exactly what T0.00's own
  drawing-index rule forbids. The line is omitted rather than pointed at nothing. For the same
  reason the revision overflow line reads `+n EARLIER REVISIONS — SEE PROJECT FILE` instead of
  §5.3's `SEE SHEET T0.00 FOR FULL REVISION HISTORY`.
- **The revision block on ANSI A.** §5.2 makes the ANSI A title block a full-width strip
  specifically "so the schedule table is not notched"; stacking an eight-row revision grid above it
  would notch the table by 130 pt and undo that. The compact strip carries the REV field but not the
  history table. A **stated §5.3 deviation**.
- **`TilingStrategy.geometric`** (§6.2). Every legal rack (`heightU ≤ 60`, CR-038) fits ANSI B
  portrait at 1:8, asserted at the 60 U worst case, so the case is unreachable in v1. The
  legibility check is implemented and reports; the tiler is not built.
- **`PageTheme(buildBackground:)`.** §5 specifies attaching furniture through it, with a VERIFY on
  the parameter names. **VERIFIED present on pdf 3.13.0** (`page_theme.dart`, `BuildCallback?`), and
  `Page.postProcess` does paint them, the doc's mechanism works. It is deliberately **not used**:
  furniture and content compose into ONE `DiagramScene` before the page exists, which satisfies §5's
  two actual requirements (every page, identical in preview) more strongly, because the preview can
  replay the identical pure-core object and one scene means one coordinate origin rather than two
  chances to get §7.4's `boxHeight` gotcha wrong.
- **File-level PDF determinism** (§8.4). **Impossible on the pinned pdf 3.13.0**:
  `PdfDocument.documentID` is `sha256(DateTime.now() + Random.secure())` and lands in the trailer
  `/ID`, and `PdfInfo` hardcodes `/CreationDate: DateTime.now()`. Neither is injectable. The
  determinism gate is therefore scoped to CONTENT STREAMS and says so, and a test asserts that two
  renders are byte-identical in their content stream AND *not* byte-identical as files, so the
  limitation stays visible rather than remembered.
- **No golden PDF is committed.** Bytes vary with the pdf package version and with the two
  non-deterministic fields above, and `.gitattributes` marks `.pdf` binary. Assertions are on
  recovered content-stream operators instead, which also keeps them readable in a diff.

### Multi-rack sheet numbering, and the counter that would have shipped

"Three-sheet PDF" in the exit criterion is the ONE-RACK case; with N racks the set is `2N + 1`. A
running counter incremented during rendering is right for one rack and wrong for two, and the exit
criterion only exercises one. So `SheetSet.forRacks` is a **dry run** that resolves every `SheetDef`
with `index`/`total` already baked in, before anything is rendered. §2.2 names `T2.01`/`T2.02` for
the single-rack case; with N racks the sequence continues within sheet type 2 (rack `i` gets
`T2.{2i+1}`/`T2.{2i+2}`), so one rack reproduces the doc exactly and two racks produce `T2.01`–`T2.04`
rather than a collision. Above 49 racks the sequence stops matching the NCS pattern; that is a
NOTICE, never a gate (CR-023, G3).

### A real finding the legibility check surfaced

`RackTextSizes.type` is 8 diagram units. At 1:8 that is **5.73 pt on paper: below §6.2's 6.0 pt
hard floor**. This is asserted as a live fact about the current rack scene, not a hypothesis, and it
is the argument for giving the elevation sheets a print type scale in pass 2 (annotation on a scaled
drawing is never at model scale). Sheet furniture is unaffected: it is drawn at 1:1 and every one of
its declared sizes is at or above 6.0 pt, asserted mechanically over `SheetTextSizes.all`.

**ACTED ON IN PASS 2:** `RackTypeScale` inflates every rack label so the smallest lands at exactly
6.5 pt of paper, and the elevation sheet asserts `scene.minTextSizePt × sceneFactor` equals that,
which is what turns §6.2's legibility check from decorative into a check. See §3e.

### Test counts and mutation testing

| Package | before | after |
|---|---|---|
| `rackmate_core` | 530 | **683** (+10 `print_units_test.dart`, +143 under `test/sheet/`) |
| `rackmate_export` | 7 | **47** (+18 `content_stream_harness_test.dart`, +6 `page_sizes_test.dart`, +16 `sheet_furniture_pdf_test.dart`) |
| `rackmate_ui` | 341 | 341 (unchanged) |
| `apps/rackmate` | 624 | 624 (unchanged) |

`flutter analyze` holds at 203 style infos, zero errors, zero warnings. `flutter build windows`
succeeds.

**26 mutations run, 26 killed: but three did not land on the first attempt and two of those were
real holes rather than bad mutations.** Reported in full because the pattern matters:

1. **A genuine surviving test.** Making the title block emit blank rows for an absent address and
   client line, the exact thing §5.2's "empty optional lines collapse" forbids, **passed the whole
   suite**. The "no empty text op is emitted" assertion could not see it, because a blank ROW emits
   nothing at all rather than emitting an empty string. Fixed by asserting the collapse
   **geometrically**: the identity band's text rows must be evenly pitched, since a collapsed line
   that left a hole shows up as a double gap. The mutation now dies.
2. **A mutation that was too weak, hiding a real gap in the test harness.** The content-stream
   CTM interpreter is what every PDF geometry assertion stands on. Swapping one term of its matrix
   composition survived, because every matrix in its self-test was diagonal-plus-translation, for
   which several wrong compositions agree. Fixed by adding a 45°-inside-90° rotation case and a
   translate-inside-rotation case; **each of the six matrix terms was then dropped in turn and all
   six mutations died.**
3. One mutation mistargeted a comment string and was re-run corrected (the §7.4 `boxHeight` gotcha, 
   flipping about the wrong height now fails six assertions).

The mutations that matter most: `pointsForLen`'s 72 → 71; the scene factor × 1.01;
`unitsPerRu` 22 → 23; the 2% tolerance read as absolute instead of relative (this is §5.2's exact
prohibition, and it kills the 1:8.34 → `NTS` case); the scale chooser walking denominators
descending; the SCALE field hardcoded to `1:8` while drawn at 1:8.34; the binding margin 54 → 36;
the title block moved to the top of the frame; measured truncation removed; a revision fabricated
when there is no history; revision rows stacked downward; the overflow line pointing at the absent
`T0.00`; `SHEET i OF n` using a fixed 3 instead of the resolved total; `DateTime.now()` replacing the
injected clock; the page flipped about the wrong height; the ANSI B page format 1224 → 1234; and
the furniture stroke losing `hairlineFloor`.

### The API pass 2 consumes

```dart
final layout    = sheetLayoutFor(sheet, doc.revisionBlock);   // drawing area, no scale needed
final area      = elevationAreaOf(layout.drawingArea);         // less the two bands
final scale     = /* the fit: rebuild the scene per candidate ratio and measure what it
                     would EMIT — see elevation_sheet.dart's `_fitElevation` */;
final furniture = buildSheetFurniture(sheet: …, scale: scale, issuedAt: …, measurer: …);
final ops       = [...furniture.ops, /* content, bracketed by OpSave/OpTransform/OpRestore */];
doc.addPage(buildSheetPage(size: sheet.size, scene: scene, fonts: fonts, measurer: measurer));
```

The two-step dance is what keeps the dependency acyclic: the drawing area depends on the revision
count but not on the scale, while the title block's SCALE field depends on the scale, which depends
on the drawing area. `buildSheetFurniture` re-resolves the identical layout from the same inputs, and
a test asserts the two agree.

---

## 3e. The PDF exporter, pass 2 of 2: the three sheets (roadmap item 9, and item 3's mirroring)

Pass 1 built the sheet FRAME. Pass 2 builds what goes on it: `T2.01` front elevation, `T2.02` rear
elevation and `T6.30` equipment list, plus `File ▸ Export PDF…`. Roadmap item 9 is now **Done**, and
so is item 3's long-outstanding **per-rack rear mirroring**, which landed here because it belongs in
core where both backends get it.

### The elevations are the EXISTING scene, scaled. There is no second renderer

`T2.01`/`T2.02` call `buildRackScene` (the same function `RackCanvasScreen` calls, with the same
layers, the same `RackGeometry` and the same injected `TextMeasurer`) and splice the returned ops
into the sheet inside ONE `OpSave` / `OpTransform(translate · scale)` / `OpRestore` bracket. That is
the identical idiom `scene_builder.dart` already uses per device fragment, and
`elevation_sheet_test.dart` asserts it by IDENTITY: the spliced ops are the same objects, in order,
so a future "just rebuild it here" cannot pass.

The scale is an `OpTransform` INSIDE the scene rather than a canvas call in the exporter. That keeps
the whole sheet one replayable `DiagramScene`, so `BoundsCanvas`, the future on-screen sheet preview
and every op-level test see the identical composition, and `rackmate_export` contributes exactly
zero geometry.

### Where the code went

| File | Package | Contents |
|---|---|---|
| `derived/device_loads.dart` | core | `resolveDeviceLoads`, `hostRackOf`/`belongsToRack`, `occupancyU`, `templateKeyFor`, EXTRACTED from `totals.dart`, which now calls them |
| `derived/equipment_list.dart` | core | `buildEquipmentList` → deterministic groups, one row per device |
| `draw/scene/rack_load_gutter.dart` | core | cumulative mass bottom-up, rack draw, BTU/hr |
| `draw/sheet/elevation_sheet.dart` | core | `T2.01`/`T2.02` composition, the fit search, the graphic scale bar |
| `draw/sheet/equipment_sheet.dart` | core | `T6.30` columns, §3.7 pagination, measured wrapping |
| `document/export_request.dart` | export | the isolate-ready request and the typed refusals |
| `document/build_document.dart` | export | `buildExportDocument` → `Outcome<ExportedDocument>` |
| `session/export_controller.dart` | app | `File ▸ Export PDF…` over the shipped save surface |

### THE HORIZONTAL AXIS WAS 11% WRONG, AND IT IS FIXED IN CORE

`RackGeometry.railWidth` was 20 diagram units of declared "legibility chrome", following docs/04
§2.1's "20 px each at z1.0". The RU ruler is chrome too and that is harmless; it sits OUTSIDE the
mounting panel. **A rail is not**: it sits INSIDE the 19 in panel, so `openingWidth`, and with it
every full-width device body, was derived from it. At 22 units per RU, 20 units is 1.59 in, so the
drawn clear opening was 19 − 2 × 1.59 = **15.82 in against a real EIA-19 opening of 17.75 in**. The
vertical axis and the overall panel width were exact; every device was 11% narrow.

`railWidth` is now `unitsForLen(Len(15_875_000))`, the real 0.625 in flange, so 19 − 2 × 0.625 =
17.75 in FALLS OUT of `openingWidth` rather than being asserted separately.

**This is a stated deviation from docs/04 §2.1's "20 px".** Rails render ≈7.86 units wide at zoom
1.0 instead of 20, visibly thinner on screen, and proportionally correct, since a real flange is
3.3% of the panel width and 20 units was 8.4%. **Not one pre-existing `rackmate_ui` or app test
needed editing**: every one of them references the geometry symbolically (`RackGeometry.rulerWidth`,
`geo.deviceRect(...)`) rather than numerically, which is what made a real physical correction cheap.

The core-side proof is `rack_geometry_physical_test.dart`, added because a mutation said so:
reverting `railWidth` to 20 is caught by the PDF tape-measure gate and by **nothing** in
`rackmate_core` or `rackmate_ui`. The physical property belongs to `rack_geometry.dart`, so it now
has an assertion that does not need a PDF to state it.

### Rear mirroring (roadmap item 3, CR-035)

`RackGeometry.deviceRect` gained `mirrored`, which reflects the lateral span about the opening
centre, `12 − startTwelfth − spanTwelfths`. `buildRackScene` reads `rack.mirrorRearElevation`
directly (it is a per-rack property with a `SetRackPropertyCommand` behind it; a parameter would be
a second answer to a question the model already answers) and applies it on `Face.rear`.

It is a LAYOUT reflection, never a canvas `scale(-1, 1)`; that would mirror every designator, name
and model string on the sheet. `rack_mirror_test.dart` asserts that against the composed scene's
actual transforms: no `OpTransform` in a rear scene carries a negative X scale or a negative
determinant, and every device bracket is a pure translation.

A full-width device (start 0, span 12) is unchanged by mirroring, which is why the on-screen rear
elevation moved for nobody in the existing suites. `T2.02` carries a chip either way, 
`REAR VIEW — MIRRORED` or `NOT MIRRORED`, because a reader cannot tell the two conventions apart
by looking, and "no chip" is not a convention anyone can look up.

### The scale is chosen against the content that is ACTUALLY drawn

There is a genuine circularity: the scale depends on the ink extent, the ink extent depends on the
text sizes, and the text sizes depend on the scale, because annotation on a scaled drawing is never
at model scale. Pass 1 surfaced the concrete fact: `RackTextSizes.type` is 8 units, which at 1:8 is
**5.73 pt on paper, under §6.2's 6.0 pt hard floor**.

`RackTypeScale` (in `rack_style.dart`, a sibling of `RackPalette` so no new branching concept)
inflates every rack label so the SMALLEST one lands at exactly 6.5 pt of paper. `buildElevationSheet`
then walks the standard denominators from the largest scale down and, for EACH candidate, builds the
scene it would actually draw, inflated text and all, keeping the first that fits both axes. The
reported ratio is therefore exactly `1/n` for the thing on the paper, at 0% error. At most twelve
scene builds; in practice two or three.

`elevation_sheet_test.dart` asserts every legal rack height 1..60 U (CR-038) lands on a STANDARD
ratio, which is the claim `TilingStrategy.geometric`'s omission rests on. The tallest, 60 U, needs
**1:10**, not 1:8: 105 in at 1:8 is 945 pt against a 909 pt drawing area.

### T6.30, and why it is not a `pw.Table`

Drawn entirely through `DiagramCanvas` ops with the pagination computed in core from the shared
measurer. A `pw.Table` would be laid out by dart_pdf's own text engine, not the engine the preview
uses, so the schedule would break lines, truncate cells and paginate DIFFERENTLY in preview and
print, which is the divergence CR-081 and CR-086 exist to make impossible. It also disposes of
§3.7's three VERIFY items (`Table.headerCount`, `MultiPage` overflow, `maxPages`) because the pages
are hand-cut and each is a plain `pw.Page`.

Thirteen columns exactly as §2.2 names them, summing to the ANSI A landscape usable width, asserted
against `frameBox.width` rather than against a repeated literal. **No pricing** (AC-055): no `Money`,
no cost, no supplier, no purchaseOrder, and the word BOM appears nowhere.

**One row per device instance; QTY is always 1.** The identical-device collapse is DELIBERATELY not
built: the exit criterion is "the equipment list matches the rack contents EXACTLY", which is a
bijection claim, and a quantity rollup is precisely the transform that would make an off-by-one
invisible to both the reader and the test. The column ships carrying 1; the collapse is deferred.

**Nothing is silently dropped.** Every `DeviceInstance` lands in exactly one group, including a
device whose rail placement names a rack the document does not hold, which goes to the trailing
`NOT IN A RACK` group rather than vanishing.

### Multi-page schedules, and the counter that would have shipped

`SheetSet.forRacks` gained `equipmentListSheets`. The order is forced: build the equipment list →
PAGINATE it (pure core, no PDF) → resolve the sheet set from `(racks, page count)` → render. A
running counter incremented during rendering is right for a one-rack, one-page project and wrong for
`whole_house`, whose 48 devices need `T6.30` **and** `T6.31`. Continuation pages take `T6.31`,
`T6.32`, … which stay inside sheet type 6 and still satisfy the NCS pattern.

### One resolver, four consumers

`resolveDeviceLoads` and `hostRackOf` were EXTRACTED from `totals.dart`, which now calls them,
so the chip strip, the elevation's load gutter, T6.30's rows and T6.30's subtotals read the same
numbers through the same code. `starters_export_test.dart` asserts the schedule's per-rack subtotal
equals `computeRackRollups`' figure on the same inputs, and `rack_load_gutter_test.dart` asserts the
gutter's topmost cumulative reading does too. A second weight-resolution path is exactly the drift
this codebase keeps shipping.

BTU/hr is `btuPerHourOverride ?? wattsToBtuPerHour(typicalWatts)` and is NULL when `typicalWatts` is
null, never synthesised from `apparentVA` (a power factor nobody authored) or `nameplateWatts`
(AC-039's explicitly rejected behaviour). Both have their own tests.

### `Stroke.scaleWithGeometry` had ZERO readers, and this stage is the first caller that could tell

CR-082 declares two independent knobs: `scaleWithGeometry` ("cable traces, symbol outlines and rack
rails scale with the diagram; UI chrome does not") and `hairlineFloor` ("sheet furniture uses a
0.25 pt print floor; everything else 0.5 pt"). **Both backends branched on `hairlineFloor` alone for
both decisions**, so `scaleWithGeometry` had no readers anywhere in the repository, a production
field whose only appearance was its own declaration. It was invisible because no caller had ever
applied a scale != 1; the elevation sheets are the first.

The width decision now reads `scaleWithGeometry` and the floor decision reads `hairlineFloor`, on
BOTH backends. At k == 1 the two spellings are identical, so nothing on screen or on an existing
sheet moved. `sheetRule` sets `scaleWithGeometry: false` explicitly. Two test files, 
`rackmate_export/test/stroke_scaling_test.dart` and `rackmate_ui/test/stroke_scaling_test.dart`,
assert it at k = 126/(22·8), and a mutation confirmed the second one was needed: fixing only the PDF
backend passed the entire `rackmate_ui` suite.

### The export UX

`File ▸ Export PDF…` reuses the shipped save surface exactly: `picker.pickSave` →
`SavePaths.forTarget(…, extension: '.pdf')` → `AtomicWriter.write(keepBackup: false)` →
`describeSaveError` + `SessionPrompts.showFileError`. That inherits the whole enumerated failure
surface for free, including `SaveLocked`, AC-058/D4's "the target PDF is open in Acrobat".
`keepBackup: false` because a PDF is a regenerable deliverable, not the project.

`SavePaths.forTarget` gained an `extension` parameter rather than the export growing its own
normalisation, so "append unless it is already there, compared case-insensitively" stays in one
asserted call site.

**Never silently do nothing:** a cancelled picker reports `Export cancelled.`; a document with no
racks is refused OUT LOUD **before** the dialog rather than producing a one-sheet PDF of nothing;
success reports `Exported 3 sheets · 214 KB`, with the notice count appended when §6.2's legibility
check or the NCS validation had anything to say. Notices are reported and NEVER gate (CR-023, G3).

**No new keybinding.** docs/08 §8.1 gives export `Ctrl+P`, and `session_layering_test.dart` RULE 14
asserts exactly four bindings and eight activators precisely so the file group cannot grow a fifth
member without that decision being re-taken. The menu item carries no `shortcut:`, which also stops
it advertising a key nothing listens for, and a widget test asserts `item.shortcut` is null.

### What is DEFERRED, and why: stated, not silently dropped

- **Every other sheet in §2.2's table**: `T0.00` cover, `T0.01` legend, `T0.02` exceptions,
  `T6.01+` interconnect, `T6.10` pull sheet, `T6.11` termination schedule, `T6.20` unused home runs,
  `T5.01` pinout details. M6, and most need `Link`s, which arrive in M2.
- **Everything on an in-scope sheet that needs `Link`/`Service`/`Conductor` data**: per-port labels
  and connector fields on `T2.02`, the cable-footage rollup with waste factor, the jumper/power-cord
  rollup and the PDU outlet map on `T6.30`. Omitted WHOLE rather than printed empty, and because
  each absence changes what the sheet promises, it is stated ON THE SHEET:
  `REAR FACES SHOWN. PORT AND CONNECTION DETAIL NOT ISSUED IN THIS SET.` and
  `EQUIPMENT ONLY. CABLE AND POWER SCHEDULES NOT ISSUED IN THIS SET.`
- **Revision clouds and the revision triangle** (§5.3, DR-005), unchanged from pass 1: no
  `RevisionEntry` generator exists, so there is no "changed since the last issued revision" set.
- **The zone grid** (§5.1), its only v1 consumer is the schedule's `REF` column, which needs
  `Link`s.
- **Identical-device QTY collapse on T6.30**: see above; it would hide an off-by-one from the exit
  criterion's own bijection test.
- **`TilingStrategy.geometric`** (§6.2), every legal rack (1..60 U) fits ANSI B portrait on a
  standard ratio, asserted over all sixty. The legibility check is implemented and reports; the
  tiler is not built.
- **`Isolate.spawn` export with progress and cancel** (§8.2). `buildExportDocument` already takes
  only bytes and an injected `DateTime`, so it is isolate-ready; three sheets sit far under §8.2's
  own 400 ms "do not show progress" threshold, so M1 calls it synchronously on the main isolate.
- **The `Ctrl+P` export dialog** (§8.1), presets, sheet checklist, palette, live preview pane. One
  File menu entry ships. Greyscale/CMYK palettes, the `ISSUED FOR CONSTRUCTION` stamp and "embed
  .rackmate source" are `ExportSpec` options that belong with that dialog.
- **printing/pdfium preview and the OS print dialog** (docs/03 §10.1, vendored binaries). Export to
  file only; the `printing` package is not added. "Open in system viewer" is not built either.
- **CSV exports** (§9).
- **File-level PDF determinism**: impossible on pdf 3.13.0, unchanged from pass 1. The gate is
  scoped to CONTENT STREAMS and says so, and a test asserts two exports are NOT byte-identical as
  files so the limit stays visible.
- **The hatch band keys on `TemplateBody.category == kCatPassive`**, which is a free-form `String`.
  Correct for the seeded catalog, which puts exactly blanks, vents and shelves there. A
  user-authored blank panel filed under another category simply does not hatch, graceful
  degradation rather than a guess, but a **silent partial behaviour**, recorded here rather than
  discovered later.
- **`RackGeometry.rulerWidth` is still 28 fixed units.** It is annotation OUTSIDE the panel, so
  nothing scalable depends on it, and the elevation says so on the sheet:
  `SCALE APPLIES TO THE MOUNTING PANEL. RULER AND GUTTER ARE ANNOTATION.` The graphic scale bar,
  exactly one foot of reality long, is what a reader measures against.

### Test counts

| Package | pass 1 | pass 2 |
|---|---|---|
| `rackmate_core` | 683 | **810** |
| `rackmate_export` | 47 | **125** |
| `rackmate_ui` | 341 | **348** |
| `apps/rackmate` | 624 | **648** |

`flutter analyze`: **204 style infos, ZERO errors, ZERO warnings** (baseline 203; the one addition is
a wrapped-line info in a new test). `flutter build windows` succeeds. All four starter projects
export end to end.

### THE GATE: how "dimensionally correct against a tape measure" is proved without a printer

`rackmate_export/test/elevation_true_scale_test.dart` runs the REAL export entry, recovers the
emitted page's operator stream, walks the actual `q`/`Q`/`cm` operators into **PDF USER SPACE
POINTS**, and asserts:

- the chassis frame is `45 × 44_450_000 × 72 / 25_400_000 / n` tall;
- the mounting panel is `482_600_000 × 72 / 25_400_000 / n` wide (EIA-19);
- **a full-width device body is `450_850_000 × 72 / 25_400_000 / n`: the 17.75 in clear opening**;
- two 1 U devices 44 U apart are separated by exactly 44 U of pitch, and each is 1 U tall;
- **the frame is 9.84375 in of paper at 1:8**, written as a literal so a reviewer can check it
  against a ruler by hand, and independently reproducing docs/08 §6.1's own "9.84 in";
- the graphic scale bar is exactly `12 × 72 / n` pt;
- the rack's bottom edge sits at a user-space Y derived from `1224 / 36 / 6 / 115 / 26 / 34` alone.

Three deliberate defences against the assertion being unfalsifiable:

1. **It asserts on the emitted BYTES**, not on the calculator.
2. **`n` is read back out of the sheet's own SCALE field**, in the same PDF. The number a human
   would scale off the paper is the number the test converts with, so drawing at 1:8.34 while
   printing "1:8" fails, which is §5.2's exact prohibition.
3. **Every expectation is computed from literals**: `44_450_000`, `25_400_000`, `72.0`,
   `482_600_000`, `450_850_000`. Nothing reads `unitsPerRu`, `pointsForLen` or `sceneFactor`.

Plus `content_stream_harness_test.dart`, which proves the CTM interpreter itself against hand-written
streams, without it, a harness that silently found zero shapes would make every assertion above
vacuously true. It gained a general PATH recovery this pass, because a device block at
`LodLevel.full` is a `drawRRect` and emits no `re` at all: a `re`-only harness would have found ZERO
device blocks and the width/pitch/height assertions would all have passed on nothing.

**On the tolerance.** `PdfNum.precision` is a compile-time `const int = 5` in pdf 3.13.0, so every
number dart_pdf writes is `toStringAsFixed(5)`. At 1:8 the scene factor 0.715909090… reaches the page
as `0.71591`, which over a 45 U rack accumulates to 9e-4 pt. The tolerance is 0.01 pt (set from that
bound, not tuned) and the test asserts that 0.01 pt is finer than a 600 dpi printer's own dot, so
the slack is checked rather than claimed.

### Mutation testing: 47 run, 47 killed: but SEVEN survived their first pass

Reported in full, because the pattern is the point.

**Six were real holes and are now fixed:**

1. **Substituting `Mass.zero` for an unknown mass passed the entire export suite.** The starters test
   compared the em-dashed cell count against `Rollup.unknownCount`, two numbers that BOTH come out
   of `resolveDeviceLoads`, so the mutation moved both to zero and they still matched. Exactly the
   self-referential shape this project keeps shipping. The expectation is now computed from the RAW
   DOCUMENT (a mass is unknown iff neither the override nor the template body states one), and a
   separate test asserts the unknown path is genuinely exercised, otherwise two zeroes would compare
   equal again.
2. **Paginating one row short survived.** "No row is lost" and "every page fits" are both true of a
   paginator that puts one row per page. Added: every page but the last must be FULL, i.e. the next
   item genuinely does not fit.
3. **Reverting `scaleWithGeometry` on the FLUTTER backend survived.** The fix was asserted on one of
   two backends. `rackmate_ui/test/stroke_scaling_test.dart` is the other half.
4. **`DateTime.now()` inside `buildExportDocument` survived.** Pass 1 proved the injected clock on a
   furniture-only render it assembled itself; nothing asserted the date on a sheet that came out of
   the real entry point, so §8.4's "no `DateTime.now()` outside the one date field" was held by a
   comment. `export_determinism_test.dart` now asserts the injected date reaches EVERY sheet, that
   today's date appears nowhere, and that dates one day apart still differ.
5. **Removing the designator fit guard survived**, and so did the missing-font refusal and the
   rackless refusal at the export entry, three production branches nothing read.
6. **`keepBackup: true` survived**, because the test exported ONCE to a fresh path and
   `AtomicWriter` only attempts a backup when the target already exists. Moved to the OVERWRITE
   case, which is the only one that exercises step 4 at all.

**One survivor is NOT a hole, and is reported as a finding.** Changing `RackGeometry.unitsPerRu`
from 22 to 23 leaves the export suite green. That is correct and designed: `unitsPerRu` is an
arbitrary internal anchor, everything length-based derives from it through `_unitsPerNm`, and
`sceneFactorForRatio` divides by it, so the PHYSICAL result is invariant, which is precisely what
`rack_geometry.dart`'s "derive it, do not hardcode a second unrelated constant" note promises. The
core suite kills it (it asserts the anchor itself), so the mutation dies against the suite as a
whole; it dies for the right reason in the right place.

The mutations that matter most, all killed: the scene factor × 1.01; `pointsForLen`'s 72 → 71; the
SCALE field printing `1:4` on a 1:8 sheet; `openingWidth = panelWidth` (the rail-width regression);
`railWidth` back to 20; the rail flange off by 18 microns; the elevation shifted by one band,
which fails the absolute-placement assertion alone while every size and spacing assertion passes,
proving that assertion earns its place; `deviceRect` ignoring `mirrored`; `buildRackScene` never
mirroring; the equipment list losing one row per group; rows sorted RU-ascending; unplaced devices
dropped; the shelf chain no longer resolving to a rack; BTU derived from `nameplateWatts`; the 2%
tolerance read as absolute; `SHEET i OF n` hardcoded to 3; the sheet set ignoring the real schedule
page count; the continuation band dropped; the schedule claiming `1:1`; a revision fabricated when
there is none; the cumulative readings failing to accumulate; off-axis devices silently dropped; the
load gutter dropped from the scene entirely; an unknown DRAW or MASS printing `0`; the cancelled
export going silent; the rackless document not being refused; the `.pdf` extension normalisation
dropped; the export inventing its own error surface; the filename losing its revision; and, on the
test harness itself, dropping curve control points, counting a clip as ink, and failing to inflate
a compressed stream.

---

## 3f. The PDF exporter, pass 3: the rear elevation was blank, and the sheet said otherwise

Four defects found by MEASURING emitted PDF content streams rather than by reading code. Two of
them were regressions introduced by pass 2's own fixes.

### The rear elevation drew nothing on every shipped starter (scene_builder.dart)

Measured off `whole_house.rackmate` through the real `buildExportDocument`: `T2.01` carried 27
device designators as ink and `T2.02` carried **zero** (68 recovered paths, all frame and RU
ruler) while both sheets printed the identical band claiming only `NOT DRAWN 4 OF 31 DEVICES`.
One of the three sheets the M1 exit criterion names was an empty 42U frame stating a count that
contradicted its own contents.

The model disagreed with the picture: 19 of RK-1's 27 rail devices resolve to templates with
`rearU > 0` and `side: both`. `_visibleDevices` dropped them on `placement.face != face`, the
face a device is BOLTED TO, while docs/04 §2.2 is explicit that the face control "selects a
coordinate, not a filter" and that occupancy (CR-036) is what decides: "a 2U patch panel with
`{frontU: 2, rearU: 2}` renders on both faces and a rear lace bar renders only on rear".

So `elevationOccupancyU(device, body, face)` now takes the SHEET's face, `_visibleDevices` filters
on it, and a device's rear block is bottom-anchored at the same `ruIndex` its front block is and
spans `rearU` (a derivation, not a stored fact, CR-006). **This changes the on-screen rear view
too**, deliberately: the screen and the sheet share one builder (CR-086) and two spellings of "what
is on this face" is the drift this stage keeps paying for. `whole_house` T2.02 now carries 19
designators and 106 paths.

`RackLoadProfile` gained `undrawnFrontCount`/`undrawnRearCount` and `undrawnOn(face)`, and the
gutter's boundary arithmetic moved from `occupancyU(body, rail.face)` to `stackOccupancyU(body)`
(the taller of the two faces), otherwise a rear lacing bar screwed to the front rails has "no
knowable position" in the gutter while T2.02 draws it at its stated RU.

### The omission sentence is now per-face, and names where the missing ones ARE

Pass 2 made the count deliberately face-INDEPENDENT ("drawn on NEITHER elevation") to avoid crying
wolf on T2.02 about front-rail devices. That reasoning is right about crying wolf and wrong about
the primary duty: **a sheet must never state a count that contradicts what it visibly contains.**

`rackLoadSummaryLines(profile, units, face)` now prints, e.g. on `whole_house` T2.02:

    NOT DRAWN HERE  12 OF 31, 8 ON FRONT, 4 ONLY ON T6.30; 4 COUNTED AT TOP

, the count for THIS sheet, split into the part the opposite elevation draws and the part no
elevation draws, so nobody is sent hunting for a row that is one sheet away. Still ONE line: the
note band is a hard five (`kElevationHeaderBand` = 56 pt) and the other four are the load figures.
Every clause is abbreviated against the 337 pt half-band, measured with the real font in
`elevation_omission_line_test.dart` rather than argued in a comment.

### Every device label vanished on a legal rack (device_layer.dart)

Pass 2's new vertical-fit guard, `_pad + designatorPt <= height - _pad`, suppressed the ENTIRE
label branch (designator, RU-span badge, name and type) for every 1U device on any elevation
drawn at 1:10 or smaller. A 58–60U rack is legal (`kMaxRackHeightU` = 60, CR-038) and reachable
from the header stepper and the inspector; `_fitElevation` picks 1:10 at `heightU >= 58`, where the
inflated designator is 15.61 units against a 22-unit body. So a user could build a legal rack,
export, and get elevations on which no block carried the one string that joins it to its T6.30 row,
with nothing in the export summary saying so (`scale.notice` and `fit.notice` were both null, and
the legibility check STRUCTURALLY cannot see a blackout: a fragment that emits no text contributes
`double.infinity` to `minTextSizePt`, so it can only ever raise the reported minimum).

The guard is now a LADDER, type, then name, then the designator + badge line last, with its
vertical pad shrinking to zero before the line is given up. The glyphs fit a 1U body at 1:10; only
the 8 units of padding did not. When the glyphs genuinely are taller than the block,
`DeviceLayerBuild.labelDropped` carries it out through `RackScene.unlabelledDeviceIds` and
`ElevationLabels` to BOTH a note on the sheet (`n OF m BLOCKS TOO SHORT TO LABEL AT THIS SCALE —
SEE T6.30.`) and a line in the export summary. A notice, never a gate (CR-023, G3).

### The schematic header rule's meaning had been inverted (symbol_layer.dart)

Pass 2's parallel `_applyStroke`/`_strokePaint` rewrite changed
`w = hairlineFloor ? widthPt / k : widthPt` to `w = scaleWithGeometry ? widthPt : widthPt / k`.
The two agree everywhere EXCEPT the one production `Stroke` where the flags disagree, the
schematic header rule, which sets `hairlineFloor: true` and inherited `scaleWithGeometry: true`,
so it moved from pixel-constant to geometry-scaled.

**The scaled reading is correct** and is now stated explicitly. CR-082, verbatim: "Cable traces,
SYMBOL OUTLINES and rack rails scale". The rule is drawn in the symbol's local coordinates one op
after the body outline that has always scaled; `hairlineFloor` is kept for what it now means alone
(this rule may print finer than the 0.5 pt signal floor). The two flags stay independently
MEANINGFUL and stop being independently SETTABLE by accident: `draw_source_gate_test.dart` requires
every production `Stroke` naming one to name the other, across all three packages.

### Numbers that join the sheets, now pinned where they are EMITTED

Each of these survived both suites under mutation before this pass:

| Mutation | Now killed by |
|---|---|
| `offAxisCount` substituted for the undrawn count in the omission sentence | `rack_load_gutter_test` (a shelf-hosted + rear-only fixture separates all five counts) and `elevation_omission_line_test` against emitted ink |
| off-by-one in T6.30's `RK-1 SUBTOTAL n DEVICES` | `equipment_sheet_test` (compared against `contributingCount`, the elevations' own denominator) and `starters_export_test` (8) |
| `(n unknown)` dropped from `formatIntRollup` (VA) / `formatBtuRollup` (BTU/hr) | `elevation_sheet_test` and `elevation_omission_line_test`, with the three counts made DISTINCT and derived from authored template fields, never from a `Rollup` |
| `RackSceneOptions.forPrint` reverting to discard the receiver | `scene_builder_test` (`copyWith` carries every field) + `draw_source_gate_test` (`forPrint` delegates to `copyWith` on `this`), no behavioural test can see it while `forPrint` happens to force all seven fields |

---

## 3g. The PDF exporter, pass 4: the other two callers of "what is on this face"

Pass 3 fixed `_visibleDevices` and stopped there. The same question is asked at three places, and
the other two were still answering it the old way, so on one screen the canvas and the chip
strip above it disagreed, and on the same screen the drop evaluator disagreed with both.

### One question, one predicate: `elevationOccupancyU`

`derived/device_loads.dart`'s `elevationOccupancyU(device, body, face)` is now THE answer to *"does
this device occupy U on this face, and how many"*, and it has four readers:

| Reader | What it does with it |
|---|---|
| `draw/scene/scene_builder.dart` | draws the canvas and T2.01/T2.02 (pass 3) |
| `draw/scene/rack_load_gutter.dart` | counts what it EXCLUDES, so the sheet can say how many |
| `derived/totals.dart` | the chip strip's per-face RU |
| `commands/catalog_placement.dart` | `elevationOccupantsOnFace` → `findLowestFreeRu` / `findBlockingOccupant` |

**The chip strip contradicted the canvas beneath it.** `computeRackRollups` still counted RU only
for devices whose `placement.face` equalled the requested face. Measured in the real widget tree
(`RackCanvasScreen` with `whole_house` at 1600×1200): `RU rear 0/42` above **19 rendered
`RenderDeviceBox`es covering 28 distinct rear U**. `rack_metrics_row_test` now recovers the U
actually covered by the boxes on screen (from their laid-out rects, through `RackGeometry`'s
inverse) and requires the chip to say that number; it never hard-codes it against the strip.

`ruUnknownCount` had to be re-derived along with it, or every half-depth rack would have grown a
superscript. It now counts a rail device only when NO elevation can place it (`!
isDrawnOnSomeElevation`), snapshot missing, or zero U on *both* faces. A front-only blank seen
from the rear is a **measured zero**, and G4 cuts both ways: refusing to state a number you have
is as dishonest as inventing one you do not.

**The drop evaluator would let you drop onto an occupied slot.** `whole_house` RK-1 bolts UPS-1 to
the FRONT rails at U1 with `frontU 3 / rearU 3 / side: both`, so the rear elevation draws it over
rear U1–U3, yet `findLowestFreeRu(face: rear, deviceH: 1)` answered `1` and `findBlockingOccupant`
called the range free. The insertion caret sat on top of drawn ink, and a palette drop or a device
move to rear U1 was evaluated "not blocked" with no `Occupied by UPS-1 (U1-U3)` reason. Committing
it put two blocks in one rear U on the canvas AND on T2.02.

### The bolted-rails question still exists, and is now named

Two callers legitimately want the OTHER question, because their answer is **written back into a
`RailPlacement.face`**: `planCompaction` and `planRackShrink` turn plans into
`MoveDeviceCommand(fromFace:, toFace:)`. Planning the rear elevation by elevation FOOTPRINT would
unbolt every front-mounted `side: both` device and re-hang it on the rear rails, a far larger edit
than "close the gaps", out of a preview that showed only vertical movement. `rack_shrink` has the
additional constraint that its enumeration must name each occupant exactly once.

So `railOccupantsOnFace` became two names over one implementation:

* **`elevationOccupantsOnFace`**: what this elevation draws. Placement, collision, the caret, the
  drag ghost, keyboard nudge, and `starter_integrity`'s overlap/overhang gate.
* **`boltedOccupantsOnFace`**: what is bolted to these rails. `compaction.dart`,
  `rack_shrink.dart`, and nothing else. `device_loads.dart`'s `boltedRailFace` is the same question
  for one device.

The split is load-bearing rather than cosmetic: pointing compaction/shrink at the elevation scan
makes `rack_shrink_test`'s "two faces each freeing 3U have together freed 3U" throw, because two
`side: both` devices at the same U on opposite rails are an occupancy conflict the bolted view
cannot see.

### Deferred, and named rather than dropped — **both closed in §3i**

`planCompaction` packs around the **bolted** set, so it still does not anchor on a device the other
face bolted and this face merely draws: Compact Down on a rear elevation can propose a target the
drop evaluator would now refuse. Closing it means anchoring on `elevationOccupantsOnFace`, which
also re-anchors every `side: both` device against its own twin on the other face and so changes
what compaction proposes on ordinary racks, a planner behaviour change with its own preview,
`freedU` arithmetic and test surface. `compaction.dart`'s `_immovableAnchors` states this in place.

Likewise `planRackShrink` measures an occupant by its height on the face it is bolted to rather
than by `stackOccupancyU` (the taller of the two), so a device with `frontU 1 / rearU 4` is judged
by 1 U. No shipped template has `frontU != rearU` with both non-zero, so nothing in the repository
exercises it today.

Both are now fixed, see §3i, which also records the third defect the first one was hiding (two
faces planned independently compose into an overlap) and the answer to "should a device be anchored
against itself across faces?" (no, and the set difference that says so is load-bearing).

### A source-level gate can only be followed if the file it names exists

`spec.dart` spent this stage sending its reader to `stroke_flag_pairing_test.dart`, which has never
existed; the CR-082 flag-pairing rule is enforced by `draw_source_gate_test.dart` (which
`symbol_layer.dart` already cited correctly). Following a citation and finding nothing is
indistinguishable from finding the gate deleted, the one failure a source-level gate cannot
survive. `draw_source_gate_test.dart` gained a third gate: every `*_test.dart` named by any
production comment, in any package, must exist somewhere in the repository.

### Test counts and mutation testing

`rackmate_core` 886, `rackmate_ui` 351, `apps/rackmate` 651, `rackmate_export` 183, **2071**.
`flutter analyze` 195 infos, 0 errors, 0 warnings.

| Mutation | Killed by |
|---|---|
| `computeRackRollups` restores the `placement.face == face` filter | `rack_metrics_row_test` (widget tree: chip vs rendered boxes) + 2 `totals_test` cases |
| `elevationOccupantsOnFace` reverts to `boltedOnly: true` | `catalog_placement_test` (`findBlockingOccupant` returns null over UPS-1's drawn rear block; the caret quick-add succeeds into it) |
| `boltedOccupantsOnFace` widened to `boltedOnly: false` | `rack_shrink_test` freedU (null rescue plan) |
| `spec.dart` cites `stroke_flag_pairing_test.dart` again | `draw_source_gate_test`'s citation gate, naming the file and the line |

---

## 3h. Per-run jacket colour: the exception half (CR-121)

**Model and core only. No UI shipped, and that is the point of the stage rather than an
omission**: there is nowhere to hang a colour picker: M2 is NOT STARTED, both the Schematic
and Schedule tabs render `UnbuiltView`, and there is no `Link`-creation surface at all.

### What shipped

A previous stage landed the **convention half**: `JacketColorId`, `JacketColorDef`,
`ProjectSettings.jacketColorConventions`, `Link.jacketColorId`, full codec support, and
`buildDefaultJacketColorConvention()` carrying the requesting integrator's seven colours as
editable per-document data. This stage added the **exception half**:

| Piece | Where |
|---|---|
| `Link.jacketColorPulledId`: what was actually pulled, null = matches convention | `model/link.dart` |
| Both jacket fields converted to public getter + `@internal` setter (AC-013) | `model/link.dart` |
| One `putIfNotNull` encode line + one decode line, both reusing existing helpers | `persistence/json_codec.dart` |
| `ResolvedJacketColor` + `resolveJacketColor`, the three derived questions | `derived/jacket_color_resolution.dart` |
| `SetLinkJacketColorCommand`, `SetLinkPulledJacketColorCommand` | `commands/link_jacket_color_commands.dart` |
| The seven-entry convention seeded into all four starter assets, and fifteen authored `jacketColorId` values on `whole_house`'s Cat6 home runs | `tool/starters/`, `assets/starters/*.rackmate` |

> **`JacketColorRollup` + `jacketColorRollup` shipped in this stage and have since been DELETED.**
> The table above used to carry a row for them reading "the definition `T0.02 EXCEPTIONS` will
> consume". Nothing outside their own four tests ever called them: no reader existed for
> `perConventionCount`, `exceptionCount`, `pulledOnlyCount`, `unrecordedCount`,
> `unknownEntryCount` or `exceptionLinkIds` in `rackmate_ui`, `rackmate_export` or
> `apps/rackmate`. The doc comment defended itself with the wrong criterion — "it is a pure
> function of its arguments, so it is not the 'production field whose only writer was test code'
> smell" — but that smell is about who READS a value; `resolveJacketColor` has the same purity
> *and* a documented read path, while the rollup's four tests were a spec written by its only
> consumer, which was itself. This is the third instance of the shape in this project, after
> `AppServices.prefs` (production field, sole writer in a test, "which is why the suite is
> green") and `chooseDrawingScale` (seven tests asserting a property false of the shipped path).
>
> Its named landing site made the case worse rather than better: docs/08 defines `T0.02` as a DRC
> **Findings** sheet ("every open Finding with rule ID, severity and locus"), `SheetRole` has
> three values and none is it, there is no `Finding` class in the codebase, and a colour rollup
> is not a Finding — a category mismatch, not deferred work. It comes back **with its consumer**;
> reconstructing it is a fifteen-line loop over `resolveJacketColor`, which is the part that is
> actually load-bearing and is fully tested. A prose note in
> `derived/jacket_color_resolution.dart` records the same, next to where it lived.

**`Link.jacketColorId` was NOT renamed** even though the refinement makes its name ambiguous:
the key is already on disk in fixture (c) and in all four starter assets, and renaming would
force regenerating them. Its doc comment was rewritten instead, it used to read "THE COLOUR OF
THE SHEATH PULLED", which is now factually wrong; it is the CONVENTION reference.

**Format: no existing USER document changes a byte.** `kSchemaVersion` stays 2,
`kMinReaderVersion` stays 2, no migration entry. The override is absent-key-when-null, so every
file that has never recorded a wrong-colour pull encodes exactly as before.

**The four starters WERE regenerated, and this section used to say they were not.** Deliberate,
and the reasoning is in CR-121: a starter is a document this build authors, `StarterAuthor
.newDocument` seeds the convention at creation exactly as `buildBlankDocument` does, and a
starter with no convention would be the only document the app produces without one. AC-052 has
the starters doing triple duty as goldens, perf fixtures and screenshot source, so an empty
convention would mean a golden that cannot catch a codec regression in the block and a
screenshot showing the empty state forever. `whole_house` additionally carries fifteen authored
`jacketColorId` values, assigned from each run's PURPOSE and never from its media (five distinct
colours across one media type, the wrong shortcut would give all fifteen the same one), with
`jc.red` and `jc.black` stocked and pulled by nothing so the third state is exercised on shipped
bytes. `dart run tool/generate_starters.dart --check` reports all four unchanged. Reverting the
assets while keeping the generator would leave `--check` reporting STALE forever, which is
strictly worse than the diff.

### Mutations run (each broken, confirmed RED, reverted)

| Mutation | Killed by |
|---|---|
| `keystoneColorId` → `pulledId ?? conventionId` (keystone follows the pull) | 4 cases in `jacket_color_resolution_test`, the single most important gate in the change |
| `isException` drops the `pulledId != null` limb | 3 cases (every ordinary run reported as an exception) |
| `isException` drops the `pulledId != conventionId` limb | 1 case (the hand-edited-file / CSV-import path) |
| `asBuiltColorId` → `conventionId ?? pulledId` | 2 cases (a takeoff would order the wrong colour) |
| `apply()` drops the equal-ids normalisation | 3 cases in `link_jacket_color_commands_test` |
| `revert()` stops restoring the prior override | `command_roundtrip_test` (the 1000-sequence fuzz) |
| codec encode line deleted | 5 cases in `jacket_color_resolution_test` |
| a banned name added to `lib/src/draw/` | `jacket_colour_is_not_hue_test` |
| `.jacketColorPulledId =` written outside `src/commands/` | `internal_setter_grep_test` |

Run again during the follow-up cleanup, on the repaired gate and the two behavioural fixes:

| Mutation | Killed by |
|---|---|
| `asBuiltColorId` planted in a drawing file under **each of the four** scanned roots | `jacket_colour_is_not_hue_test`: all four reported by path |
| `JacketColorId` (the id TYPE) planted in `rackmate_ui/lib/src/canvas/` | same: the spelling that used to pass |
| `_decodeJacketColorDef` reverted to `asStr(json['meaning'], …)` | `jacket_color_test`: one absent OPTIONAL key made the whole document a `FormatException` |
| a shipped starter carrying a dangling `jacketColorPulledId` | `starter_integrity` check 12: `link W001 pulled jacket colour jc.deleted does not resolve` |

> **A finding worth recording, SINCE FIXED: the golden fixture corpus did NOT kill the deleted
> encode line.** `_assertByteRoundTrip` OVERWROTE `test/fixtures/*.rackmate.json` with whatever
> the encoder currently produced, then asserted write→read→write stability — so the fixtures were
> **records, not golden expectations**, and could not catch "the encoder stopped emitting a key".
> That had been true since M0 (`b94bd60`). `b5a957f` repaired it: the test now compares against
> the **committed** goldens and `UPDATE_GOLDENS=1` regenerates them deliberately, so a format
> change to a stored document is a red test. Fixture (c) carries a populated override plus a
> `jc.yellow` convention entry, so the corpus both contains the shape and now defends it.
>
> The per-key byte-level assertions live in `jacket_color_resolution_test.dart`'s
> `THE FOUR STATES ON DISK` group. Its two `indexOf` "sorted adjacency" assertions were removed
> as part of this cleanup: `encodeJsonTreeBytes` runs `deepSortKeys` over the whole tree before
> encoding, so swapping the two `putIfNotNull` calls in `_encodeLink` left them green — they only
> restated that `"jacketColorId" < "jacketColorPulledId" < "lifecycleStatus"` in ASCII. The
> canonical sort is the repaired golden corpus's to guard; the two key NAMES are still asserted
> directly.

### Deferred, named rather than implied

1. **The Pull Sheet jacket-colour swatch column (T6.10)** and **the Termination Schedule column
   (T6.11)**: specified now (docs/01 §, docs/08 §3.2: two tokens, `BLU→YEL`, never one), drawn
   later. `sheet_def.dart` emits three of eleven sheet roles; the other nine are M6 and most are
   blocked on `Link`s.
2. **`T0.02 EXCEPTIONS`**: the named, unbuilt sheet role a wrong-colour pull is a row of.
   **Nothing ships for it.** `jacketColorRollup` was written as "its definition, so the fact
   cannot rot", and was deleted for having no consumer, see the note in §What shipped. The
   counting loop is fifteen lines over `resolveJacketColor` and belongs in the same change as the
   renderer. (docs/08 in fact defines `T0.02` as a DRC **Findings** sheet, so the sheet role a
   colour rollup lands on may not be this one at all.)
3. **Keystone matching (task #9, v1.X)**: nothing stores a keystone colour and nothing should;
   `keystoneColorId` derives it. There is no keystone entity: the wall-plate end is a
   `StructureOrigin.terminationField` whose `TerminationType` may be `keystone`, and `Outlet`
   carries no colour.
4. **ALL M2 UI**: the inspector control that picks a convention entry and the "pulled a
   different colour" control beside it. This is the surface that will actually let a user set
   any of this; today only a test or an importer can.
5. **The convention settings screen** (add / rename / recolour / delete entries) and its
   Commands. The map is plain-mutable like `ruleOverrides`, so nothing blocks it structurally.
6. **CSV import mapping for the override column**: the alias table in docs/07 §now lists it,
   the importer does not implement it.
7. **The white/black swatch-outline rendering rule**: a near-white swatch is invisible on white
   paper without an outline. Already recorded as debt in `catalog/jacket_color_convention.dart`;
   still unowned, and it belongs to the sheet consumer that does not exist.
8. **Any DRC advisory** (e.g. "an override is set on a run still at `roughInStatus.planned`"), 
   M5, which is 0 of 27 rules. The model is deliberately NOT gated on `roughInStatus`: refusing
   to record an observation because a status field is stale is the opposite of the principle
   this feature exists for.
9. **Widening the PAL-1 source gate beyond the drawing layer**: it scans drawing roots only, so
   a coupling introduced in a Command or in `derived/` (writing a jacket colour into
   `Net.colorOverride`, `DeviceInstance.colorOverride` or `ProjectSettings.familyColorOverrides`)
   would reach the renderer through the back door. Recorded in docs/05 §6.1.

   > **The gate itself shipped with two holes and has been repaired.** It scanned
   > `rackmate_core/lib/src/draw` and `rackmate_export/lib/src/draw` but NOT
   > `rackmate_ui/lib/src/draw` or `rackmate_ui/lib/src/canvas` — which are not future work:
   > `flutter_canvas.dart` and the three `CustomPainter`s are what puts colour on screen today. A
   > probe naming all nine banned names was dropped into `rackmate_ui/lib/src/draw` and the gate
   > stayed green. Its `_bannedNames` also omitted `JacketColorId` (the id TYPE — the regex is
   > case-sensitive, so the banned `jacketColorId` never matched it) and `asBuiltColorId`, the
   > accessor its own adjacent comment called "the most tempting of these to reach for in a
   > renderer"; `Rgb wireHueFor(JacketColorId id, …)` passed. Both lists are fixed and the
   > CONFIGURATION is now itself under test three ways: every named root must EXIST (a skipped
   > root is now red, not silent), every banned name must be a real symbol in `lib/` (a
   > misspelled ban is vacuous), and the detector is run over a synthetic drawing source carrying
   > the coupling, in the shape of `session_layering_test.dart` RULE 15b. Bare `keystone` and
   > `asBuilt` are deliberately NOT banned: both are ordinary drawing vocabulary (a keystone
   > termination symbol, an `AS-BUILT` title-block stamp), and a gate that cries wolf gets
   > weakened.
10. **`Link.unknown` passthrough map**: without it, an older build that opens a newer file and
    re-saves silently drops the override. Pre-existing for `jacketColorId` too; fixing it would
    change every `Link`'s bytes. Flagged in CR-121, not recommended now.

### One judgement call the user should confirm

**"Override set, convention unset" is ALLOWED.** A tech observed a yellow jacket at prewire but
nobody recorded what the run is for. It is kept rather than refused, because refusing would make
a CSV importer discard an observed physical fact and promoting it to the convention field would
guess the run's purpose (G4). It resolves as `asBuilt = yellow`, `keystone = null`,
`isException = true`, and reads on a schedule as `—→YEL`, which is admittedly awkward. If the
user would rather forbid it, that is a one-line invariant plus a Command refusal, and per this
project's rules, a refused action must report rather than silently drop.
## 3i. The two planners, pass 5: compaction could still propose an overlap

§3g fixed what the elevation DRAWS and stopped at the planner that packs against it, naming two
deferrals in place. Both are closed here, along with a third that only became visible once the first
was fixed.

### What moves is the bolted set; what it must clear is the rack

`planCompaction` had one occupancy question where it needed two. It asked
`boltedOccupantsOnFace` (correctly, for **movers**, because a `CompactionMove` becomes
`MoveDeviceCommand(fromFace:, toFace:)` and planning by elevation footprint would unbolt every
front-mounted `side: both` device and re-hang it on the rear rails) and then packed **around** that
same set. So a device the other face bolted and this face merely draws (CR-036) was not an obstacle
at all: Compact Down on the rear could propose a target `findBlockingOccupant` refuses, out of a
preview showing a device sliding into space another device is visibly standing in.

The obstacle set is now `elevationOccupantsOnFace` **on both faces, minus the movers**
(`compaction.dart`'s `_anchors`), and the fit test (`_straddles`) checks a candidate target against
every elevation that draws the mover, not just the one being planned. Both halves are load-bearing:

* **Both faces, because a move carries the whole device.** Packing a full-depth device down the
  front elevation moves its rear block too. Front-only clearance sends it onto a rear-bolted
  device: the same defect, mirrored.
* **Minus the movers, because a device is not an obstacle to itself.** This was §3g's stated
  objection to "just anchor on the elevation scan", and the set difference is the whole answer: a
  device's front block and rear block are one object at one U. Anchoring them wholesale pins every
  `side: both` device against its own reflection, and Compact Down proposes nothing, ever, on any
  rack whose devices are full depth, which is 19 of `whole_house` RK-1's 27.

`freedU` is unchanged in meaning and now measures against the widened anchor list for the planned
face: a front elevation whose top is still held by a rear-bolted device has gained nothing at the
top, exactly as it already reported for a device no elevation can model. The other face's anchors
are deliberately **not** folded in: the number is a run on one elevation and is spent there, and a
front-only blank really does fit above a front stack whose rear neighbour reaches higher.

### The packing cursor steps by the planned face, and `blockers` does the rest

Two heights meet in the pass and they are not interchangeable. The **monotonic cursor** exists only
for order preservation on the elevation being compacted, so it steps by that face's height. The
**rack-extent bound** in `_lowestFit`/`_highestFit` is the stack height (`max(frontU, rearU)`), or a
`frontU 1 / rearU 4` device compacted up a 12U rack lands at U12 with three U of itself outside the
rack. Correctness (nothing overlapping anything) belongs to neither of them: it belongs to
`blockers`, which every placed mover is added to on every face it draws on. Stepping the cursor by
the stack instead only refuses **legal** placements: a front-only follower belongs at the next front
U, not three U above it, staring at a gap the preview cannot explain.

### The third defect: two faces planned independently compose into an overlap

`planRackShrink` plans both faces, because a shrink is a physical change to a rack rather than a
view operation. With cross-face anchoring in place that exposed the real bug underneath: two calls
planned against the document's *current* positions both reach for U1, and the composed rescue puts
two full-depth devices in the same U, an overlap the planner proposed, out of a modal promising a
lossless shrink. `planCompaction` gained one optional parameter, `alreadyPlanned`, and
`_planRescue` now runs the faces **in sequence**, feeding the second the targets the first assigned.
The residual asymmetry is stated rather than hidden: the front pass still anchors on the rear's
pre-compaction positions, so it can leave a gap the rear later vacates, an error that packs less
tightly, never into occupied U.

### An occupant is measured by its tallest face

`planRackShrink`'s `_Occupant` now carries two heights. `deviceH` stays the bolted face's: it is
what a `CompactionMove` hands the preview to draw a ghost at. `stackH` is `stackOccupancyU`, and it
is what every *does this still fit* question uses: `_diesUnderPlainTrim`, `_losslessFloor`, and the
U range `DoomedOccupant` names in the casualty list. Judged by its 1 U front block, a
`frontU 1 / rearU 4` device survives a shrink to 22U with three U of itself outside the rack and
**no modal opens at all**, the silent stranding "always name the casualties" exists to prevent. It
also reaches the `unmodelledRail` branch: a device bolted to the front rails with `frontU 0` is
skipped by both bolted scans, but its snapshot may still say the rear elevation draws four U of it,
and claiming 1 U there was an under-count with a resolvable answer sitting right beside it.

### The fixtures that were quietly invalid

Three `rack_shrink_test` fixtures put two **full-depth** devices at the same U on opposite rails.
That is not a rack; it is an occupancy conflict, and the bolted-only planner simply could not see
it. Two are now spelled with single-face devices (`otherU: 0`), which is what their comments always
claimed they were testing: *independent* elevations whose contiguous runs do not sum. The third
(the shipped-demo shape) keeps its full-depth devices and gets a truer number: the rear pass cannot
drop PP-1 to U1 under a full-depth front stack, so the rack frees **3U**, not the 4 the old
independent planning claimed and emphatically not the 10 a per-face fold reports. Both test helpers
gained an `otherU` knob, and `side` is now derived from the two heights rather than passed, so a
body cannot claim `both` with `rearU: 0`.

Two invariant tests now pin the whole thing end-to-end rather than by target arithmetic: applying a
plan (compaction) or a rescue (shrink) and asserting that `findBlockingOccupant` reports **no**
occupied range on either elevation, for every direction and both trims.

### Test counts and mutation testing

`rackmate_core` 903, `rackmate_ui` 351, `apps/rackmate` 651, `rackmate_export` 183, for **2088**.
`flutter analyze` 195 infos, 0 errors, 0 warnings.

Ten mutations run, ten killed, and **two survived their first pass**, which is how the packing
cursor got fixed. `cursor = target + _stackH(foot)` and dropping `_occupy` for placed movers were
*both* invisible, because the over-conservative cursor was masking the missing obstacle record. The
kill for the second one only exists because the first was corrected to the height it should always
have used.

| Mutation | Killed by |
|---|---|
| A move need only clear the face being planned | `compaction_test` "a move must clear EVERY elevation…" + 5 more |
| `_anchors` stops subtracting `movers` | 15 `compaction_test` cases: every plan becomes empty |
| `_anchors` drops the elevation ranges (the §3g behaviour) | `compaction_test` "Compact Down packs AROUND a device the other face bolted…" + 9 more |
| `_planRescue` passes `alreadyPlanned: const {}` | `rack_shrink_test` "the rear pass packs above the front pass" + 3 more |
| `_Occupant.stackH` reverts to the bolted-face height | `rack_shrink_test` "judged by 4U" |
| The cursor steps by the stack height | `compaction_test` "…the next front U really is the next front U" |
| `_occupy` is not called for a placed mover | `compaction_test` "two movers on ONE face can still collide on the OTHER" |
| `_occupy` is not called for a locked occupant | `compaction_test` "never packs a device THROUGH an anchor…" |
| `_occupy` is not called for a device that could not move | `compaction_test` "…an obstacle where it STANDS" |
| The fit bound uses `frontU`, not the stack | `compaction_test` "bounded by its TALLER face" |

---

## 4. Suggested next order

Roughly in the order that unblocks the most subsequent work, not a commitment:

1. **Seeded catalog + palette** (roadmap item 6), replaces the 4 hand-built demo devices with
   real data and gives placement something to draw from. Blocks quick-add and drag-from-palette.
2. **Quick-add by typing + insertion caret + keyboard nudge** (roadmap item 4, §3.2/§3.4), the
   fastest path to populating a rack and the one the exit criterion's "20 devices in under four
   minutes, keyboard only" is actually measuring. **Substantially done** (uncommitted as of this
   log update, see §2's §3.2/§3.4 rows above for exactly what shipped vs what's still deferred:
   Shift/Ctrl/Alt+↑↓, multi-device nudge, and the back-to-back-Enter known gap). **Drag from the
   palette to the rails (§3.1)**, the other half of roadmap item 6/this item's original scope,
   is now **done** for the two BLOCKING CR-017 checks (front U range free; fits within rack
   extent), built directly on top of this one's `CaretController`, `EditingOverlayPainter`,
   `ShakeController`, and `findBlockingOccupant` rather than duplicating any of them, see §3.1
   above for the full mechanism and what remains deferred (the five advisory/warning checks, the
   Staging Bin, and several visual-polish animations). **Moving an EXISTING placed device (§3.3)**
   now shares all of that machinery too (same evaluator, same ghost/hatch/chip rendering, same
   blocked-release behaviour) closing the gap where only the palette drag had live feedback; see
   §3.3 above for the four remaining deferred steps (cross-rack, duplicate, insert-and-push, swap).
3. **Rack configuration UI** (§4), **substantially done** (uncommitted, passes 1 and 2 of
   three): the inspector, the rack header, presets, the compaction preview, and the inspector's
   height field all ship. **Pass 3 remains**: the header stepper's 400ms-then-8/s hold-repeat,
   the drag-the-top-edge gesture with its live "24U (+3)" readout and real-time red hatch, and
   the shrink-below-occupancy modal. Still needed before a user can create a rack that isn't
   hardcoded (multi-rack + the new-rack dialog are their own stage, see §3a).
4. **~~Chip strip~~ + Rack Vitals + validation rules** (§5), the **chip strip is done** (§3c);
   what remains is the Vitals panel and the first of the 27 v1 DRC rules
   (`derived/validation.dart` still doesn't exist in any package, and the rack header's `⚠n`
   rollup waits on it). `derived/totals.dart` now exists and is the shape the rest of
   `derived/` should follow: pure, argument-driven, and returning `null` for unknown.
5. **Non-device occupants + shelves + 0U** (§6).
6. ~~**Compaction** (§3.6).~~ **Done**: shipped with the rack-configuration stage (passes 1
   and 2), since the shrink modal's option 1 needs the planner anyway.
7. **Naming/designator UI + idformat wiring** (§7).
8. **Persistence wiring + starter projects** (roadmap item 10), needed regardless of interaction
   completeness, since the exit criterion requires opening/saving real files.
9. ~~**Minimal PDF exporter** (roadmap item 9)~~, **DONE, both passes.** §3d is the sheet frame and
   furniture; §3e is `T2.01`/`T2.02` rendering the EXISTING `buildRackScene` through
   `PdfDiagramCanvas` inside one scale bracket, `T6.30` off the shared `resolveDeviceLoads`, and
   `File ▸ Export PDF…` on the shipped storage layer. Rear mirroring (item 3) landed with it, in
   core, so both backends have it. What remains of docs/08 is the M6 sheet set and the `Ctrl+P`
   dialog, see §3e's deferred list.
10. **Remaining keymap + accessibility + empty states** (§8/§9), can land incrementally
    alongside any of the above rather than as one dedicated pass.
