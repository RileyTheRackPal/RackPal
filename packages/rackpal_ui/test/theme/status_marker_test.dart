// DR-090 §11.89.6 as an assertion. Board #774.
//
// The rule: a status marker must carry a cue that SURVIVES ITS COLOUR
// BEING REMOVED. That is not a property of a colour, so
// `console_palette_test.dart` says in its last group that it cannot check
// it. This is where it gets checked, and the method is the rule read
// literally: paint the five at ONE colour and require that they differ.
//
// PIXELS, NOT SHAPE NAMES. Asserting `shapeFor(critical) != shapeFor(...)`
// would pass for five names that painted the same marks, which is the
// failure mode the rule is about. Rasterising and comparing is the only
// version of this test that could catch two shapes drawn identically.

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

/// The shape alone, at one colour, as bytes.
Future<Uint8List> _raster(StatusShape shape, {double size = 48}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  // ONE COLOUR FOR ALL FIVE. This is the deletion the rule describes.
  StatusShapePainter(
    shape: shape,
    color: const Color(0xFFFFFFFF),
  ).paint(canvas, Size(size, size));
  final image = await recorder.endRecording().toImage(
    size.toInt(),
    size.toInt(),
  );
  final data = await image.toByteData();
  image.dispose();
  return data!.buffer.asUint8List();
}

/// How many bytes two rasters differ in.
int _difference(Uint8List a, Uint8List b) {
  var n = 0;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) n++;
  }
  return n;
}

void main() {
  testWidgets('with the colour deleted, no two severities look alike', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final rasters = <ConsoleStatus, Uint8List>{
        for (final s in ConsoleStatus.values) s: await _raster(shapeFor(s)),
      };

      // NOT VACUOUS: an empty or blank raster would compare equal to
      // nothing and pass every pair below. Each shape has to have drawn
      // something.
      for (final entry in rasters.entries) {
        expect(
          entry.value.any((byte) => byte != 0),
          isTrue,
          reason: '${entry.key.name} painted nothing at all',
        );
      }

      for (final a in ConsoleStatus.values) {
        for (final b in ConsoleStatus.values) {
          if (a.index >= b.index) continue;
          final differing = _difference(rasters[a]!, rasters[b]!);
          expect(
            differing,
            greaterThan(0),
            reason:
                '${a.name} and ${b.name} are the same mark once the colour '
                'is gone, which is §11.89.6 failing rather than passing',
          );
        }
      }
    });
  });

  testWidgets('the round mark is an OUTLINE, because a filled dot is the '
      'thing the rule forbids', (tester) async {
    await tester.runAsync(() async {
      final circle = await _raster(StatusShape.circle);
      final diamond = await _raster(StatusShape.diamond);
      // A filled circle would cover more of its box than an outline does.
      // Comparing against the filled diamond is the cheap way to say
      // "this one is not solid" without pinning a pixel count.
      int lit(Uint8List px) {
        var n = 0;
        for (var i = 3; i < px.length; i += 4) {
          if (px[i] != 0) n++;
        }
        return n;
      }

      expect(
        lit(circle),
        lessThan(lit(diamond)),
        reason:
            'the circle is drawn solid, so the set contains a bare '
            'coloured dot after all',
      );
    });
  });

  testWidgets('every severity has a shape, and the mapping is total', (
    tester,
  ) async {
    // Total by the switch's exhaustiveness rather than by this test, which
    // only records that a sixth severity is a compile error and not a
    // silent default.
    expect(
      ConsoleStatus.values.map(shapeFor).toSet(),
      hasLength(ConsoleStatus.values.length),
      reason: 'two severities share a shape, so one cue serves both',
    );
  });

  testWidgets('a marker carries its severity in semantics too', (
    tester,
  ) async {
    // The one consumer for which EVERY visual cue is deleted, shape
    // included.
    await tester.pumpWidget(
      MaterialApp(
        theme: buildConsoleTheme(),
        home: const Scaffold(
          body: StatusMarker(ConsoleStatus.critical, label: '18 devices'),
        ),
      ),
    );
    expect(find.bySemanticsLabel('critical: 18 devices'), findsOneWidget);
  });
}
