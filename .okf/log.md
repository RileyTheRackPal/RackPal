# Update Log

## 2026-08-02

* **Update**: [DR-013](/decisions/dr-013-delete-cascades.md) is **BUILT**
  (`48f1198`, board #95). The `TODO(post-M0)` that DR-011.1 turned from inert
  into a live defect is closed: deleting a wired device now takes its cables,
  ports and orphaned nets with it, after a confirmation that states the count,
  and undo puts every one of them back under the same id.
* **Note**: the cascade made a LATENT DEFECT REACHABLE, and the property suite
  found it on the first run. A `Link` can now vanish without
  `RemoveLinkCommand` doing it, so "apply ran and found nothing" became a legal
  outcome — and the nullable-capture guard was reading that as "revert before
  apply" and throwing `StateError` out of undo. One explicit `_applied` flag
  now answers the two questions separately. **The general shape: a nullable
  field standing in for "has this run" stops working the moment something else
  can produce the same emptiness.**
* **Note**: the far end's ports STAY when a device is deleted, and the first
  draft of the test asserted otherwise. §11.13.1 removes the device's OWN
  materialised ports; a jack on a device that still exists is not a lie because
  nothing is plugged into it. The code was right and the test was wrong, which
  is worth recording because it is the less common direction.
* **Update**: **D7's owed gate is PAID** (board #94, `7c2ac49`). The
  `SingleActivator` ban was enforced over one file in the app package while
  every binding surface except the File menu lives in `rackmate_ui`.
  `keymap_source_ban_test.dart` now scans that whole package with comments
  stripped — which is load-bearing and measured: 20 mentions of the type across
  `lib/` and exactly ONE constructor call, because the rack canvas explains the
  framework's semantics in prose. Landed BEFORE M3-C, which docs/13 §3.5 names
  as the largest remaining binding surface.
* **Note**: `registry_claim_test` fired TWICE this session on new prose, both
  times correctly — once on markdown backticks breaking its exact-phrase match
  in `docs/14-deployment.md`, once on the phrase "leaves no trace" inside a
  comment that was DENYING it. The gate is blunt on purpose (canon §11.6.4:
  each of those absolutes was shipped and each was measured false), and out of
  context in a grep the denial reads exactly like the claim. Both fixed by
  rewording, neither by relaxing the gate.
* **Creation**: [DR-006](/decisions/dr-006-self-signed-distribution.md), written
  up now because board #13 built the first part of it. **The portable build
  ships** (`580cb2a`, `1e45cf6`, `bee96bd`): `tools/release/` stages, signs and
  gates a portable Windows folder, documented in `docs/14-deployment.md`.
  **M2's headline does not move** — the portable build is not named by M2's
  exit criterion, and M8's four clauses are untouched.
* **Note**: this is a **scope edit and is recorded as one**. DR-006 consequence
  4 says outright that a portable output before M8 is *"a scope edit under
  roadmap §8.3 and not something this consequence grants"*. One was wanted
  early, for the team to test with.
* **Note**: the APP half needed no code. `data_root.dart` has been the portable
  seam since M0, and docs/03:847's claim that pinning `path_provider_windows`
  to one call site "keeps M2's portable build a one-function change" held
  exactly. Verified by running the staged tree, which wrote
  `RackMateData\sessions\<uuid>.lease` beside the executable rather than under
  AppData.
* **Creation**: [the release signature gate](/gates/release-signature.md), and
  with it a correction to the ruling it implements. **DR-006 §11.6.2's
  expiry recipe has an unstated precondition**: run as written on a normal
  build machine it is INCONCLUSIVE, because a self-signed root is untrusted
  there and the chain engine reports `UntrustedRoot` before reaching the time
  check — so both the timestamped and the untimestamped copy come back
  identical. The gate uses `X509Chain` with an explicit `VerificationTime`
  instead, and states which half is observed and which is modelled.
* **Note**: a second correction, this one to consequence 4's wording. **"Every
  artifact a release produces" is not "every file it ships."** The first
  signing run replaced Microsoft's signature on the three redistributable VC++
  DLLs with a self-signed one — trading a chain that validates on every Windows
  machine for one that validates only where the GPO has landed. Binaries
  already signed by another publisher are now skipped.
* **Creation**: [the ZIP trap](/practices/the-zip-trap.md). Explorer propagates
  Mark-of-the-Web into extracted files, so a portable ZIP fetched over HTTP
  re-arms SmartScreen on every binary inside it however well signed — silently,
  until somebody on a fresh machine sees the prompt. The general shape is that
  **a property living in the channel cannot be gated at the source**, which is
  why M8's clause had to be split rather than tightened.

* **Update**: [DR-012](/decisions/dr-012-deferred-gesture-rules.md) §11.12.2 —
  **multi-draw is BUILT** (`8876261`, `4840307`, `e078c0b`), which completes
  all four of RJ-001's gestures. N `Link`s in rank order under one undo entry,
  a live preview of all N bands, driven identically from pointer and keyboard.
  **M2's headline does not move**: it was already `CRITERION MET`, the
  sixty-connection drill passed WITHOUT multi-draw, and roadmap §8.1 grades a
  milestone against its exit criterion rather than against work inside it.
* **Note**: the gesture needed **one pairing the corpus does not contain** —
  what a press does when the selected run is made of `atomicConnect` pins.
  Multi-draw wins over DR-011.2's set branch, because the set branch is decided
  by the JACK while a run is an explicit act with a modifier. The cost is that
  such pairs become N separate `Link`s where the template says one cable, so
  the arming sentence names it out loud. Recorded as a consequence of two
  rulings rather than a third; it wants a DR if it is ever argued with.
* **Creation**: [catalog port order](/gates/catalog-port-order.md). `FracIndex`
  is a string-ordered extension type with no comparison operator, and
  `PortBuilder` emitted `a0 … a9, a10 …` — so **678 of 727 seed ports, across
  29 of 45 templates, were in the wrong order**, and had been through every
  milestone. `A01`'s zone speaker outputs were DRAWN out of sequence.
  FIXED_ORDER, `PORT_SEQ`, `chainOutputFor` and `portsInBank` all read that
  field and all four were wrong. Fixed at `d8aedca`; the regenerated goldens
  diff to `"order"` values and nothing else.
* **Creation**: [census before building](/practices/census-before-building.md).
  The catalog defect was found by a measurement taken for something else, which
  is now the third time the same habit has paid — an empty field (DR-012), an
  unmeasured cost (M2-G), and an ordering nobody had ever compared (#93). The
  shape is one shape: a value never compared against anything cannot be wrong,
  and tests written from the code's own assumption inherit it.
* **Note**: one defect the suite caught that reading did not —
  `_anchorPinSelection` reset the pin run on every modifier-free press,
  including the press that STARTS the multi-draw drag. The run was built, the
  press dropped it to one pin, and every drag fell through to an ordinary
  pin-to-pin cable. Multi-draw arrived stillborn on that line with every unit
  test at both ends green, which is the composition-level blindness
  [defer past the gesture](/practices/defer-past-the-gesture.md) already
  collects.

## 2026-08-01

* **Note**: **M2's criterion is MET.** The user performed the sixty-connection
  drill on 2026-08-01 — roughly 5–7 minutes, after a bit of practice — which
  discharges the last of its five exit clauses. The clause carries no time
  bound, so that figure is a data point rather than a threshold met. **It was
  done without multi-draw**, which is still unbuilt: the gesture is a
  throughput improvement on a clause that is already met, not a requirement of
  it. `CONFIRMED` is not a gate — nothing re-runs a drill, and the gesture
  tests are what guard the mechanism between runs.
* **Note**: M2-G — the paint half of M2's budget was **never measured**, and
  measuring it found the 300-link fixture taking **63.9 ms to replay against a
  16.7 ms frame**, beside a scene build of ~3 ms that a green test had been
  citing. `FlutterDiagramCanvas.drawText` built a fresh `TextPainter` — and a
  native `ui.Paragraph` — on every call, and a pan re-records the picture, so
  2 374 runs were laid out per frame over a working set of 703. With the cache
  the same replay is **10.6 ms**.
* **Note**: the roadmap's sizing for that cache did not survive either. docs/09
  says it "must be sized for" ~10,000 runs and warns a 2,000-entry LRU would
  thrash; the measured working set is **703**. Worse, its prescribed key
  `(text, styleId, quantisedScale)` would have CAUSED the thrash it feared —
  `sizePt` is in diagram units and the zoom is applied to the canvas, so the
  same run lays out identically at every zoom and scale is not a term.
* **Note**: docs/12 §5.1's clause-4 row is corrected in place rather than
  rewritten. It was marked `DEMONSTRATED` on a citation that measured the
  display list being BUILT — `rackmate_core` is pure Dart and cannot touch a
  `ui.Canvas` — which is the exact failure shape that board's opening table
  collects: an assertion that quietly stopped covering the thing it named.
* **Creation**: [DR-013 — deleting a wired device cascades](/decisions/dr-013-delete-cascades.md).
  The `TODO(post-M0)` in `RemoveDeviceCommand` was **inert for every milestone
  up to M2-F** — nothing wrote `doc.ports`, so there was nothing to orphan —
  and DR-011.1 made it live in the same commit that fixed the finding it came
  from. The recommended option (demote the far end to `OpenEndpoint`, which
  AC-018 models as first-class) was **rejected**: a cable to a device that has
  been deleted is not a design intent, it is debris, and M5's validation is not
  there to flag it.
* **Update**: [DR-011](/decisions/dr-011-connect-gesture.md) is **BUILT** — all
  seven clauses, across M2-F's six phases. Two of its findings had SURVIVED the
  phase that was supposed to close them: `AtomicConnectCommand` still never
  materialised a port (Phase 0 had added a guard against the symptom whose own
  comment described the disease), and §11.11.4's layout hold silently did
  nothing because `touches` is `wires | meta` and the meta bump advanced the
  scene epoch past the stamp the wires listener had just written.
* **Update**: [DR-012](/decisions/dr-012-deferred-gesture-rules.md) is **BUILT**
  for three of its four clauses. §11.12.2's multi-draw is deferred to its own
  board item — the ranking is ruled and waiting, which was the part worth
  having.
* **Creation**: [A deferred action needs a frame](/practices/defer-past-the-gesture.md)
  — two defects one phase apart, both invisible to every unit test at both ends:
  `addPostFrameCallback` queues a callback but does not schedule the frame that
  runs it, and a `TabBarView` settles its page under a tab switch made inside
  the click that asked for it.
* **Note**: CR-105's elevation signposting and AC-048's coach mark shipped with
  M2-F Phase 5. The chip is SCREEN CHROME and not scene: `buildRackScene` feeds
  the PDF as well as the screen (CR-086), so a chip emitted into the scene would
  print on the customer's elevation sheet.
* **Note**: `docs/12-milestone-board.md` §5.1 re-audited at `ea0af6d`. M2 moves
  from `NOT STARTED` to **PARTIAL**, four of five exit clauses cited; the open
  one is the sixty-connection drill, which needs a person. Every other row on
  that board is still as of `0fa532d` and says so.

## 2026-07-31

* **Creation**: [DR-012 — the four gesture rules DR-011.8 deferred](/decisions/dr-012-deferred-gesture-rules.md),
  taken before Phase 4 started rather than during it. **Three of the four were
  decided by one piece of arithmetic**: `acceptedFamilies`, `channelIndex` and
  `maxConnections` are all declared on `PortDef`, all round-trip, and all are
  populated on NONE of the 727 seed catalog ports — so every rule that would
  have read them does nothing on every real document. That is the third time
  this shape has appeared in M2-F (see
  [diagnose before fixing](/practices/diagnose-before-fixing.md)); the first
  was `effectiveMaxConnections` in Phase 0.
* **Update**: [DR-011](/decisions/dr-011-connect-gesture.md) §11.8's four open
  questions now point at DR-012. The sharpest of them was chain-draw's
  *"matching output"*, which docs/05's OWN worked example refutes: it chains
  `MTX-1 IN1` to `MTX-1 OUT1`, and **a matrix switcher has no pairing between
  them — that is what makes it a matrix.**
* **Note**: a licensing sweep found the dependency tree clean for a possible
  GPLv3 release — 81 packages, 58 BSD / 18 MIT / 5 Apache-2.0, zero copyleft;
  Jost ships its OFL-1.1 text; the seed catalog is all `Generic` archetypes so
  there is no third-party SKU data. `pdf` being Apache-2.0 means GPLv2 is
  closed and GPLv3 is the only copyleft option. Recorded here because a future
  dependency choice can quietly foreclose it. Not a ruling: the business model
  is §10.3's open question and would need one.
* **Update**: [DR-011](/decisions/dr-011-connect-gesture.md) — clauses .1 to .6
  are BUILT (M2-F phases 1B, 2A and 2B). **The connection is made from the
  keyboard, and that is the whole of the ruling's "order that matters"**: the
  pointer path is Phase 3 and has not been written yet. Three findings came out
  of building it, and none was visible from the ruling:
  * **the defect Phase 1A tracked was described backwards.** "A widget
    unmounted mid-press never delivers its terminal and the claim leaks" — in
    fact `GestureBinding` caches the hit test at pointer-DOWN and keeps
    dispatching down the cached path, so the gesture did not stall, it
    COMMITTED out of a widget that had left the tree. Measured: `[begin,
    update]` at the unmount, `[begin, update, update, commit]` at the release.
    The leaked claim was never seen because the stale commit released it;
  * **DR-011.4's first implementation silently did nothing.**
    `ConnectPortsCommand.touches` is `wires | meta`, and the meta bump advanced
    the scene epoch past the stamp the wires listener had just written. Every
    symbol still moved, on the very commit the clause is about;
  * **`unbuilt_copy_accuracy_test.dart` had drifted into a hole shaped like
    this change.** Its scan named `AddLinkCommand` alone, so a schematic wiring
    through `ConnectPortsCommand` would have left it green while the sheet's own
    copy told the user nothing could create a cable. See
    [diagnose before fixing](/practices/diagnose-before-fixing.md) — all three
    are the same shape: a mechanism that reads as working because of what it
    was checked against.
* **Creation**: `kUnstatedMedia` records that **no document can say what cable a
  connect makes**. `Registries.mediaTypes` is empty in every seeded document,
  `SignalFamilyDef` carries no `typicalMedia`, and a `PortDef` names a connector
  rather than a cable — so the alternatives are all fabrications, and
  `ProjectSettings.defaultNetworkMedia` on an HDMI run would put a wrong spec on
  the sheet an installer buys from. [G4](/invariants/g4-unknowns-are-counted.md),
  in the one place it is expensive.

## 2026-07-29

* **Creation**: [DR-011 — the connect gesture](/decisions/dr-011-connect-gesture.md),
  seven clauses scoping M2-F. Three findings forced it, and all three were
  invisible from the API's own surface: NOTHING IN THE APP EVER MATERIALISES A
  PORT (so the connect API shipped in M2-A returns a zero-conductor plan on the
  document the exit criterion starts from), committing a link re-runs the
  auto-layout and moves every symbol, and every link would have landed in the
  Structure domain.
* **Creation**: [One keymap registry](/practices/one-keymap-registry.md) —
  M2-H's practice, INCLUDING THE HALF THAT WAS DONE WRONG. The ban is enforced
  by a test that reads one named file; the package where most remaining UI work
  lands has no layering test at all. A structural rule needs a structural gate.
* **Update**: [DR-009](/decisions/dr-009-macos-in-v1.md)'s register revised —
  two of its rows overstated the debt. `pdfium` is in no pubspec at all, and the
  cross-platform PDF worry cited CR-117, which governs the `.rackmate` JSON and
  not the PDF. Recorded because a register row that has stopped describing the
  tree is worse than a missing one: it is trusted.

## 2026-07-28

* **Update**: Caught the bundle up with M2-D (`e13fa68`) and M2-E (`219c0bf`),
  which had landed after it was written. Batching that catch-up was itself the
  drift this bundle exists to prevent — maintain as changes land, not after.
* **Creation**: [CR-078 — four encoding channels](/invariants/four-encoding-channels.md),
  recording that the GLYPH CHANNEL CURRENTLY CARRIES NOTHING: there is no `tier`
  field, so `glyphAlt` is unreachable for all eight domains and all 55 families.
* **Creation**: [Diagnose before fixing](/practices/diagnose-before-fixing.md) —
  the salvage post-mortem, where twelve consecutive fix commits touched neither
  cause because a third defect made the surface unable to change at all.
* **Update**: [DR-001](/decisions/dr-001-net-labels-by-default.md) is now BUILT,
  with the measured cost against M2-C's baseline: 4155 -> 6555 ops, the label
  layer 19% of a frame with ~4x headroom.
* **Update**: [Package layering](/invariants/package-layering.md) records a
  violation in waiting — `wire_trace.dart` sits in `rackmate_ui`, which
  `rackmate_export` may never import, so the exporter cannot draw a wire and
  M6's interconnect sheets are unbuildable until it moves.
* **Creation**: Scaffolded the RackMate bundle with `okf_init.py`.
* **Creation**: Established the bundle's spine — the ruling to spec to
  implementation to test chain — in [getting started](/getting-started.md).
* **Creation**: `decisions/` with [DR-001](/decisions/dr-001-net-labels-by-default.md),
  [DR-008](/decisions/dr-008-wiring-model.md),
  [DR-009](/decisions/dr-009-macos-in-v1.md) and
  [DR-010](/decisions/dr-010-seeded-registries.md). DR-002 through DR-007 are
  recorded in the canon but not yet written up here.
* **Creation**: `invariants/` with [CR-117](/invariants/cr-117-byte-exactness.md),
  [G4](/invariants/g4-unknowns-are-counted.md) and
  [package layering](/invariants/package-layering.md).
* **Creation**: `gates/` with the [analyzer ratchet](/gates/analyzer-baseline.md),
  [registry parity](/gates/registry-parity.md) and the
  [byte-exactness sweep](/gates/byte-exactness-sweep.md) — each recording its
  blind spot as well as its coverage.
* **Creation**: `practices/` with
  [decompose before building](/practices/decompose-before-building.md), written up
  because a session died mid-milestone and the task breakdown is what made the
  work recoverable.
