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
// the graph, phases 0–3, and the symbol display list emitted. That is
// everything M2-C builds, and it is the conservative number: the layout
// alone is a fraction of it.
//
// NOT MEASURED, because it does not exist yet: the LABEL-LAYER commit cost
// the same criterion asks for (AC-016 #20, docs/03 §5.2's "the dominant
// commit-path term is the label layer, not the wire layer"). Net labels are
// docs/05 §10.2's phase 6 and belong to the render half of M2, not the
// layout half. The op count this file prints is the symbol layer's alone,
// and it is printed so the label layer's share can be stated as a delta
// against a real baseline when it lands rather than guessed.

import 'dart:convert';
import 'dart:io';

import 'package:rackmate_core/rackmate_core.dart';
import 'package:test/test.dart';

import 'op_digest.dart';
import 'schematic_fixture.dart';

/// One frame at 60 Hz. The criterion's own unit; not a tuned threshold.
const double _oneFrameMs = 1000 / 60;

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
      final doc = readSchematicFixture();
      final measurer = _Measurer();

      // Warm up: the first call on the VM pays JIT compilation for the
      // whole pipeline, which is not what "at commit" means — a commit
      // happens in a running editor.
      for (var i = 0; i < 5; i++) {
        buildSchematicScene(doc: doc, measurer: measurer);
      }

      var bestUs = 1 << 30;
      var lastOps = 0;
      for (var i = 0; i < 15; i++) {
        final watch = Stopwatch()..start();
        final scene = buildSchematicScene(doc: doc, measurer: measurer);
        watch.stop();
        lastOps = scene.scene.ops.length;
        if (watch.elapsedMicroseconds < bestUs) {
          bestUs = watch.elapsedMicroseconds;
        }
      }

      final ms = bestUs / 1000;
      // Printed, not only asserted: docs/12 §5.1 asks for the commit cost
      // to be MEASURED AND RECORDED, and a green test records nothing.
      printOnFailure('best of 15: ${ms}ms over $lastOps ops');
      // `print` rather than `printOnFailure`: docs/12 section 5.1 asks for
      // the commit cost to be MEASURED AND RECORDED, and a number that only
      // appears when the test FAILS is recorded nowhere. This one lands in
      // the CI log of every green run.
      // ignore: avoid_print
      print(
        'M2-C commit path: 300 links, ${doc.devices.length} devices, '
        '$lastOps ops, best of 15 = ${ms}ms (budget ${_oneFrameMs}ms)',
      );
      expect(
        ms,
        lessThan(_oneFrameMs),
        reason:
            'the 300-connection fixture no longer lays out within one frame '
            '(60 Hz). This is an M2 exit criterion, not a nice-to-have.',
      );
    });
  });
}
