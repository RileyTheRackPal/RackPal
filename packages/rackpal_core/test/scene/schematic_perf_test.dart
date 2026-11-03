// M2's PERFORMANCE exit criterion, measured rather than asserted:
// "routes a 300-connection fixture within one frame at commit"
// (docs/09, docs/12 §5.1).
//
// docs/12 §4 records that there was "no perf test and no CI to run one in",
// and names the missing instrument: "Grep for `@Tags` / `Tags([` across every
// Dart file returns nothing." This file is the first one.
//
// ── WHERE IT RUNS, AND WHY IN TWO PLACES (DR-178, `#843`) ──────────────
// A test here asserts a COUNT, a DIGEST or a SHAPE, or it asserts a
// STOPWATCH READING, and never both. The first kind runs in the core suite
// on every push. The second kind carries [_timed] and runs in a gate step
// of its own, one test at a time, because a stopwatch shares the machine
// with whatever else is running: on 2026-09-05 the text-bound budget read
// 6.355 ms alone and 20.877 ms under its own suite's load, and failed a
// commit that touched three markdown files. Both steps block a merge, so
// the budget is still defended on every push, not just recorded.
//
// ── WHAT IS AND IS NOT MEASURED, STATED PLAINLY ─────────────────────────
// MEASURED: the whole commit-path recompute — the document projected onto
// the graph, phases 0–3, and the display list emitted. At M2-C that was
// the symbol layer alone; at M2-D it is the symbols AND the net labels,
// which is now the whole default render of the sheet.
//
// THE LABEL-LAYER COST IS THE CLAUSE M2-C DELIBERATELY DID NOT CLAIM
// (AC-016 #20, docs/03 §5.2's "the dominant commit-path term is the label
// layer, not the wire layer"). M2-C recorded its symbol-layer number so
// that this stage could state a DELTA against a real baseline rather than
// guess one, and [_kM2cOps] / [_kM2cMs] below are that recorded baseline.
// The op delta is exact and machine-independent; the millisecond delta is
// not, because the baseline was taken in a different process on a
// different day — so the label layer is ALSO timed on its own, in this
// same process, against this same run's total. That second figure is the
// one to trust.
//
// AND IT IS MEASURED TWICE, ON TWO DOCUMENTS, because the committed
// fixture understates the label layer by construction — see
// `_withNetsAndRegistries` and the corpus note on its own group.

import 'dart:convert';
import 'dart:io';

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

import 'op_digest.dart';
import 'schematic_fixture.dart';

/// One frame at 60 Hz. The criterion's own unit; not a tuned threshold.
const double _oneFrameMs = 1000 / 60;

/// The tag every STOPWATCH assertion in this file carries, and nothing else
/// here does (DR-178, `#843`).
///
/// `tools/ci/run_suite.ps1 -Tests untimed` leaves these out of the core
/// suite, and `-Tests timed` runs only these, one test at a time, in a gate
/// step of their own. A test that asserts an op count or a digest must NOT
/// carry it: that half of the record is machine-independent, and it belongs
/// in the suite beside everything else.
const String _timed = 'perf';

/// M2-C's recorded symbol-layer figures on THIS fixture: 4,155 ops, best
/// of 15 = 3.052 ms. Written down rather than re-derived, because the
/// symbols-only path no longer exists — `buildSchematicScene` has no flag
/// that turns the labels off, deliberately (DR-001 makes them the default
/// render, not an option over one).
const int _kM2cOps = 4155;
const double _kM2cMs = 3.052;

/// The symbol layer's op count on this fixture SINCE `#801`, which is what
/// the total is actually asserted against.
///
/// ═══════════════════════════════════════════════════════════════════════
/// 4,155 IS KEPT ABOVE RATHER THAN OVERWRITTEN, BECAUSE IT IS A RECORD
/// ═══════════════════════════════════════════════════════════════════════
/// `_kM2cOps` is what M2-C measured, and editing it in place would leave
/// the file claiming M2-C had measured a number that did not exist until
/// `#801`. The two are different facts and both are worth having: the
/// delta IS the change.
///
/// **4,155 -> 2,371, which is 1,784 ops and 42.9% of the symbol layer.**
/// CR-103's bank collapse now runs on first layout as well as in the
/// preview, so the fixture's banks over eight draw one vector pin each
/// instead of one pin per port. The saving is large because the fixture is
/// twenty-four switches and patch panels wide.
///
/// MEASURED TWICE AND EQUAL: the committed fixture reports 3,463 total
/// against 948 label ops, and the nets-and-registries document reports
/// 3,700 against 1,185. Both leave 2,515, which is the check that this is
/// the symbol layer moving rather than the label layer.
///
/// **2,371 -> 2,403 -> 2,515 ON 2026-09-04, IN TWO MOVES WITH DIFFERENT
/// CAUSES.** The first was DR-120 giving `F13` a third bus alternate:
/// sixteen keypads times two ops for one more vector pin, +32 exactly.
///
/// The second is DR-121 and is not a regression. Giving the keypad ONE
/// bus port broke this fixture outright with *"KEY-1 ran out of ports"*,
/// because it had been wiring TWO home runs into each of sixteen
/// keypads and the second was landing on an alternate no installer would
/// wire. The fixture now holds THIRTY-TWO keypads with one bus cable
/// each, still 300 links, and the +112 is sixteen more device bodies to
/// draw against thirty-two fewer bus pins.
///
/// **THE OLD NUMBER WAS CHEAPER BECAUSE THE FIXTURE WAS WRONG**, which is
/// the honest way to read this: a smaller symbol layer bought by drawing
/// a house that could not be built is not a saving. Label ops did not
/// move in either step (948 and 1,185 throughout).
const int _kSymbolOps = 2515;

/// The headroom fixture: twelve copies of the 300-link pod, which is a
/// building with twelve IDFs rather than a house with one rack.
const int _kHeadroomPods = 12;

/// Devices in the headroom fixture, asserted before anything is timed.
///
/// **110 per pod**, and the arithmetic is written out because the first
/// draft said 93 and the shape assertion caught it: 16 rail (1 MTX, 2 AMP,
/// 2 SW, 6 PP, 1 CTL, 1 PWR, 1 SHF, 2 BLK), 5 shelf (1 AVR, 4 STB), 88
/// field (8 DIS, 10 SPK, 12 IWS, 8 CAM, 6 WAP, 4 TP, 32 KEY, 8 VOL), and
/// the Structure device. `schematic_fixture.dart`'s own header says "93
/// devices", which was the same count with `STR-1` left out of it.
///
/// **94 -> 110 ON 2026-09-04 (DR-121).** The keypads went from sixteen to
/// thirty-two, because the fixture had been wiring two home runs into
/// each of sixteen and the second was landing on a bus alternate no
/// installer would wire. One cable per keypad needs twice the keypads to
/// keep 300 links, and the link count is what this fixture is for.
const int _kHeadroomDevices = 110 * _kHeadroomPods;

/// THE RATCHET, NOT THE BUDGET. Measured at ~110 ms on the machine that
/// wrote this (32 cores, Dart 3.12), and set well above it because wall
/// time is not stable across runners — `schematic_perf_test.dart`'s own
/// header says op count is the machine-independent signal and wall time
/// is not. It exists to catch a regression that makes an already
/// unacceptable number worse, and for nothing else. **Delete it when #702
/// lands**; the budget is `_oneFrameMs` and always was.
const double _kHeadroomCeilingMs = 400;

/// Regeneration is a deliberate act, never a side effect of a test run —
/// `byte_roundtrip_test.dart`'s rule, applied to this golden too.
final bool _updateGoldens = Platform.environment['UPDATE_GOLDENS'] == '1';

const _codec = JsonDocumentCodec();

final class _Measurer implements TextMeasurer {
  @override
  TextMetrics measureText(String text, TextStyleSpec style) => TextMetrics(
    advanceWidth: text.length * style.sizePt * 0.55,
    ascent: style.sizePt * 0.75,
    descent: style.sizePt * 0.25,
    capHeight: style.sizePt * 0.7,
    xHeight: style.sizePt * 0.5,
    lineHeight: style.sizePt * 1.2,
  );
}

void main() {
  group('the fixture is what this test thinks it is', () {
    test('the committed golden survives a load-and-save unchanged '
        '(CR-117)', () {
      if (_updateGoldens) {
        writeSchematicFixture(buildSchematicFixture());
        markTestSkipped('UPDATE_GOLDENS=1 — regenerated, asserted nothing');
        return;
      }
      final stored = File(kSchematicFixturePath).readAsBytesSync();
      final decoded = _codec.read(stored);
      expect(decoded, isA<Ok<RackDocument>>());
      final reencoded = _codec.write((decoded as Ok<RackDocument>).value);
      expect(
        utf8.decode(reencoded),
        utf8.decode(stored),
        reason:
            'CR-117 broken for the 300-link fixture: write(read(bytes)) != '
            'bytes.',
      );
    });

    test('the generator still produces exactly the committed corpus', () {
      if (_updateGoldens) {
        markTestSkipped('UPDATE_GOLDENS=1');
        return;
      }
      final stored = File(kSchematicFixturePath).readAsBytesSync();
      expect(
        utf8.decode(encodeFixture(buildSchematicFixture())),
        utf8.decode(stored),
        reason:
            'schematic_fixture.dart no longer encodes to its committed '
            'golden. If this is intended, regenerate with UPDATE_GOLDENS=1 '
            'and review the diff — that diff is the change.',
      );
    });

    test('it carries EXACTLY 300 links, 600 landed ends and a real graph — '
        'a budget met by a smaller fixture is not met', () {
      final doc = readSchematicFixture();
      expect(doc.links, hasLength(kSchematicFixtureLinkCount));
      expect(doc.ports, hasLength(2 * kSchematicFixtureLinkCount));
      // Every link lands both ends on a materialised port: a fixture whose
      // links dangled would exercise none of the graph.
      for (final link in doc.links.values) {
        expect(link.conductors, hasLength(1));
        expect(link.conductors.first.from, isA<PortEndpoint>());
        expect(link.conductors.first.to, isA<PortEndpoint>());
      }
    });

    test('it contains the cases phases 0 and 1 exist for', () {
      final doc = readSchematicFixture();
      final scene = buildSchematicScene(doc: doc, measurer: _Measurer());

      // A cycle, broken — and broken on the RETURN CHANNEL, which is the
      // one edge in this document that declares one.
      expect(scene.reversedLinkIds, hasLength(1));
      final reversed = doc.links[scene.reversedLinkIds.single]!;
      final arcEnd = reversed.conductors.first.from as PortEndpoint;
      expect(
        doc.ports[arcEnd.portId]!.templatePortKey,
        const PortKey('hdmi.1'),
      );

      // Zero-port devices, counted rather than dropped: two blank panels
      // and a shelf.
      expect(scene.unsymbolisedDeviceIds, hasLength(3));

      // A real layered graph, not one column.
      expect(scene.layers.length, greaterThan(3));
      expect(scene.symbols.length, greaterThan(80));
    });
  });

  group('determinism holds on the REAL fixture, not only on a toy', () {
    test('the same 300-link document lays out to a byte-identical display '
        'list twice', () {
      final doc = readSchematicFixture();
      final first = buildSchematicScene(doc: doc, measurer: _Measurer());
      final second = buildSchematicScene(doc: doc, measurer: _Measurer());
      expect(digestScene(second.scene), digestScene(first.scene));
    });

    test('a SEPARATELY DECODED copy of the same bytes lays out identically — '
        'the decoder builds its maps in its own order', () {
      final a = buildSchematicScene(
        doc: readSchematicFixture(),
        measurer: _Measurer(),
      );
      final b = buildSchematicScene(
        doc: readSchematicFixture(),
        measurer: _Measurer(),
      );
      expect(digestScene(b.scene), digestScene(a.scene));
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // EACH BUDGET IS TWO TESTS (DR-178, `#843`)
  // ══════════════════════════════════════════════════════════════════════
  // The first asserts the display list's op counts, which are the same on
  // every machine, and runs in the core suite. The second asserts the
  // stopwatch and carries [_timed], so it runs alone in its own gate step.
  // They used to be one call that asserted both, which is how a budget
  // with three times the headroom it needed failed a docs-only commit.
  group('the budget', () {
    test('a 300-connection fixture emits exactly the display list its '
        'budget is measured over', () {
      _expectOps(
        readSchematicFixture(),
        // FOUR, AND THAT IS #124's FALLBACK BEING EXERCISED. This document
        // seeds no registries, so no family resolves, so `SignalStyle
        // .glyph` is empty and there is no shape to draw — channel 4 stays
        // the single measured run it has always been. The augmented case
        // below is the same fixture with the registries added and is where
        // the glyph becomes geometry.
        opsPerFlag: 4,
      );
    });

    test('a 300-connection fixture lays out and emits its display list '
        'within ONE FRAME at commit', () {
      _measure(readSchematicFixture(), 'AS COMMITTED (no nets, no registries)');
    }, tags: _timed);

    test('…and still emits exactly its display list with every link named '
        'and every family resolved', () {
      // THE COMMITTED FIXTURE UNDERSTATES THIS LAYER BY CONSTRUCTION, and
      // the understatement is exactly where the cost is. Its own header
      // says `Service`s and `Net`s are "deliberately NOT in it" because
      // "the layout reads `Link.conductors` and nothing else" — TRUE OF
      // M2-C, FALSE OF M2-D. It also predates DR-010, so it carries six
      // empty registry maps and every family resolves to the same
      // unresolved slate.
      //
      // Measured on the as-committed bytes it therefore draws 600 flags
      // that all say `—`, in one colour, with no dash and no domain
      // grouping. That is the FLOOR, not the number canon §11.1.5
      // predicts: "two net labels per Link is ~300 additional text runs …
      // it is now the PRIMARY commit-budget term", and the term is text.
      //
      // So the same bytes are augmented IN MEMORY. The golden on disk is
      // untouched — it is M2-C's baseline document and a regenerated
      // fixture would make the 4,155-op comparison meaningless — and the
      // augmentation adds only what CR-011 says the app itself adds the
      // moment a link is made: one `Service` per link and the implicit
      // `Net` behind it, named `N001`… by `ProjectSettings.netNameFormat`'s
      // own default template.
      final doc = _withNetsAndRegistries();
      _expectAugmented(doc);
      _expectOps(doc, opsPerFlag: 5);
    });

    test('…and still does with every link named and every family resolved '
        '— the case DR-001 §11.1.5 calls TEXT-BOUND', () {
      final doc = _withNetsAndRegistries();
      // ASSERTED HERE AS WELL AS IN THE SUITE, because this test runs in a
      // different step and a precondition checked somewhere else is not a
      // precondition of this measurement.
      _expectAugmented(doc);
      _measure(doc, 'AUGMENTED (300 nets, seeded registries)');
    }, tags: _timed);
  });

  // ═══════════════════════════════════════════════════════════════════════
  // M2-G — HOW MANY TEXT RUNS IS THE PAINT PATH ACTUALLY ASKED FOR?
  // ═══════════════════════════════════════════════════════════════════════
  // The roadmap's M2 risk paragraph sizes a cache against an assumption:
  // "two net labels per Link puts ~300 additional text runs on a
  // 150-connection project on top of the ~10,000 the cache must be sized
  // for", and warns that "a 2,000-entry LRU against ~10,000 runs thrashes,
  // and a thrashing LRU is worse than none because eviction disposes a
  // native `ui.Paragraph` in the paint path."
  //
  // THAT FIGURE HAS NEVER BEEN CHECKED AGAINST THIS TREE. Sizing a cache
  // from it would be the same class of move as the budget this whole file
  // exists to stop being assumed, so the count is taken FIRST, here, before
  // `FlutterDiagramCanvas` gains a cache at all.
  //
  // WHAT IS COUNTED, and why the distinction is the whole measurement:
  //   * TOTAL runs is how many times `drawText` is called on one paint —
  //     the work a cache has to eliminate.
  //   * DISTINCT `(text, style)` pairs is the WORKING SET — the number of
  //     entries a cache must hold to eliminate it. A cache smaller than
  //     this thrashes; a cache larger is only memory.
  // The ratio between them is the hit rate a perfect cache would get, and
  // it is the number that says whether a cache is worth having at all.
  //
  // COUNTED OFF THE DISPLAY LIST, not off a real paint, and deliberately:
  // `OpText` carries the exact `(text, TextStyleSpec)` pair `drawText`
  // receives, so this is the same key at one remove, and it costs no
  // Flutter binding in a pure-Dart package.
  // ══════════════════════════════════════════════════════════════════════
  // THE HEADROOM CASE, AND THE DEBT IT RECORDS (M8-F1, board #702)
  // ══════════════════════════════════════════════════════════════════════
  // The group above measures 300 links and passes at ~5.8 ms. Nobody had
  // asked what happens past 300, and `tool/scale_probe.dart` answered:
  // the scene build is 93 ms at 1,200 links and 110 ms at 3,600. A large
  // commercial job is therefore FIVE TO SEVEN TIMES over the one-frame
  // budget M2's criterion states.
  //
  // It is not a once-per-open cost. `schematic_canvas_screen.dart` bumps
  // `_sceneEpoch` in `_onDocumentChanged`, which fires on EVERY document
  // change, so the scene cache misses and this whole build reruns on
  // every edit while the schematic tab is open.
  //
  // ── WHY THIS DOES NOT ASSERT THE BUDGET ──────────────────────────────
  // Because it would fail, today, on every commit, and a permanently red
  // gate is one people learn to ignore. So it asserts a CEILING instead:
  // the measured figure plus headroom, which cannot get worse without
  // somebody hearing about it, and which is deliberately far too loose to
  // be mistaken for the budget.
  //
  // THE ASSERTION FLIPS WHEN #702 LANDS. AC-008 already prescribes the
  // remedy — eight per-domain sub-pictures, so an edit rebuilds one and
  // seven replay untouched — and `domainFragments` exists but is read
  // only by `schematic_paint_plan.dart`, which is a PAINT-side saving.
  // The recompute is still whole-document, always. When the incremental
  // rebuild ships, delete [_kHeadroomCeilingMs] and assert `_oneFrameMs`
  // like the group above.
  //
  // ── WHY IT IS BUILT AND NOT COMMITTED ────────────────────────────────
  // `schematic_fixture.dart`'s header argues for a committed golden, and
  // that argument is honoured for the 300-link case which remains a file.
  // A 3,600-link golden is roughly 10 MB of JSON whose diff no human will
  // read, in a repo whose plain-JSON decision (CR-091) was taken so that
  // diffs WOULD be reviewable. The stated risk of building in-process is
  // that "a later change to this builder quietly shrink the fixture", and
  // the shape assertions below are the actual guard against that: the
  // builder is deterministic, so every machine gets the same document.
  group('the headroom case — 12 pods, 3,600 links (M8-F1)', () {
    test('THE SHAPE IS WHAT IT CLAIMS, asserted before anything is timed, '
        'because a budget met by a smaller graph is not met', () {
      final doc = buildSchematicFixture(pods: _kHeadroomPods);

      expect(doc.links, hasLength(kSchematicFixtureLinkCount * _kHeadroomPods));
      expect(doc.devices, hasLength(_kHeadroomDevices));
      expect(
        doc.racks,
        hasLength(2 * _kHeadroomPods),
        reason: 'two racks per pod, which is what makes each one an IDF',
      );
      expect(
        doc.sheets,
        hasLength(1),
        reason:
            'DR-004 keeps the sheet set single-sheet, so twelve pods are '
            'twelve rack clusters on ONE drawing',
      );
    });

    test('IT IS OVER THE ONE-FRAME BUDGET, and this test says so out loud '
        'rather than leaving it to be rediscovered (#702)', () {
      final doc = buildSchematicFixture(pods: _kHeadroomPods);
      final measurer = _Measurer();
      // The shape test above runs in the suite; this runs in the timed
      // step, so the one figure the ceiling depends on is checked here too.
      expect(
        doc.links,
        hasLength(kSchematicFixtureLinkCount * _kHeadroomPods),
        reason: 'a ceiling met by a smaller graph is not met',
      );

      buildSchematicScene(doc: doc, measurer: measurer);
      var bestUs = 1 << 30;
      var ops = 0;
      for (var i = 0; i < 5; i++) {
        final watch = Stopwatch()..start();
        final scene = buildSchematicScene(doc: doc, measurer: measurer);
        watch.stop();
        ops = scene.scene.ops.length;
        if (watch.elapsedMicroseconds < bestUs) {
          bestUs = watch.elapsedMicroseconds;
        }
      }
      final ms = bestUs / 1000;

      // `print` rather than `printOnFailure`, for the reason the 300-link
      // group gives: a number that only appears when a test FAILS is
      // recorded nowhere, and this one is the debt's running total in the
      // CI log of every green run.
      // ignore: avoid_print
      print(
        'M8-F1 headroom [12 pods]: '
        '${doc.links.length} links, ${doc.devices.length} devices\n'
        '  total      $ops ops, best of 5 = ${ms}ms\n'
        '  budget     ${_oneFrameMs}ms  '
        '(OVER by ${(ms / _oneFrameMs).toStringAsFixed(1)}x — see #702)\n'
        '  ceiling    $_kHeadroomCeilingMs ms (the ratchet this defends)',
      );

      expect(
        ms,
        lessThan(_kHeadroomCeilingMs),
        reason:
            'the schematic scene build at 3,600 links got WORSE. This is a '
            'ratchet, not the budget: the budget is one frame and this '
            'case has never met it (#702). Something made an already '
            'unacceptable number worse.',
      );
      // THE "STILL OVER BUDGET" TRIPWIRE IS GONE, AND DR-076 §11.75.4 IS
      // WHY. This case used to assert `ms > _oneFrameMs` so that fixing
      // #702 would fail the test and force the ceiling to be replaced by
      // the budget. The ruling narrowed what the budget covers: it binds
      // an EDIT, not an open, because a cold build of a twelve-pod job
      // happens once, behind a file load the person is already waiting
      // through. A cold build over one frame is therefore no longer a
      // debt to be tripped over, and the group below asserts the budget
      // where the ruling puts it.
    }, tags: _timed);

    test('AN EDIT at this size is what the tiers actually changed', () {
      // The running total for the INCREMENTAL path, printed for the same
      // reason the cold figure is: a number that appears only on failure
      // is recorded nowhere.
      final doc = buildSchematicFixture(pods: _kHeadroomPods);
      final measurer = _Measurer();
      final base = buildSchematicScene(doc: doc, measurer: measurer);

      double best(SchematicScene Function() build) {
        var bestUs = 1 << 30;
        for (var i = 0; i < 5; i++) {
          final watch = Stopwatch()..start();
          build();
          watch.stop();
          if (watch.elapsedMicroseconds < bestUs) {
            bestUs = watch.elapsedMicroseconds;
          }
        }
        return bestUs / 1000;
      }

      final held = best(
        () => buildSchematicScene(
          doc: doc,
          measurer: measurer,
          holdAt: base.positions,
        ),
      );
      final byLayout = best(
        () => buildSchematicScene(
          doc: doc,
          measurer: measurer,
          reuseLayout: base.layout,
        ),
      );
      final byTier = best(
        () => buildSchematicScene(
          doc: doc,
          measurer: measurer,
          reuseSymbols: base.symbolTier,
        ),
      );

      // A running total belongs in every green CI log, not only in a
      // failure — the same reason the cold figure above is printed.
      // ignore: avoid_print
      print(
        'DR-076 tiers [12 pods]: holdAt = ${held}ms  '
        'reuseLayout = ${byLayout}ms  reuseSymbols = ${byTier}ms  '
        '(one frame = ${_oneFrameMs}ms)',
      );

      expect(
        byTier,
        lessThan(byLayout),
        reason: 'holding the symbols must beat holding only the layout',
      );
      expect(
        byLayout,
        lessThan(held),
        reason:
            'and holding the layout must beat the `holdAt` path it '
            'replaced, which lays out and then overrides',
      );
    }, tags: _timed);
  });

  // ══════════════════════════════════════════════════════════════════════
  // THE BUDGET, WHERE DR-076 §11.75.4 PUTS IT (`#731`)
  // ══════════════════════════════════════════════════════════════════════
  // One frame binds an EDIT at a size a real job reaches. The shipped
  // 300-link fixture is that size: it is a house with one rack, which is
  // what M2's exit criterion was written against.
  //
  // THE TWELVE-POD CASE IS NOT ASSERTED AGAINST THE BUDGET and the group
  // above says why: an edit there is ~20 ms, still over a frame, and
  // §11.75.6's domain split is where the remaining margin would come
  // from. Asserting it here would make a red gate out of work the ruling
  // deliberately sequenced later.
  group('the incremental path meets one frame (DR-076 §11.75.4)', () {
    test('a wires-only rebuild on the shipped fixture', () {
      final doc = readSchematicFixture();
      final measurer = _Measurer();
      final base = buildSchematicScene(doc: doc, measurer: measurer);

      var bestUs = 1 << 30;
      for (var i = 0; i < 5; i++) {
        final watch = Stopwatch()..start();
        buildSchematicScene(
          doc: doc,
          measurer: measurer,
          reuseSymbols: base.symbolTier,
        );
        watch.stop();
        if (watch.elapsedMicroseconds < bestUs) {
          bestUs = watch.elapsedMicroseconds;
        }
      }
      final ms = bestUs / 1000;

      // Printed on green runs for the reason above: this is the number
      // that says whether the budget is still met, and it is worth
      // reading before it fails rather than after.
      // ignore: avoid_print
      print(
        'DR-076 edit budget [300 links]: ${ms}ms against '
        '${_oneFrameMs}ms',
      );

      expect(
        ms,
        lessThan(_oneFrameMs),
        reason:
            'a cable drawn on a one-rack house must cost less than a '
            'frame, which is the budget M2 states and the one DR-076 '
            '§11.75.4 keeps',
      );
    }, tags: _timed);
  });

  group('M2-G — the text-run census', () {
    test('the schematic, in the TEXT-BOUND case DR-001 made the default', () {
      final doc = _withNetsAndRegistries();
      final scene = buildSchematicScene(doc: doc, measurer: _Measurer());
      _census(
        'schematic, augmented (300 nets, seeded registries)',
        scene.scene.ops,
      );
    });

    test('the schematic as committed — the floor', () {
      final scene = buildSchematicScene(
        doc: readSchematicFixture(),
        measurer: _Measurer(),
      );
      _census('schematic, as committed', scene.scene.ops);
    });

    test('the rack elevations, both faces of every rack in the fixture', () {
      // The OTHER surface that paints text on every frame, and the one
      // M2-G's cache lives in front of just as much as the schematic:
      // `device_layer.dart` emits a designator, a name, a type line and a
      // U-height badge per device, and the ruler emits one figure per U.
      final doc = readSchematicFixture();
      final ops = <DiagramOp>[];
      for (final rack in doc.racks.values) {
        for (final face in Face.values) {
          ops.addAll(
            buildRackScene(
              rack: rack,
              devices: doc.devices.values,
              templates: doc.templates,
              face: face,
              lod: LodLevel.full,
              measurer: _Measurer(),
            ).scene.ops,
          );
        }
      }
      _census('rack elevations, ${doc.racks.length} racks x 2 faces', ops);
    });
  });
}

/// Counts the text runs in [ops] and PRINTS the census.
///
/// `print` rather than `printOnFailure`, for this file's stated reason: a
/// number that only appears when the test fails is recorded nowhere.
///
/// It asserts almost nothing on purpose. This is an INSTRUMENT, and the
/// figure it produces is an input to a decision that has not been taken
/// yet — pinning a count here would freeze the fixture rather than measure
/// it. The one assertion is that there is something to count, because a
/// census of zero runs would silently agree with any cache size at all.
void _census(String label, List<DiagramOp> ops) {
  final texts = ops.whereType<OpText>().toList(growable: false);
  final distinct = <(String, TextStyleSpec)>{};
  final byStyle = <TextStyleSpec, int>{};
  var chars = 0;
  for (final t in texts) {
    distinct.add((t.text, t.style));
    byStyle[t.style] = (byStyle[t.style] ?? 0) + 1;
    chars += t.text.length;
  }

  expect(
    texts,
    isNotEmpty,
    reason: 'a census of zero runs agrees with every cache size',
  );

  final ratio = distinct.isEmpty
      ? 0.0
      : (texts.length / distinct.length * 100).round() / 100;
  // A census that only appears when the test FAILS is a census nobody
  // reads — this file's own rule, applied to its newest number.
  // ignore: avoid_print
  print(
    'M2-G text census [$label]:\n'
    '  total runs      ${texts.length}  (drawText calls per paint)\n'
    '  distinct pairs  ${distinct.length}  (the working set)\n'
    '  reuse factor    ${ratio}x  (a perfect cache saves '
    '${texts.length - distinct.length} layouts)\n'
    '  styles          ${byStyle.length}\n'
    '  characters      $chars',
  );
}

/// The augmented document gained what [_withNetsAndRegistries] says it adds.
///
/// THE AUGMENTATION IS ASSERTED BEFORE IT IS COUNTED OR TIMED. A measurement
/// of a document that quietly failed to gain its nets would be the same
/// floor again wearing a different label.
void _expectAugmented(RackDocument doc) {
  final scene = buildSchematicScene(doc: doc, measurer: _Measurer());
  expect(scene.unnamedLinkIds, isEmpty);
  expect(scene.unresolvedDomainFragment, isNull);
  expect(
    scene.domainFragments.length,
    greaterThan(3),
    reason:
        'the point of seeding the registries is that the labels spread '
        'across real sub-pictures — one bucket would measure the same '
        'single-picture case as the floor run',
  );
  expect(
    scene.netLabels.map((l) => l.netName),
    everyElement(
      anyOf(
        startsWith('N0'),
        startsWith('N1'),
        startsWith('N2'),
        startsWith('N3'),
      ),
    ),
  );
}

/// The machine-independent half of the record: the display list's op
/// counts, asserted in the core suite (DR-178). [_measure] is the other half
/// and asserts only the stopwatch.
void _expectOps(RackDocument doc, {required int opsPerFlag}) {
  final measurer = _Measurer();
  final scene = buildSchematicScene(doc: doc, measurer: measurer);
  final layer = buildNetLabelLayer(
    doc: doc,
    symbols: scene.symbols,
    measurer: measurer,
    palette: const SchematicPalette(),
    unitsPerGrid: kSchematicUnitsPerGrid,
  );
  final labels = scene.netLabels.length;
  final labelOps = layer.ops.length;
  expect(
    labels,
    greaterThan(0),
    reason: 'a per-flag identity over zero flags agrees with every number',
  );
  // FIVE ops per flag — leader, pennant, family glyph, family tag, net
  // name — and two flags per link.
  //
  // IT WENT TO FIVE, CAME BACK TO FOUR, AND HAS GONE TO FIVE AGAIN FOR A
  // DIFFERENT REASON, which is why this number is worth watching.
  //
  //   * the first five was ACCIDENTAL: making the flag opaque with a
  //     second `OpPath` behind the tint. Compositing the two colours at
  //     build time gives identical pixels in one op, so that one was given
  //     back (`0269200`);
  //   * this five is STRUCTURAL (#124). Channel 4 used to be one text run
  //     carrying a glyph the app's font does not have — measured near-zero
  //     by Jost and painted full width by the screen's fallback face, which
  //     is what put the net name on top of the token. The glyph is geometry
  //     now, so channel 4 is a path plus a shorter run. There is no
  //     arithmetic that gives this one back: the fix is that the two are
  //     separate objects.
  //
  // A flag whose family glyph has no shape stays at FOUR — the defined
  // fallback to the measured run. Every family in this fixture resolves,
  // which is what makes the figure a single number here.
  expect(labelOps, opsPerFlag * labels);
  expect(scene.scene.ops.length, _kSymbolOps + labelOps);
}

/// Times [doc] end to end, times the label layer alone in the same
/// process, and PRINTS both. docs/12 §5.1 asks for the commit cost to be
/// measured and recorded, and a green test records nothing.
///
/// ASSERTS ONLY THE STOPWATCH (DR-178). The op counts it prints are
/// [_expectOps]'s to assert, in the suite, where a busy machine cannot fail
/// them.
void _measure(RackDocument doc, String label) {
  final measurer = _Measurer();

  // Warm up: the first call on the VM pays JIT compilation for the whole
  // pipeline, which is not what "at commit" means — a commit happens in a
  // running editor.
  for (var i = 0; i < 5; i++) {
    buildSchematicScene(doc: doc, measurer: measurer);
  }

  var bestUs = 1 << 30;
  var ops = 0;
  var labels = 0;
  var built = buildSchematicScene(doc: doc, measurer: measurer);
  for (var i = 0; i < 15; i++) {
    final watch = Stopwatch()..start();
    final scene = buildSchematicScene(doc: doc, measurer: measurer);
    watch.stop();
    ops = scene.scene.ops.length;
    labels = scene.netLabels.length;
    built = scene;
    if (watch.elapsedMicroseconds < bestUs) bestUs = watch.elapsedMicroseconds;
  }

  // THE LABEL LAYER ON ITS OWN, over the symbols the run above positioned.
  // This is the honest share: same process, same measurer, same document,
  // so it does not depend on what machine M2-C's baseline was taken on.
  var labelUs = 1 << 30;
  var labelOps = 0;
  for (var i = 0; i < 15; i++) {
    final watch = Stopwatch()..start();
    final layer = buildNetLabelLayer(
      doc: doc,
      symbols: built.symbols,
      measurer: measurer,
      palette: const SchematicPalette(),
      unitsPerGrid: kSchematicUnitsPerGrid,
    );
    watch.stop();
    labelOps = layer.ops.length;
    if (watch.elapsedMicroseconds < labelUs) {
      labelUs = watch.elapsedMicroseconds;
    }
  }

  final ms = bestUs / 1000;
  final labelMs = labelUs / 1000;
  printOnFailure('best of 15: ${ms}ms over $ops ops');
  // `print` rather than `printOnFailure`: a number that only appears when
  // the test FAILS is recorded nowhere. This one lands in the CI log of
  // every green run.
  // ignore: avoid_print
  print(
    'M2-D commit path [$label]: 300 links, ${doc.devices.length} devices, '
    '$labels labels\n'
    '  total      $ops ops, best of 15 = ${ms}ms '
    '(budget ${_oneFrameMs}ms)\n'
    '  labels     $labelOps ops, best of 15 = ${labelMs}ms\n'
    '  symbols    $_kSymbolOps ops (collapsed, `#801`)\n'
    '  vs M2-C    $_kM2cOps ops / ${_kM2cMs}ms symbols-only baseline '
    '=> ${_kSymbolOps - _kM2cOps} ops '
    '(${((_kSymbolOps - _kM2cOps) / _kM2cOps * 100).toStringAsFixed(1)}%) '
    'on the symbol layer alone, '
    'label share ${(labelMs / ms * 100).toStringAsFixed(1)}% of this run',
  );
  expect(
    ms,
    lessThan(_oneFrameMs),
    reason:
        'the 300-connection fixture no longer lays out and LABELS within '
        'one frame (60 Hz). This is an M2 exit criterion, not a '
        'nice-to-have.',
  );
}

/// The committed fixture with the registries DR-010 seeds and one
/// `Service` + `Net` per link, added IN MEMORY. See the caller.
///
/// The family is not invented: it is the one the label layer would resolve
/// for that link anyway — `_familyOf`'s source-pin fallback — read back off
/// a first build rather than re-derived here. So the augmentation changes
/// what each flag SAYS and which sub-picture it lands in, and changes no
/// family assignment at all.
RackDocument _withNetsAndRegistries() {
  final doc = readSchematicFixture();
  doc.registries.signalDomains.addAll(buildSeedSignalDomains());
  doc.registries.signalFamilies.addAll(buildSeedSignalFamilies());

  final familyOf = <Uuid, SignalFamilyId>{};
  for (final label in buildSchematicScene(
    doc: doc,
    measurer: _Measurer(),
  ).netLabels) {
    familyOf[label.linkId] = label.style.familyId;
  }

  final links = doc.links.values.toList()
    ..sort((a, b) => a.order.v.compareTo(b.order.v));
  final meta = EntityMeta(
    createdAt: DateTime.utc(2026, 7, 28),
    updatedAt: DateTime.utc(2026, 7, 28),
    updatedBy: 'perf',
  );
  for (var i = 0; i < links.length; i++) {
    final link = links[i];
    final family = familyOf[link.id];
    if (family == null) continue;
    final netId = Uuid(
      '0190ff00-0000-7000-8000-${i.toString().padLeft(12, '0')}',
    );
    // `IdFormat('N{SEQ:3}')` — `ProjectSettings.netNameFormat`'s default.
    doc.nets[netId] = Net(
      id: netId,
      name: 'N${(i + 1).toString().padLeft(3, '0')}',
      signalFamily: family,
      meta: meta,
    );
    link.services.add(Service(id: 's$i', signalFamily: family, netId: netId));
  }
  return doc;
}
