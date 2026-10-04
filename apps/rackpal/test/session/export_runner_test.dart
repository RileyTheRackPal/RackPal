// The export off the main isolate (M6-I2 `#353`, M6-I3 `#354`, CR-099).
//
// Plain `test`s, not `testWidgets`: these spawn a REAL isolate, and a
// widget test's fake-async zone never delivers another isolate's work, so
// one written as a widget test would hang without a word.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:rackpal/src/session/export_runner.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_export/rackpal_export.dart';
import 'package:rackpal_ui/rackpal_ui.dart' show ExportProgress;

ExportRequest _request({Uint8List? json}) => ExportRequest(
  documentJson:
      json ?? File('assets/starters/whole_house.rppj').readAsBytesSync(),
  fontBytes: <FontRef, Uint8List>{
    const FontRef('Jost'): File(
      'assets/fonts/Jost-Regular.ttf',
    ).readAsBytesSync(),
  },
  fileName: 'whole_house.rppj',
  issuedAt: DateTime.utc(2026, 10, 4),
);

void main() {
  test('THE ISOLATE AND THE INLINE RUNNER PRODUCE ONE FILE: the same '
      'bytes, which determinism (M6-I5) is what lets this compare', () async {
    final apart = await runExportInIsolate(_request()).result;
    final inline = await runExportInline(_request()).result;
    final a = (apart! as Ok<ExportedDocument>).value;
    final b = (inline! as Ok<ExportedDocument>).value;
    expect(a.sheetCount, 16);
    expect(a.bytes, b.bytes);
    expect(a.notices, b.notices);
  });

  test('progress crosses the boundary and ends at every sheet drawn', () async {
    final job = runExportInIsolate(_request());
    final seen = <ExportProgress>[];
    job.progress.addListener(() => seen.add(job.progress.value!));
    await job.result;
    expect(seen, isNotEmpty);
    expect(seen.last, (sheetsDone: 16, sheets: 16));
    expect(
      seen.map((p) => p.sheetsDone),
      orderedEquals(seen.map((p) => p.sheetsDone).toList()..sort()),
    );
  });

  test('CANCEL STOPS IT: the result is null at once, and nothing is '
      'delivered afterwards', () async {
    final job = runExportInIsolate(_request())..cancel();
    expect(await job.result, isNull);
    // Long enough for an uncancelled export to have finished several times
    // over (about 100 ms measured); nothing arrives.
    final before = job.progress.value;
    await Future<void>.delayed(const Duration(seconds: 1));
    expect(job.progress.value, before);
  });

  test('a refusal crosses as a refusal, not a crash', () async {
    final outcome = await runExportInIsolate(
      _request(json: Uint8List.fromList('not json'.codeUnits)),
    ).result;
    expect(
      (outcome! as Err<ExportedDocument>).error,
      isA<ExportDocumentUnreadable>(),
    );
  });

  test('the INLINE runner cancels by discarding: null, though the work '
      'it cannot stop runs on', () async {
    final job = runExportInline(_request())..cancel();
    expect(await job.result, isNull);
  });
}
