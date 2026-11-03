# Testing and Quality

RackPal's deliverable is a printed sheet set an installer follows in an attic at 7 pm, so the quality bar is set by G1 ("the schedule is the deliverable") and G4 ("never fabricate data"): a test suite that proves the drawing is pretty but not that the schedule is right has tested the wrong thing. This document fixes the testing pyramid, the fixture corpora, the golden strategy and its font determinism, how PDF output is asserted without byte comparison, the performance harness, the CI matrix, the lint stance, the definition of done, and the diagnostics/privacy posture. It is binding on every milestone exit criterion in [Roadmap](09-roadmap.md); where a test is named there, its mechanism is specified here.

---

## 1. The pyramid, and why it is bottom-heavy

The `rackpal_core` package is pure, synchronous Dart with no `package:flutter`, no `dart:ui` and no `package:pdf` (per CR-083). Every rule, every derived number, every route and every byte of the file format is therefore testable in `dart test` in milliseconds, with no binding, no golden, and no runner variance. That is the reason the pyramid is shaped the way it is.

```text
                 ┌───────────────────────────┐
        ~6       │  manual / hardware         │  print matrix, CVD sim, mixed-DPI,
                 │  (pre-release checklist)   │  domain-expert review        AC-058/D13
                 ├───────────────────────────┤
       ~25       │  integration_test          │  file lifecycle, crash recovery
                 ├───────────────────────────┤
      ~150       │  widget + pixel goldens    │  designed, not built (DR-253)
                 ├───────────────────────────┤
      ~400       │  display-list goldens      │  DiagramScene text dumps (budget, DR-253)
                 ├───────────────────────────┤
   ~2 000+       │  pure-Dart unit + property │  model, rules, routing, codecs
                 └───────────────────────────┘
```

| Tier | Package | Runs | Gate |
|---|---|---|---|
| Unit / property | `rackpal_core`, `rackpal_text`, `rackpal_export` | every PR on Windows; macOS as an optional check (DR-255) | blocking on Windows only |
| Byte and text goldens | `rackpal_core`, `rackpal_ui`, `rackpal_export` | with the suites that hold them | blocking on Windows (DR-253) |
| Pixel goldens, and display-list goldens at the budgeted scale | `rackpal_core`, `rackpal_ui` | **designed, not built**: no `matchesGoldenFile` exists and the ~150 and ~400 are budgets | none (DR-253) |
| Integration | `apps/rackpal` | **designed, not built**: no `integration_test` exists; the app suite runs from `apps/rackpal/test` | none |
| Performance | `rackpal_core/test/scene/schematic_perf_test.dart` | every PR, under the `perf` tag, one test at a time (DR-178) | blocking on Windows; not run on macOS |
| Pixel-diff PDF | `rackpal_export` | **designed, not built** | none |
| Manual / hardware | — | per milestone | milestone exit criterion |

**Read the table as the plan except where a row says otherwise.** There is no Linux job anywhere. The macOS check is a second pipeline, `azure-pipelines-macos.yml`, run as an optional PR check on a Microsoft-hosted image, and it **may never be made blocking** (DR-255 §11.254): the month its free minutes ran out, nothing would merge. §7 says what runs.

Rejected alternative: a Flutter-first suite where the model is exercised through widgets. It makes every domain assertion cost a pump-and-settle and it cannot run the 1,000-seed property tests at all.

---

## 2. Unit testing the pure-Dart core

### 2.1 Model invariants and units

Two tests are written **before any other code in the repository** (CR-001, AC-001), because they discriminate between the four unit bases the design documents proposed and only one survives:

```dart
test('EIA 1/32-inch inter-panel clearance is exact', () {
  expect(Len.inches(1, 32), Len(793750));            // no rounding, no double
});

test('45U stack accumulates zero error', () {
  var y = Len.zero;
  for (var i = 0; i < 45; i++) { y += kRackUnit; }   // 44_450_000 nm
  expect(y, Len(2_000_250_000));
  expect(y.toMillimetres(), 2000.25);
});
```

Companion invariant tests, each named for the ruling it defends: `ruIndex` is 1-based bottom-origin and asserted at load (CR-025); `heightU` is 1..60 (CR-038); `order` is a `FracIndex` everywhere it appears and re-inserting between two neighbours never renumbers a sibling (CR-027); a `Conductor` spans exactly two `Endpoint`s while a `Link` may reach N devices (CR-014); `Service.netId` is non-null and `Link.netId` does not exist (CR-010); `dominantSignalFamily` is never present in serialized output (CR-009, CR-115); `typicalWatts` is never inferred from `nameplateWatts` (G4, AC-039); `TemplateBody.bodyDepth` and `.weight` are nullable, serialize as **absent** when null, and every rollup that consumes them reports its unknown count (G4, CR-114, canon §12 G5); `LifecycleStatus` has five values on both `DeviceInstance` and `Link` (canon §4.2); `Len`→PDF-point conversion happens in exactly one function (CR-007).

Two mechanical guards, both dependency-free, both cheap enough to keep forever:

1. `no_flutter_import_test.dart`, greps `packages/rackpal_core/lib` for `package:flutter/`, `dart:ui` and `package:pdf/` and fails the build with the offending path (CR-083). Belt and braces: core's pubspec has no `flutter:` key, so a stray import is also a compile error.
2. `banned_names_test.dart`, greps the whole repository, including prose and comments, for the [canon §4.7](canonical-decisions.md#47-banned-names) banned vocabulary (`Connection`, `PhysicalLink`, `CableType`, `bottomU`, `refDes`, `StructureDrop`, `StructureBundle`, `bundleStatus`, `RulePredicate`, `RendererCaps`, `ObstacleField`, `blockExportOnErrors`, `Money`, …). `StructureBundle` and `bundleStatus` are named explicitly because bare "bundle" is banned (CR-016) and `Outlet.bundleStatus` survived in prose long after the field became `Outlet.roughInStatus`; the word survives only as UI copy for `Pathway`. Registry IDs are **not** in this list; those are caught by the resolve test in §2.6. N2 makes a banned word banned in prose too; without a test that is an aspiration. One allowlisted file: the migration note that explains each removal.
3. A third grep asserts no entity setter is invoked outside `src/commands/`, backing the `@internal` decision (AC-013).

### 2.2 Command round-trip and epoch coverage

```dart
test('apply ∘ revert == identity over 1000 seeded (doc, command) pairs', () {
  for (var seed = 0; seed < 1000; seed++) {
    final rng = Random(seed);
    final doc = randomDocument(rng);              // domain-aware, hand-rolled
    final before = DocumentCodec.encode(doc);     // bytes, not a semantic compare
    final cmd = randomCommandFor(doc, rng);
    cmd..apply(doc)..revert(doc);
    expect(DocumentCodec.encode(doc), before, reason: 'seed=$seed');
  }
});
```

The generator must emit add-device commands so that `TemplateSnapshot` refcounting is covered for free (AC-015), and the comparison is on **encoded bytes**, which is what makes it also assert `templates.keys` ordering. The alternation invariant `apply; revert; apply == apply` runs on the same seeds. Rejected alternative: a generic property-testing package with an automatic shrinker; it cannot generate valid RU spans or compatible connectors, and a failing seed number is a perfectly good repro.

The **epoch-mask coverage test** (AC-014) is forty lines and is the highest value-per-line test in the plan: for every registered command type, snapshot every derived output, apply the command, snapshot again, diff, and assert the command's declared `touches` mask covers every epoch that actually changed. Hand-declared masks with "when in doubt, over-declare" produce stale renders, which is the hardest bug class to reproduce. `lodLevel` is an explicit parameter of every `SceneBuilder.build*` and part of every cache key, so the same test catches LOD-keyed staleness (AC-016 #13).

### 2.3 Validation rules, addressed by rule ID

The v1 catalogue is **8 tier-1 + 6 tier-2 + 16 tier-3**, with `PLC-001..003` ratified (canon §12.6(b)), `LEN-002` added (DR-020, canon §11.19), `ELE-005` restored (DR-132, canon §11.131) and `RCK-014` added (DR-219, canon §11.218.4), and every one is a Dart function in a registry keyed by `ruleId` (CR-024, AC-011). **The plan advisories are a second band** and are not counted here (DR-154 §11.153.2). The gate is AC-051, it is absolute, and it follows the RULE rather than the list: **no rule in either band ships without its fixture pair.**

```text
packages/rackpal_core/test/validation/
  drc_corpus_test.dart              # the gate: every catalogue rule has both halves
  fixtures/
    drc_fixture.dart                # DrcFixture, FixtureKind {knownBad, nearMiss}, violationOf
    drc_corpus.dart                 # drcCorpus(): the one list, across all four evaluators
    connect_scenarios.dart          # tier 1, TOP-001..005 (evaluateConnect)
    placement_scenarios.dart        # tier 1, PLC-001..003 (evaluatePlacement)
    spring_back_scenarios.dart      # tier 2 (SpringBackChip)
    tier3_scenarios.dart            # tier 3 (evaluateDocument)
    plan_scenarios.dart             # the plan band, PLN-*
```

The corpus is **Dart builders, not `.rmpj` files**, because the four evaluators do not share an input: tier 1 refuses a gesture through two evaluators, tier 2 springs a gesture back, and only tier 3 describes a document and produces findings. A file format could have expressed the tier-3 half and nothing else. Every fixture therefore normalises to one question, *which rule ids fired?*, through `FixtureOutcome` (`drc_fixture.dart`): a `knownBad` fixture must fire **exactly** its own rule and nothing else, not merely include it, and a `nearMiss` fixture must not fire that rule at all. A near-miss that is one property away from the bad case is what stops a rule from being written as `return true`. The gate `drc_corpus_test.dart` has the **catalogue** as its subject rather than an enum, so a row no enum mentions still fails for want of a pair. Three further assertions ride along: every `ruleId` in [the rule catalogue](02-data-model.md#5-the-v1-validation-rule-catalogue-three-tiers) resolves to a registered function and vice versa (a rule not in the catalogue does not exist, CR-021); every rule's severity is one of the CR-018 vocabulary with `Severity.info` absent; and **no rule at any severity prevents a PDF from being written to disk** (CR-022, G3), asserted in `packages/rackpal_export/test/findings_never_block_export_test.dart`.

**Superseded:** this section said fixtures were `.rmpj` files so a domain expert could open one in the app during the M5 sign-off review without reading code. They are Dart builders, and each `DrcFixture` carries a one-line `what` saying what makes the case bad or which single property pulls it back to good, which is what a reviewer reads.

### 2.4 Routing determinism

The router is Sugiyama phases 0–3 plus a deterministic layer-ordered orthogonal trace (CR-013 as amended by DR-001), with **full deterministic recompute**; `ObstacleField` and `RouteCache` do not exist. Determinism is therefore not an implementation detail, it is the property that makes goldens possible, and it is asserted directly:

- **Byte-identical replay.** Same `RackDocument` in ⇒ byte-identical `DiagramScene` dump out, asserted 20× on one 300-connection fixture within a run, and across a run with a shuffled iteration order of the entity maps (flat UUID-keyed maps must not leak hash order into layout).
- **Insertion-order independence.** Building the same graph by adding links in a different sequence produces the same layout. This is the assertion that catches an accidental dependency on map order.
- **There are no `HOP` ops.** A test asserts the display list contains none in any mode, because hop arcs are not built in v1 (DR-001). Crossings render as plain crossovers. The 300-connection fixture survives and changes purpose: it is the **layout-determinism and label-density** fixture, and what is measured on it is text-run count and label-layer commit time.
- **Both render modes are deterministic, and the switch is lossless.** Same input ⇒ byte-identical display list in **both** render modes, and switching `netLabels` ⇄ `drawn` and back reproduces the original display list exactly. Net labels are the default render; `drawn` appears only under a domain filter, `Alt`-hover or focus (DR-001), and `SheetRenderMode` is derived from the active filter, never persisted.

### 2.5 Schema migrations and the golden corpus

The migration corpus is the highest-value directory in the repository: it is what allows the model to be refactored for years. `migrateToCurrent` returns `Outcome<T>` and never throws for an expected condition (CR-093).

```text
packages/rackpal_core/test/fixtures/          # flat, no schema/ subdirectory
  a_empty_project.rmpj.json ... f_plate_gangs.rmpj.json
                                              # byte-round-trip goldens (byte_roundtrip_test.dart)
  e_three_hundred_links.rmpj.json             # also the 300-link perf and layout fixture
  v1_templates_and_power.rmpj.json            # migration inputs, one per schema step:
  v2_ports_with_positions.rmpj.json           #   v1->v2 ... v5->v6, opened as BYTES
  v3_carried_protocols.rmpj.json              #   by migration_corpus_test.dart
  v4_before_plan.rmpj.json
  v5_outlet_counts.rmpj.json
```

**The files keep `.rmpj.json`, the earlier extension, on purpose.** They are test inputs whose names the tests read by path, not documents a user opens; the extension written today is `.rppj`, and `.rmpj` still opens (DR-179 §11.178). The earlier plan here named `v1_minimal`, `v1_full`, `v1_unicode` and `v1_unknown_fields` under a `schema/` directory; none of those exists. The corpus grew one input per real schema step instead, the day each step shipped (`v0 -> v1` is a map built inside the test), and an existing input is never edited.

Assertions, as the tests in `migration_corpus_test.dart` make them: a v1 to v5 input migrates to a valid current document; `minReaderVersion > kSchemaVersion` ⇒ `Err(NewerSchemaError)`; a `schemaVersion` newer than this build's with a readable `minReaderVersion` ⇒ `Ok(doc, openReadOnly: true)` (CR-093, defect fixed); a chain that did not arrive is an error and not a success. Unknown fields surviving the round-trip in their original position (`unknown` on every persisted object, §4.4) is the byte round-trip's job, below. The device template format (`.rpdx`, earlier `.rmdx`) has its own parallel chain and its own corpus (CR-063).

The **byte round-trip** is the contract, not the semantic one (CR-117): `write(read(bytes)) == bytes`. This is what constrains key ordering, including inside nested `unknown` maps, timestamp precision, and integer formatting, and those are exactly the things that otherwise produce spurious git diffs and a lying dirty flag. Rejected alternative: `read(write(read(x))) == read(x)`, which passes while the file churns.

The four starter projects (AC-052) are real `.rppj` files and do triple duty: golden corpus, performance fixtures, screenshot source. At least one exercises the Structure device and at least one exports a full sheet set.

### 2.6 Registry and catalog assertions

The §6.7 acceptance criteria are unit tests, not aspirations, and they run in `dart test` with no rendering:

| Test | Assertion | Ruling |
|---|---|---|
| PAL-1 | pairwise over **rendered family values**; reference implementation is `tools/pal1_check.py`, ported to Dart at M0, see below | §6.7/4, AC-054, canon §14 |
| Dash floor | every shipped dash period ≥ 4.5 pt (1.5875 mm), 4.25 pt is 1.4992 mm and therefore *below* the 1.5 mm physical floor the rule derives from | §6.7/5 |
| Glyph coverage | every non-ASCII character in a Dart string literal exists in both bundled Jost weights (`tools/glyph_coverage_check.py` reads the binary); no fallback face ships | §6.7/6, DR-249 §11.248.4 |
| Referential integrity | every `defaultConnector`, `typicalMedia`, `MediaTypeDef.supports` and `SignalFamilyDef.domain` resolves; every connector on a shipped template has a footprint | §6.7/7, AC-050/A2.2 |
| Documented IDs resolve | every `media.*`, `conn.*`, `SignalDomainId` and signal-family ID appearing in any repository document, template or fixture resolves in `assets/catalog/registries.json`, see below | N1, §6.7/7, seed-devices C2 |
| Documented **values** match | every hue, dash pattern and weight multiplier printed in a prose table beside such an ID equals the registry's effective value for that family, see below | N1, §6.7/7 |
| Prefix collision | no catalog template shares a `typePrefix` with a system prefix (`STR` stays with Structure, streaming is `STRM`) | CR-043 |
| Provenance | every safety-adjacent field (`pinoutVariant`, `impedanceOhms`, `poeBudgetWatts`, `maxUnsupportedMass`) has a citation in `assets/catalog/sources.md`; an uncited template fails the build | AC-052 |

**The prefix-collision row is about template `typePrefix` values only.** A catalog template's `typePrefix` and a signal family's `shortTag` are **different namespaces** and are never looked up together, so a family may carry a tag spelled like a reserved prefix without colliding with it: `structure.undetermined` ships `shortTag` `STR` (seed-devices §4.4), and that is the correct value precisely because `STR` belongs to Structure on both sides. What CR-043 forbids is a *template* claiming `STR`, which is why streaming templates are `STRM`.

**PAL-1 is a pairwise test over rendered family values.** The rule it asserts, stated verbatim as canon §14.1 states it:

> **PAL-1 (rendered-value form).** Every shipped `SignalFamilyDef` renders as the triple
> *(L, dashClass, weight)*, where **L** is the WCAG relative luminance of its **effective** hue,
> **dashClass** is the class of its effective dash pattern per the mechanical definition below, and
> **weight** is its effective line-weight multiplier — *effective* meaning **after** any
> `colorOverride`, `dashOverride` or weight override declared in the signal-family registry, not
> the domain base value.
>
> For **every pair of families belonging to different `SignalDomainDef`s** whose luminances satisfy
> **|L₁ − L₂| < 0.10**, at least one of the following must hold: **(a)** their dash classes differ,
> **or** **(b)** their weight multipliers differ by a factor **≥ 1.4**.
>
> Families **within one domain** are exempt from (a)/(b) — they share a hue by construction, the
> legend prints them adjacently, and the tag pill disambiguates them — but any two families in one
> domain must still differ in **dash pattern, weight, or glyph**.

Dash class is the mechanical definition of canon §14.2, reproduced there in full. The test enumerates every shipped `SignalFamilyDef`, computes its triple, and checks every cross-domain pair inside the band; the within-domain exemption is a **domain-equality check, never an allowlist of pairs**: an allowlist is how a real collision gets waived.

**The rule is now enforced by a committed, executable check: [`tools/pal1_check.py`](../tools/pal1_check.py).** Where this document, or any other, disagrees with that file about a family's dash pattern, weight or luminance, **the file wins and the document is wrong.** It runs with no dependencies and no Dart:

```text
python tools/pal1_check.py     # exits 0 clean, 1 on any violation
PAL-1 conformance: 55 families, 385 in-band cross-domain pairs checked
PASS - no collisions.
```

What it checks, in one pass over the 55 shipped families:

1. **The (a)/(b) limb.** Every pair of families in **different** domains whose luminances lie within the 0.10 band (385 pairs, not 8 domain rows) must differ in dash class or by a weight factor ≥ 1.4. Luminance is computed from the shipped hex, never transcribed.
2. **The within-domain limb.** No two families in one domain may render as the same `(dash, weight)`. This is the limb that caught two byte-identical pairs.
3. **The period floor.** Every dash period ≥ 4.5 pt, the same rule the Dash-floor row above states.
4. **Requirement-4 attribution.** A violation touching one of the ten cable types the brief names by hand is reported with that name attached, because such a collision is not a style nit; it is requirement 4 failing its own acceptance test.

**This file is the reference implementation, and it is ported, not re-derived, to `pal1_conformance_test.dart` in `rackpal_core` at M0.** The port reads the shipped registry rather than a transcribed family list, and thereafter the Dart test is the authority; `pal1_check.py` remains in the tree as the executable statement of intent the port is diffed against. **Both run in CI on every PR** (§7), the Python check as a dependency-free job that cannot be broken by a Dart refactor.

**The port must carry a known-bad fixture, and that requirement is not negotiable: a conformance test that cannot fail is worthless.** `pal1_check.py` is verified in both directions, it passes on the corrected palette, and it reproduces **all fourteen** violations when the five corrections below are reverted, six of them naming S/PDIF, one of the brief's ten types. The Dart port asserts the same two directions: green on the shipped registry, and exactly fourteen findings on a checked-in reverted-palette fixture, matched by family pair rather than by count alone. A count-only assertion passes when one collision is fixed and another introduced.

Note the asymmetry, because it is the reason the fixture obligation falls on the port. `pal1_check.py` takes no arguments and has **no built-in negative mode**: its positive direction runs in CI on every PR, but its negative direction is reproduced by hand-reverting the five rows above and re-running. That is a verification someone performed, not a verification the repository performs, the same shape of assurance that failed three times. Institutionalising it as a checked-in known-bad fixture is precisely what the M0 port is for, and the port is not done until the fixture exists and has been observed to fail loudly when the corrections are restored to it.

| Reverted to | Family | Restores the collision |
|---|---|---|
| `solid` 1.00× | `video.hdmi.1_4` | byte-identical to `video.hdmi.2_0` (within-domain) |
| `12,4` 1.00× | `video.composite` | byte-identical to `rf.modulated` (within-domain) |
| `10,3` 1.00× | `audio.line_bal` | four video.analog families at once, all at dL 0.0112 |
| `6,3,1,3` 1.00× | `audio.spdif_coax` | six ctl families: RS-232, DMX512, DALI, KNX, contact, IR receive |
| `10,3,1,3` 1.00× | `audio.aes3` | `ctl.cresnet` and `video.avoip` |

That `dL 0.0112` is the whole argument for the rule: `video.analog` (`#56B4E9`, **L = 0.4050**) and `audio.analog` (`#E69F00`, **L = 0.4162**) are vividly different colours and near-identical greys. Publish that figure as 0.4050; several documents round it to 0.401, and the value in [`tools/pal1_check.py`](../tools/pal1_check.py) (computed from the hex, not typed) is the one that governs.

**No document may claim PAL-1 was verified by inspection.** It was asserted "verified clear" three times against a palette that contained fourteen collisions, because each check read the eight domain rows rather than enumerating the 385 family pairs actually drawn. A rule checked by reading is not checked. Prose that names which families were compared against which is prose that will be wrong again; the only durable form of the claim is a pointer to the file and its exit code.

**Every `media.*`, `conn.*`, `SignalDomainId` and signal-family ID appearing in any repository document, template or fixture resolves in `assets/catalog/registries.json`.** A grep-and-resolve test over `docs/**/*.md` and `assets/**`. This exists because RJ-012 makes an unmatched media value in a Structure CSV import **silently create a new `MediaTypeDef`** with a confirmation chip rather than fail, so a wrong ID in a shipped synonym table manufactures duplicate media types on the first real import and splits the `T6.30` footage rollup across them. That is a silent data-quality failure, which is exactly the class a test must catch (N1, canon §6.7 criterion 7, seed-devices C2). One allowlisted file: the migration note that records each renamed ID.

**The same test resolves VALUES, not only IDs.** Where a prose table prints a hue, a dash pattern or a weight multiplier beside a family or media ID, the test parses that cell and asserts it equals the registry's **effective** value, after overrides, the same value PAL-1 renders. This is not a tidiness rule. Value drift between a prose table and the registry is the exact class of defect that shipped here: the palette tables were re-read and re-blessed three times while the drawn values disagreed with them, and an ID-only resolve test was green throughout, because every ID in those tables was perfectly valid. A document that is authoritative about which families exist and wrong about what they look like is worse than one that says nothing, because it is the document a reviewer trusts. The parse is deliberately narrow (hex, `solid`, comma-separated dash lists, and `N.NN×`) and a cell it cannot parse fails rather than skips, since a silently skipped cell is how the check quietly becomes an ID test again.

The provenance test is what sets the catalog count, not a target number (CR-061), see [Seed devices](catalog/seed-devices.md).

---

## 3. Goldens: display lists first, pixels second

> **Status (2026-11-03, DR-253 §11.252).** A "golden" is a committed fixture compared exactly: exported bytes, display-list text or generated reference text, failing on any difference. Those exist and run on Windows with their suites (`byte_roundtrip_test.dart`, `schematic_fixture.dart` with `schematic_perf_test.dart`, `keymap_reference_golden_test.dart`, `starters_pdf_golden_test.dart`). **No pixel golden exists**: no `matchesGoldenFile`, no `flutter_test_config.dart`, no `golden` tag, and no Linux job. What follows is the design for pixel goldens, which DR-253 left as an aspiration that carries no gate.

**Do not pixel-diff the canvas as the first line of defence, and do not byte-diff the PDF.** The primary painter regression net is a canonical deterministic text dump of the `DiagramScene`:

```text
RECT      l=0 t=0 w=48260 h=186690  fill=#1A1D21 stroke=#3A4048/0.75pt
TEXT      "U42" @(-2400,900) font=RackMono size=6.0pt anchor=centerRight baseline=903.4
POLYLINE  [(12000,4445),(20000,4445),(20000,17780)] stroke=#009E73/1.5pt dash=none
PATH      "M0 0h8v6h-8z" @(31000,8890) fill=#0072B2
```

Every colour in that sample is a real palette value, because the whole argument for the dump is that a reviewer reads *"the wire changed colour"*, a fixture teaching a hue that does not ship teaches the reviewer nothing. `#009E73` is Network, the domain that ships at 1.5×; `#0072B2` is Digital Video. The opcode is `PATH`, not `SVGPATH`: `drawSvgPath` does not exist on `DiagramCanvas`, and authored `d` strings are parsed once at catalog load by `DiagramPath.fromSvg`, because a backend that parses strings is a backend that can disagree with the other one. The dump keeps the `d` payload; only the opcode changed.

This is reviewable in a pull request (a reviewer reads *"the wire moved 2 mm and changed colour"*, not *"47 pixels differ"*), it is deterministic across platforms and Flutter versions, it runs under `dart test` with no Flutter binding, and because CR-086 puts screen and print on **one** rendering path it covers both simultaneously. Device faceplates are covered by construction, which is the parity mechanism CR-086 exists to create. Goldens pin `lodLevel` explicitly, with at least one golden at print LOD (AC-016 #13).

Pixel goldens then serve one narrow purpose: proving the two backends are faithful interpreters of that list. Keep them small and few.

- `matchesGoldenFile` via plain `flutter_test`. No `golden_toolkit`, no `alchemist`, the value over a good `flutter_test_config.dart` is small and the maintenance risk is not. ~~VERIFY: `golden_toolkit` maintenance status at the time of scaffolding.~~ **Moot (2026-10-12, `#1056`):** the choice above was plain `flutter_test`, and no golden library is a dependency.
- Golden the device faceplate renderer and the wire layer **separately**. Never golden the whole canvas: one pixel of change anywhere fails everything and reviewers begin rubber-stamping.
- `debugDisableShadows = true`, fixed `Random` seeds, no animations, fixed `Size`. A separate invariant test asserts the scene contains no gradient, shadow, blur, blend mode or shader op (CR-088 deleted `RendererCaps` and promoted that rule from prose to a test) and that `saveLayer` count is zero.
- Tagged `@Tags(['golden'])` in `dart_test.yaml` so non-Linux jobs skip them. (Not built: there is no `golden` tag.)

### 3.1 Font strategy: the thing that actually makes goldens flaky

Two families ship, named so no test ever names a system font: **Jost** (Regular 400 and Medium 500, a modified build) for text, and `RackMono` = Space Mono (Regular + Bold), both SIL OFL 1.1 (CR-080 as amended by DR-249, canon §11.248). `RackCond` is retired and schedules are set in Jost; no fallback face ships, and `tools/glyph_coverage_check.py` holds the codepoints. The earlier Plex trio and its Noto fallback are history (canon §12.57).

Four rules remove the system-font variable entirely:

1. Register the bundled TTFs in `flutter_test_config.dart` via `FontLoader` before any golden runs.
2. A test asserts **no golden scene references a family other than `Jost` or `RackMono`**: a fallback silently substituting Ahem or Roboto is the classic invisible golden drift.
3. **Pixel** goldens, if they are ever built, run on **one platform only**, with a **pinned** Flutter version, and the other platform's job excludes them. The design named Linux; the project has no Linux job, so the platform is whichever one is blocking, which is Windows (DR-255). Per-platform golden sets collapse under maintenance cost within months; this is the only approach that holds.
4. Golden regeneration is a deliberate, reviewed step of every Flutter upgrade, because a minor bump routinely shifts antialiasing by a pixel.

---

## 4. PDF output testing

### 4.1 Why byte comparison fails

A PDF's bytes are not deterministic: `/CreationDate` and `/ModDate` are wall-clock, object numbering and the xref table depend on emission order, and font subsetting depends on the glyph set encountered. Hashing the file therefore produces a test that fails on a clock tick and passes on a wrong drawing. **Never hash the file.** Generation itself is made as deterministic as it can be, a fixed `DateTime` injected through the same `Clock` the document uses, a fixed document ID, no randomness in layout (CR-013), so that a diff between two runs of the same fixture is small and explicable, but the assertion is structural.

### 4.2 Structural assertions, every PR

Generate a document from each starter project and assert: page count equals the dry-run count; page sizes match the requested `ExportSpec`; every font referenced is embedded and subset; no page is empty; the **schedule row count equals the `Link` count** for the sheet's filter (one row per cable, services on a sub-line, per CR-010); every `W###` designator on the diagram appears in the schedule and vice versa; the 40-sheet warning fires and the 2000-sheet cap is not hit (AC-050/A7.4); the legend prints **one row per named cable type**, not per domain, and all ten requirement-4 types are present (AC-054); `T0.02` lists every `AckedFinding` with reason, author and date; and, the G3 assertion, a document with errors at every severity still writes a file.

Two further families of assertion, each defending a ruling that is easy to erode silently:

- **Sheet furniture is a deliverable, so it is asserted (DR-005).** Every emitted sheet carries a title block, a revision block, a drawing border, zone references and a sheet number; revision clouds render where a revision is flagged; the issued-for-construction stamp appears when the `ExportSpec` requests it. Sheet furniture is **orthogonal to wire idiom**: a fully drafted sheet still renders net labels by default (DR-001), and no assertion here may be written as though polish implied drawn wires.
- **The `T6.01…` count is a partition, not multi-sheet authoring (DR-004, CR-073).** Assert that the document contains exactly one schematic `Sheet` and that the exporter emits one interconnect sheet per domain partition of it, so cross-sheet connections are zero by construction. There are no match lines, no off-sheet connectors and no sheet-boundary link handling to test, because they are never built. A test that reads "N sheets came out of the PDF, therefore multi-sheet exists" is asserting the wrong thing. Those sheets render `drawn`, because a domain partition *is* a domain filter; and where `ExportSpec.wireRender: auto` degrades a dense sheet back to `netLabels`, a test asserts the printed note saying so is present, a degradation the reader cannot see is a lie about the drawing (G4).

### 4.3 The CR-081 baseline parity assertion, concretely

CR-081 makes one injected `TextMeasurer`, backed by `PdfFont.stringMetrics` and living in `rackpal_text`, the single source of truth for both backends, and AC-007 requires the parity test to assert on **baseline Y**, not just a bounding box. The test is written against the one declared shape: `TextMetrics measureText(String text, TextStyleSpec style)`, declared in `rackpal_core/draw/text.dart` alongside `TextMetrics`, `TextStyleSpec` and the 12-value `TextAnchor`, with `DiagramCanvas` in `rackpal_core/draw/canvas.dart` carrying the identical signature on every backend. Neither `draw/text_measurer.dart` nor `draw/diagram_canvas.dart` exists; a test that imports one is testing a file the design does not have. That is directly testable in four steps:

```dart
const kFixtures = ['AV Wa To Ty', 'W014', 'WO14', 'Ω 75 µs', 'RK1-PP2-24'];

for (final s in kFixtures) {
  for (final anchor in TextAnchor.values) {
    // 1. One scene, built once, in pure Dart with the shared measurer.
    final scene = SceneBuilder(measurer: PdfFontMeasurer(RackBody.regular))
        .buildTextProbe(s, anchor, size: 8.0);
    final op = scene.ops.single as TextOp;   // carries the resolved baseline Y

    // 2. What the PDF backend actually emits: the Tm/Td translation in the
    //    content stream for this op, un-flipped by the single global flip (CR-085).
    final pdfBaselineY = PdfProbe.baselineOf(renderToStream(op));   // SUPERSEDED 2026-10-12: the
                                                                    // gate was built differently, as
                                                                    // apps/rackpal/test/baseline_parity_test.dart

    // 3. What Flutter actually paints, with kern AND liga disabled (CR-081).
    final painter = TextPainter(text: op.toTextSpan(), textDirection: TextDirection.ltr)
      ..layout();
    final uiBaselineY = op.origin.y + painter.computeDistanceToActualBaseline(TextBaseline.alphabetic);

    // 4. Both must agree with the shared value and with each other.
    expect(pdfBaselineY, closeTo(op.baselineY, op.baselineY.abs() * 0.005));
    expect(uiBaselineY,  closeTo(op.baselineY, op.baselineY.abs() * 0.005));
    expect(painter.width, closeTo(op.advanceWidth, op.advanceWidth * 0.005));
  }
}
```

`'AV Wa To Ty'` is the kerning-heavy fixture named in AC-007; if Flutter applies GPOS kerning and dart_pdf does not, this string diverges first. `'W014'` versus `'WO14'` is the glyph-disambiguation case CR-080's font argument rests on. The anchor loop matters because `TextAnchor` resolves in one shared pure-Dart helper (CR-081), the test proves neither adapter guesses a baseline, which is the failure that is otherwise diagnosed months later as "the PDF is wrong". A second test covers CR-085: a label rotated 90° for a vertical rail lands in the same place under the global flip as an unrotated one does under composition, which per-coordinate negation could not satisfy.

### 4.4 Pixel diff, nightly only

Render pages with poppler's `pdftoppm` in the Linux job and image-diff against references. Nightly, not per-PR: it is slow and mildly flaky, and it is the third line of defence behind structural assertions and display-list goldens. ~~VERIFY: `pdftoppm` availability and version pinning on the GitHub-hosted Ubuntu image.~~ **Moot (2026-10-12, `#1056`):** CI is Azure on Windows, and pages are rendered through the vendored pdfium (DR-153), not `pdftoppm`.

---

## 5. Widget and integration tests

**Widget tests** cover the surfaces where state and UI meet: inspector panels binding typed `DeviceOverrides` (CR-053); the device-builder port grid with fill-down and TSV paste; menu enablement (Undo disabled at sequence 0, enabled after one command, with the correct label); the spring-back reason chip and its `[ Connect anyway ]` affordance (CR-017); the Staging Bin return affordance (CR-032). **Leak tests** via `leak_tracker_flutter_testing` run on every canvas widget test, targeting undisposed `TextPainter` and `ui.Picture`, with a 12,000-entry label cache (AC-009) that is not optional.

**Integration tests** (`integration_test`, desktop) cover the file lifecycle end to end: new → place devices → connect → save → close → reopen → assert a **byte-identical** document; the unsaved-changes close interception; the crash-recovery path (kill mid-edit, relaunch, assert the recovery prompt, accept, assert the document matches); open a `.rppj` with a newer `minReaderVersion` and assert the refuse path, then one with a newer `schemaVersion` only and assert the read-only banner (CR-093). Two error-surface cases from AC-058/D3 are integration tests because nothing else catches them: **target PDF open in Acrobat**, the most common Windows export failure, and two app instances on one file.

The keyboard connection path (AC-058/D11) is asserted at both levels: a widget test drives select port → `W` → `Tab`/`Shift+Tab` across all ports → `Enter` and asserts one `Link` results; the NVDA/VoiceOver announcement matrix is manual and gated at M7.

---

## 6. Performance testing against the budget

The budget lives in [Architecture](03-architecture.md); this is how it is defended. Scale targets are 200 devices / 2,000 ports / 1,000 links, hard caps at 500 / 6,000 / 3,000, with a soft warning at 1.5× and an open-read-only gate at 3× (AC-058/D14).

| Operation | Target (p95) | Harness |
|---|---|---|
| Commit a command | **≤ 16 ms**, ≤ 8 ms reserved for non-paint terms (re-baselined by AC-008) | `benchmark_harness` + op count |
| Undo / redo step | ≤ 4 ms | core benchmark |
| Full layout, cold, 300 links | ≤ 40 ms | core benchmark on the 300-link fixture |
| Full DRC sweep (isolate) | ≤ 150 ms, no UI hitch | isolate timing |
| Load → first paint (500 KB) | ≤ 400 ms | integration `Stopwatch` |
| Explicit save (500 KB, atomic) | ≤ 150 ms | integration test |
| PDF export, 8-sheet set | ≤ 2.5 s, UI never blocks > 16 ms | export benchmark |
| Cold start → empty document | ≤ 1.2 s (includes lazy `PdfTtfFont` first-paint cost, AC-016 #18) | `--trace-startup` |

Three mechanisms, and the first one is the CI signal:

1. **Op count per layer, not wall time.** AC-008 is explicit: op count is stable across CI runners and wall time is not. The harness asserts that an edit to one HDMI run rebuilds ~1,200 ops in one of the eight per-domain sub-pictures and that the other seven are untouched. Wall-clock thresholds are asserted too, but the job is **warn-only for the first three months**: establish the baseline curve on runner hardware before it can fail a build, or three months are spent chasing variance instead of writing the app.
2. **The LOD gate is a test, not an intention** (AC-009): at fit-to-sheet zoom, assert **zero text runs laid out**. `dashPath` is explicitly profiled rather than assumed cheap (AC-016 #17).
3. **DevTools timeline on demand**, driven by a scripted 30-second pan/zoom/drag `integration_test` under `--profile`, asserting `frame_build_times` and `frame_rasterizer_times` p95 from `TimelineSummary`. Not per-PR: desktop CI runners have no GPU worth trusting.

A three-item manual checklist catches what nothing automated will: `debugRepaintRainbowEnabled` (only the overlay flickers during a drag), `checkerboardOffscreenLayers` (must be zero, any `saveLayer` is a bug), and dragging the window between a 4K and a 1080p monitor, because mixed-DPI breaks naive viewport code and Windows users genuinely run that configuration.

---

## 7. CI

> **Rewritten 2026-08-03 under [DR-017](canonical-decisions.md)**, which answered the open decision [docs/12 §4.1](12-milestone-board.md) recorded: **adopt `dart format` as a gate, keep the analyzer's info ratchet.** What stood here until then was a GitHub Actions workflow running `dart analyze --fatal-infos` and a three-OS matrix, none of which existed. The pipeline is Azure DevOps, on one agent, and had been for months. A CI section describing a provider the project does not use is not a specification, it is a trap: docs/12 §4.1 caught it only because somebody ran both and compared.

**What runs today.** One job, `windows_ci`, defined in [`azure-pipelines.yml`](../azure-pipelines.yml) and run on the **self-hosted agent in the `Default` pool** (it ran on a Microsoft-hosted `windows-2022` image until 2026-08-30; the `pool:` block there says why it moved). It is the blocking build-validation policy on `main`. Its gates are the ones `tools/ci/run_local.ps1` runs, in the same order, minus the two local-only checks (`flutter pin`, `tracked sources`), which a clean clone cannot fail by construction: the pipeline installs and verifies the pinned Flutter itself. **The number of gates is not written here**: count the `Invoke-Gate` calls in `run_local.ps1`, the one place that holds it. Every gate is reproducible locally with `pwsh -File tools/ci/run_local.ps1`:

| Gate (`run_local.ps1` name) | What runs | Fails when |
|---|---|---|
| `flutter pin` (local only) | `tools/ci/ensure_flutter.ps1 -VerifyOnly` | The machine is not on the pinned version and framework revision, which live in `flutterVersion` and `flutterFrameworkRevision` in `azure-pipelines.yml` and nowhere else |
| `tracked sources` (local only) | `tools/ci/verify_tracked_sources.ps1` | A `lib/` source is untracked, so a clone would not compile |
| `flutter pub get` | At the workspace root | Resolution fails for any member |
| `analyzer gate` | `tools/ci/analyze_gate.ps1` | Any error, any warning, or **more infos than the pin** in `tools/ci/analyze_info_baseline.txt`, which carries its own history |
| `formatter` | `dart format --output=none --set-exit-if-changed .` | Any file is unformatted |
| `PAL-1 conformance` | `python tools/pal1_check.py` | A palette collision ships. **Blocking**, and it needs no Dart, so a Dart refactor cannot break it |
| `palette parity` | `python tools/palette_parity.py` | The documented dashes and weights disagree with the checker |
| `registry parity` | `python tools/registry_parity.py` | The Dart seed disagrees with `pal1_check.py` on hue, dash or weight (DR-010), or with seed-devices §4.4 on a family's name, connector, tag, direction or topology (DR-175) |
| `milestone completeness` | `python tools/milestone_gate.py` | A milestone before the current one holds an exit clause that is neither `DEMONSTRATED` nor `CONFIRMED` nor parked on a later milestone by a ruling (roadmap §8.9, [DR-095](canonical-decisions.md)). It runs its own planted cases first |
| `rule review pack` | `python tools/rule_review.py --check` | A rule has no place in the review pack's grouping (`docs/20-rule-review.md`), or sits in the wrong band (#972). It writes nothing |
| `identity (DR-258)` | `python tools/identity_gate.py` | A commit reachable from `HEAD` has an author or committer other than the identity [DR-257](canonical-decisions.md) ruled, or an offset other than `+0000` ([DR-258](canonical-decisions.md)). A shallow clone fails it, so CI fetches commits only first; `--ci` skips only a PR build's own merge. Planted cases first |
| `glyph coverage` | `python tools/glyph_coverage_check.py` | A non-ASCII character in a Dart string literal is missing from a bundled font weight (DR-090 §11.89.8). The only gate that reads a font binary; it needs `fontTools`, which a pipeline step installs hash-pinned |
| `JUnit converter self-test` | `tools/ci/junit_converter_selftest.py` | The converter would report green over a red run: a failing hidden `loading` test dropped, or a missing `done` event or `success:false` not becoming a failure. Each clause is asserted with a clean stream that must **not** produce it |
| `AC-051 pair coverage` | `dart test test/validation/drc_corpus_test.dart` in `rackpal_core` | A catalogue rule lacks either half of its fixture pair. A named step although the core suite runs the same file, so the schedule control reads as its own failure |
| `suite: <name>`, one per package | `tools/ci/run_suite.ps1` for `rackpal_core` (untimed), `rackpal_text`, `rackpal_export`, `rackpal_pdfium`, `rackpal_ui` and `apps/rackpal` | Any test fails, **or** a suite falls below its non-vacuity floor, recorded in `$SuiteFloors` in `run_suite.ps1` and nowhere else. The floor counts **non-skipped** cases, so silencing a flaky batch cannot buy a green run |
| `suite: rackpal_core_timed` | `run_suite.ps1 -Tests timed` in `rackpal_core`, after every suite | A test tagged `perf` misses its stopwatch budget, run one test at a time. The core suite runs `-Tests untimed` and leaves those tests to this step ([DR-178](canonical-decisions.md)), so a budget never shares the machine with its own suite |
| `flutter build windows --release`, then `windows release output` | `tools/ci/verify_windows_build.ps1` | The build fails, or the release output has a plugin DLL removed, the exe missing, a packaged starter CRLF-corrupted, or a `dartjni.dll` **planted** (it must not be there) |

**Definition 2, `RackPal CI (macOS)`** ([`azure-pipelines-macos.yml`](../azure-pipelines-macos.yml), [DR-255](canonical-decisions.md) §11.254) runs the same gates on a Microsoft-hosted `macOS-15` image, as an **optional** PR check that **may never be made blocking**. It reads the Flutter pin from `azure-pipelines.yml` rather than restating it, leaves out the timed budgets (a shared hosted VM measures the VM), and **also builds `RackPal.app`**: `flutter build macos --release`, then `tools/ci/verify_macos_build.ps1`, then an archive round-tripped through `ditto` and checked with `codesign --verify`. Its suite floors differ from Windows only where `$SuiteFloorsMacOS` in `run_suite.ps1` says, and each difference names its cause.

**The analyzer gate and the formatter differ deliberately, and [DR-017](canonical-decisions.md) is why.** The analyzer gate is a ratchet rather than `--fatal-infos` because 195 infos on the day CI was stood up would have made `main` permanently red, and a permanently red `main` trains people to ignore output. The formatter is absolute because formatting is mechanical: it has one correct answer and the gate's own remedy is the same command. Documenting the two as one question was this section's original error. Clearing the remaining infos (the pin in `tools/ci/analyze_info_baseline.txt` says how many) and switching the analyzer gate to `--fatal-infos` stays available and is nobody's scheduled work (DR-017 §11.16.4).

**Caching.** The Flutter SDK (keyed on the exact pinned version, and skipped when the agent already has it) and `~/.pub-cache`, keyed on the committed `pubspec.lock`. Do not cache `build/`: a stale plugin registrant costs more debugging time than a cold build costs wall time.

**Artifacts.** The raw `dart test` JSON streams and the converted JUnit documents on every run, for forensics, plus the archived Windows release on a successful build.

**Designed and NOT built.** Kept here because they are the intent, and marked because the section above is a claim about what exists:

- **A pixel-goldens job.** There are no pixel goldens: no `matchesGoldenFile`, no `goldens/` directory, no `@Tags(['golden'])`, no `flutter_test_config.dart` registering Jost. The byte and text goldens of DR-253 exist and run inside the suites that hold them, with no tag. §3.1's one-platform rule applies the day the first pixel golden is written. The pipeline deliberately has neither a `--tags golden` step nor an `--exclude-tags golden` one, so the first golden somebody writes runs immediately rather than being silently skipped.
- **A Linux agent, and a blocking macOS check.** DR-009 puts macOS in v1 and [docs/13](13-macos-debt-register.md) is the work list; the macOS pipeline exists as an optional check (above) and is never blocking (DR-255). A blocking macOS check would need a macOS agent that costs no hosted minutes, which is a later ruling. No Linux job exists or is planned.
- **`flutter gen-l10n && git diff --exit-code`** (AC-058/D12). There is no `l10n/` and no generated Dart in the tree at all.
- ~~**A `--tags perf` job.**~~ **Built on 2026-09-15 as a blocking step, not a job** ([DR-178](canonical-decisions.md)). Until then `schematic_perf_test.dart` ran inside the core suite, where on 2026-09-05 a budget read 20.877 ms under the suite's own load against 6.355 ms alone and failed a docs-only commit. The tests tagged `perf` now assert only a stopwatch reading and run after every suite, one at a time.
- **A nightly `--tags pdf-pixel` job** needing `poppler-utils`.

The Flutter version pin is load-bearing and lives in exactly one place.

**Nothing is adopted until it is fourteen days old** (DR-248, a standing rule): a pub package, direct or
transitive, or a Flutter release, measured from its pub.dev publication date or its release-feed date
on the day of the upgrade. An exception names its reason in the commit that takes it; a security fix is
the one anticipated. Followed by the person upgrading, not yet enforced by a gate.

---

## 8. Linting and `analysis_options.yaml`

`very_good_analysis`, **pinned exactly** (`11.0.0`, not `^11.0.0`; 9.0.0 until DR-248) and bumped deliberately, because a minor bump of a third-party lint set can fail CI on code nobody touched. Fallback if the strictness proves noisy in practice: `flutter_lints`. It is stricter than `flutter_lints` where it matters for a document editor, `prefer_final`, `avoid_dynamic_calls`, and the unawaited-future family.

Project additions on top of the base set:

- **Errors and warnings gated at zero; infos ratcheted, not `--fatal-infos`.** The principle below is unchanged and is why the ratchet exists at all: an info-level lint that nobody fixes is a lint that trains people to ignore output. What the 2026-08-03 ruling changed is the enforcement, because switching on `--fatal-infos` against a 195-info tree would have made `main` red on the first push and taught the same lesson faster. The pin only moves down. See §7's analyzer gate and `tools/ci/analyze_info_baseline.txt`.
- `public_member_api_docs` **on for `rackpal_core` only**. The core is the shared vocabulary; the UI package is not.
- Generated code (`*.g.dart`, `l10n/`) excluded; nothing else is.
- Custom naming is enforced by test rather than by lint, because no analyzer rule expresses it: N3 (types `UpperCamelCase`, JSON keys `lowerCamelCase`, registry IDs `lower.dotted.snake`, tokens `UPPER_SNAKE`, rule IDs `AAA-000`) and N4 (a serialized `weight` or `length` without a unit suffix or a unit type is a defect) are asserted over the codec layer in `naming_conventions_test.dart`.

~~VERIFY: `very_good_analysis` 9.x rule set against Dart 3.12 before pinning.~~ Superseded by DR-248's move to 11.0.0 on Dart 3.13.4, measured rather than verified in advance: the infos it added, and what was fixed, are recorded in `tools/ci/analyze_info_baseline.txt`. **A bump moves two things**: the pubspec pins and the versioned include in `analysis_options.yaml`, since every release ships the older rule files and a package-only bump changes nothing.

---

## 9. Definition of done

A change is done when all of the following are true. This list is the PR checklist and it is short on purpose.

1. `pwsh -File tools/ci/run_local.ps1` is green: every gate it runs (§7; count them in the script), including zero analyzer errors and warnings, an info count at or under the pin, and `dart format` clean.
2. New behaviour has a test at the **lowest tier that can express it**: a rule gets fixtures, not a widget test; a layout change gets a display-list golden, not a screenshot.
3. A new rule ships with its `.bad`/`.near` fixture pair (AC-051). No exceptions; this is the gate that holds the catalogue to its size, and **it follows the rule rather than the list** (DR-154 §11.153.4), so it covers the plan band too and reports per band. `drc_corpus_test.dart` is where the coverage is asserted, and it is the only place a count of pairs is written down.
4. A new command declares its `touches` mask and passes the epoch-coverage test (AC-014), and participates in the round-trip property test.
5. A format change adds a schema fixture on the day it ships and never edits an existing one (§2.5).
6. A change to any signal-family hue, dash or weight, in the registry **or** in a prose table, keeps `python tools/pal1_check.py` at exit 0, and the family list in that file was updated in the same commit. PAL-1 is never re-blessed by reading (§2.6).
7. A new name exists in [the glossary](01-domain.md) and in canon §4, and no banned name was introduced ([canon §4.7](canonical-decisions.md#47-banned-names), N2).
8. Any user-visible string is localisable and any number that could be unknown renders `—` with an unknown count in its rollup (G4).
9. Goldens that changed were regenerated deliberately and the diff was read, not rubber-stamped.

A milestone is done when its exit criterion in [Roadmap](09-roadmap.md) is demonstrated by running something, CI is green, goldens pass, and the app opens all four starter projects. A milestone that ends with a known-broken build has not ended.

---

## 10. Crash reporting, diagnostics, and the privacy stance

**No telemetry by default.** RackPal is a locally installed professional tool holding client project data; silent network egress is a trust violation and for some commercial clients a contractual one.

- On an uncaught error, write a redacted bundle plus stack to `crashes/<timestamp>.json` in application support. `ErrorWidget.builder` is replaced by a neutral pane offering "Copy diagnostics" and "Save a recovery copy", a red-and-yellow error box inside a professional tool destroys credibility.
- On next launch, offer **View report** (showing the exact JSON, no hidden payload), **Send**, and **Never ask again**. Nothing leaves the machine without an opt-in, and then only to a self-hosted Sentry, which is deliberately **not a v1 dependency** until there is somewhere to send reports.
- **Recovery files are never attached automatically (CR-096).** A recovery file is a complete project containing the client's name and site address. The crash dialog offers an explicit, **default-off** "Attach the project file" checkbox labelled *"This includes your client's name and site address."* The design document contradicted itself here; this is the resolution.
- The diagnostics bundle carries versions, document **statistics** (device count, link count, schema version), the last 200 log records, and epoch/`sequence` values, never document content.
- **Redaction is a test.** `redaction_test.dart` asserts no log call above `FINE` interpolates a device name, client name, project address or file path, and that a synthesized crash bundle built from a starter project contains none of that project's proper nouns. Convention alone does not survive a debugging session at 2 am.
- Rollback poisoning is tested: force a command to throw mid-`apply`, assert the transaction reverts, and if revert itself fails assert the undo stack is poisoned, a forced recovery snapshot is written, and the unrecoverable notice appears (M8 exit criterion: a deliberately induced crash produces a local report containing no project content).

---

## 11. Later work: signing, notarisation, and distribution

Named here so it is not rediscovered, and scheduled in [Roadmap](09-roadmap.md) rather than treated as a build step (AC-058/D10 calls distribution the largest unowned area in the corpus).

| Item | When | Note |
|---|---|---|
| ~~Windows OV/EV certificate procurement~~ **Self-signing, with a timestamp** | M8: **not M6, and there is no procurement** | **Superseded by DR-006 (canon §12.9); owed edit paid 2026-08-03.** `New-SelfSignedCertificate` + `Set-AuthenticodeSignature` **with a timestamp server**, public `.cer` to `LocalMachine\Root` and `\TrustedPublisher`, ideally by GPO. **Microsoft Trusted Signing is the named fallback**, adoptable at M8, verify eligibility for an Individual Partner Center account before relying on it (#101). The lead time the old row defended against was OV/EV identity verification, the SmartScreen reputation ramp and hardware-token logistics; none attaches to either path DR-006 names |
| Signed MSIX / installer, symbol archival | M8 | **The criterion SPLITS (canon §11.6.2).** Build-side gate: signed, timestamped, valid publisher in file properties, **and the signature still validates after the signing certificate has expired**. Distribution-side, documented and not gated: Local Intranet UNC or Intune/GPO, plus docs/14 §14.2's ZIP trap. **"No SmartScreen warning" is not a build-side property**: SmartScreen evaluates Mark-of-the-Web, which is how a file arrived, not what it is |
| Vendored pdfium | **Built (DR-153, canon §11.152), for both platforms** | Windows x64 (`win-x64/pdfium.dll`) and macOS universal (`mac-univ/libpdfium.dylib`, #468) are vendored under `third_party/pdfium/` and placed by a person; nothing fetches either (CR-100). It was scheduled here for M8 because the `printing` plugin's CMake downloads binaries at build time; DR-153 vendored the binary through `rackpal_pdfium` instead, and the export preview renders through it (DR-230 §11.229.1). The macOS binary is in the app bundle's Frameworks copy phase and `tools/ci/verify_macos_build.ps1` gates it; what docs/13 D9 still carries is in that register |
| macOS notarisation and stapling | **In v1 by DR-009; how it is done is unruled** (docs/13 D8) | DR-009 puts macOS in v1, so this is no longer conditional on §10.10. It is where the anonymity constraint costs most (DR-254 §11.253.2): Apple notarisation needs a Developer ID enrolled under a legal name. DR-256 ruled the hardened runtime on, which notarisation requires. The original row's estimate, kept as written and not re-measured: `Cmd`/`Ctrl` bindings across ~40 entries, a second font-availability check and a second print matrix, 3–5 weeks plus ongoing CI |
| Reproducible signed builds | Post-v1 | A signed release is a supply-chain and reproducibility problem, not only a CI one |
| In-app auto-update | **Not doing in v1** (RJ-014) | Signed installer plus a version-check ping. Auto-update is a security surface and a support burden before there are users |

VERIFY: MSIX packaging versus a plain signed installer for a desktop app that registers a `.rppj` file association, the file-association path differs between the two and drives the choice. **Answered in part (2026-10-12, `#1056`):** the Store alpha (`#100`) packages as MSIX, and MSIX-7 (`#171`) registers the association in its manifest; a plain installer for copies outside the Store is still undecided. **Superseded in part (2026-10-17, DR-254 §11.253):** the Store alpha (`#100`) is **parked on M8** and `#171` moved to M8 with it, because the distribution route is not chosen. The user's direction (WinGet and a Homebrew cask) is recorded and not ruled; **anonymity, at least initially, is a stated constraint on distribution**, and the route is ruled at M8's decomposition after `DIST-0` (`#1105`) verifies the facts. DR-006 stands until then, and whether a self-signed certificate is compatible with the constraint is one of `#1105`'s questions.

---

**Related:** [Overview](00-overview.md) · [Architecture](03-architecture.md) · [Data model](02-data-model.md) · [PDF export](08-pdf-export.md) · [Roadmap](09-roadmap.md) · [Decisions](10-decisions.md)
