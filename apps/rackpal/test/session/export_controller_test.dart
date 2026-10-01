// `File ▸ Export PDF…`, end to end over the fake disk.
//
// The PDF's CONTENT is proved in `rackpal_export`'s own suite. This file
// is about the app-layer contract: that the export reuses the shipped save
// surface rather than inventing one, that every outcome REPORTS, and that
// a refusal leaves nothing behind.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:rackpal/src/session/export_controller.dart';
import 'package:rackpal/src/session/file_error_presenter.dart';
import 'package:rackpal/src/storage/save_paths.dart';
import 'package:rackpal_core/rackpal_core.dart';

import '../storage/fake_file_store.dart';
import 'session_fakes.dart';

/// The bytes at [path] in [fs], or null when nothing is there.
Uint8List? _bytesAt(FakeFileStore fs, String path) {
  final content = fs.state.files[path];
  return content is Bytes ? content.value : null;
}

/// THE DRAWING, recovered from an exported PDF: every page's content
/// stream, inflated, in file order.
///
/// ───────────────────────────────────────────────────────────────────────
/// WHY THIS LAYER READS THE CONTENT AT ALL
/// ───────────────────────────────────────────────────────────────────────
/// Two assertions in this file were about what the export DRAWS and could
/// not see it: one compared byte LENGTHS (dominated by the embedded font
/// subset, so a great many content changes are length-neutral) and one
/// compared two suggested FILE NAMES while claiming to guard the sheets'
/// date. Both needed the drawing, so the drawing is what they now compare.
///
/// WHY IT IS NOT IMPORTED. `rackpal_export`'s suite has a full
/// content-stream interpreter, and one package's `test/` directory is not
/// an importable surface from another's. What is needed here is much
/// smaller than that file: not "where did the ink land" — that is proved
/// against the bytes one layer down — but "is this the same drawing".
///
/// WHY THE COMPARISON IS STABLE. A pdf 3.13.0 file has exactly two
/// non-deterministic parts, both outside the page streams: the trailer
/// `/ID` (`sha256(DateTime.now() + Random.secure())`) and `PdfInfo`'s
/// hardcoded `/CreationDate`. `rackpal_export/test/
/// export_determinism_test.dart` asserts that same-input page streams are
/// byte-identical and that whole FILES are not, which is the fact this
/// helper stands on.
List<String> _pageStreams(Uint8List pdfBytes) {
  final source = String.fromCharCodes(pdfBytes); // bytes are 0..255 -> latin1
  final pattern = RegExp(r'stream\r?\n(.*?)\r?\nendstream', dotAll: true);
  final pages = <String>[];
  for (final match in pattern.allMatches(source)) {
    final body = match.group(1)!;
    final start = match.start + match.group(0)!.indexOf(body);
    var operators = body;
    try {
      operators = String.fromCharCodes(
        ZLibDecoder().convert(pdfBytes.sublist(start, start + body.length)),
      );
      // A body that is not deflate — a font blob in another filter — has no
      // inflated form, and its raw bytes are then what is tested against
      // the page predicate below. That is an answer, not an error.
      // ignore: avoid_catches_without_on_clauses
    } catch (_) {}
    // A drawn sheet has rectangles and text; a font or a CMap has neither.
    if (operators.contains(' re ') && operators.contains('BT')) {
      pages.add(operators);
    }
  }
  return pages;
}

/// Every path in [fs] ending in [suffix].
List<String> _pathsEndingIn(FakeFileStore fs, String suffix) =>
    fs.state.files.keys.where((k) => k.toLowerCase().endsWith(suffix)).toList();

EntityMeta _meta() => EntityMeta(
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  updatedBy: 'test',
);

/// A document with one 12 U rack and one device on it.
RackDocument _document({
  int rackCount = 1,
  String projectName = 'Smith Residence',
  List<RevisionEntry>? revisions,
}) {
  final racks = <Rack>[
    for (var i = 0; i < rackCount; i++)
      Rack(
        id: Uuid('rack-$i'),
        name: 'RACK $i',
        designator: 'RK-${i + 1}',
        heightU: 12,
        order: FracIndex('a$i'),
        meta: _meta(),
      ),
  ];
  return RackDocument(
    id: const Uuid('doc-1'),
    appVersion: 'test',
    createdAt: DateTime.utc(2026),
    modifiedAt: DateTime.utc(2026),
    meta: _meta(),
    info: ProjectInfo(projectName: projectName),
    racks: <Uuid, Rack>{for (final r in racks) r.id: r},
    devices: racks.isEmpty
        ? <Uuid, DeviceInstance>{}
        : <Uuid, DeviceInstance>{
            const Uuid('dev-1'): DeviceInstance(
              id: const Uuid('dev-1'),
              kind: DeviceKind.rackDevice,
              templateRef: const TemplateRef(
                templateId: TemplateId('T1'),
                version: 1,
                contentHash: 'h',
              ),
              designator: 'AMP-1',
              name: 'Zone amp',
              placement: RailPlacement(
                rackId: racks.first.id,
                ruIndex: 3,
                face: Face.front,
              ),
              meta: _meta(),
            ),
          },
    templates: <String, TemplateSnapshot>{
      'T1@1': TemplateSnapshot(
        templateId: const TemplateId('T1'),
        version: 1,
        contentHash: 'h',
        body: TemplateBody(
          manufacturer: 'ACME',
          model: 'AMP-8',
          displayName: 'Eight-channel amp',
          frontU: 2,
          side: OccupancySide.front,
        ),
        capturedAt: DateTime.utc(2026),
      ),
    },
    revisionBlock: revisions,
  );
}

/// A document with no racks at all — reachable the moment the app can open
/// a file.
RackDocument _racklessDocument() => _document(rackCount: 0);

void main() {
  group('a successful export', () {
    test('writes the PDF and reports what it wrote', () async {
      final session = await buildTestSession(
        document: _document(),
        savePaths: <String?>[r'C:\jobs\smith'],
      );

      expect(await session.services.export.exportPdf(), isTrue);

      // THE EXTENSION IS FORCED, through the SAME `SavePaths.forTarget`
      // the document save uses. The Windows dialog hands back `smith`
      // when the user types `smith`.
      final written = _pathsEndingIn(session.fs, '.pdf');
      expect(written, <String>[r'C:\jobs\smith.pdf']);
      expect(
        String.fromCharCodes(_bytesAt(session.fs, written.single)!.take(5)),
        '%PDF-',
      );

      expect(session.services.session.status, startsWith('Exported '));
      // The cover, the legend, two elevations and the list since M6-A.
      expect(session.services.session.status, contains('5 sheets'));
    });

    test('leaves NO .bak beside the deliverable, even on the OVERWRITE '
        '(CR-098)', () async {
      // ==============================================================
      // THE OVERWRITE IS THE ONLY CASE THAT TESTS keepBackup, AND A
      // MUTATION PROVED IT.
      // ==============================================================
      // This used to export ONCE to a fresh path. `AtomicWriter` sets
      // `backupAttempted = keepBackup && targetExisted`, so a first write
      // has nothing to back up — flipping `keepBackup` to `true` produced
      // no `.bak` and the assertion passed anyway. Only the second export
      // over an existing file exercises step 4 at all.
      final session = await buildTestSession(
        document: _document(),
        savePaths: <String?>[r'C:\jobs\smith.pdf', r'C:\jobs\smith.pdf'],
      );
      await session.services.export.exportPdf();
      await session.services.export.exportPdf();

      expect(
        _pathsEndingIn(session.fs, '.bak'),
        isEmpty,
        reason: 'a PDF is a regenerable deliverable, not the project',
      );
      expect(
        _pathsEndingIn(session.fs, '.tmp'),
        isEmpty,
        reason: 'the temp is swept by step 8',
      );
      // ...and the user's folder holds NOTHING but the file they asked for.
      expect(
        session.fs.state.files.keys.where((k) => k.startsWith(r'C:\jobs')),
        <String>[r'C:\jobs\smith.pdf'],
      );
    });

    test('does not dirty the document — an export is not an edit', () async {
      final session = await buildTestSession(
        document: _document(),
        savePaths: <String?>[r'C:\jobs\smith.pdf'],
      );
      final before = session.services.session.isDirty;

      await session.services.export.exportPdf();

      expect(session.services.session.isDirty, before);
      // ...and it does not claim the document has been saved.
      expect(session.services.session.filePath, isNull);
    });

    test('overwriting an existing PDF replaces it with the SAME DRAWING, '
        'not merely with the same number of bytes', () async {
      // ==============================================================
      // A LENGTH COMPARISON WAS NOT A CONTENT COMPARISON.
      // ==============================================================
      // This used to assert `hasLength(first)` — the byte COUNT of the
      // two exports. PDF lengths are dominated by the embedded font
      // subset, so a great many content changes are length-neutral: a
      // second export silently writing the FIRST document's cached
      // bytes, or a title-block field resolving to a same-width wrong
      // value, both passed. Its real subject — that the overwrite
      // REPLACES rather than appends or backs up — is already carried by
      // the `.bak`/`.tmp` assertions above, so what is left for this test
      // to say is about the drawing.
      //
      // It also doubles as the control for the clock group at the bottom
      // of this file: with the clock standing still, two exports of one
      // unmodified document draw byte-identically. That is what makes a
      // DIFFERENCE there attributable to the clock and to nothing else.
      final session = await buildTestSession(
        document: _document(),
        savePaths: <String?>[r'C:\jobs\smith.pdf', r'C:\jobs\smith.pdf'],
      );

      expect(await session.services.export.exportPdf(), isTrue);
      final first = _pageStreams(_bytesAt(session.fs, r'C:\jobs\smith.pdf')!);
      expect(await session.services.export.exportPdf(), isTrue);
      final second = _pageStreams(_bytesAt(session.fs, r'C:\jobs\smith.pdf')!);

      // Not vacuous: there really are five drawn sheets to compare, and
      // each of them has ink on it.
      expect(first, hasLength(5));
      for (final page in first) {
        expect(page.length, greaterThan(500));
      }
      expect(second, first, reason: 'the second export drew something else');
      // ...and there is still exactly one file, replaced rather than
      // appended to.
      expect(_pathsEndingIn(session.fs, '.pdf'), <String>[
        r'C:\jobs\smith.pdf',
      ]);
      expect(session.prompts.errors, isEmpty);
    });
  });

  group('NEVER SILENTLY DO NOTHING', () {
    test('a cancelled dialog REPORTS the cancel', () async {
      final session = await buildTestSession(
        document: _document(),
        savePaths: const <String?>[null],
      );

      expect(await session.services.export.exportPdf(), isFalse);
      expect(session.services.session.status, kExportCancelledStatus);
      expect(_pathsEndingIn(session.fs, '.pdf'), isEmpty);
    });

    test('a document with NO RACKS is refused OUT LOUD, before the '
        'dialog', () async {
      // Refused before, not after: asking where to put a file and only
      // then saying there is nothing to put in it wastes the interaction.
      // And it must not emit a one-sheet PDF of an empty project, which
      // would look like a deliverable.
      final session = await buildTestSession(
        document: _racklessDocument(),
        savePaths: <String?>[r'C:\jobs\smith.pdf'],
      );

      expect(await session.services.export.exportPdf(), isFalse);
      expect(session.picker.saveCalls, 0);
      expect(session.prompts.errors, hasLength(1));
      expect(session.prompts.errors.single.title, kExportNoRacksTitle);
      expect(session.prompts.errors.single.detail, contains('no racks'));
      expect(_pathsEndingIn(session.fs, '.pdf'), isEmpty);
    });

    test('a write failure reports through the SHIPPED error surface', () async {
      // `SaveLocked` is AC-058/D4's "the target PDF is open in Acrobat",
      // and it already has copy and a Retry button because the document
      // save path needed the same thing. Modelled as a promote that keeps
      // failing with errno 32 past the retry budget.
      final session = await buildTestSession(
        document: _document(),
        savePaths: <String?>[r'C:\jobs\smith.pdf'],
        prompts: ScriptedPrompts(errorActions: <String>[FileErrorActionId.ok]),
        fs: FakeFileStore(
          initialDirectories: <String>{kTestDataRoot, kTestJobsDir, 'C:'},
          failRenamesTo: <String, int>{r'C:\jobs\smith.pdf': 99},
        ),
      );

      expect(await session.services.export.exportPdf(), isFalse);
      expect(session.prompts.errors, hasLength(1));
      expect(
        session.prompts.errors.single.title.toLowerCase(),
        contains('another program'),
      );
      // NOTHING IS LEFT BEHIND for the user to wonder about, and the
      // status line does not claim a success that did not happen.
      expect(_pathsEndingIn(session.fs, '.pdf'), isEmpty);
      expect(session.services.session.status, isNot(startsWith('Exported')));
    });

    test('Retry re-runs the write and can succeed', () async {
      // `kPromoteRetryBackoff` gives four attempts per write, so five
      // scripted failures exhaust the first write and leave the second —
      // the user's Retry — to succeed on its own first attempt.
      final session = await buildTestSession(
        document: _document(),
        savePaths: <String?>[r'C:\jobs\smith.pdf'],
        prompts: ScriptedPrompts(
          errorActions: <String>[FileErrorActionId.retry],
        ),
        fs: FakeFileStore(
          initialDirectories: <String>{kTestDataRoot, kTestJobsDir, 'C:'},
          failRenamesTo: <String, int>{r'C:\jobs\smith.pdf': 4},
        ),
      );

      expect(await session.services.export.exportPdf(), isTrue);
      expect(_pathsEndingIn(session.fs, '.pdf'), <String>[
        r'C:\jobs\smith.pdf',
      ]);
      expect(session.services.session.status, startsWith('Exported '));
    });
  });

  group('the suggested file name (§8.3)', () {
    test('is {slug}_{rack}_rev{REV}_{date}.pdf for one rack', () {
      expect(
        exportFileNameFor(
          displayName: 'Smith Residence',
          document: _document(),
          issuedAt: DateTime.utc(2026, 7, 18),
        ),
        'smith-residence_rk-1_rev-_2026-07-18.pdf',
      );
    });

    test('more than one rack is a SET, not a rack name', () {
      expect(
        exportFileNameFor(
          displayName: 'Smith Residence',
          document: _document(rackCount: 3),
          issuedAt: DateTime.utc(2026, 7, 18),
        ),
        contains('_SET_'),
      );
    });

    test('the REVISION is carried when there is one', () {
      // §8.3: "the revision in the filename is not optional; it is the
      // only thing that stops the wrong PDF being on site."
      expect(
        exportFileNameFor(
          displayName: 'Smith',
          document: _document(
            revisions: <RevisionEntry>[
              RevisionEntry(
                revision: 'C',
                date: DateTime.utc(2026, 3),
                description: 'Added AMP-2',
                by: 'JS',
              ),
            ],
          ),
          issuedAt: DateTime.utc(2026, 7, 18),
        ),
        'smith_rk-1_revc_2026-07-18.pdf',
      );
    });

    test('NO revision history gives rev-, never a fabricated revA', () {
      expect(
        exportFileNameFor(
          displayName: 'Smith',
          document: _document(),
          issuedAt: DateTime.utc(2026, 7, 18),
        ),
        contains('_rev-_'),
      );
    });

    test(
      'it reaches the DIALOG, which is what the user actually sees',
      () async {
        final session = await buildTestSession(
          document: _document(),
          savePaths: const <String?>[null],
        );
        await session.services.export.exportPdf();

        expect(session.picker.suggestedNames, hasLength(1));
        expect(
          session.picker.suggestedNames.single,
          'smith-residence_rk-1_rev-_'
          '${formatSheetDate(session.clock.nowUtc())}.pdf',
        );
      },
    );
  });

  group('slugify — the name reaches a filesystem', () {
    test('every character Windows forbids is removed', () {
      for (final bad in <String>[
        r'\',
        '/',
        ':',
        '*',
        '?',
        '"',
        '<',
        '>',
        '|',
      ]) {
        expect(slugify('a${bad}b'), 'a-b', reason: bad);
      }
    });

    test('runs collapse and edges are trimmed', () {
      expect(slugify('  Smith — Phase 2 (rev C)  '), 'smith-phase-2-rev-c');
    });

    test('a name with nothing usable still produces a file name', () {
      // An empty stem would produce `_RK-1_rev-_2026-07-18.pdf`, which is
      // legal but reads as a bug.
      expect(slugify('！！！'), 'project');
      expect(slugify(''), 'project');
    });
  });

  group('the status line', () {
    test('names the sheet count and the size', () {
      expect(
        describeExportSuccess(
          sheetCount: 3,
          bytesWritten: 219_136,
          notices: const <String>[],
        ),
        'Exported 3 sheets · 214 KB',
      );
    });

    test('a single sheet is not pluralised', () {
      expect(
        describeExportSuccess(
          sheetCount: 1,
          bytesWritten: 900,
          notices: const <String>[],
        ),
        'Exported 1 sheet · 900 B',
      );
    });

    test('NOTICES ARE SURFACED, never swallowed', () {
      // §6.2's legibility check and the NCS validation report here. A
      // notice nobody is told about is a notice that did not happen — and
      // it is still never a gate (CR-023): the bytes are already on disk.
      expect(
        describeExportSuccess(
          sheetCount: 3,
          bytesWritten: 1024,
          notices: const <String>['T2.01: small text'],
        ),
        'Exported 3 sheets · 1 KB · 1 notice',
      );
    });

    test('formatByteSize uses 1024, like a Windows file listing', () {
      expect(formatByteSize(0), '0 B');
      expect(formatByteSize(1023), '1023 B');
      expect(formatByteSize(1024), '1 KB');
      expect(formatByteSize(1024 * 1024), '1.0 MB');
    });
  });

  group('SavePaths shares ONE extension normalisation', () {
    test('the .pdf and .rppj rules are the same rule', () {
      final ctx = p.Context(style: p.Style.windows);
      expect(
        SavePaths.forTarget(
          r'C:\jobs\smith',
          context: ctx,
          extensions: const <String>[kPdfExtension],
        ).target,
        r'C:\jobs\smith.pdf',
      );
      // Already-correct extensions are left alone, case-insensitively...
      expect(
        SavePaths.forTarget(
          r'C:\jobs\smith.PDF',
          context: ctx,
          extensions: const <String>[kPdfExtension],
        ).target,
        r'C:\jobs\smith.PDF',
      );
      // ...and a deliberate second extension is APPENDED, not replaced, so
      // nothing the user typed is thrown away.
      expect(
        SavePaths.forTarget(
          r'C:\jobs\smith.v2',
          context: ctx,
          extensions: const <String>[kPdfExtension],
        ).target,
        r'C:\jobs\smith.v2.pdf',
      );
      // The default is unchanged for every existing caller.
      expect(
        SavePaths.forTarget(r'C:\jobs\smith', context: ctx).target,
        r'C:\jobs\smith.rppj',
      );
    });
  });

  group('the export path calls DateTime.now() nowhere (§8.4)', () {
    // ====================================================================
    // THIS GROUP MADE NO ASSERTION ABOUT THE EXPORT PATH'S CLOCK.
    // ====================================================================
    // It advanced a fake clock 400 days, exported twice, and then compared
    // two suggested FILE NAMES. Those come from `exportFileNameFor` at
    // `export_controller.dart:157` — a DIFFERENT call site from the one
    // line the group claimed to guard, `issuedAt: clock.nowUtc()` at line
    // 185, which is what every sheet's ISSUED field is drawn from.
    //
    // Change line 185 to `DateTime.now()` and every sheet of every
    // user-facing export prints the wall-clock date instead of the
    // injected one — while the whole app suite stayed green, because the
    // suggested name is unaffected. `rackpal_export/test/
    // export_determinism_test.dart` proves `buildExportDocument` honours
    // the `issuedAt` it is GIVEN; nothing proved the app gives it the
    // injected clock. The comment that said "the content determinism proof
    // lives in rackpal_export" is exactly what papered over the gap.

    test('MOVING THE INJECTED CLOCK MOVES WHAT THE SHEETS ARE DRAWN '
        'WITH', () async {
      // Both exports go to the SAME path, so the `fileName` that reaches
      // `buildExportDocument` — which is also drawn, in the title block —
      // is identical between them and the clock is the only difference.
      final session = await buildTestSession(
        document: _document(),
        savePaths: <String?>[r'C:\jobs\smith.pdf', r'C:\jobs\smith.pdf'],
      );

      expect(await session.services.export.exportPdf(), isTrue);
      final before = _pageStreams(_bytesAt(session.fs, r'C:\jobs\smith.pdf')!);

      session.clock.advance(const Duration(days: 400));
      expect(await session.services.export.exportPdf(), isTrue);
      final after = _pageStreams(_bytesAt(session.fs, r'C:\jobs\smith.pdf')!);

      expect(before, hasLength(5), reason: 'five drawn sheets to compare');
      expect(after, hasLength(5));
      expect(
        after,
        isNot(before),
        reason:
            'the sheets did not change when the injected clock moved 400 '
            'days, so the export is reading some other clock',
      );

      // THE CONTROL IS A SEPARATE TEST, NAMED: "overwriting an existing
      // PDF replaces it with the SAME DRAWING" above exports twice with a
      // STOPPED clock and asserts the two drawings are identical. Without
      // it, the assertion above would also pass on an export that was
      // simply non-deterministic. Restated here as a dependency rather
      // than duplicated.
      expect(session.prompts.errors, isEmpty);
    });

    test('the injected clock also reaches the SUGGESTED NAME — a second '
        'call site, and both must use it', () async {
      // The claim the old test actually made, kept and labelled correctly.
      // `exportFileNameFor` is a different line from the one above, and a
      // wall-clock leak in EITHER of them ships a wrong date.
      final session = await buildTestSession(
        document: _document(),
        savePaths: <String?>[r'C:\jobs\a.pdf', r'C:\jobs\b.pdf'],
      );

      final before = session.clock.nowUtc();
      await session.services.export.exportPdf();
      session.clock.advance(const Duration(days: 400));
      final after = session.clock.nowUtc();
      await session.services.export.exportPdf();

      // Read off the INJECTED clock, not off a literal: what is claimed is
      // that the name follows that clock, and 400 days is far enough that
      // no wall clock can be mistaken for both readings.
      expect(formatSheetDate(after), isNot(formatSheetDate(before)));
      expect(
        session.picker.suggestedNames[0],
        endsWith('_${formatSheetDate(before)}.pdf'),
      );
      expect(
        session.picker.suggestedNames[1],
        endsWith('_${formatSheetDate(after)}.pdf'),
      );
    });
  });
}
