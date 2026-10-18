// The integrator's logo, imported (`#590`, DR-030, DR-217).
//
// Four formats in, one kind of member out (DR-217 §11.216.2): PNG and JPEG
// verbatim, flattened only over alpha; PDF and SVG rendered through the
// REAL pdfium to fit the 100 x 45 pt box at 600 dpi. Then the refusals an
// SVG owes before anything draws it, and the two writes `LogoIo` makes.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:rackpal/src/session/document_session.dart';
import 'package:rackpal/src/session/file_picker.dart';
import 'package:rackpal/src/session/logo_import_actions.dart';
import 'package:rackpal_core/rackpal_core.dart';

import '../storage/fake_file_store.dart';
import 'macos_pdfium_debt.dart';
import 'pdf_page_import_test.dart' show realJpeg, smallVectorPdf;
import 'session_fakes.dart';

final _fixed = DateTime.utc(2026, 10);

Uint8List _png(int w, int h, {bool alpha = false}) {
  final image = img.Image(width: w, height: h, numChannels: alpha ? 4 : 3);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      if (alpha) {
        image.setPixelRgba(x, y, 200, 30, 30, x.isEven ? 255 : 0);
      } else {
        image.setPixelRgb(x, y, 200, 30, 30);
      }
    }
  }
  return Uint8List.fromList(img.encodePng(image));
}

Uint8List _svg(String body, {String root = 'viewBox="0 0 400 100"'}) =>
    Uint8List.fromList(
      utf8.encode(
        '<?xml version="1.0"?>\n'
        '<svg xmlns="http://www.w3.org/2000/svg" $root>$body</svg>',
      ),
    );

const _rect = '<rect x="0" y="0" width="400" height="100" fill="#1e3c78"/>';

Future<ImportedLogo> _ok(Uint8List bytes) async =>
    ((await importLogoBytes(bytes: bytes, id: const Uuid('logo-1')))
            as Ok<ImportedLogo>)
        .value;

Future<Object> _refused(Uint8List bytes) async =>
    ((await importLogoBytes(bytes: bytes, id: const Uuid('logo-1')))
            as Err<ImportedLogo>)
        .error;

RackDocument _doc() => RackDocument(
  id: const Uuid('doc-1'),
  appVersion: '0.1.0',
  createdAt: _fixed,
  modifiedAt: _fixed,
  meta: EntityMeta(createdAt: _fixed, updatedAt: _fixed, updatedBy: 'tester'),
);

void main() {
  group('the four formats (§11.216.1)', () {
    test('AN OPAQUE PNG IS STORED VERBATIM, its own size', () async {
      final bytes = _png(300, 120);
      final logo = await _ok(bytes);
      expect(logo.memberBytes, bytes);
      expect(logo.logo.format, PlanImageFormat.png);
      expect((logo.logo.pixelWidth, logo.logo.pixelHeight), (300, 120));
      expect(logo.logo.imageMember, 'logos/logo-1.png');
      expect(logo.logo.contentHash, startsWith('sha256:'));
    });

    test('A PNG WITH ALPHA IS FLATTENED OVER WHITE, and stores no alpha', () {
      return _ok(_png(20, 10, alpha: true)).then((logo) {
        final stored = img.decodePng(logo.memberBytes)!;
        expect(stored.hasAlpha, isFalse);
        // An odd column was transparent: it is paper now.
        final px = stored.getPixel(1, 0);
        expect((px.r, px.g, px.b), (255, 255, 255));
      });
    });

    test('A JPEG IS STORED VERBATIM', () async {
      final bytes = realJpeg(240, 90);
      final logo = await _ok(bytes);
      expect(logo.memberBytes, bytes);
      expect(logo.logo.format, PlanImageFormat.jpeg);
      expect(logo.logo.imageMember, 'logos/logo-1.jpg');
    });

    test('A PDF IS RENDERED BY PDFIUM to fit 834 x 375, aspect kept', () async {
      // A 144 x 72 pt page, 2 : 1, narrower than the box's 100 : 45, so it
      // is height-bound.
      final logo = await _ok(smallVectorPdf());
      expect((logo.logo.pixelWidth, logo.logo.pixelHeight), (750, 375));
      expect(logo.logo.format, PlanImageFormat.png);
      expect(img.decodePng(logo.memberBytes)!.width, 750);
    }, skip: noMacOSPdfium);

    test(
      'AN SVG IS DRAWN, then rendered like a PDF, and the ink is there',
      () async {
        // 4 : 1, wider than the box, so it is width-bound.
        final logo = await _ok(_svg(_rect));
        expect((logo.logo.pixelWidth, logo.logo.pixelHeight), (834, 209));
        final stored = img.decodePng(logo.memberBytes)!;
        final centre = stored.getPixel(417, 104);
        // The rectangle's navy, not the paper: the SVG really was drawn.
        expect(centre.b, greaterThan(centre.r));
        expect(centre.r, lessThan(100));
      },
      skip: noMacOSPdfium,
    );

    test(
      'an SVG with only width and height takes its aspect from them',
      () async {
        final logo = await _ok(
          _svg(
            '<rect width="100" height="100" fill="black"/>',
            root: 'width="100" height="100"',
          ),
        );
        expect((logo.logo.pixelWidth, logo.logo.pixelHeight), (375, 375));
      },
      skip: noMacOSPdfium,
    );

    test('ANYTHING ELSE IS REFUSED BY NAME', () async {
      final error = await _refused(
        Uint8List.fromList(utf8.encode('just some text')),
      );
      expect(error, isA<LogoFormatError>());
      expect('$error', 'A logo must be a PNG, JPEG, PDF or SVG file.');
    });
  });

  group('WHAT AN SVG OWES BEFORE ANYTHING DRAWS IT', () {
    test('over 4 MB is refused before it is parsed', () async {
      final big = Uint8List(kMaxLogoSvgBytes + 1)
        ..setAll(0, utf8.encode('<svg>'));
      expect(await _refused(big), isA<LogoSvgTooLargeError>());
    });

    test('an <!ENTITY declaration is refused outright', () async {
      final bomb = Uint8List.fromList(
        utf8.encode(
          '<?xml version="1.0"?><!DOCTYPE svg [<!ENTITY a "aaaa">]> '
          '<svg xmlns="http://www.w3.org/2000/svg">&a;</svg>',
        ),
      );
      final error = await _refused(bomb);
      expect(error, isA<LogoSvgRefusedError>());
      expect('$error', contains('entities'));
    });

    test(
      'an embedded image over the caps is refused before pdf decodes it',
      () async {
        // A PNG HEADER declaring 100000 x 100000: past the pixel cap, and a
        // decode would ask for forty gigabytes.
        final header = BytesBuilder()
          ..add([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
          ..add([0, 0, 0, 13])
          ..add(ascii.encode('IHDR'))
          ..add([0, 1, 0x86, 0xA0, 0, 1, 0x86, 0xA0, 8, 2, 0, 0, 0])
          ..add([0, 0, 0, 0]);
        final href = 'data:image/png;base64,${base64.encode(header.toBytes())}';
        final error = await _refused(
          _svg('<image width="10" height="10" href="$href"/>'),
        );
        expect(error, isA<LogoSvgRefusedError>());
        expect('$error', contains('embedded image'));
      },
    );

    // RGB AND JPEG BOTH, because `pdf` treats every decoded buffer as
    // four channels and threw a RangeError on either before the import
    // re-encoded them as RGBA.
    for (final (kind, bytes, mime) in [
      ('an RGB PNG', _png(40, 10), 'image/png'),
      ('a JPEG', realJpeg(40, 10), 'image/jpeg'),
    ]) {
      test(
        '$kind embedded in the SVG is drawn, and its ink is there',
        () async {
          final href = 'data:$mime;base64,${base64.encode(bytes)}';
          final logo = await _ok(
            _svg('<image width="400" height="100" href="$href"/>'),
          );
          expect(logo.logo.pixelWidth, 834);
          final centre = img.decodePng(logo.memberBytes)!.getPixel(417, 104);
          expect((centre.r, centre.g, centre.b), isNot((255, 255, 255)));
        },
        skip: noMacOSPdfium,
      );
    }

    test('a root that is not <svg> is refused', () async {
      final error = await _refused(
        Uint8List.fromList(utf8.encode('<html><svg></svg></html>')),
      );
      expect('$error', contains('root element'));
    });
  });

  group('LogoIo: the member, then the command', () {
    ({DocumentSession session, LogoIo io, FakeFilePicker picker}) harness(
      Map<String, Uint8List> files, {
      String? picked = r'C:\logos\firm.png',
    }) {
      final session = DocumentSession(
        controller: DocumentController(
          _doc(),
          clock: FixedClock(_fixed),
          actor: 'tester',
        ),
        context: p.Context(style: p.Style.windows),
      );
      final picker = FakeFilePicker(openPaths: [picked]);
      return (
        session: session,
        picker: picker,
        io: LogoIo(
          session: session,
          picker: picker,
          fs: FakeFileStore(initialFiles: files),
        ),
      );
    }

    test('a chosen file becomes the logo AND the member it names', () async {
      final bytes = _png(300, 120);
      final h = harness({r'C:\logos\firm.png': bytes});
      final result = await h.io.choose();

      final logo = (result! as Ok<ProjectLogo>).value;
      expect(h.picker.dialogTypes, [FileDialogType.logo]);
      expect(h.session.document.info.logo, logo);
      expect(h.session.members[logo.imageMember], bytes);
    });

    test(
      'UNDO REMOVES THE LOGO AND LEAVES THE BYTES, so redo finds them',
      () async {
        final h = harness({r'C:\logos\firm.png': _png(300, 120)});
        final logo = ((await h.io.choose())! as Ok<ProjectLogo>).value;
        final controller = h.session.controller;
        controller.undo.undo(controller.doc);
        expect(h.session.document.info.logo, isNull);
        expect(h.session.members.containsKey(logo.imageMember), isTrue);
      },
    );

    test('a cancel is null and writes nothing', () async {
      final h = harness(const {}, picked: null);
      expect(await h.io.choose(), isNull);
      expect(h.session.document.info.logo, isNull);
      expect(h.session.members, isEmpty);
    });

    test('a refusal writes nothing', () async {
      final h = harness({
        r'C:\logos\firm.png': Uint8List.fromList(utf8.encode('not a logo')),
      });
      expect(await h.io.choose(), isA<Err<ProjectLogo>>());
      expect(h.session.document.info.logo, isNull);
      expect(h.session.members, isEmpty);
    });
  });

  test('fitPixels keeps the aspect and never returns zero', () {
    // 833, NOT 834: the box at 600 dpi is 833.3 px, and 834 is its ceiling.
    expect(fitPixels(100, 45, maxWidth: 834, maxHeight: 375), (833, 375));
    expect(fitPixels(400, 100, maxWidth: 834, maxHeight: 375), (834, 209));
    expect(fitPixels(1, 1000, maxWidth: 834, maxHeight: 375), (1, 375));
    expect(fitPixels(100000, 1, maxWidth: 834, maxHeight: 375), (834, 1));
  });
}
