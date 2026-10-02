// `File ▸ Sheet set…`, in the shell (`#969` DR-209, `#312` DR-210).
//
// `sheet_set_dialog_test.dart` proves the dialog emits the right command to
// whatever `onEdit` it was handed. This proves the route a person takes:
// the menu item exists, opens the dialog over the SESSION's document, and
// the edit lands on the document's undo stack under its own name.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_text/rackpal_text.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

import '../storage/fake_file_store.dart';
import 'session_fakes.dart';

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
      ..physicalSize = const Size(1600, 1400)
      ..devicePixelRatio = 1;
  });

  tearDown(() {
    TestWidgetsFlutterBinding.ensureInitialized()
          .platformDispatcher
          .implicitView!
      ..resetPhysicalSize()
      ..resetDevicePixelRatio();
  });

  testWidgets('File ▸ Sheet set… edits the title block, and Edit undoes '
      'it', (tester) async {
    final built = await buildTestApp(measurer);
    await tester.pumpWidget(built.app);
    await tester.pumpAndSettle();
    final doc = built.session.services.session.document;
    final before = doc.info.clientName;

    await tester.tap(find.widgetWithText(SubmenuButton, 'File'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(kSheetSetLabel));
    await tester.pumpAndSettle();
    expect(find.byKey(kSheetSetListKey), findsOneWidget);

    // THE FIELD THAT HAD NO WRITER ANYWHERE until `#312`.
    final client = find.byKey(
      projectInfoFieldKey(ProjectInfoFields.clientName),
    );
    await tester.ensureVisible(client);
    await tester.pumpAndSettle();
    await tester.enterText(client, 'Jones Family Trust');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    expect(
      doc.info.clientName,
      'Jones Family Trust',
      reason: 'the dialog edits the session document, not a copy',
    );

    await tester.tap(find.widgetWithText(SubmenuButton, 'Edit'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Undo Edit project details'));
    await tester.pumpAndSettle();
    expect(doc.info.clientName, before);
  });

  testWidgets('Choose logo… sets the logo from the shell picker, and a save '
      'carries the member and the field into the file (#590, DR-217)', (
    tester,
  ) async {
    final logoPng = Uint8List.fromList(
      img.encodePng(img.Image(width: 300, height: 120)),
    );
    final fs = FakeFileStore(
      initialDirectories: {kTestDataRoot, kTestJobsDir, 'C:', r'C:\logos'},
      initialFiles: {r'C:\logos\firm.png': logoPng},
    );
    final built = await buildTestApp(
      measurer,
      fs: fs,
      openPaths: [r'C:\logos\firm.png'],
      savePaths: [r'C:\jobs\logo.rppj'],
    );
    await tester.pumpWidget(built.app);
    await tester.pumpAndSettle();
    final services = built.session.services;

    await tester.tap(find.widgetWithText(SubmenuButton, 'File'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(kSheetSetLabel));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(kChooseLogoKey),
      100,
      scrollable: find
          .descendant(
            of: find.byKey(kSheetSetListKey),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.ensureVisible(find.byKey(kChooseLogoKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(kChooseLogoKey));
    await tester.pumpAndSettle();

    final logo = services.session.document.info.logo;
    expect(logo, isNotNull, reason: 'the shell wired Choose to LogoIo');
    expect(find.byKey(kLogoThumbnailKey), findsOneWidget);
    expect(services.session.members[logo!.imageMember], logoPng);

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(await services.controller.saveAs(), isTrue);

    // THE FILE ITSELF, read back the way an open reads it.
    final saved = await tester.runAsync(
      () => fs.readBytes(r'C:\jobs\logo.rppj'),
    );
    final parts = (readContainerParts(saved!) as Ok<ContainerParts>).value;
    expect(parts.members[logo.imageMember], logoPng);
    final reopened =
        (const JsonDocumentCodec().read(parts.documentBytes)
                as Ok<RackDocument>)
            .value;
    expect(reopened.info.logo, logo);
  });
}
