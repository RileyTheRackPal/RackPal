I'll review this design set. Let me start by understanding the actual environment, the claimed SDK versions and package availability are load-bearing for several findings.Versions check out. Let me verify the load-bearing package and API claims.All PDF APIs verified real. Now the highest-risk claims, rendering backend behavior and platform status.Both confirmed. Let me verify two API claims that specific design decisions rest on.I verified the environment and the load-bearing API claims before writing. Here is the review.

---

# RackMate Design Review: Technical Feasibility & Engineering Risk

**Verified against the live environment:** Dart 3.12.2 / Flutter 3.44.4 stable, Windows 11. Repo `C:\Users\riley\Documents\Projects\Vibecoding\RackMate` is empty except for `.editorconfig`, `.gitattributes`, `.gitignore`, `docs/`.

**API claims I checked and found correct** (credit where due, this design set has a much lower hallucination rate than typical):

| Claim | Status |
|---|---|
| `pdf ^3.13.0`, Apache-2.0, publisher `nfet.net` | ✅ real, current, correct license |
| `PdfGraphics.drawShape(String d)`: "Draw an SVG path" | ✅ real, exact signature as described |
| `PdfGraphics.setLineDashPattern([List<num>, int phase])` | ✅ real |
| `PdfFont.stringMetrics(String, {double letterSpacing})` → `PdfFontMetrics` | ✅ real |
| `PdfGraphics.setTransform(Matrix4)`, `saveContext`/`restoreContext` | ✅ real |
| `flutter_riverpod ^3.3.2` | ✅ real, current |
| `Picture.toImageSync(int, int)` | ✅ real |
| Impeller not yet default on Windows | ✅ correct as of Flutter 3.44 |

**The one API claim that is shakier than stated:** "Skia kerning disabled to match" (pdf §6.7). There is no first-class API for this. The only route is `FontFeature.disable('kern')`, and the design does not mention that standard ligatures (`liga`) are also on by default and also affect advances. Achievable, but it is two feature flags plus a test, not a checkbox.

Findings ranked by severity.

---

## SEV-1: Blocking

### 1. The five documents specify **three mutually incompatible base units**, and one of them contains an arithmetic error

**Risk:** The unit base is the single hardest thing to change after ship. It is in the file format, the router, the hit-tester, every codec, and every golden fixture.

**Evidence:**

| Document | Base unit |
|---|---|
| data-model §3.7 | `Len` = **int64 nanometres** |
| architecture D3 | **hundredths of a mm (10 µm)**, and explicitly rejects tenths-mm as "not exact" |
| ux-rack (constants + Appendix) | `int usableDepthTenthMm`, `depthTenthMm`, `xOffsetTenthMm`, **tenths-mm** |
| ux-schematic §1.1 | "Everything is stored as `int` **tenths-of-a-millimetre**" |

Mass diverges too: data-model uses `Mass(int ug)` micrograms; ux-rack uses `weightCapacityGrams` / `weightGrams`.

The schematic coordinate system is specified three incompatible ways: data-model says integer **grid units at 1 gu ≡ 2.54 mm** with 1/64 sub-offsets; ux-schematic says **tenths-mm on a 2.5 mm grid**. Those are different pitches *and* different storage.

Two of these are provably wrong on their own stated criterion:

- **architecture D3 is wrong.** It justifies hundredths-mm as exact, but the EIA inter-panel clearance the data-model doc specifically calls out, 1/32 in = 0.79375 mm, is **79.375 hundredths-mm**, not an integer. D3's own exactness argument fails on the exact case it was written to handle. Only the nanometre choice survives it (793,750 nm).
- **ux-schematic §5.4 contains a hard arithmetic error.** It states `heightU × 444` tenths-mm and calls it "EIA-310 1U = 44.45 mm = 444 tenths, **exact: no rounding anywhere in the vertical axis**." 44.45 mm is **444.5** tenths. Over a 45U rack that is 2.25 mm of accumulated error, which is visible on a dimensioned print and would be caught by an installer, not by you.

**Mitigation:** Pick **int64 nanometres** (data-model is right, and its 25,400,000 nm/inch argument is the only one that holds for every imperial fraction to 1/1000 in). Do a mechanical sweep of all five documents before a line of code is written. Define `Len`, `Mass`, and the schematic `Pt` exactly once in `rackmate_core/units/` and make every other document reference it rather than restate it. Add the 1/32-in clearance and the 45U-stack accumulation as unit tests on day one; they are the two cases that discriminate between the candidate units.

---

### 2. Four more direct contradictions between the architecture doc and the others

**Risk:** Each is a decision two subsystems will implement differently, discovered at integration.

| # | Contradiction | Which is right |
|---|---|---|
| **2a** | **Y-flip.** pdf decision #10: "Global Y-flip in the PDF adapter, **not per-coordinate**, because the interface exposes `rotate`/`transform`." architecture §6.6: "Use **per-coordinate** flipping (`_y(y) => _h - y`) rather than a global `scale(1,-1)`." | **pdf doc.** Per-coordinate flipping is only valid for an axis-aligned, rotation-free interface. architecture §6.6's own `DiagramCanvas` declares `void rotate(double radians)` and `SheetItem` has `rotationQuarterTurns`. A rotation composed with per-coordinate negation is not a valid transform, rotated text and rotated 0U PDU labels will come out mirrored or mis-sheared. architecture §6.6 is internally inconsistent with the interface three lines above it. |
| **2b** | **Route caching.** architecture §5.2 specifies a `RouteCache` with per-connection incremental invalidation and an `ObstacleField`, "~15–40 ms cold." ux-schematic §2.6: "**Do not build incremental-reroute machinery in v1.** A full deterministic recompute is both cheaper than the invalidation bookkeeping." | They are describing **two different routers**. architecture's is an obstacle-avoiding pathfinder; ux-schematic §3.1's central thesis is "RackMate **never needs a general orthogonal router**" because layering makes gutters empty. Resolve explicitly: if you take the Sugiyama+channel router (you should, the interval-graph-colouring argument is genuinely good), then delete `ObstacleField` and `RouteCache` from the architecture and the `router.dart # obstacle-aware` comment with it. |
| **2c** | **Revision monotonicity.** data-model invariant #6: "`Project.revision` is **strictly monotonic** across the life of the document and **never decreases** on save." architecture §7.4: undo "**restore**[s] the revision they were recorded at rather than incrementing it… This means `revision` is **not strictly monotonic**." | **architecture**, on the UX (undo-to-clean is correct behaviour), but it violates a stated invariant that the sync design depends on. Fix by separating the two counters properly: `revision` = dirty-tracking, non-monotonic; `sequence` = strictly monotonic sync cursor, never decremented. architecture mentions `sequence` in one sentence; promote it to the model and update invariant #6 to name it. |
| **2d** | **Structure device kind.** data-model invariant #24 requires a structure device always has `UnplacedPlacement`. ux-rack's `Placement` has `String? rackId; // null => Staging Bin`, a completely different, non-sealed shape with `lastRackId`/`lastBottomU` fields that do not exist in the data model. | data-model's sealed union. But ux-rack's Staging Bin is a **real product requirement** with no representation in the data model, `UnplacedPlacement` has only a `schematicHint`, no `lastRackId`/`lastBottomU`, so "Return to Rack A U21" is unimplementable as specified. Add those two fields. |

**Mitigation:** These docs were clearly written in parallel by different passes. Before implementation, do a reconciliation pass producing one **normative** document per subsystem, with the others explicitly marked as non-normative UX intent. Right now every doc reads as normative and they disagree.

---

### 3. The file-size budget is off by 3–6×: and it invalidates the "plain pretty JSON" decision

**Risk:** The plain-JSON-for-git-diffability decision (persistence §7.1, data-model §4.1) is justified by "the ~3× size penalty is irrelevant at 500 KB." The 500 KB figure does not survive contact with the design's own port model.

**Evidence:** Ports are first-class entities with their own UUID, `deviceId`, `designator`, `overrides`, two booleans, and a full `EntityMeta` (two microsecond ISO timestamps, `updatedBy`, `localRevision`). Pretty-printed with 2-space indent and sorted keys, one `Port` entry is ~450–500 bytes:

```json
    "0190e3c1-7a2f-7c9d-8b11-a0f2c4e51d33": {
      "deviceId": "0190e3c1-7a2f-7c9d-8b11-a0f2c4e51d34",
      "designator": "J2401",
      "id": "0190e3c1-7a2f-7c9d-8b11-a0f2c4e51d33",
      "meta": {
        "createdAt": "2026-07-18T09:22:00.000000Z",
        "localRevision": 7,
        "updatedAt": "2026-07-18T15:02:11.000000Z",
        "updatedBy": "inst-7f2c"
      },
      "orphaned": false, "overrides": {}, "reserved": false,
      "templatePortKey": "hdmi_out_1"
    },
```

- At the **target** of 2,000 ports: **~1.0 MB for ports alone**, before devices, links, nets, sheets, notes, or registries.
- At the stated **hard cap** of 6,000 ports: **~3.0 MB** for ports alone.
- Plus embedded `TemplateSnapshot` bodies: a 24-port patch panel snapshot carries 48 `PortDef`s at ~400 B each ≈ 20 KB per template; 30 distinct templates ≈ **600 KB of embedded templates**.

The catalog makes this worse than average, not better: N09 is a 48-port patch panel = **96 ports on one device**; V03 is 51 ports; A03 is ~50.

Knock-on: architecture §7.3 says "Serialize on the main isolate (~15 ms at 500 KB)". At 2–3 MB that is ~60–120 ms of encoding **plus** pretty-printing **plus** key sorting, on the UI thread, against a stated ≤150 ms save budget.

**Mitigation, in preference order:**
1. **Do not materialise unconnected ports as document entities.** This is the real fix. `Port` only needs to exist in the file when it carries project state (a connection, an override, a designator the user pinned, an IP, a bus address). Everything else is derivable from `TemplateSnapshot.ports` by key-join at load. This drops a typical file by ~70% and costs you nothing except a `resolvePort(deviceId, portKey)` helper you need anyway. The data-model's justification for eager ports, reserve-ID allocation (§3.9), is satisfied by storing the *allocation watermark* per device, not 6,000 placeholder entities.
2. Drop `EntityMeta` from `Port`. A port's `updatedAt` has no consumer in v1 and the sync design (§5.5) already declares device+ports a **single conflict unit**, so per-port LWW metadata is dead weight by the design's own conflict model.
3. Keep pretty JSON (the diffability argument is good), but re-justify it against the *real* number, and move serialization to `Isolate.run` for explicit saves too.

---

### 4. `measureText` returns `Pt`: the abstraction leaks at the baseline, guaranteeing vertical text divergence

**Risk:** This is the specific place the shared screen/PDF abstraction breaks, and it is the one the design does not anticipate. The pdf doc correctly identifies §6.7 as "the one thing to get right" and then gets it half right.

**Evidence:** The interface is

```dart
Pt measureText(String s, TextSpec spec);
```

A `Pt` carries width and height. Text positioning needs **ascent** and the **baseline**, and the two backends anchor differently:

- `PdfGraphics.drawString(font, size, s, x, y)`, verified signature, positions at the **baseline**.
- Flutter's `TextPainter.paint(canvas, offset)` positions at the **top-left of the line box**.

Converting between them requires ascent, which the interface does not expose. So each backend adapter will independently derive a baseline from `height`, one using `PdfFontMetrics.ascent`, the other using `TextPainter.computeDistanceToActualBaseline` or a fudge of `height × 0.8`. They will not agree. The result is text that sits a fraction of a line off between screen and print, uniformly, everywhere, which is invisible in code review, invisible in a display-list golden (the golden records the anchor point, not the resolved baseline), and glaring on a printed drawing next to a leader line.

This is worse in the label-dense places: port labels 1U inboard of a body edge, tag pills anchored at track tops, the RU ruler's right-aligned per-U labels, silkscreen text on the rear-panel view.

**What the design got right, and I want to be clear about this:** routing `measureText` on *both* backends through `PdfFont.stringMetrics` **does** achieve layout parity. The scene builder gets identical numbers, so symbol widths, pill sizes, track counts, and sheet fitting are identical. The residual is bounded: Skia will *paint* a string a fraction of a percent wider than PDF metrics predict (kerning + ligature delta), so screen text can overflow a box that fits in the PDF. That is a cosmetic, screen-only, bounded error and it is the correct trade. Don't let finding #4 be read as "the abstraction doesn't work"; it works; it's under-specified at one point.

**Mitigation:**
1. Change the signature to return a metrics record, not a point:
   ```dart
   TextMetrics measureText(String s, TextSpec spec);
   // TextMetrics { double width, height, ascent, descent; }
   ```
   Populate from `PdfFontMetrics` on both backends. Make `TextSpec` carry an explicit `TextAnchor` (`baselineLeft`, `centerCenter`, `topRight`, …) and resolve the anchor **in the shared scene builder**, so both adapters receive an already-resolved baseline point and neither gets a chance to guess.
2. Add the parity test the pdf doc's build step 3 already calls for, but assert on **baseline y**, not just bounding box; that is the assertion that would catch this.
3. Add `FontFeature.disable('kern')` **and** `FontFeature.disable('liga')` to the Flutter `TextStyle`, and add a test that measures a kerning-heavy string (`"AV Wa To Ty"`) on both backends and asserts agreement within 0.5%.

---

### 5. There is no roadmap, and the implied scope is 16–22 months solo

**Risk:** The brief asked me to sanity-check effort. There is **no schedule anywhere in the five documents.** The only estimate in the entire corpus is pdf §11: "Steps 1–5 are roughly a week." Everything else is unpriced. A design set this detailed with no cost attached reliably produces a build that stalls at 40%.

**Evidence: bottom-up sizing, one experienced engineer, implementation only, no design iteration and no bug tail:**

| Area | Weeks |
|---|---|
| Workspace, core model (~40 entity types), hand-written codecs both ways, migrations, fixtures | 3–4 |
| Command / Transaction / UndoStack + property tests | 2 |
| Viewport, hybrid `RenderRackCanvas`, device widgets, RU snapping | 3–4 |
| `DiagramCanvas` + scene builder + both backends + parity harness | 3 |
| **Rack elevation editor to the ux-rack spec** (staging bin, shrink dialog, compact/auto-arrange with preview, shelves as containers, 0U gutters, marquee, ~60 shortcuts, a11y outline tree) | **6–8** |
| **Device builder** (virtualized grid, Quick-Add DSL, label pattern engine, archetype generators, column packs, TSV paste, footprint auto-layout, 3-pane live preview) | **6–8** |
| Seeded catalog authoring: 62 templates with realistic weight/depth/wattage | 2 |
| **Schematic editor** (symbols, banks, unit splitting, vector pins, wire state machine, chain/multi-draw, buses, bundles, net labels, focus/isolate/trace, filters, layers, minimap, search DSL, connections table) | **10–14** |
| Router (Sugiyama + channel routing + crossing sweep + preview-diff with 3 variants) | 4–5 |
| Structure editor (location tree, matrix entry, command DSL, CSV import w/ synonym mapping, drop table, bundles, label templates) | 4–5 |
| DRC: ~70 rules incl. graph reachability, RF cascade budget, PoE budget, NEC derates | 4–6 |
| PDF export (8 sheet types, furniture, title/revision blocks, pagination, sheet planning, cross-refs, isolate, cancel, preview) | 5–6 |
| Rear-panel view (which doubles as the device builder's output surface) | 3 |
| File lifecycle: autosave, recovery, recents, close interception, atomic save | 1.5 |
| i18n plumbing, theming, a11y across all views | 3 |
| Test infra, CI, goldens, perf harness | 2 |
| **Total** | **62–83 weeks** |

That is **16–22 months of pure implementation**; with normal overhead, 24+ months to a shippable v1.

**Mitigation: a v1 that is ~5–6 months and still demos the wedge:**

| Cut | Keep |
|---|---|
| Device builder (ship catalog + "duplicate & edit" field overrides only) | Seeded catalog, 62 templates |
| Multi-sheet (all of it: see #9) | One schematic sheet |
| Auto-layout preview variants, `Tab`-cycling | One deterministic layout + pin/unpin |
| Buses, bundles, unit splitting, vector pins | Drawn wires + net labels above K layers |
| `SignalRoute`, `Circuit`, `SheetItem` rotation, `RevisionEntry` | `Link` + `Net` + `Conductor` |
| ~58 of the 70 DRC rules | The 5 blocking + ~12 highest-value (SIG-001, DIR-001/003, RCK-001/002/003, LEN-001, PWR-001/003, CON-001, NET-001, ELE-003) |
| Structure bundles, CSV import, matrix entry | Flat drop table + one label template |
| Rear-panel view |: |
| 8 PDF sheet types | 2: diagram + schedule |

The `DiagramCanvas`/display-list architecture, the command stack, the unit model, and the file format all stay; those are the "do it now or pay 10× later" items and the architecture doc is right to say so.

---

## SEV-2: High

### 6. Rules-as-data cannot express the rules in the catalogue

**Risk:** A declarative predicate AST is specified (`CompatibilityRuleDef.predicate`, "JSON-serializable"), and the rule catalogue contains rules that are not expressible in one.

**Evidence:** The only example given is trivial:
```json
"predicate": { "and": [ {"endpointSignalFamily": "video.hdbaset"},
                        {"otherEndpointSignalFamily": "net.ethernet"}, ... ] }
```
Now look at what else is in the catalogue:

- `NET-003` "Dante/AES67 endpoints with **no network path** between them", graph reachability over a filtered subgraph.
- `NET-004` "AVB endpoints **traversing** a non-AVB/TSN switch", path enumeration with a per-hop predicate.
- `ELE-008` "RF cascade insertion loss exceeds the budget from source to the worst drop", weighted traversal with per-device loss models and a max over leaves.
- `PWR-001` / `NET-001` / `ELE-005`, **aggregation** over a circuit / switch / net.
- `ELE-004` "parallel low-Z speakers drop the amplifier's load below its rated minimum", parallel impedance arithmetic over a net.
- `BUS-005` Cresnet, "**two independent limits, two findings**" from one rule.

None of these fit a boolean predicate tree. In practice you will build the AST *and* a native escape hatch, and ~20 of 70 rules will take the escape hatch, two rule systems, two debuggers, two sets of tests.

The stated benefits are also unreachable in v1: "a user can author a rule for a proprietary Cresnet variant"; **there is no rule-authoring UI in any of the five documents.**

**Mitigation:** Rules are **Dart functions** in a registry keyed by `String ruleId`:
```dart
typedef Rule = Iterable<Finding> Function(RuleContext ctx);
final Map<String, RuleDef> kRules = { 'SIG-001': RuleDef(severity: error, run: _sig001), … };
```
Keep as **data**: the catalogue metadata (id, message, rationale, remedyHint, defaultSeverity, userAcknowledgeable), per-project severity overrides, acknowledgements with reasons, and forward-compat on unknown `ruleId`s in `AckedFinding`. You lose only user-authored rules, which have no UI. If catalog-shippable rules genuinely matter later, add a data-driven layer for the *simple* connector/signal-compatibility subset only, that subset really is a lookup table and doesn't need an AST at all.

---

### 7. The label cache is sized ~4× too small and the label count is ~5× too low

**Risk:** The `TextPainter` LRU is the single named non-negotiable optimisation (architecture §6.4), and its sizing is derived from a wrong input.

**Evidence:** architecture §6.4 computes "200 devices × ~8 labels = 1600 labels" and sizes the LRU at **2,000 entries**. But:

- The catalog's own devices average far more than 8 labels. N09 patch panel: **96 ports**. V03 matrix: 51. A03 AVR: ~50. C02 IR block: 21.
- ux-schematic §1.3 draws **two text runs per pin**: designator *and* label (`J01  HDMI IN 1`).
- Plus per-device header (refdes + name + metadata line = 3), plus **tag pills at both ends of every run** (ux-schematic §1.4: "Every drawn run carries a tag pill at **both ends**"), each pill containing `{tag} · {type} · {length}`.

At 200 devices averaging 20 ports: 200 × 20 × 2 = **8,000 port labels**, + 600 header runs, + 1,000 wires × 2 pills = **2,000 pill runs**. Call it **~10,000 text runs** against a 2,000-entry cache.

An LRU that thrashes is worse than no cache: you pay the miss *and* `TextPainter.dispose()` on every eviction, and disposal releases a native `ui.Paragraph`, so you get GC pressure and native churn in the paint path.

**Mitigation:**
1. Size the cache from the real figure: **12,000 entries**, and measure. A `TextPainter` with a laid-out paragraph is ~1–2 KB, so 12k ≈ 12–24 MB, comfortably inside the 350 MB budget.
2. Better: exploit the domain. Port labels are drawn from a **small set of repeated strings** (`"1"`…`"48"`, `"HDMI IN 1"`…`"HDMI IN 8"`, `"J01"`…). Key the cache on `(text, styleId, quantisedScale)` and the *distinct* count collapses to low thousands even at the hard cap. The design already quantises scale to a ladder, good, it just under-counted distinct strings.
3. Enforce the LOD gate hard: ux-schematic §1.3 suppresses designators below 0.80× and all labels below 0.40×. At fit-to-sheet zoom you should be drawing ~0 text runs. Make that a test, not an intention.

---

### 8. The 8 ms commit budget is not achievable with the wire-layer rebuild included

**Risk:** "Commit a command (mutate + invalidate + reroute + revalidate + repaint) ≤ 8 ms" (architecture §10.2). The repaint term is under-counted.

**Evidence:** The budget's own arithmetic ("1000 wires × ~4 µs ≈ 4 ms") counts one stroked polyline per wire. The actual wire layer per ux-schematic §1.4 is, per run: polyline + dash synthesis + arrowhead fill + **two tag pills** (rounded rect + outline + text) + junction dots + hop arcs at every crossing. That is ~8–10 draw ops per wire, not 1 → **~10,000 ops**, plus 2,000 cached-text blits, plus `dashPath` re-synthesis on the dashed domains.

Replay of that cached `ui.Picture` is fine. But **rebuild** is what happens on commit, and rebuild is Dart-side command construction for 10,000 ops. That is 10–25 ms, not 4.

**Mitigation:**
1. Split L3a into **per-domain sub-pictures** (8 domains). An edit to one HDMI run rebuilds the digital-video picture only (~1,200 ops), and the other 7 replay unchanged. This is nearly free; you are already batching `Path`s by colour class.
2. Move tag pills into their own picture keyed on `(wires, viewport-decade)`, pills are LOD-gated and screen-space-ish, and they are half the op count.
3. Re-baseline the budget honestly: **commit ≤ 16 ms** (one frame) is the achievable target, with ≤ 8 ms reserved for the non-paint terms. Nothing about the product requires sub-frame commits.
4. Set the perf harness to measure *op count* per layer, not just wall time, op count is the stable CI signal; wall time on a shared runner is not. The design already wisely makes the perf job warn-only for 3 months.

---

### 9. Multi-sheet is a v2 feature stack sitting on the critical path to the first PDF

**Risk:** The default schematic partition is **7 sheets** (ux-schematic §4.5). That means the first end-to-end PDF requires the entire multi-sheet subsystem.

**Evidence:** What "multi-sheet by default" actually pulls in: per-sheet symbol positions (`SheetItem`), per-sheet collapse state, per-sheet waypoints (`Link.waypointsBySheet`), **automatic unit splitting by domain** (a device appearing on 4 sheets as 3 bodies sharing one refdes), off-sheet connector pairs, **zone references** (`↗3/B4`) that must be recomputed whenever anything moves, cross-sheet connector-count minimisation via **graph min-cut**, sheet navigator, contact-sheet view, and, in the PDF doc, net partitioning, match lines, and key plans.

Meanwhile ux-schematic §4.6's own density table says **0–40 connections = one sheet, draw everything.** A residential rack at the design's own target scale is 50–300 connections, and the 40–80 band is "one sheet + collapsed devices + auto net labels."

**Mitigation:** v1 = **one schematic sheet**, with the auto net-label degradation rule (§1.5) as the density valve. That rule is genuinely good and it does most of the work multi-sheet does. Ship `Sheet` in the data model (so the file format doesn't need migrating) but expose exactly one. Add domain filtering (§4.1), it's cheap and it covers the "I can't see anything" case for the demo. Multi-sheet in 1.1, when you know from real projects which partition users actually want.

---

### 10. Library-private setters via `part of` will be genuinely painful: and `@internal` already solves it

**Risk:** architecture §2.3 rule 2: "Enforced by making entity fields private with library-private setters (`part of` the commands library)."

**Evidence:** `part of` files **cannot have their own imports**: every import must be hoisted to the library file. With ~40 entity types and ~30 command types in one library, you get one `library` declaration importing everything, and 70 `part` files that cannot be reasoned about independently. Analyzer performance degrades, IDE navigation degrades, and any file's imports become everyone's problem. This is a known-bad Dart pattern at scale.

**Mitigation:** Use `@internal` from `package:meta`, **already a declared dependency**. `@internal` on setters produces an analyzer error for consumers *outside the declaring package*, and `rackmate_ui` / `apps/rackmate` are different packages. That gives you exactly the enforcement you want with zero structural cost:

```dart
class RackDevice {
  int get ruIndex => _ruIndex;
  @internal set ruIndex(int v) => _ruIndex = v;   // error if set from rackmate_ui
}
```
Add the existing `no_flutter_import_test.dart` pattern as a second guard, a test that greps for `.ruIndex =` outside `src/commands/`. Belt and braces, no `part of`.

---

## SEV-3: Medium

### 11. `SignalRoute` has no v1 UI surface: cut it

Stored entity with N:M relations to Links and Nets, plus invariant #33 requiring path-connectivity validation on load. Its stated consumers are Dante flows, AVoIP streams, matrix crosspoints, and eARC, **none of which has a v1 editor**. The `T` Trace feature (ux-schematic §4.3) walks pass-through devices and can compute paths on demand. Rules NET-003/004 need reachability, which is also computed. **Mitigation:** delete from v1. Add in v2 alongside a Dante view. The `Link`/`Net` two-layer split (data-model §3.6) is the genuinely load-bearing part and it stands on its own, that argument is the best one in the whole data-model doc.

### 12. The dotted-path override argument is self-defeating

data-model §3.2 rejects a typed `DeviceOverrides` class because it "must be edited in lockstep with `TemplateBody` forever," then proposes a hand-maintained `TemplateBody.pathType(String)` table, which has **exactly the same lockstep requirement, minus the compiler check**, plus a runtime validation pass (invariant #15) that the typed version wouldn't need. `TemplateBody` is a fixed app-defined shape, not user-extensible; there is no forward-compat argument here (unknown *keys* are already handled by `EntityMeta.unknown`). **Mitigation:** typed `DeviceOverrides` with ~15 nullable fields covering what the UI actually exposes (name, weight, depth, wattage, per-port label). ~40 lines, compiler-enforced, and it makes the property inspector trivially bindable.

### 13. The layer-cache key omits LOD: screen and PDF diverge by construction

architecture §6.2's cache table keys each layer on epochs only. But ux-schematic §1.3 and ux-rack §2.2 both define **zoom-dependent LOD** that changes which ops are emitted. So the scene is a function of `(epoch, lodLevel)`, not `epoch`. Two consequences: the cache silently returns the wrong LOD after a zoom change, and the claim that display-list goldens "cover screen and PDF simultaneously" only holds if the golden pins the LOD (PDF exports at print LOD, screen at current zoom). **Mitigation:** make `lodLevel` an explicit parameter of `SceneBuilder.build*` and part of every cache key; golden at a fixed LOD; add one golden at print LOD specifically.

### 14. `RendererCaps` is an unbounded escape hatch

Mentioned once in the file listing (`canvas.dart # abstract interface DiagramCanvas + RendererCaps`) and never defined. The moment scene builders branch on capabilities, you have two code paths and the abstraction has already leaked. **Mitigation:** delete it. If a genuine capability difference appears, the correct fix is to lower the interface to the common denominator (which the design already does well, §6.6's "no gradients, shadows, blurs" rule is exactly right and should be stated as an invariant with a test).

### 15. Template snapshots are never refcounted: undo will leave junk in the file

Placing a device may insert a `TemplateSnapshot` into `Project.templates`. `AddDeviceCommand.revert` must remove it **only if** no other device references it. Nothing specifies this. Symmetrically, `RemoveDeviceCommand` must not orphan a snapshot another device still uses. **Mitigation:** make snapshot insertion/removal an explicit child command in the transaction, with a refcount computed from `devices.values.where((d) => d.templateRef.key == k)`. Add to the round-trip property test: after `apply; revert`, `templates.keys` must be unchanged, which the existing test (#9.2, JSON equality) already catches for free, so this is really "make sure the generator produces add-device commands."

### 16. Epoch masks are hand-declared with no verification

~30 commands × 5 epochs, hand-assigned, "when in doubt, over-declare." A wrong mask produces a stale render, the hardest class of bug to reproduce. **Mitigation:** one generic test: for each command type, snapshot all derived outputs, apply, snapshot again, diff, and assert the declared `touches` mask covers every derived output that changed. ~40 lines, catches the whole class permanently. This is the highest value-per-line test not already in the plan.

### 17. Dash phase will diverge on arcs and fillets; `dashPath` cost is on the hot path

`path_drawing.dashPath` resamples via `PathMetrics`, an approximation on curves, and allocates a new `Path` of line segments. PDF's `setLineDashPattern` is exact and applied by the rasterizer. Orthogonal segments agree; the design's **hop arcs** (r = 1.2U) and **corner fillets** (0.6U) will not, dashes land in different places on screen vs print. Also `dashPath` is O(length/dashPeriod) allocations, and the cache key is `(geometry, dash)`, so it re-synthesizes on every reroute. **Mitigation:** (a) accept the cosmetic divergence but *document* it so it isn't chased later; (b) suppress hops on dashed domains, control (`1,3` dot) and structure (`6,3`) are the dashed ones and they're also the ones where hops matter least; (c) profile `dashPath` explicitly in the perf harness before assuming the cache saves you.

### 18. `PdfTtfFont` must be constructed on the main isolate too: unbudgeted cold-start cost

`measureText` routes through `PdfFont.stringMetrics` on **both** backends (pdf decision #11), so the screen renderer needs a live `PdfTtfFont`. But `PdfTtfFont` requires a `PdfDocument` to construct, so the app must build a throwaway `PdfDocument` at startup purely to parse 3–6 TTFs for metrics. Parsing IBM Plex Sans + Condensed + Mono is real work against the **1.2 s cold-start budget**. **Mitigation:** lazily construct the metrics font on first paint rather than at bootstrap, and cache `stringMetrics` results aggressively (the same string-set argument as #7 applies). Verify the cost in pdf §11's step-1 spike, add it as a sixth spike.

### 19. Riverpod 3 has moved `ChangeNotifierProvider` to legacy

The design uses `ChangeNotifier` for `SelectionController`, `ViewportController`, `InteractionController`, plus a "`ChangeNotifier`→`Provider` adapter on `epochs.revision`." pub.dev confirms `flutter_riverpod` 3.3.2 ships a **`legacy` library section**. Not a blocker (the design consumes these as plain `Listenable`s for painters anyway, which is correct and idiomatic) but the one place it needs Riverpod integration (`_revisionProvider`) will be hand-written. **Mitigation:** verify before writing the provider layer; the hand-written adapter is ~15 lines (`Provider` + `ref.onDispose(notifier.removeListener)`). Don't import the legacy library for this.

### 20. "Sub-millisecond at N=300" is optimistic for the 6-phase pipeline

The O(N log N) analysis is right for phases 0–4. Phase 5 is a Bentley–Ottmann sweep at O((N+X) log N) where **X = crossings**, and X is not bounded by N, in a dense schematic X can approach O(N²). At N=300 with heavy crossing, X ≈ 10⁴–10⁵ → priority-queue operations with allocation in the tens of thousands. That is **5–20 ms in Dart**, not sub-millisecond. Combined with §2.6's "full recompute on every edit," this lands on the commit path. **Mitigation:** (a) cap hop rendering, above a crossing threshold, fall back to `gap` or `none` mode (the preference already exists); (b) run phase 5 lazily at paint time for the visible viewport only, not at commit; (c) measure X on a real 300-connection fixture before committing to "full recompute every edit."

---

## SEV-4: Low, but cheap to fix now

**21. Stroke caps/joins/miter aren't in `StrokeSpec`.** PDF default miter limit is 10; Flutter's `Paint.strokeMiterLimit` default is 4. At 90° orthogonal corners the miter ratio is √2 ≈ 1.41, safely under both, so this is fine *today*, and breaks the day someone adds a shallow-angle bus entry (the 45° bus stubs in §1.6 give ratio ≈ 2.6, still fine; anything under ~29° is not). Add `cap`, `join`, `miterLimit` to `StrokeSpec` now and set both backends explicitly rather than inheriting defaults.

**22. Web has no isolates: PDF export would block the UI thread.** The env has Chrome/Edge targets and `pdf` is web-compatible, so a read-only web viewer is genuinely within reach and is a nice distribution story. But `Isolate.run` is unavailable on web. One line in the export service: `kIsWeb ? buildDocument(req) : Isolate.run(() => buildDocument(req))`, and accept the jank on web.

**23. The touch intent layer is specified in ux-rack and absent from architecture.** ux-rack §1.2 defines a `PointerDeviceKind`-agnostic `CanvasIntent` layer as "the architectural rule that keeps touch open." architecture's `input/pointer_router.dart` is described as "Listener: wheel/trackpad/buttons" only. The brief explicitly requires that the architecture not preclude touch. Reconcile, the intent layer is the right call and costs nothing if built first.

**24. The round-trip invariant tests the wrong property.** Invariant #16 asserts `read(write(read(x))) == read(x)` (semantic round-trip). What prevents spurious git diffs and lying dirty-flags is `write(read(bytes)) == bytes` (**byte** round-trip), which is much harder, it constrains key ordering of nested `unknown` maps, timestamp precision, and integer formatting. Since git-diffability is the stated justification for plain JSON, test the property you're actually claiming.

---

## What is genuinely good here

Worth saying explicitly, because the list above is long and this design set is well above average:

- **The display-list IR (D4) is the right call**, and building it *before* the PDF backend is the right sequencing. It is the single decision that makes screen/print parity tractable at all.
- **D5 (pointer drags never touch the document)** is correct and is the thing that makes 60 fps achievable without coalescing logic. Most designs get this wrong.
- **Epoch counters over equality** is right for a 500 KB mutable aggregate, and using one mechanism to drive repaint + derived-cache + dirty-tracking is elegant.
- **The `Link` / `Net` split** (data-model §3.6) is the best-argued decision in the corpus. "A net with six endpoints does not tell an installer what to pull" is exactly right, and both rejected alternatives are rejected for the correct reasons.
- **Immutable content-addressed template snapshots with opt-in migration**, joined by stable `PortKey`; this is the correct answer and the rejected alternatives (index identity, label identity) are the actual failure modes of competing tools.
- **Findings-with-acknowledgement instead of hard-blocking** (§3.5) is the right product call and the "cannot document an existing miswired system" argument is the one that proves it.
- **Interval-graph colouring for channel routing** (ux-schematic §3.2) is a genuinely good insight, exploiting the layered structure to get a provably optimal track count instead of reaching for libavoid is the kind of thing that separates a fast tool from a slow one.
- **The migration golden corpus** (§9.1) and the **command round-trip property test** (§9.2) are correctly identified as the highest-value tests in the repo.
- **Display-list goldens over pixel goldens** as the primary regression net, with Linux-only pixel goldens and a pinned Flutter version, is exactly right and is a mistake most teams make.
- **Not using `InteractiveViewer`**: correct, and for the correct reasons (`PointerSignal`, gesture-arena conflict).
- **`Path.contains()` doesn't work on strokes**: correct, non-obvious, and would have cost someone two days.

---

## Recommended first three weeks

Reordered from the two build-order lists, front-loading the things that are cheap now and ruinous later:

1. **Reconcile the unit base and the four contradictions (#1, #2).** One normative decision per subsystem, written down. ~2 days, and it is the highest-leverage work available.
2. **`rackmate_core` units + `Pt`/`Box` + the 1/32-in and 45U-accumulation tests.** Locks #1 in code.
3. **The five pdf spikes, plus a sixth for `PdfTtfFont` main-isolate metrics cost (#18).**
4. **`DiagramCanvas` with `TextMetrics` (#4) and explicit `TextAnchor`**, both backends, and the parity test asserting on **baseline y**. If parity doesn't hold, stop, the pdf doc is right that every hour spent on layout before parity is an hour that may need redoing.
5. **Command/Transaction/UndoStack + the round-trip property test + the epoch-mask test (#16)**, with `@internal` setters (#10) rather than `part of`.
6. **Decide the v1 cut list (#5)** and write it into `docs/` as a scope document, because right now the design set reads as one release.