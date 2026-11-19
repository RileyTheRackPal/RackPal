// Writes the two-storey residence sample and its PDF sheet set.
//
//   cd apps/rackpal
//   dart run tool/generate_sample_residence.dart
//
// Draw the floorplans first if `residence_geometry.json` changed:
//   python tools/samples/draw_residence_plans.py   (from the repo root)
//
// The project and the PDF land in `docs/samples/two-storey-residence/`. The
// export runs through `buildExportDocument`, the function behind
// `File > Export PDF...`, and the findings printed are the validation
// drawer's, from `evaluateDocument`.
import 'dart:io';

import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_export/rackpal_export.dart';

import 'samples/two_storey_residence.dart';

const String kSampleOutDir = '../../docs/samples/two-storey-residence';
const String kSampleName = 'two-storey-residence';

Future<void> main() async {
  final sample = buildTwoStoreyResidence();
  final doc = sample.doc;
  const codec = JsonDocumentCodec();
  final json = codec.write(doc);

  // Read it back before trusting it: a sample the application cannot open
  // is worse than none.
  if (codec.read(json) case Err(:final error)) {
    stderr.writeln('The sample does not read back: $error');
    exitCode = 1;
    return;
  }

  final out = Directory(kSampleOutDir)..createSync(recursive: true);
  final project = File('${out.path}/$kSampleName.rppj')
    ..writeAsBytesSync(writeContainerBytes(json, sample.members));
  stdout
    ..writeln('written    ${project.path}  ${project.lengthSync()} bytes')
    ..writeln(
      '           ${doc.racks.length} racks, ${doc.devices.length} devices, '
      '${doc.links.length} cables, ${doc.outlets.length} outlets, '
      '${doc.locations.length} locations',
    )
    ..writeln('project templates forked for this job:');
  for (final name in sample.forkedTemplates) {
    stdout.writeln('  - $name');
  }

  final findings = evaluateDocument(doc);
  stdout.writeln('validation findings: ${findings.length}');
  for (final f in findings) {
    stdout.writeln(
      '  ${f.severity.name.padRight(7)} ${f.ruleId}  ${f.message}',
    );
  }

  for (final underlay in doc.underlays.values) {
    final unpinned = unpinnedCarriersFor(doc, underlay);
    for (final row in unpinned.rows) {
      stdout.writeln('  unpinned on ${underlay.name}: ${row.designator}');
    }
  }

  final font = File('assets/fonts/Jost-Regular.ttf').readAsBytesSync();
  final result = await buildExportDocument(
    ExportRequest(
      documentJson: json,
      fontBytes: {kSheetFont: font},
      fileName: '$kSampleName.rppj',
      issuedAt: DateTime.utc(2026, 11, 18),
      members: sample.members,
    ),
  );
  switch (result) {
    case Ok(:final value):
      final pdf = File('${out.path}/$kSampleName.pdf')
        ..writeAsBytesSync(value.bytes);
      stdout.writeln(
        'written    ${pdf.path}  ${value.sheetCount} sheets, '
        '${value.bytes.length} bytes',
      );
      for (final sheet in value.sheets) {
        stdout.writeln('  ${sheet.ncsId.padRight(8)} ${sheet.title}');
      }
      if (value.notices.isNotEmpty) {
        stdout.writeln('export notices: ${value.notices.length}');
        for (final n in value.notices) {
          stdout.writeln('  $n');
        }
      }
    case Err(:final error):
      stderr.writeln('Export failed: ${(error as ExportError).message}');
      exitCode = 1;
  }
}
