// `sizeSymbolForBody` is the sheet's own sizing, or it is a second drawing.
//
// ═══════════════════════════════════════════════════════════════════════
// WHY THIS TEST EXISTS AT ALL
// ═══════════════════════════════════════════════════════════════════════
// The device builder's symbol preview (`#228`) needs a symbol sized from a
// `TemplateBody` that has never been placed in a rack. Before `#229` the
// only way in was `_measureCandidate`, which wants a whole `RackDocument`
// and a `DeviceInstance`, so the obvious move was for `rackpal_ui` to
// re-derive width and height itself.
//
// That move is the defect CR-086 names — *a symbol that cannot print is not
// a symbol* — and `schematic_scene.dart` already says what it costs: the gu
// terms in `sizeSymbolForBody` and the diagram-unit terms inside
// `buildSymbolGeometry` are "the two transcriptions" a test keeps in
// agreement. A THIRD transcription in the widget layer would be reachable
// by no test in this package.
//
// So the seam was published instead, and this is the test that the seam is
// really the same code path rather than a plausible copy of it: for every
// device in the 300-link fixture, the symbol the SHEET drew and the symbol
// the PREVIEW would draw are compared field by field.
//
// A fixture rather than an invented body, deliberately: 93 devices across
// the real seed catalog exercise zero-port devices, banked ports, every
// symbol side and both label bands. A hand-built two-port template would
// pass this test while disagreeing on all four.
import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

import 'schematic_fixture.dart';

/// The same crude proportional measurer the rest of the scene tests use.
/// Nothing here depends on the numbers, only on both paths being handed
/// the SAME measurer, which is the whole question.
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
  group('sizeSymbolForBody is the sheet path, not a copy of it', () {
    test('every symbol in the 300-link fixture is reproduced exactly from '
        'its body alone', () {
      final doc = readSchematicFixture();
      final scene = buildSchematicScene(doc: doc, measurer: _Measurer());

      // The fixture has to actually contain symbols, or this test passes by
      // iterating nothing — the vacuity trap `run_suite.ps1` floors guard
      // at the suite level and which a single test has to guard itself.
      expect(
        scene.symbols.length,
        greaterThan(40),
        reason:
            'the fixture stopped producing symbols; this test then '
            'compares an empty list to an empty list and proves nothing',
      );

      var banded = 0;
      var banked = 0;

      for (final drawn in scene.symbols) {
        final device = doc.devices[Uuid(drawn.id)];
        expect(device, isNotNull, reason: 'symbol ${drawn.id} has no device');
        final body = doc.templates[templateKeyFor(device!.templateRef)]?.body;
        expect(body, isNotNull, reason: '${device.designator} has no body');

        final preview = sizeSymbolForBody(
          id: device.id.v,
          designator: device.designator,
          name: device.name,
          body: body!,
          measurer: _Measurer(),
        );

        // The sheet's symbol is ABSOLUTE and the preview's is at the
        // origin, which is the one difference that is supposed to exist.
        final rebuilt = preview.geometry.movedTo(
          DPt(drawn.bodyRect.left, drawn.bodyRect.top),
        );

        final who = '${device.designator} (${body.displayName})';
        expect(rebuilt.bodyRect.width, drawn.bodyRect.width, reason: who);
        expect(rebuilt.bodyRect.height, drawn.bodyRect.height, reason: who);
        expect(rebuilt.headerHeight, drawn.headerHeight, reason: who);
        expect(rebuilt.labelBandTop, drawn.labelBandTop, reason: who);
        expect(rebuilt.labelBandBottom, drawn.labelBandBottom, reason: who);
        expect(rebuilt.ports, drawn.ports, reason: who);

        if (drawn.labelBandTop > 0 || drawn.labelBandBottom > 0) banded++;
        if (body.banks.isNotEmpty) banked++;
      }

      // The two features most likely to be dropped by a re-derivation are
      // the ones a two-port fixture would never reach, so assert the
      // fixture reaches them rather than hoping it does.
      expect(banded, greaterThan(0), reason: 'no symbol had a label band');
      expect(banked, greaterThan(0), reason: 'no symbol had a bank');
    });

    test('a body with no ports still sizes, because zero-port devices are '
        'real hardware and the fixture has three', () {
      final doc = readSchematicFixture();
      final empty = doc.templates.values
          .map((t) => t.body)
          .where((b) => b.ports.isEmpty)
          .toList();
      expect(empty, isNotEmpty, reason: 'fixture lost its blanks and shelves');

      for (final body in empty) {
        final sized = sizeSymbolForBody(
          id: 'preview',
          designator: 'X-1',
          name: '',
          body: body,
          measurer: _Measurer(),
        );
        // The floor is what it is for: a portless body still has a box,
        // because the builder draws one while you are adding the first
        // port and a zero-sized preview would flash on every template.
        expect(sized.widthGu, greaterThan(0), reason: body.displayName);
        expect(sized.heightGu, greaterThan(0), reason: body.displayName);
        expect(
          sized.geometry.bodyRect.width,
          greaterThan(0),
          reason: body.displayName,
        );
        for (final side in SymbolSide.values) {
          expect(sized.geometry.ports[side], isEmpty, reason: body.displayName);
        }
      }
    });
  });
}
