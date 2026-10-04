// The Structured Wiring table's CROSSOVER column (`#973`, DR-231): what the
// cell writes, what it refuses, and the ticket's own owed test, that a
// cable marked null-modem through the table puts T5.01 in the export.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:rackpal/src/session/export_runner.dart';
import 'package:rackpal/src/session/structure_edit_actions.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_export/rackpal_export.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

RackDocument _starter(String name) =>
    (const JsonDocumentCodec().read(
              File('assets/starters/$name.rppj').readAsBytesSync(),
            )
            as Ok<RackDocument>)
        .value;

void main() {
  late RackDocument doc;
  late DocumentController controller;
  late StructureEditFn edit;
  late Link run;

  setUp(() {
    doc = _starter('whole_house');
    controller = DocumentController(
      doc,
      clock: FixedClock(DateTime.utc(2026, 10, 4, 9)),
    );
    edit = buildStructureEditAction(controller: controller);
    run = doc.links.values.firstWhere((l) => l.structureOrigin != null);
  });

  StructureCellEdit cell(String value) => StructureCellEdit(
    linkId: run.id,
    column: StructureColumnId.crossover,
    value: value,
  );

  test('the menu label writes the value, and the dash clears it', () {
    expect(edit([cell(crossoverLabel(CrossoverKind.nullModem))]), isNull);
    expect(run.crossover, CrossoverKind.nullModem);
    expect(edit([cell(kUnknownCell)]), isNull);
    expect(run.crossover, isNull);
  });

  test('a typed label is matched without regard to case', () {
    expect(edit([cell('polarity REVERSED')]), isNull);
    expect(run.crossover, CrossoverKind.polarityReversed);
  });

  test('anything else is refused with the list, writing nothing', () {
    final refusal = edit([cell('crossed')])!;
    expect(refusal, contains('"crossed" is not a crossover'));
    for (final k in CrossoverKind.values) {
      expect(refusal, contains(crossoverLabel(k)));
    }
    expect(run.crossover, isNull);
  });

  test(
    'the cell shows the label, and unset shows the dash, never Straight',
    () {
      String shown() => structureCell(
        doc,
        buildSchedule(doc).rows.firstWhere((r) => r.linkId == run.id),
        StructureColumnId.crossover,
        units: doc.settings.displayUnits,
      );
      expect(shown(), kUnknownCell);
      edit([cell(crossoverLabel(CrossoverKind.straight))]);
      expect(shown(), 'Straight');
    },
  );

  test('THE TICKET’S TEST: a cable marked null-modem in the table puts '
      'T5.01 in the export, which it was not before', () async {
    // WHOLE HOUSE IS THE ONLY STARTER WITH HOME RUNS, and it already prints
    // T5.01 for five powered IR receiver ports and nothing else (measured).
    // Their variants are cleared first, as `auto_sheet_absent_test.dart`
    // clears Home Theatre's, so the control below can see T5.01 absent and
    // the null-modem is what brings it back.
    for (final t in doc.templates.values) {
      for (final p in t.body.ports) {
        if (p.pinoutVariant == 'xantech-stereo') p.pinoutVariant = null;
      }
    }
    Future<List<String>> sheetIds() async {
      final outcome = await runExportInline(
        ExportRequest(
          documentJson: const JsonDocumentCodec().write(doc),
          fontBytes: <FontRef, Uint8List>{
            const FontRef('Jost'): File(
              'assets/fonts/Jost-Regular.ttf',
            ).readAsBytesSync(),
          },
          fileName: 'whole_house.rppj',
          issuedAt: DateTime.utc(2026, 10, 4),
        ),
      ).result;
      return [
        for (final s in (outcome! as Ok<ExportedDocument>).value.sheets)
          s.ncsId,
      ];
    }

    expect(await sheetIds(), isNot(contains('T5.01')), reason: 'control');
    edit([cell(crossoverLabel(CrossoverKind.nullModem))]);
    expect(await sheetIds(), contains('T5.01'));
  });
}
