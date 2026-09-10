// PLAN-E/5: the caller PLAN-D never got (DR-143 §11.142).
//
// ═══════════════════════════════════════════════════════════════════════
// THE SUBJECT IS THE SEQUENCE, AND THE ARTIFACT IS AN OPENABLE DOCUMENT
// ═══════════════════════════════════════════════════════════════════════
// `plan_import_test.dart` already covers the caps, the sniff, the header
// re-check and the decode. What was missing was anything that RAN them
// from the product: every function it tests had zero call sites in `lib/`,
// so `AddPlanUnderlayCommand` had no producer and no project could hold a
// floorplan.
//
// So these cases assert the two writes together. An underlay whose
// `imageMember` names bytes the container does not hold is a dangling
// reference in a saved file, and it is exactly what a test asserting only
// `doc.underlays.length` would miss.
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:rackpal/src/session/document_session.dart';
import 'package:rackpal/src/session/pdf_rasteriser.dart';
import 'package:rackpal/src/session/plan_import_actions.dart';
import 'package:rackpal_core/rackpal_core.dart';

import '../storage/fake_file_store.dart';
// A REAL, LIFTABLE PDF, borrowed rather than re-rolled. The first draft of
// this file used a stub that began with `%PDF-` and lifted no pages, which
// made both cases below pass on a document nothing was imported into: an
// assertion that cannot fail. `onePagePdf` is the fixture
// `pdf_page_import_test.dart` already builds and exercises.
import 'pdf_page_import_test.dart'
    show onePagePdf, realJpeg, smallVectorPdf, stubPng;
import 'session_fakes.dart';

final _fixed = DateTime.utc(2026, 9, 8, 9);

Uint8List _png(int w, int h) {
  final image = img.Image(width: w, height: h);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      image.setPixelRgb(x, y, 200, 30, 30);
    }
  }
  return Uint8List.fromList(img.encodePng(image));
}

RackDocument _doc() => RackDocument(
  id: const Uuid('doc-1'),
  appVersion: '0.1.0',
  createdAt: _fixed,
  modifiedAt: _fixed,
  meta: EntityMeta(createdAt: _fixed, updatedAt: _fixed, updatedBy: 'tester'),
);

({DocumentSession session, FloorplanIo io, FakeFilePicker picker}) _harness({
  required Map<String, Uint8List> files,
  String? picked,
  List<String?>? picks,
  PdfRasteriser? rasteriser,
}) {
  final session = DocumentSession(
    controller: DocumentController(
      _doc(),
      clock: FixedClock(_fixed),
      actor: 'tester',
    ),
    context: p.Context(style: p.Style.windows),
  );
  final picker = FakeFilePicker(openPaths: picks ?? [picked]);
  return (
    session: session,
    picker: picker,
    io: FloorplanIo(
      session: session,
      picker: picker,
      fs: FakeFileStore(initialFiles: files),
      // THE REAL ONE UNLESS A CASE SAYS OTHERWISE, which is what the app
      // ships. It is never CALLED for a page the lifter can take, so the
      // raster cases below neither need the vendored binary nor prove
      // anything about it.
      rasteriser: rasteriser ?? pdfiumRenderPng,
    ),
  );
}

/// The page picker, as a callback that never runs for a raster file.
Future<PdfPageOption?> _neverPicks(
  List<Outcome<PdfPageOption>> pages,
  String fileName,
) async {
  fail('the page picker ran for a file that is not a PDF');
}

void main() {
  group('a raster floorplan', () {
    test('LANDS IN THE DOCUMENT AND IN THE CONTAINER, which is two writes', () {
      // The load-bearing case. An underlay naming a member the container
      // does not hold is a dangling reference in a saved file, and
      // asserting only `doc.underlays` cannot see it.
      final h = _harness(
        files: {r'C:\plans\Level 1.png': _png(64, 48)},
        picked: r'C:\plans\Level 1.png',
      );

      return h.io.import(pickPage: _neverPicks).then((result) {
        final underlay = (result! as Ok<PlanUnderlay>).value;

        expect(h.session.document.underlays[underlay.id], isNotNull);
        expect(
          h.session.members[underlay.imageMember],
          isNotNull,
          reason: 'the member the underlay NAMES must be the one written',
        );
        expect(underlay.pixelWidth, 64);
        expect(underlay.pixelHeight, 48);
      });
    });

    test('is named from the file, without its extension', () async {
      final h = _harness(
        files: {r'C:\plans\Level 1.png': _png(32, 32)},
        picked: r'C:\plans\Level 1.png',
      );

      final result = await h.io.import(pickPage: _neverPicks);

      expect((result! as Ok<PlanUnderlay>).value.name, 'Level 1');
    });

    test('stamps meta from the INJECTED clock, not the wall clock', () async {
      // Every other command in this product does, which is what makes a
      // fixture reproducible and a byte round-trip comparable (CR-117).
      final h = _harness(
        files: {r'C:\plans\a.png': _png(16, 16)},
        picked: r'C:\plans\a.png',
      );

      final result = await h.io.import(pickPage: _neverPicks);

      expect((result! as Ok<PlanUnderlay>).value.meta.createdAt, _fixed);
    });

    test(
      'UNDO REMOVES THE UNDERLAY AND LEAVES THE MEMBER, which is ruled',
      () async {
        // `RemovePlanUnderlayCommand`'s own doc: "the member is cheap, the
        // bytes are the architect's, and deleting them on an undo would
        // make a redo unable to find them". The asymmetry is deliberate and
        // is asserted so a later tidy-up has to argue with a test.
        final h = _harness(
          files: {r'C:\plans\a.png': _png(16, 16)},
          picked: r'C:\plans\a.png',
        );
        final result = await h.io.import(pickPage: _neverPicks);
        final underlay = (result! as Ok<PlanUnderlay>).value;

        h.session.controller.undoLast();

        expect(h.session.document.underlays, isEmpty);
        expect(h.session.members[underlay.imageMember], isNotNull);
      },
    );

    test('a second import keeps the first, and sorts after it', () async {
      final h = _harness(
        files: {
          r'C:\plans\a.png': _png(16, 16),
          r'C:\plans\b.png': _png(16, 16),
        },
        picks: [r'C:\plans\a.png', r'C:\plans\b.png'],
      );
      final first =
          ((await h.io.import(pickPage: _neverPicks))! as Ok<PlanUnderlay>)
              .value;
      final second =
          ((await h.io.import(pickPage: _neverPicks))! as Ok<PlanUnderlay>)
              .value;

      expect(h.session.document.underlays.length, 2);
      expect(h.session.members.length, 2);
      expect(
        second.order.v.compareTo(first.order.v),
        greaterThan(0),
        reason: 'a new plan goes last, which is what an import means',
      );
    });
  });

  group('the ways it ends early', () {
    test('a CANCELLED file dialog is null and writes nothing', () async {
      final h = _harness(files: {});

      final result = await h.io.import(pickPage: _neverPicks);

      // NULL, NOT AN Err. Cancelled and refused are different answers and
      // the shell speaks for only one of them.
      expect(result, isNull);
      expect(h.session.document.underlays, isEmpty);
      expect(h.session.members, isEmpty);
    });

    test(
      'a REFUSED file is an Err and writes nothing, not even the member',
      () async {
        // The member is written first, on purpose, so this asserts the
        // refusal happens before either write rather than between them.
        final h = _harness(
          files: {
            r'C:\plans\notes.txt': Uint8List.fromList([1, 2, 3, 4]),
          },
          picked: r'C:\plans\notes.txt',
        );

        final result = await h.io.import(pickPage: _neverPicks);

        expect(result, isA<Err<PlanUnderlay>>());
        expect(h.session.document.underlays, isEmpty);
        expect(h.session.members, isEmpty);
      },
    );
  });

  group('the PDF branch', () {
    test(
      'reaches the picker, and the picked page becomes the underlay',
      () async {
        var sawPages = 0;
        final h = _harness(
          files: {r'C:\plans\set.pdf': onePagePdf(realJpeg(100, 50))},
          picked: r'C:\plans\set.pdf',
        );

        final result = await h.io.import(
          pickPage: (pages, fileName) async {
            sawPages = pages.length;
            expect(fileName, 'set.pdf', reason: 'the grid names the file');
            return (pages.single as Ok<PdfPageOption>).value;
          },
        );

        expect(sawPages, 1);
        final underlay = (result! as Ok<PlanUnderlay>).value;
        expect(h.session.members[underlay.imageMember], isNotNull);
        expect(underlay.name, 'set');
      },
    );

    test('A CANCELLED PAGE PICK IS NULL AND WRITES NOTHING', () async {
      // A person who opens an 80-page drawing set and closes the grid has
      // not hit an error, so this is the file-dialog cancel one step
      // later. It needs a PDF the lifter CAN read, or it passes for the
      // wrong reason.
      final h = _harness(
        files: {r'C:\plans\set.pdf': onePagePdf(realJpeg(100, 50))},
        picked: r'C:\plans\set.pdf',
      );

      final result = await h.io.import(
        pickPage: (pages, fileName) async => null,
      );

      expect(result, isNull);
      expect(h.session.document.underlays, isEmpty);
      expect(h.session.members, isEmpty);
    });

    /// LOAD-BEARING (DR-153 §11.152.6). A rendered page throws the vector
    /// away, so the container keeps the PDF it came from. Asserting only
    /// the underlay cannot see whether the member was written, which is
    /// the same hole this file's first case exists for.
    test(
      'A RENDERED PAGE WRITES TWO MEMBERS: the image and its source',
      () async {
        final pdf = smallVectorPdf();
        final h = _harness(
          files: {r'C:\plans\cad.pdf': pdf},
          picked: r'C:\plans\cad.pdf',
          rasteriser: (bytes, index, {required width, required height}) =>
              Ok(stubPng(width, height)),
        );

        final result = await h.io.import(
          pickPage: (pages, fileName) async =>
              (pages.single as Ok<PdfPageOption>).value,
        );

        final underlay = (result! as Ok<PlanUnderlay>).value;
        final source = underlay.sourcePage;
        expect(source, isNotNull);
        expect(h.session.members, hasLength(2));
        expect(h.session.members[underlay.imageMember], isNotNull);
        expect(
          h.session.members[source!.member],
          pdf,
          reason: 'the member holds the file the architect sent, byte for byte',
        );
      },
    );

    test('a LIFTED page writes one member and keeps no source', () async {
      final h = _harness(
        files: {r'C:\plans\set.pdf': onePagePdf(realJpeg(100, 50))},
        picked: r'C:\plans\set.pdf',
      );

      final result = await h.io.import(
        pickPage: (pages, fileName) async =>
            (pages.single as Ok<PdfPageOption>).value,
      );

      final underlay = (result! as Ok<PlanUnderlay>).value;
      expect(underlay.sourcePage, isNull);
      expect(h.session.members, hasLength(1));
    });

    test('ROUTES BY CONTENT, so a PDF named .png reaches the picker', () async {
      // Step 2 of the sequence: a dialog filter is a courtesy. Routing on
      // the extension would send this to the raster path, which refuses a
      // PDF by name and would report "the picker was skipped" about a
      // file the user picked correctly.
      var pickerSawIt = false;
      final h = _harness(
        files: {r'C:\plans\plan.png': onePagePdf(realJpeg(100, 50))},
        picked: r'C:\plans\plan.png',
      );

      await h.io.import(
        pickPage: (pages, fileName) async {
          pickerSawIt = true;
          return null;
        },
      );

      expect(
        pickerSawIt,
        isTrue,
        reason: 'a PDF must never reach the raster path by extension',
      );
    });
  });
}
