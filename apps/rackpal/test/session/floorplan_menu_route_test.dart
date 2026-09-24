// The Plan view's first clause at the boundary it names (`#943`): "an
// architect's floorplan PDF is imported WITHOUT LEAVING THE APP".
//
// `floorplan_io_test.dart` and `plan_import_pdfium_test.dart` prove the
// import itself, the second on the real pdfium, by calling `FloorplanIo`
// directly. Nothing drove it from the product: the File menu item, the file
// dialog, the details dialog a person answers, and the document afterwards.
// A route proved by calling its handler has never been proved reachable, and
// this repository has shipped an importer with no caller once already
// (PLAN-D, DR-143). So this pumps the real app, uses the real menu bar and
// the real details dialog, and looks at the document.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_text/rackpal_text.dart';

import '../storage/fake_file_store.dart';
import 'session_fakes.dart';

const _planPath = r'C:\jobs\Level 1.png';

Uint8List _png() {
  final image = img.Image(width: 64, height: 48);
  for (var y = 0; y < 48; y++) {
    for (var x = 0; x < 64; x++) {
      image.setPixelRgb(x, y, 230, 230, 230);
    }
  }
  return Uint8List.fromList(img.encodePng(image));
}

void main() {
  late TextMeasurer measurer;

  setUpAll(() {
    final bytes = File('assets/fonts/Jost-Regular.ttf').readAsBytesSync();
    measurer = PdfFontMeasurer.fromBytes(PdfDocument(), {
      const FontRef('Jost'): bytes,
    });
  });

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized()
          .platformDispatcher
          .implicitView!
      ..physicalSize = const Size(1600, 1000)
      ..devicePixelRatio = 1;
  });

  tearDown(() {
    TestWidgetsFlutterBinding.ensureInitialized()
          .platformDispatcher
          .implicitView!
      ..resetPhysicalSize()
      ..resetDevicePixelRatio();
  });

  testWidgets('File ▸ Import floorplan… puts a plan in the open project', (
    tester,
  ) async {
    final built = await buildTestApp(
      measurer,
      fs: FakeFileStore(
        initialFiles: {_planPath: _png()},
        initialDirectories: {kTestDataRoot, kTestJobsDir, 'C:'},
      ),
      openPaths: [_planPath],
    );
    final doc = built.session.services.session.document;
    expect(doc.underlays, isEmpty, reason: 'the precondition');

    await tester.pumpWidget(built.app);
    await tester.pumpAndSettle();
    await tester.tap(find.text('File'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Import floorplan…'));
    await tester.pumpAndSettle();

    // The details a person confirms before anything is written.
    expect(find.text('New floorplan page'), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    final after = built.session.services.session.document;
    expect(after.underlays, hasLength(1));
    final underlay = after.underlays.values.single;
    expect(underlay.name, 'Level 1', reason: 'named from the file');
    expect(underlay.pixelWidth, 64);
    expect(
      built.session.services.session.members.keys,
      contains(underlay.imageMember),
      reason: 'the image rides with the project, so a save keeps it',
    );
  });
}
