@Tags(['perf'])
library;

// M2's PERFORMANCE exit criterion, measured rather than asserted:
// "routes a 300-connection fixture within one frame at commit"
// (docs/09, docs/12 §5.1).
//
// docs/12 §4 records that there was "no perf test and no CI to run one in",
// and names the missing instrument: "Grep for `@Tags` / `Tags([` across every
// Dart file returns nothing." This file is the first one. It is TAGGED but
// NOT EXCLUDED — `tools/ci/run_suite.ps1` does no tag filtering, deliberately
// — so it runs on every push and the number is defended, not just recorded.
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

import 'package:rackmate_core/rackmate_core.dart';
import 'package:test/test.dart';

import 'op_digest.dart';
import 'schematic_fixture.dart';

/// One frame at 60 Hz. The criterion's own unit; not a tuned threshold.
const double _oneFrameMs = 1000 / 60;

/// M2-C's recorded symbol-layer figures on THIS fixture: 4,155 ops, best
/// of 15 = 3.052 ms. Written down rather than re-derived, because the
/// symbols-only path no longer exists — `buildSchematicScene` has no flag
/// that turns the labels off, deliberately (DR-001 makes them the default
/// render, not an option over one).
const int _kM2cOps = 4155;
const double _kM2cMs = 3.052;

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

  group('the budget', () {
    test('a 300-connection fixture lays out and emits its display list '
        'within ONE FRAME at commit', () {
      _measure(
        readSchematicFixture(),
        'AS COMMITTED (no nets, no '
        'registries)',
      );
    });

    test('…and still does with every link named and every family resolved '
        '— the case DR-001 §11.1.5 calls TEXT-BOUND', () {
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

      // THE AUGMENTATION IS ASSERTED BEFORE IT IS TIMED. A measurement of
      // a document that quietly failed to gain its nets would be the same
      // floor again wearing a different label.
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

      _measure(doc, 'AUGMENTED (300 nets, seeded registries)');
    });
  });
}

/// Times [doc] end to end, times the label layer alone in the same
/// process, and PRINTS both. docs/12 §5.1 asks for the commit cost to be
/// measured and recorded, and a green test records nothing.
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
    '  vs M2-C    $_kM2cOps ops / ${_kM2cMs}ms symbols-only baseline '
    '=> +${ops - _kM2cOps} ops '
    '(${((ops - _kM2cOps) / _kM2cOps * 100).toStringAsFixed(1)}%), '
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
  // The op delta is the machine-independent half of the record, so it is
  // asserted rather than only printed: four ops per flag — leader,
  // pennant, family token, net name — and two flags per link.
  expect(labelOps, 4 * labels);
  expect(ops, _kM2cOps + labelOps);
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
    link.services.add(
      Service(id: 's$i', signalFamily: family, netId: netId),
    );
  }
  return doc;
}
