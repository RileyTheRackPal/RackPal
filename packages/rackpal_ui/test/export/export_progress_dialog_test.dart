// The export's progress dialog (M6-I2, `#353`, docs/08 §8.2): two phases
// said as two, a Cancel that asks rather than decides, and a dialog that
// closes itself when the work is over.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

void main() {
  late ValueNotifier<ExportProgress?> progress;
  late Completer<void> finished;
  late int cancels;

  Future<void> open(WidgetTester tester) async {
    progress = ValueNotifier<ExportProgress?>(null);
    finished = Completer<void>();
    cancels = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showExportProgressDialog(
              context,
              progress: progress,
              finished: finished.future,
              onCancel: () => cancels++,
            ),
            child: const Text('go'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pump();
  }

  double? barValue(WidgetTester tester) => tester
      .widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      )
      .value;

  testWidgets('before the set resolves it says so, with no count', (
    tester,
  ) async {
    await open(tester);
    expect(find.text(kExportProgressTitle), findsOneWidget);
    expect(find.text(kExportPreparingLabel), findsOneWidget);
    expect(barValue(tester), isNull);
  });

  testWidgets('drawing: the sheet it is on, and a bar that counts', (
    tester,
  ) async {
    await open(tester);
    progress.value = (sheetsDone: 11, sheets: 31);
    await tester.pump();
    expect(find.text('Drawing sheet 12 of 31'), findsOneWidget);
    expect(barValue(tester), closeTo(11 / 31, 1e-9));
  });

  testWidgets('WRITING IS SAID AS WRITING, with no bar parked at full: '
      'most of the time is spent here and nothing counts it', (tester) async {
    await open(tester);
    progress.value = (sheetsDone: 31, sheets: 31);
    await tester.pump();
    expect(find.text(kExportWritingLabel), findsOneWidget);
    expect(barValue(tester), isNull);
  });

  testWidgets('Cancel asks the caller to stop, and the dialog waits for the '
      'work to say it has', (tester) async {
    await open(tester);
    await tester.tap(find.text('Cancel'));
    await tester.pump();
    expect(cancels, 1);
    expect(find.text(kExportProgressTitle), findsOneWidget);

    finished.complete();
    await tester.pumpAndSettle();
    expect(find.text(kExportProgressTitle), findsNothing);
  });

  testWidgets('it closes itself when the export finishes', (tester) async {
    await open(tester);
    finished.complete();
    await tester.pumpAndSettle();
    expect(find.text(kExportProgressTitle), findsNothing);
    expect(find.text('go'), findsOneWidget, reason: 'only the dialog went');
  });
}
