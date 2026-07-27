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
| 4 | Quick-add by typing with the drop caret; the Staging Bin; shelves with auto-pack; 0U occupants from the inspector | **Partial** — quick-add by typing now places at the insertion caret (docs/04 §3.2/§3.4), see §3.2/§3.4 below; the Staging Bin, shelves-with-auto-pack, and 0U-from-the-inspector remain **not started**. §3.1's "release outside any rack" now shows an HONEST chip and reports its refusal instead of silently doing nothing, but it still creates no `StagedPlacement` — see §3c |
| 5 | Compact Up/Down with preview-then-accept, and the shrink-rack dialog; locks | **Partial** — Compact Up/Down ship COMPLETE (planner + preview overlay + floating Apply/Cancel bar + `Enter`/`Esc`, see §3.6); the shrink-rack dialog is planner-only (see §4.1) and its modal is pass 3; locks are honoured as immovable anchors by the planner but there is still no `Ctrl+L` UI to SET one |
| 6 | The full seeded catalog (incl. 18 field devices, `sources.md` provenance, connector-footprint CI assertion) | **Partial** — 48-template seed catalog (30 rack-side + 18 field) with `assets/catalog/sources.md` provenance and the connector-footprint CI assertion all landed, plus a device palette panel wired into `RackCanvasScreen` (search + categories, **click-to-add** via double-click/Enter, **and now drag-from-palette-to-rails** — see §3.1 below); the 4 hand-built demo devices remain as the rack's starting contents alongside the catalog |
| 7 | Copy-on-place with `DeviceOverrides`; the chip strip (RU, weight, VA, outlets) with unknown counts | **Partial** — the **chip strip ships complete**, including the unknown counts (`rackmate_core/derived/totals.dart` + `rackmate_ui/canvas/rack_metrics_row.dart`, 54 new tests, see §5 below). Copy-on-place with `DeviceOverrides` remains **not started** — the rollup READS `DeviceOverrides.weight` where one exists, but nothing writes one |
| 8 | `DiagramCanvas` + `SceneBuilder` + both backends + the baseline-Y parity test | **Done** — mutation-tested twice |
| 9 | Minimal PDF exporter: front elevation, rear elevation, `T6.30`, title block, revision block | **Not started** |
| 10 | Atomic save, autosave, recovery, recents, close interception; the outline tree; four starter projects | **Not started** |

---

## 2. Against the rack editor spec (docs/04-rack-editor.md), section by section

### §1 Screen layout
- [x] Palette panel (280 px, search, categories) — **done** — collapsible
      per-category (not the whole panel) via `ExpansionTile`; panel-width
      persistence/resize handle not built
- [x] Inspector panel (320 px, selection section + Rack Vitals) — **partial, this stage
      (pass 2)** — the 320px FOURTH COLUMN now exists
      (`rackmate_ui/src/inspector/inspector_panel.dart`), so the layout is finally
      `Row(palette 280 | divider | canvas | divider | inspector 320)`. It hosts either the full
      `RackInspector` (§4) or a MINIMAL selection summary (count + the focused device's
      designator/name). The summary is deliberately NOT a device inspector — device property
      editing is its own body of work (§3's Width position dropdown, §6's shelf capacity, §7's
      `F2` rename, copy-on-place `DeviceOverrides`), none of it in this stage. **Rack Vitals
      stays not-started** (§5, needs the validation engine).
- [x] Rack header bar — **new, this stage (pass 2)**, not previously listed here because
      nothing in the spec's §1 layout list names it separately: a screen-space
      `RackHeaderBar` (`rackmate_ui/src/canvas/rack_header_bar.dart`) showing designator +
      name + a read-only height badge, with an overflow menu carrying Compact Down / Compact
      Up / Rack settings…. Screen-space (a `Positioned` in the canvas `Stack`, sibling to the
      zoom HUD) rather than scene-space, because it hosts real Flutter controls a
      `CustomPainter` cannot and must not scale with zoom. The height STEPPER and the `⚠n`
      findings rollup are both absent — pass 3 and the validation stage respectively.
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
- [x] §3.6 Compact Up / Compact Down with preview overlay — **DONE, across passes 1 and 2.**
      Pass 2 added everything the §3.6 sentence asks for on top of pass 1's planner:
      **proposed positions as solid ghosts** (`EditingOverlayPainter` gained an optional
      `compaction` source; one ghost box per move at its `toRuIndex`, reusing the ghost
      fill+border extracted out of `_paintGhost` into a shared `_paintGhostBox`);
      **current positions dimmed to 25%** (`RenderDeviceBox`'s boolean `dragSource` flag
      generalised to a nullable `fadeOpacity`, so ONE `saveLayer` implementation serves both
      §3.3's 30% move-drag fade and §3.6's 25% — two booleans would have needed a precedence
      rule for a combination that cannot occur); and the **floating bar** reading exactly
      "Compact Up — 4 devices move — 3U freed [Apply] [Cancel]"
      (`compaction_preview_bar.dart`, a `Positioned` rather than an `OverlayEntry` because,
      unlike the drag chips, it does not follow a pointer and must accept clicks).
      **`Enter` applies as one undo entry; `Esc` cancels**, both through the existing
      `Shortcuts`/`Actions` map. Only the movers dim — a device that stays put is not part of
      the proposal.
      **THE AFFORDANCE IS THE RACK HEADER'S OVERFLOW MENU**, chosen because §3.6/AC-045 keep
      `Ctrl+B` RESERVED AND UNBOUND (it is bound nowhere) while still requiring the two
      commands to ship, and because compaction is a per-rack operation that belongs on the
      rack's own chrome. A global toolbar does not exist in this app and would have to invent
      a target-rack concept the moment a second rack lands.
      **`Enter` NEEDED A REAL `Action` SUBCLASS, not a `CallbackAction`** — it is bound BARE,
      inside the same `Shortcuts` subtree as the palette search box and every focusable
      palette row, and `ShortcutManager` consults `isActionEnabled`, NOT the callback's
      return value. A `CallbackAction` returning null would have reported the key HANDLED and
      silently eaten `Enter` app-wide. `_ApplyCompactionAction.isActionEnabled` returns false
      when no preview is open, so the key falls through. (The test for this had to be
      rewritten after a mutation survived — see the mutation note at the end of §3.)
      **STALE-PLAN GUARD, and it is load-bearing.** A plan holds `fromRuIndex` values captured
      at plan time and then waits for a human. If the document moves underneath (Ctrl+Z, a
      palette placement, a nudge), applying it would issue `MoveDeviceCommand`s whose "from"
      is a fabrication — and `revert()` would faithfully restore devices to positions they
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
      (1) **compaction preserves relative order** — devices only ever close the gap ahead of
      them and never leapfrog a neighbour into a lower run that would "fit better", because
      greedy best-fit packs marginally tighter while silently REORDERING the user's rack, which
      is a much larger edit than a button labelled Compact Down offers; §3.6 parking
      "Auto-arrange with trade heuristics" in v1.2 draws the same line.
      (2) **`freedU` is the contiguous run gained at the direction's far end**
      (`highestOccupiedBefore - highestOccupiedAfter` for Down, mirrored for Up), NOT the sum of
      gaps closed — the number on the bar has to be the U the user can actually spend.
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
      depth, rail type, weight cap, mount, swing frame, ground bar) — **DONE, pass 2**
      (`rackmate_ui/src/inspector/rack_inspector_panel.dart`), on top of pass 1's command
      layer. All four sections render; Identity, Form factor and Display are fully editable
      and **every field routes through a real Command, so every field undoes** — asserted
      field-by-field by `rack_inspector_panel_test.dart`, which changes a value and then
      undoes it for each one.
      THE THREE ENTRY POINTS §4 NAMES ALL WORK, plus the bonus fourth: clicking the rack
      HEADER; clicking the rack's EMPTY BACKGROUND (tested against the existing `_geo` extent
      — inside the rack body opens the inspector, outside is just a deselect, and
      `rack_layer.dart` emits no hit regions of its own so there was nothing else to ask);
      `Ctrl+Alt+U` (a new `_RackSettingsIntent`, which also focuses the panel's first field so
      the keyboard path lands somewhere useful); and the overflow menu's "Rack settings…".
      Clicking a DEVICE puts the column back on the selection summary — that pair is how §4's
      "REPLACES the Selection section" is honoured, given there was no Selection section to
      replace (see the §1 row).
      COMMIT DISCIPLINE, one rule for the whole panel: text and numeric fields commit on blur
      or Enter (§4.1 states this for height; applying it uniformly means a user never has to
      remember which box behaves which way), dropdowns/radios/checkboxes commit on change, and
      `Esc` in a focused field reverts the buffer WITHOUT running a command. Refusals are never
      silent (§3.4): an empty designator, an unparseable depth or capacity, and an
      out-of-range height each revert the buffer AND report on the status line.
      NOTABLE FIELD DECISIONS. **Usable depth and weight capacity are nullable with an explicit
      unset state** — empty string means null, hinted `—` rather than `0`, with a clear button
      that writes null explicitly (CR-114: null means unknown, never zero; a 0 mm depth is a
      claim about the rack, an empty field is the absence of one). **Own weight is read-only
      and renders `—` when unknown**, never "0.0 kg". **Mount is a two-way Floor/Wall radio
      over the eight-value `RackFormFactor`**, and the mapping — which the spec does not
      make — PRESERVES the existing subtype: Wall→Floor→Wall on a pivot cabinet lands back on
      a pivot cabinet, and only a genuine cross-category move picks the category's generic
      member. Explicitly unit-tested, because a lossy default here would let two clicks
      silently destroy a fact a preset put there. **Hinge side is disabled and dashed while
      Swing frame is off.** **The Preset dropdown is write-only in the honest sense**: a
      `Rack` has no `presetRef`, so the displayed preset is DERIVED by exact value match and
      reads "Custom" the moment the user diverges — continuing to claim "Floor enclosure 18U"
      after the rail type changed would be the UI telling a story the document does not.
      **Applying a preset is ONE `Transaction`** (N `SetRackPropertyCommand`s + one
      `SetRackHeightCommand`), and it is ATOMIC OR NOTHING: a preset whose height would
      displace occupants is refused WHOLE rather than landing eight fields and quietly
      skipping the ninth, which would leave a rack claiming to be a "Wall box 6U" at 12U.
      **The Location dropdown is REAL, enabled and command-backed** over `doc.locations`, with
      a leading "(none)" mapping to null; `_buildDemoDocument` now seeds three demo Locations
      so the control is genuinely exercisable (demo data only — the `Location` model,
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
- [ ] Three ways to change height (stepper / field / drag top edge) — **one of three built
      (pass 2); the other two are pass 3.**
      **WAY TWO — the inspector field — SHIPS**, committing on blur or Enter, clamping to
      CR-038's [1, 60] with a status message when it clamps, and carrying §4's "advisory above
      50" as helper text. It calls a NAMED FUNNEL, `_requestHeight`, rather than inlining the
      logic in its callback, precisely so ways one and three can call the same method in pass
      3 and §4.1's "ALL producing one ResizeRackCommand" stays literally true. Growing is
      always safe and never reaches the guard below.
      **THE SHRINK-BELOW-OCCUPANCY CASE IS GUARDED, NOT HANDLED, IN THIS PASS — read this
      before assuming it was forgotten.** §4.1 requires a modal here; that modal is pass 3.
      Until it exists `_requestHeight` REFUSES the shrink and names the casualties on the
      status line, plus the lossless height that would work ("Cannot shrink RK-1 to 6U — SW-1,
      PP-1 would lose their U. 9U is the smallest that fits."). That honours the principle's
      first two clauses exactly (nothing destroyed, nothing moved) and its third as far as one
      status line can. It is deliberately NOT a silent clamp to `smallestFittingHeightU`:
      quietly handing the user a different height than they typed is precisely the "silently
      move" §4.1 forbids. **Pass 3 replaces this one branch with the real modal** — the funnel,
      the `planRackShrink` call and the casualty list are already in place; only the dialog is
      missing.
      The one piece of core geometry all three need is **done**:
      `RackGeometry.heightForTopEdgeY()`, the drag-the-top-edge inverse, which
      `ruIndexForTopY` could not serve because it clamps to the current `heightU` — the very
      quantity the gesture solves for. `RackGeometry` also gained value `==`/`hashCode`, without
      which every `geo != old.geo` repaint check becomes unconditionally true the moment
      `heightU` starts changing.
- [ ] Shrink-below-occupancy modal (compact-first / move-to-bin / keep-larger, trim
      from top/bottom) — **not started (UI)**; the PLANNER behind it is **done**
      (`rackmate_core/src/commands/rack_shrink.dart`). `planRackShrink()` returns, without
      mutating anything: every doomed occupant with designator, description, U range and REAL
      link count (rule 4, via `linkCountForDevice` — a true 0 today, not a stub); the uniform
      downward `shiftMoves` a Trim-from-Bottom requires (rule 5); `smallestFittingHeightU`
      (option 3); and a nullable `CompactionRescue` (option 1) that is null precisely when
      compaction rescues nobody, enforcing rule 1's "appears ONLY when compaction actually
      helps" in the planner rather than leaving the modal to remember it.
      **Trim direction is recomputed, not cosmetic**: Top and Bottom produce genuinely
      DIFFERENT casualty sets, different rescue directions (Compact Down vs Compact Up) and
      different `smallestFittingHeightU` values. §4.1's own mockup implies one static list
      beside the radio; that is a spec simplification, corrected here.
      **On partial rescue, option 1 composes with option 3**: rather than shipping §4.1's
      literal "2 of 3 fit — 1 goes to Staging Bin" label (unbuildable, and shipping it would
      silently drop a device), the rescue reports an `achievableHeightU` — the smallest height
      the compacted layout permits losslessly — so option 1 remains selectable per rule 1 and
      NOTHING is ever displaced out of the rack under any option. Rule 3's "DELETION IS NOT
      OFFERED" holds structurally: no code path in the planner removes a device, asserted by a
      purity test that sweeps every height in both trim directions.
- [x] Rack presets (wall box, swing gate, floor enclosure, etc.) — **done (data)**,
      `rackmate_core/src/catalog/rack_presets.dart`, in the same `build*()`-returning-a-keyed-Map
      idiom as the 48-template device catalog, with provenance appended to
      `assets/catalog/sources.md` §5 under the same generic-archetype-never-a-real-SKU rule
      (DR-002/AC-052). **ELEVEN presets, not twelve** — the stage's design brief said twelve, but
      §4's own enumerated list ("Wall box 6U/12in, Swing gate 12U/18in, Pivot cabinet 10U, Floor
      enclosure 18/21/27/35/44U, Open frame 4-post 44U, Credenza bay 8U, Data 42U/36in") counts
      1+1+1+5+1+1+1 = 11. No `openFrame2Post` preset ships even though §4 cites a 2-post frame as
      the reason `usableDepth` is nullable: §4 does not name one, and inventing an archetype to
      make a null-depth case reachable would put unreviewed dimensions in front of users.
      **No codec work was needed and none was done** — presets are not persisted (a `Rack` has no
      `presetRef`), so applying one is a fan-out of writes to fields `json_codec.dart` already
      round-trips. CR-117's invariants are untouched and `byte_roundtrip_test.dart` needed no new
      fixture.
      **The preset-apply Transaction landed in PASS 2, not pass 3 as originally planned** —
      because `_requestHeight` (the height funnel it must route through) also landed in pass 2
      alongside the inspector's height field. It is one `Transaction` labelled
      `applyRackPreset`, and it is atomic or nothing: "Wall box 6U" on the occupied 12U demo
      rack is refused WHOLE with a status message, rather than applying eight fields and
      silently skipping the height. Pass 3 swaps that refusal for §4.1's modal.
- [x] Circuits panel (flat, filtered by `rackId`) — **done, pass 2**, as far as it honestly
      can go. Verified state of the world, unchanged: the `Circuit` model, the `doc.circuits`
      map and full codec support all exist; there are ZERO `Circuit` instances, ZERO commands
      and ZERO UI anywhere in the codebase. The section therefore ships a READ-ONLY list
      filtered by `c.rackId == rack.id` (each row rendering the designator, `breakerAmps` and
      the derived `continuousLimitAmps`, CR-048), a real empty state — "No circuits on
      RK-1." — and **NO `[+ Add circuit]` button**, because no command anywhere creates a
      `Circuit` and a rendered-but-inert button is exactly the "silently does nothing" trap
      §3.4 forbids. One caption line says circuit creation arrives with the power stage.
      Membership-by-walking-power-`Link`s (CR-028's other half) is untouched: the inspector
      merely filters, which is all CR-028 asks of it.

### §5 Derived readouts
- [x] Always-visible chip strip (RU, weight, VA, outlets, each with an unknown-count
      superscript) — **done, this stage**. `computeRackRollups` in
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
        so the chip starts telling the truth the moment those fields become nullable — which
        they should, since a template nobody has authored outlets for is not a template that
        provides none.
      * VA sums `PowerProfile.apparentVA` **only** (CR-056/AC-020: circuit loading is computed
        in VA). It is never derived from `typicalWatts` — AC-039's rejected "half of
        nameplate" behaviour, restated as a test.
- [ ] Collapsed Rack Vitals panel (space bars, weight bar, power bar, BTU/CG advisory) —
      **not started**. The derivation the panel needs now exists (`RackRollups` carries the
      per-face RU split and the weight/VA/outlet rollups); what is missing is the panel.
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
- [x] `Ctrl+Alt+U` (open the RackInspector) — **done, §4 pass 2** (`_RackSettingsIntent`); it
      also focuses the panel's first field
- [x] Bare `Enter` applies an open compaction preview — **done, §3.6 pass 2**, via a real
      `Action` subclass whose `isActionEnabled` is false when no preview is open, so the key
      falls through to the palette's own `Enter` handlers rather than being swallowed
- [x] Bare `Esc` also cancels an open compaction preview — **done, §3.6 pass 2**, extending
      the existing `_CancelDragIntent`
- [ ] `Ctrl+B` — **deliberately RESERVED AND UNBOUND** (§3.6/AC-045). Bound nowhere. Compact
      Up/Down are reachable from the rack header's overflow menu instead
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
**Twelve deliberate mutations were run against pass 2's new tests** — compaction applying
immediately instead of previewing, ghosts drawn at the current rather than the proposed U, the
stale-plan guard defeated, the apply split into N transactions instead of one, the shrink guard
removed, a preset applying partially after a refused height, every device dimmed rather than only
the movers, the empty-background click ignoring the rack bounds, the `Enter` action always
enabled, designator validation dropped, compaction ghosts painted in the BLOCKED (dashed/error)
vocabulary, and an empty plan shown as a preview. **Eleven were killed on the first pass; ONE
survived.** Making `_ApplyCompactionAction.isActionEnabled` return `true` unconditionally did not
fail the "Enter is not stolen from the palette" test, because that test drove the palette flow
through `testTextInput.receiveAction` — the TEXT INPUT channel, which never touches the key-event
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
default 800x600 surface leaves the canvas ~198 logical pixels — narrower than the rack's own
267-unit scene width, and narrow enough that the floating chrome overlaps itself and that
`_focusCanvas`'s click at (300, 400) lands on the INSPECTOR. docs/04 §1 already treats anything
under 1080px as the (unbuilt) tablet-collapse case, so 800x600 was never a supported size for
this screen; the tests now say so explicitly rather than depending on a default that happened to
work while there were only two columns.

---

## 3a. Rack configuration (§4) — what is DELIBERATELY out of scope

Recorded here rather than only in a session report, because every item below is something a
future reader could reasonably assume was forgotten. None of it was.

**Not built in ANY of the three passes of this stage:**

1. **Multi-rack canvas layout and the new-rack dialog.** There is exactly ONE hardcoded demo
   rack; `rack_canvas_screen.dart` holds a single `_rack` field and a single `RackGeometry`.
   Supporting N racks touches the scene builder, hit-testing, drag targeting and the caret
   simultaneously — its own stage, paired with persistence and the four starter projects. This
   stage configures the rack that already exists. **No `AddRackCommand` or `RemoveRackCommand`
   was added.**
1a. **The full shrink-below-occupancy MODAL, as of pass 2 only.** Not a permanent deferral —
   it is pass 3 of this same stage — but recorded here because pass 2 ships a REFUSAL in its
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
   its reason stated, and substitutes option 3 as the fallback preselection — see the note on
   rule 2 below.
3. **§4.2 finding filings (`RCK-012` usable depth, `RCK-003` weight capacity) and every other
   validation rule.** No validation or finding engine exists in any package — there is no
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
7. **Rack Vitals, the chip strip and the rack-header `⚠n` rollup** — they belong with the
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
should choose deliberately. **Nothing is silently dropped under any selection** — rule 3's
no-deletion holds trivially, since no option removes a device.

**Pass 1 coordination note — RESOLVED IN PASS 2.** The stage's design assigned two
`rack_canvas_screen.dart` prerequisites to pass 1 — making `_geo` non-`late final` so it
recomputes on a height change, and adding the first-ever `epochs.rack` subscription. Pass 1's own
task brief forbade touching that file, so both were deferred. **Pass 2 landed both**, and they
were exactly as load-bearing as flagged:

* `_geo` became a MEMOISED GETTER (`_geoCache`, keyed on `_rack.heightU`) rather than a field
  re-assigned from the epoch listener. A getter cannot go stale by construction — there is no
  ordering to get wrong between "the command mutated `heightU`" and "somebody read `_geo`" — and
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
  set in both directions, with a test — it is not something to leave to paint order.
* `RackHeaderBar` deliberately has NO stepper yet, only a read-only height badge. Replacing the
  badge with the hold-repeat stepper is pass 3's job; the widget is otherwise complete.
* The modal-storm problem the design flagged (a held stepper ratcheting down through occupied
  territory opening one modal per tick) is still unaddressed, because there is no stepper yet.

---

## 3b. The Schematic and Schedule tabs — DELETED, and what stands in their place

An off-discipline stage built an M2 schematic and schedule ahead of the roadmap, with **zero
tests across 2 608 inserted lines**. This section records what was removed, what replaced it,
and — because it is the part a future reader will otherwise re-litigate — the doc conflict the
replacement resolves.

**Deleted outright** (`git rm`, recoverable from history; nothing imported any of them except
`apps/rackmate/lib/main.dart`):

| File | Why |
|---|---|
| `rackmate_ui/canvas/schematic/schematic_canvas_screen.dart` (707 L) | Could only ever draw ONE anonymous placeholder box. See the two root causes below. |
| `rackmate_ui/canvas/schematic/sugiyama.dart` (324 L) | Dead and crashing — `_phase1LayerAssign` mutates `queue` inside `for (final node in queue)`, so it throws `ConcurrentModificationError` on any graph with an edge. |
| `rackmate_ui/canvas/schematic/wire_drawing.dart` | `WireConnection` is a stand-in for `Link`/`Service`/`Conductor`, which M2 defines properly (CR-008/010/011). Relocating a stand-in into `rackmate_core` would have inverted the discipline. |
| `rackmate_ui/schedule/schedule_screen.dart` | Renders `document.links`, and no code path can create a `Link`. Its `_EmptyState` told the user to "Create links in the Schematic tab" — a tab that cannot create one. |

**Relocated instead of deleted** (with 72 new tests, in the same stage — see
`rackmate_core/test/symbol_layer_test.dart`, `symbol_hit_test_test.dart` and
`rackmate_export/test/symbol_layer_pdf_test.dart`): `symbol.dart` →
`rackmate_core/draw/scene/symbol_layer.dart` and `hit_test.dart` → `symbol_hit_test.dart`, per
CR-071 and docs/05 §3's "drawn by `symbol_layer.dart` in `rackmate_core/draw/` and replayed by
both backends". They are the only part of the deleted work that had salvage value, and the
export-side test is the one that could not have been written before the move.

**THE TWO ROOT CAUSES, recorded so nobody re-debugs them.** Twelve consecutive `fix:` commits
went at this and none of them touched either path.

1. *One placeholder symbol.* The document never reached the schematic. `main.dart` constructed
   the scene inline with `fragments: {}` and `rackId: ''`, both hardcoded — there is no
   app-level document, because `RackCanvasScreen` seeds and owns the only one privately.
   `_autolayoutSymbols()` then branched on `scene.fragments.isEmpty` and MANUFACTURED a single
   `RenderedSymbol` with dummy `in1`/`out1` ports, which `symbol.dart` drew as `'P${port.id}'`
   — the literal `Pin1` / `Pout1` on screen. The else-branch was no better: it skipped keys
   matching `startsWith('rack-')`, a prefix that matches nothing the scene builder emits, and
   emitted the same dummy box for everything else. There was no code path in that file capable
   of rendering a real device, so wiring a real scene in would still have shown grey boxes.
2. *No toolbar.* `_RenderSchematicCanvas.paint(context, offset)` filled its background with
   `DBox.fromLtwh(0, 0, size.width, size.height)` — ignoring `offset`, while threading it into
   the symbol draw two lines later. The object opts out of its own layer
   (`isRepaintBoundary => false`), so `context.canvas` is in the enclosing layer's space; the
   `Column` paints the toolbar first and the canvas second at `offset ≈ (0, 48)`, and the grey
   rect landed on top of the toolbar band. `render_rack_canvas.dart:225` has always done this
   correctly, by pushing `Matrix4.translationValues(offset.dx, offset.dy, 0)` first.

   Neither was a constraints problem, which is why `LayoutBuilder` wrapping and repeated
   `setState` never converged. (`updateRenderObject` was also a structural no-op: every setter
   guarded on `identical()` against the same instance the State passed on every build.)

**What the tabs show now.** `UnbuiltView` (`rackmate_ui/src/shell/unbuilt_view.dart`) — a
milestone badge, `Schematic — not built` / `Schedule — not built`, a sentence on what is
absent, a sentence on why the tab is in the strip, and the governing docs. **No control of any
kind**, enforced by two independent tests rather than by review.

**THE DOC CONFLICT, and the ruling taken.** docs/09 M1 says "an empty Schedule tab that
explains it is coming is a lie, so the tab does not exist yet"; docs/05 §12 line 780 says "The
v1 tab strip shows three tabs: Rack, Schematic, Schedule". Read strictly against each other,
one removes the tabs and the other requires them. **The strip keeps three tabs and the two
unbuilt ones say they are not built.** The reasoning: what M1 forbids is a view that LOOKS
finished and is empty — a zero-row schedule table asserts "you have not wired anything", which
is false when the truth is "this build cannot wire anything". A tab whose first line is *not
built* asserts nothing untrue. If the owner reads M1 strictly, the two tabs come out of the
strip entirely and `UnbuiltView` goes with them; that is a one-line change in `main.dart` and
the tests would need re-pointing, so it is worth an explicit ruling rather than a silent
default.

**Debug cruft removed in the same pass:** 8 `print()` calls (6 under `schematic/`, 2 in
`main.dart`), the uncommitted `Container` wrapping `SchematicToolbar` commented "Debug border
to verify toolbar visibility", its amber/orange decoration, and
`print('LayoutBuilder received constraints: …')`. Two source-level gates now hold that line —
`packages/rackmate_ui/test/no_print_test.dart` and `apps/rackmate/test/no_print_test.dart`, in
the same shape as `rackmate_core`'s `no_flutter_import_test.dart`. `avoid_print` DID fire on
all eight; it fires at INFO in a project that carries ~210 of those by design, so it was
invisible.

**Deliberately NOT done here, and honest about it:**

* **The schematic does not render devices, and this stage did not try.** It cannot until an
  app-level `DocumentController` exists that sibling tabs can read, and that belongs with
  roadmap item #10 (atomic save, autosave, recovery, recents, the outline tree) — the stage
  that follows. Doing it here would duplicate or pre-empt that work.
* **`Ctrl+1` / `Ctrl+2` and the reserved `Ctrl+3` (docs/05 §12) are unbound.** No view-switching
  keymap exists in this app in any view; binding two of three would read as a whole keymap.
  Lands with §8's keymap pass.
* **docs/05 §3's gu-denominated sizing is still not implemented** in `symbol_layer.dart` — the
  20 gu minimum width, 6 gu header, 2 gu pin pitch and `kBankCollapseThreshold = 8`. The shape
  of the formulas is honoured in caller-supplied units; converting `kGridUnit` to diagram
  points needs a schematic scene builder's scale anchor, which does not exist. Flagged in that
  file's header.
* **`.clinerules/editing.md`** (added by the off-discipline stage, commit `6db8131`) still
  instructs whoever reads it to "Make a commit after every task … just commit to the main
  branch." It is almost certainly how 19 commits including 12 thrashing `fix:` commits landed
  directly on `main`. It was not acted on and was not removed — that is the repo owner's call,
  but it should be made.

**Mutation testing, scoped honestly.** Deleting a file cannot be mutation-tested, so the
discipline applies only to the honest-panel behaviour that replaced it. Ten mutations were run
against it and **all ten were killed on the first pass**; the two worth recording are that
drawing a single circle inside `UnbuiltView` fails
`paintsExactlyCountTimes(#drawCircle, 0)` (proving that assertion is live rather than vacuous),
and that a button wrapped in `ExcludeSemantics` is caught ONLY by the widget-subtree check —
which is why both that check and the semantics check exist.

---

## 3c. The chip strip, the Staging Bin chip, and one repaired test

Same off-discipline stage as §3b, different files: three M1 features that were worth keeping
and shipped untested. All three now have tests; all three had real defects.

### The chip strip (§5, roadmap item 7) — the number was never computed

`RackMetricsRow` displayed `12/12U · 0 free` on a 12 U rack holding 5 U. The widget was not
miscomputing: **its one call site passed the numbers as literals** —
`ruFree: 0, // TODO(M1): wire to actual computed free RU`, and the same for weight, VA and
outlets — and the widget derived USED from the FREE it was handed, so `ruFree: 0` printed the
rack as completely full. Nothing anywhere computed free RU.

What shipped instead:

* **`rackmate_core/lib/src/derived/totals.dart`** — `computeRackRollups(rack, devices,
  templates, face) -> RackRollups`, the first file in the `derived/` directory
  docs/03-architecture.md reserves for it. Pure, argument-driven rather than
  `RackDocument`-driven, so the persistence stage's `DocumentController` can arrive without
  touching it. Counts DISTINCT occupied RU (overlapping placements — an `RCK-001` state the
  model permits — count once) clamped to `[1, heightU]` (a device hanging past the top
  contributes only the slots that exist). Membership follows shelf-host chains with a visited
  set, so a corrupt file's cycle terminates instead of hanging the UI thread.
* **`Rollup<T>`** carries `value` (`null` = unknown), `knownCount` and `unknownCount`. The rule,
  in one place for all four rollups: a total is `null` **iff** at least one device contributed
  and none supplied a value; a rack with no contributors at all reports a genuine zero, because
  an empty rack really does weigh nothing extra. `T` is unbounded rather than `T extends Object`
  because `Mass` is an extension type and its only supertype is `Object?`.
* **`MassFormatting.toPoundsValue`/`toKilogramsValue`** (units/unit_formatter.dart) — the
  unit-less forms, so the strip's `148/200 lb` does not re-derive the µg conversion. The
  suffixed forms now delegate to them, so the two spellings cannot drift.
* The strip **moved into the rack header**, per §5's "20 px, in the rack header" and §2.1's
  "32 px header, sticky / 20 px chip strip". It was a `Positioned.fill` + `Align.bottomCenter`
  36 px OPAQUE bar over the bottom of the canvas — absorbing every pointer event aimed at the
  lowest RUs, which no test covered — and it had pushed the status-message stub from
  `bottom: 12` to `bottom: 48` to get out of its way. Both undone. It is a SIBLING of
  `RackHeaderBar` in the same `Positioned`, not a child of it, because that widget is flagged
  mid-rework above and a fifth concern threaded through it would collide with the pending
  `⚠n` rollup.
* The widget now takes the whole `RackRollups` rather than four loose scalars. That is the
  structural half of the fix: a widget that accepts loose numbers invites a call site to
  invent them, which is exactly what happened.
* Fixed on the way: every chip's text used `colorScheme.onPrimaryContainer` regardless of its
  background, and any chip whose value was `0` was HIDDEN — so "this rack draws no power" and
  "nobody has measured this rack" rendered identically.

**Deviations from §5's literal line are listed in §2's §5 entry above**, not here, so they sit
next to the requirement they depart from.

### The Staging Bin chip (§3.1's escape hatch, roadmap item 4) — three defects, and a lie

docs/04 §3.1 wants "Dragging outside any rack shows the ghost at 40 % with a `Release to add to
Staging Bin` chip; dropping there creates a `StagedPlacement`". The overlay that shipped showed
that chip. **Releasing there does nothing**, and still does: `StagedPlacement` is fully modelled
and codec-round-tripped, but no command produces one and no surface lists the bin, so a device
dropped there would vanish with no way to retrieve it — strictly worse than a refusal. Building
the bin properly (a command, a query surface, the `↩ Return to RK-1 U21` chip of CR-032, and the
shrink modal's option 2) is its own stage and was not in this one's scope.

So the ruling for this stage is the same one §3b applies to the tabs: **mark it unfinished
rather than half-fake it.** The chip now reads `Staging Bin — not in this build` /
`Releasing here will not place <device>.`, and release reports the same refusal through
`StatusMessageController` instead of silently doing nothing. **The shrink dialog's Staging Bin
option stays DISABLED with its existing honest reason** — nothing about this stage makes it
deliverable, and enabling it would re-introduce exactly the promise this chip stopped making.

The three mechanical defects, all now tested:

1. **A leaked `OverlayEntry`.** `RackCanvasScreen.dispose()` removed the palette-drag, move-drag
   and resize overlays and not this one — the exact bug class the three comments beside them
   were written to prevent. `_cancelPaletteDrag` (the `Esc` path) had the same hole. Note that
   an assertion about the CHIP cannot catch the second one: `Esc` resets the controller, which
   alone makes the builder return an empty box, so the test asserts `find.byType(
   StagingBinOverlay)` is gone — the entry, not merely its output. The first version of that
   test SURVIVED its mutation for precisely that reason and was strengthened.
2. **No `Positioned`.** It was inserted into the root overlay unpositioned, so its `Material`
   stretched to fill the window — a full-screen elevated panel flashing over the app on every
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
surface starts. Each copy the step actually claims is now asserted where it lives — one inside
the palette `ListTile`, one inside the cursor card, located by the new public
`kDragCursorCardKey` — plus the position assertion the test's own name promised and never made.
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
strengthened** — the `Esc` case in defect 1 above. The mutations that matter most: `ruUsed` →
`ruFree` in the RU chip (the original bug, killed by six assertions); unknown weight rendering
`0` instead of `—`; a superscript on a fully known rollup; VA falling back to `typicalWatts`;
`StagedPlacement` counted as loading a rack; the shelf-host chain not followed; removing the
`_removeStagingBinOverlay()` call from `dispose` and from `_cancelPaletteDrag`; dropping the
chip's `Positioned`; removing the release-refusal status message; and the cursor card losing
either its name or its scoping key.

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
3. **Rack configuration UI** (§4) — **substantially done** (uncommitted, passes 1 and 2 of
   three): the inspector, the rack header, presets, the compaction preview, and the inspector's
   height field all ship. **Pass 3 remains**: the header stepper's 400ms-then-8/s hold-repeat,
   the drag-the-top-edge gesture with its live "24U (+3)" readout and real-time red hatch, and
   the shrink-below-occupancy modal. Still needed before a user can create a rack that isn't
   hardcoded (multi-rack + the new-rack dialog are their own stage, see §3a).
4. **~~Chip strip~~ + Rack Vitals + validation rules** (§5) — the **chip strip is done** (§3c);
   what remains is the Vitals panel and the first of the 27 v1 DRC rules
   (`derived/validation.dart` still doesn't exist in any package, and the rack header's `⚠n`
   rollup waits on it). `derived/totals.dart` now exists and is the shape the rest of
   `derived/` should follow: pure, argument-driven, and returning `null` for unknown.
5. **Non-device occupants + shelves + 0U** (§6).
6. ~~**Compaction** (§3.6).~~ **Done** — shipped with the rack-configuration stage (passes 1
   and 2), since the shrink modal's option 1 needs the planner anyway.
7. **Naming/designator UI + idformat wiring** (§7).
8. **Persistence wiring + starter projects** (roadmap item 10) — needed regardless of interaction
   completeness, since the exit criterion requires opening/saving real files.
9. **Minimal PDF exporter** (roadmap item 9) — the rendering spine already exists; this is sheet
   assembly on top of it.
10. **Remaining keymap + accessibility + empty states** (§8/§9) — can land incrementally
    alongside any of the above rather than as one dedicated pass.
