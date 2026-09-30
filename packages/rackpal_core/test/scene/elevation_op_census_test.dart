// #757 — the elevation's op census, and the hole it fills.
//
// ═════════════════════════════════════════════════════════════════════
// WHY THIS FILE EXISTS: 3152 GREEN CASES COULD NOT SEE A NEW OP PER DEVICE
// ═════════════════════════════════════════════════════════════════════
// #753 added a path op to EVERY device on EVERY elevation and the whole
// suite stayed green, because nothing anywhere counted the elevation's
// ops. The schematic has `schematic_perf_test`'s baselines; the elevation
// had a TEXT-RUN census beside them and nothing else, and a mark is a
// path, so that census printed identical figures before and after.
//
// THE ASSERTION IS THE ARTIFACT, NOT A TOTAL. A pinned grand total would
// move on every unrelated change and teach the next reader to regenerate
// it without looking, which is how a baseline stops being a gate. What is
// pinned instead is the RELATIONSHIP a person could verify by eye on a
// printed sheet: every visible device carries exactly one mark.
//
// The full census is PRINTED on every green run, on
// `schematic_perf_test`'s reasoning: a number that appears only when a
// test fails is recorded nowhere.
import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

import 'schematic_fixture.dart';

final class _M implements TextMeasurer {
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

/// One face of one rack, the devices the scene actually drew, and how many
/// of them sit on a shelf the scene itself reports as overfull.
({List<DiagramOp> ops, int devices, int squeezed}) _face(
  RackDocument doc,
  Rack rack,
  Face face,
) {
  final built = buildRackScene(
    rack: rack,
    devices: doc.devices.values,
    templates: doc.templates,
    face: face,
    lod: LodLevel.full,
    measurer: _M(),
  );
  final overfull = built.shelfOverflow.keys.toSet();
  final squeezed = built.devices.where((l) {
    final placement = doc.devices[l.deviceId]?.placement;
    return placement is ShelfPlacement &&
        overfull.contains(placement.hostDeviceId);
  }).length;
  return (
    ops: built.scene.ops,
    devices: built.devices.length,
    squeezed: squeezed,
  );
}

void main() {
  test('every visible device carries exactly one mark, on both faces of '
      'every rack in the committed fixture', () {
    final doc = readSchematicFixture();
    var totalDevices = 0;
    var totalPaths = 0;
    var totalSqueezed = 0;
    final byKind = <String, int>{};

    for (final rack in doc.racks.values) {
      for (final face in Face.values) {
        final f = _face(doc, rack, face);
        totalDevices += f.devices;
        totalSqueezed += f.squeezed;
        totalPaths += f.ops.whereType<OpPath>().length;
        for (final op in f.ops) {
          byKind.update(
            op.runtimeType.toString(),
            (v) => v + 1,
            ifAbsent: () => 1,
          );
        }
      }
    }

    // `print` rather than `printOnFailure`, on schematic_perf_test's
    // reasoning: a figure that only appears when a case FAILS is recorded
    // nowhere, and this one is the elevation's op profile in the log of
    // every green run.
    // ignore: avoid_print
    print(
      'ELEVATION OP CENSUS [${doc.racks.length} racks x 2 faces]:\n'
      '  devices drawn   $totalDevices\n'
      '  marks drawn     $totalPaths\n'
      '  on overfull     $totalSqueezed\n'
      '  ops by kind     $byKind',
    );

    expect(
      totalDevices,
      greaterThan(0),
      reason:
          'a fixture that draws no devices proves nothing at all, '
          'which is the shape of vacuous pass this file exists to end',
    );
    // ONE EXCEPTION, AND THE SCENE NAMES IT RATHER THAN THIS TEST. Since
    // DR-204 (`#953`) a device on a shelf is drawn, and a shelf whose hosts
    // are wider than it squeezes them together to fit, which can take one
    // below `device_layer.dart`'s width for a mark. The fixture's SHF-1
    // carries five on 2U, which is `#844`'s case (stacking is parked).
    // The squeezed hosts are counted from `RackScene.shelfOverflow`, so an
    // unreported squeeze still fails here.
    expect(
      totalPaths,
      greaterThanOrEqualTo(totalDevices - totalSqueezed),
      reason: 'every device not on an overfull shelf carries its mark',
    );
    expect(
      totalPaths,
      lessThanOrEqualTo(totalDevices),
      reason:
          'ONE mark per device. Fewer means a mark that does not draw, '
          'which is what shipped for four months as `accentColor` and was '
          'invisible to every gate; more means one drawn twice. The only '
          'other path source on an elevation is the mark itself',
    );
  });

  test('the marks are NOT all the same silhouette, which is the collapse '
      'DR-084 ended and the fixture is where it would come back', () {
    final doc = readSchematicFixture();
    final marks = {
      for (final d in doc.devices.values)
        if (doc.templates[templateKeyFor(d.templateRef)]?.body case final b?)
          effectiveGlyph(b.glyph, b.category),
    };

    // Same reasoning as the census above: this is the number DR-084 was
    // about, and it belongs in the log of every run rather than in
    // somebody's memory of a probe they ran once.
    // ignore: avoid_print
    print('DISTINCT MARKS IN THE FIXTURE: ${marks.length} $marks');

    expect(
      marks.length,
      greaterThan(1),
      reason:
          'before DR-084 every device in a category answered one mark, '
          'and a fixture drawn entirely from one category would hide a '
          'regression to exactly that',
    );
  });
}
