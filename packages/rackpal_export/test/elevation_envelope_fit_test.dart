// DR-239 §11.238.4 (`#923`, ENV-4): the envelope line fits its column on
// paper, measured through the REAL font.
//
// THE CASE THIS FILE EXISTS FOR is the one the core test cannot see. Its
// `FakeMeasurer` would pass any length, and `_band` cuts a note that does
// not fit with a measured ellipsis. The first wording, own weight included,
// measured 331.5 pt here against a 327 pt column for a 1200 x 1400 x 2400
// mm cabinet at 300 kg: on paper it would have lost its last word.
import 'dart:io';

import 'package:pdf/widgets.dart' as pw;
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_text/rackpal_text.dart';
import 'package:test/test.dart';

final _when = DateTime.utc(2026, 10, 6);
EntityMeta _meta() =>
    EntityMeta(createdAt: _when, updatedAt: _when, updatedBy: 'test');

Len _mm(int mm) => Len(mm * 1000000);

/// The largest cabinet a residential or light-commercial job plausibly
/// specifies, with every value that prints known, so every field is at
/// its widest.
Rack _worstCase() => Rack(
  id: const Uuid('rack-big'),
  name: 'Big',
  designator: 'RK-1',
  heightU: 52,
  order: const FracIndex('a0'),
  meta: _meta(),
  overallWidth: _mm(1200),
  overallDepth: _mm(1400),
  overallHeight: _mm(2400),
  hasFrontDoor: true,
  frontRailClearance: _mm(300),
  frontDoorClearance: _mm(1200),
  hasRearDoor: true,
  rearRailClearance: _mm(300),
  rearDoorClearance: _mm(1200),
);

TextMeasurer _jost() => PdfFontMeasurer.fromBytes(pw.Document().document, {
  kSheetFont: File(
    '../../apps/rackpal/assets/fonts/Jost-Regular.ttf',
  ).readAsBytesSync(),
});

void main() {
  for (final units in UnitSystem.values) {
    for (final role in [
      SheetRole.rackElevationFront,
      SheetRole.rackElevationRear,
    ]) {
      test('the worst-case envelope prints WHOLE on $role, ${units.name}', () {
        final rack = _worstCase();
        final face = role == SheetRole.rackElevationFront
            ? Face.front
            : Face.rear;
        final expected = envelopeNote(rack, face, units)!;
        final sheet = buildElevationSheet(
          sheet: SheetSet.forRacks(<Rack>[
            rack,
          ]).sheets.firstWhere((s) => s.role == role),
          rack: rack,
          devices: const <DeviceInstance>[],
          templates: const <String, TemplateSnapshot>{},
          info: ProjectInfo(projectName: 'Fit'),
          settings: ProjectSettings(displayUnits: units),
          revisions: const <RevisionEntry>[],
          fileName: 'fit.rppj',
          issuedAt: _when,
          measurer: _jost(),
        );
        final printed = sheet.scene.ops
            .whereType<OpText>()
            .map((o) => o.text)
            .where((t) => t.startsWith('ENCLOSURE'))
            .toList();
        expect(
          printed,
          [expected],
          reason: 'a cut line ends in an ellipsis and drops its last value',
        );
      });
    }
  }
}
