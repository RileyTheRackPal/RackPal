// PLAN-D/2's import path, end to end, and PLAN-D/4's controls where they
// actually run.
//
// ═══════════════════════════════════════════════════════════════════════
// THE ORDER IS THE THING UNDER TEST, NOT JUST THE OUTCOME
// ═══════════════════════════════════════════════════════════════════════
// Every one of these refusals could be produced by a slower, wronger
// implementation that decoded first and checked afterwards. The cases
// below therefore assert on inputs a correct order survives and an
// incorrect one does not: a file whose header declares 60000 x 60000 is
// refused although its bytes decode fine, and a file too big to read is
// refused although it was never read.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:rackpal/src/session/plan_import_actions.dart';
import 'package:rackpal_core/rackpal_core.dart';

import '../storage/fake_file_store.dart';

final _fixed = DateTime.utc(2026, 9, 7, 9);
const _id = Uuid('0190e3c1-1111-7000-8000-000000000001');

EntityMeta _meta() =>
    EntityMeta(createdAt: _fixed, updatedAt: _fixed, updatedBy: 'tester');

Outcome<ImportedFloorplan> importBytes(Uint8List bytes) => importFloorplanBytes(
  bytes: bytes,
  id: _id,
  name: 'Level 1',
  order: const FracIndex('a0'),
  meta: _meta(),
);

Object errorOf(Outcome<ImportedFloorplan> o) =>
    (o as Err<ImportedFloorplan>).error;

ImportedFloorplan valueOf(Outcome<ImportedFloorplan> o) =>
    (o as Ok<ImportedFloorplan>).value;

/// A real, decodable PNG of the given size. Built with the same library
/// the import uses, because the point of these cases is the SEQUENCE and
/// a hand-rolled PNG would only test the header parser again.
Uint8List realPng(int w, int h, {bool alpha = false}) {
  final image = img.Image(width: w, height: h, numChannels: alpha ? 4 : 3);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      image.setPixelRgba(x, y, 200, 30, 30, alpha && x < w ~/ 2 ? 0 : 255);
    }
  }
  return img.encodePng(image);
}

Uint8List realJpeg(int w, int h) {
  final image = img.Image(width: w, height: h);
  img.fill(image, color: img.ColorRgb8(10, 120, 200));
  return img.encodeJpg(image);
}

void main() {
  group('a real PNG and a real JPEG import', () {
    test('a PNG becomes an underlay naming a container member', () {
      final result = valueOf(importBytes(realPng(120, 80)));

      expect(result.underlay.format, PlanImageFormat.png);
      expect(result.underlay.pixelWidth, 120);
      expect(result.underlay.pixelHeight, 80);
      expect(result.underlay.imageMember, 'underlays/${_id.v}.png');
      expect(result.underlay.contentHash, startsWith('sha256:'));
      expect(result.underlay.contentHash.length, 'sha256:'.length + 64);
    });

    test('a JPEG becomes one too, with its own extension', () {
      final result = valueOf(importBytes(realJpeg(120, 80)));
      expect(result.underlay.format, PlanImageFormat.jpeg);
      expect(result.underlay.imageMember, endsWith('.jpg'));
    });

    test('AN IMPORTED PLAN IS UNCALIBRATED, which is a fact and not a gap', () {
      // G4. Inventing a 1:1 scale here would make every length derived on
      // this plan wrong AND confident, which is the worse of the two.
      expect(valueOf(importBytes(realPng(120, 80))).underlay.scale, isNull);
      expect(
        valueOf(importBytes(realPng(120, 80))).underlay.isCalibrated,
        isFalse,
      );
    });

    test('the member bytes are the file itself when nothing needed doing', () {
      // `library_io_actions.dart`'s rule: the shelf holds what the sender
      // sent. Re-encoding an opaque PNG would make the stored member
      // differ from the architect's file for no reason a person could
      // see, and re-encoding a JPEG would lose a generation.
      final source = realJpeg(64, 64);
      expect(valueOf(importBytes(source)).memberBytes, source);
    });

    test('the hash is over the STORED bytes, so it verifies what is in the '
        'container', () {
      final result = valueOf(importBytes(realPng(60, 40)));
      final rehashed = importFloorplanBytes(
        bytes: result.memberBytes,
        id: _id,
        name: 'Level 1',
        order: const FracIndex('a0'),
        meta: _meta(),
      );
      expect(
        valueOf(rehashed).underlay.contentHash,
        result.underlay.contentHash,
      );
    });
  });

  group('THE FLATTEN: alpha never reaches the stored bytes', () {
    test('a PNG with transparency is stored opaque', () {
      // docs/08 row 9 forbids alpha absolutely, and
      // `PdfImage(..., alpha: true)` emits an /SMask with nobody calling
      // setGraphicState. The screening moved to the export backend
      // (DR-037 §11.36.3); THIS obligation did not move with it.
      final source = realPng(40, 40, alpha: true);
      expect(img.decodeImage(source)!.hasAlpha, isTrue);

      final stored = valueOf(importBytes(source)).memberBytes;
      expect(img.decodeImage(stored)!.hasAlpha, isFalse);
      expect(stored, isNot(source));
    });

    test('and it is composited over WHITE, because that is what paper is', () {
      final source = realPng(40, 40, alpha: true);
      final stored = img.decodeImage(valueOf(importBytes(source)).memberBytes)!;
      // The left half was fully transparent; over white it is white, and
      // over the other plausible default it would be black.
      final pixel = stored.getPixel(5, 20);
      expect(pixel.r, greaterThan(200));
      expect(pixel.g, greaterThan(200));
      expect(pixel.b, greaterThan(200));
    });

    test('an opaque image is NOT re-encoded, so the flatten costs nothing '
        'when there is nothing to flatten', () {
      final source = realPng(40, 40);
      expect(valueOf(importBytes(source)).memberBytes, source);
    });
  });

  group('PLAN-D/4: what is refused, and in what order', () {
    test('a PDF is refused by NAME, not as an unsupported format', () {
      // DR-029 bought PDF import deliberately, so "that is not a
      // supported format" would tell a person the product decided
      // something it did not.
      final pdf = Uint8List.fromList([
        0x25,
        0x50,
        0x44,
        0x46,
        0x2D,
        0x31,
        0x2E,
        0x37,
        0x0A,
      ]);
      final error = errorOf(importBytes(pdf));
      expect(error, isA<PdfImportNotAvailableError>());
      // THIS PINNED `contains('not built yet')` UNTIL 2026-09-08, which
      // was the sentence DR-138 made false: PDF import IS built, and the
      // message told the reader to go and convert the file by hand. A
      // test that keeps asserting the copy it was written against
      // survives the behaviour it was protecting, which is the house
      // rule this is the newest instance of. Assert what the error means
      // NOW -- the page picker was skipped -- so the next change to that
      // meaning fails here.
      expect(error.toString(), contains('page picker'));
      expect(error.toString(), isNot(contains('not built yet')));
    });

    test('anything not PNG, JPEG or PDF is refused on its CONTENT', () {
      // Named `.png` by the picker or not, the bytes are what decides.
      final executable = Uint8List.fromList([0x4D, 0x5A, 0x90, 0x00, 0x03]);
      expect(
        errorOf(importBytes(executable)),
        isA<UnsupportedImageFormatError>(),
      );
    });

    test('A DECLARED SIZE PAST THE CAP IS REFUSED THOUGH THE BYTES ARE '
        'TINY, which is the order under test', () {
      // The header says 60000 x 60000 in under a hundred bytes. An
      // implementation that decoded first would allocate 10.8 GB before
      // reaching its cap.
      final bomb = Uint8List.fromList([
        0x89,
        0x50,
        0x4E,
        0x47,
        0x0D,
        0x0A,
        0x1A,
        0x0A,
        0,
        0,
        0,
        13,
        0x49,
        0x48,
        0x44,
        0x52,
        0,
        0,
        0xEA,
        0x60,
        0,
        0,
        0xEA,
        0x60,
        8,
        6,
        0,
        0,
        0,
      ]);
      expect(bomb.length, lessThan(100));
      expect(errorOf(importBytes(bomb)), isA<ImageTooLargeError>());
    });

    test('a truncated PNG is malformed rather than a crash', () {
      final source = realPng(60, 40);
      expect(
        errorOf(importBytes(Uint8List.sublistView(source, 0, 12))),
        isA<Exception>(),
      );
    });

    test('a well-formed header over garbage is a DECODE failure, which is '
        'a different sentence', () {
      // Signature and IHDR parse; there is no image data behind them. The
      // header parser cannot see this and is not supposed to: it is the
      // decode that finds out, and the two errors say different things.
      final head = Uint8List.fromList([
        0x89,
        0x50,
        0x4E,
        0x47,
        0x0D,
        0x0A,
        0x1A,
        0x0A,
        0,
        0,
        0,
        13,
        0x49,
        0x48,
        0x44,
        0x52,
        0,
        0,
        0,
        40,
        0,
        0,
        0,
        30,
        8,
        6,
        0,
        0,
        0,
        ...List<int>.filled(64, 0x41),
      ]);
      final error = errorOf(importBytes(head));
      expect(error, anyOf(isA<ImageDecodeFailedError>(), isA<Exception>()));
      expect(error, isNot(isA<ImageTooLargeError>()));
    });
  });

  group('the file-system half stats before it reads', () {
    test('a file over the cap is refused ON ITS SIZE, with the cap lowered '
        'rather than the fixture raised', () async {
      // `JsonLimits`' trick, a third time: proving the gate fires must
      // not cost a 64 MB fixture. The file below is a perfectly good PNG
      // that would import fine at the real cap.
      final png = realPng(80, 60);
      final fs = FakeFileStore(
        initialFiles: {r'C:\plans\level1.png': png},
        initialDirectories: {'C:', r'C:\plans'},
      );

      // THROUGH `readImportedBytes`, the read `FloorplanIo` makes (#945
      // deleted the `importFloorplanFrom` wrapper this used to call, which
      // nothing in the product did).
      final read = await readImportedBytes(
        fs: fs,
        path: r'C:\plans\level1.png',
        maxBytes: 10,
      );

      expect(read, isA<Err<Uint8List>>());
      expect((read as Err<Uint8List>).error, isA<DocumentTooLargeError>());
    });

    test('a real file on the fake store imports', () async {
      final png = realPng(80, 60);
      final fs = FakeFileStore(
        initialFiles: {r'C:\plans\level1.png': png},
        initialDirectories: {'C:', r'C:\plans'},
      );

      // The two halves `FloorplanIo` composes: the capped read, then the
      // decode.
      final read = await readImportedBytes(
        fs: fs,
        path: r'C:\plans\level1.png',
      );
      final result = importFloorplanBytes(
        bytes: (read as Ok<Uint8List>).value,
        id: _id,
        name: 'Level 1',
        order: const FracIndex('a0'),
        meta: _meta(),
      );
      expect(valueOf(result).underlay.pixelWidth, 80);
    });
  });
}
