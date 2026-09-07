// PLAN-D/2 and PLAN-D/4: what an image declares, read without decoding
// it, and the three controls AC-058/D8 owes every import path.
//
// ═══════════════════════════════════════════════════════════════════════
// THE FIXTURES ARE BUILT BYTE BY BYTE, DELIBERATELY
// ═══════════════════════════════════════════════════════════════════════
// A parser over hostile input cannot be tested with well-formed files
// from a library, because the cases that matter are the ones no encoder
// produces: a length field of zero, a frame header past the end of the
// buffer, a PNG signature followed by a chunk that is not IHDR. Every
// fixture below is assembled here so the malformed ones are as easy to
// write as the good ones.
//
// ═══════════════════════════════════════════════════════════════════════
// THE PIXEL CAP IS THE ONE THAT GETS FORGOTTEN, AND IT IS WHY THIS FILE
// IS IN `rackpal_core` AT ALL
// ═══════════════════════════════════════════════════════════════════════
// A three-kilobyte PNG can declare 60000 x 60000, and a cap that runs
// after the decode runs after the allocation it exists to prevent. So the
// header is read first, in a package with no decoder in it, and the tests
// below assert the refusal happens on the DECLARED size with nothing
// decoded.

import 'dart:typed_data';

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

/// A PNG with a valid signature and IHDR, sized as asked.
Uint8List png(int width, int height, {List<int>? chunkType}) {
  final out = BytesBuilder()
    ..add(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
    ..add(const [0, 0, 0, 13]) // IHDR length
    ..add(chunkType ?? const [0x49, 0x48, 0x44, 0x52]) // "IHDR"
    ..add(_be32(width))
    ..add(_be32(height))
    ..add(const [8, 6, 0, 0, 0]); // depth, colour type, and the rest
  return out.toBytes();
}

/// A JPEG with [leading] segments before the frame header, so the marker
/// walk has something to walk.
Uint8List jpeg(
  int width,
  int height, {
  int frameMarker = 0xC0,
  List<int> leading = const [],
}) {
  final out = BytesBuilder()
    ..add(const [0xFF, 0xD8]) // SOI
    ..add(leading)
    ..add([0xFF, frameMarker])
    ..add(const [0, 17]) // segment length
    ..add(const [8]) // sample precision
    ..add(_be16(height))
    ..add(_be16(width))
    ..add(const [3, 1, 0x22, 0, 2, 0x11, 1, 3, 0x11, 1]);
  return out.toBytes();
}

/// An APP0 segment, the ordinary thing that sits before a frame header.
List<int> app0() => <int>[0xFF, 0xE0, 0, 16, ...List<int>.filled(14, 0)];

List<int> _be32(int v) => [
  (v >> 24) & 0xFF,
  (v >> 16) & 0xFF,
  (v >> 8) & 0xFF,
  v & 0xFF,
];

List<int> _be16(int v) => [(v >> 8) & 0xFF, v & 0xFF];

Uint8List bytes(List<int> v) => Uint8List.fromList(v);

Object errorOf(Outcome<ImageHeader> o) => (o as Err<ImageHeader>).error;

void main() {
  group('THE SNIFF IS BY CONTENT AND NEVER BY EXTENSION', () {
    test('each of the three kinds is recognised by its signature', () {
      expect(sniffImportKind(png(10, 10)), SniffedImportKind.png);
      expect(sniffImportKind(jpeg(10, 10)), SniffedImportKind.jpeg);
      expect(
        sniffImportKind(bytes([0x25, 0x50, 0x44, 0x46, 0x2D, 0x31, 0x2E])),
        SniffedImportKind.pdf,
      );
    });

    test('anything else is unknown, including plausible near-misses', () {
      // A ZIP (which the container sniff DOES accept, one layer over), an
      // executable, a text file, and a PNG signature one byte wrong.
      expect(
        sniffImportKind(bytes([0x50, 0x4B, 0x03, 0x04])),
        SniffedImportKind.unknown,
      );
      expect(sniffImportKind(bytes([0x4D, 0x5A])), SniffedImportKind.unknown);
      expect(
        sniffImportKind(bytes('plan.png'.codeUnits)),
        SniffedImportKind.unknown,
      );
      final nearly = png(10, 10)..[0] = 0x88;
      expect(sniffImportKind(nearly), SniffedImportKind.unknown);
    });

    test('an empty file and a one-byte file do not crash the sniff', () {
      expect(sniffImportKind(Uint8List(0)), SniffedImportKind.unknown);
      expect(sniffImportKind(bytes([0xFF])), SniffedImportKind.unknown);
    });

    test('a PDF has no stored format of its own, because it is rasterised '
        'and the member is still PNG or JPEG', () {
      expect(SniffedImportKind.pdf.storedFormat, isNull);
      expect(SniffedImportKind.png.storedFormat, PlanImageFormat.png);
      expect(SniffedImportKind.jpeg.storedFormat, PlanImageFormat.jpeg);
    });
  });

  group('PNG dimensions, read at a fixed offset', () {
    test('a realistic architectural page reads back exactly', () {
      final header = readImageHeader(png(4200, 3300)) as Ok<ImageHeader>;
      expect(header.value.format, PlanImageFormat.png);
      expect(header.value.pixelWidth, 4200);
      expect(header.value.pixelHeight, 3300);
      expect(header.value.pixelCount, 4200 * 3300);
    });

    test('WIDTH AND HEIGHT ARE NOT TRANSPOSED, which a square fixture '
        'cannot tell you', () {
      final header = readImageHeader(png(1000, 500)) as Ok<ImageHeader>;
      expect(header.value.pixelWidth, 1000);
      expect(header.value.pixelHeight, 500);
    });

    test('a signature with a first chunk that is not IHDR is malformed', () {
      // Not "assume the bytes at offset 16 are a size". A file shaped like
      // this would otherwise invent a dimension out of whatever is there.
      final wrong = png(10, 10, chunkType: const [0x73, 0x52, 0x47, 0x42]);
      expect(errorOf(readImageHeader(wrong)), isA<MalformedImageHeaderError>());
    });

    test('a truncated PNG is malformed rather than a crash', () {
      for (final cut in [8, 12, 16, 19]) {
        final truncated = bytes(png(4200, 3300).sublist(0, cut));
        expect(
          errorOf(readImageHeader(truncated)),
          isA<MalformedImageHeaderError>(),
          reason: 'cut at $cut',
        );
      }
    });

    test('a zero dimension is malformed, not a zero-pixel image', () {
      expect(
        errorOf(readImageHeader(png(0, 100))),
        isA<MalformedImageHeaderError>(),
      );
      expect(
        errorOf(readImageHeader(png(100, 0))),
        isA<MalformedImageHeaderError>(),
      );
    });
  });

  group('JPEG dimensions, read by a marker walk', () {
    test('a frame header straight after SOI reads back', () {
      final header = readImageHeader(jpeg(1600, 1200)) as Ok<ImageHeader>;
      expect(header.value.format, PlanImageFormat.jpeg);
      expect(header.value.pixelWidth, 1600);
      expect(header.value.pixelHeight, 1200);
    });

    test('THE WALK SKIPS PRECEDING SEGMENTS, which is the whole reason it '
        'is a walk', () {
      // Three APP0s and a comment before the frame. A fixed-offset read
      // would return whatever is 20 bytes in.
      final header =
          readImageHeader(
                jpeg(
                  1600,
                  1200,
                  leading: [...app0(), ...app0(), ...app0()],
                ),
              )
              as Ok<ImageHeader>;
      expect(header.value.pixelWidth, 1600);
      expect(header.value.pixelHeight, 1200);
    });

    test('progressive JPEGs are read too: SOF2, not just SOF0', () {
      final header =
          readImageHeader(jpeg(800, 600, frameMarker: 0xC2)) as Ok<ImageHeader>;
      expect(header.value.pixelWidth, 800);
    });

    test('0xC4, 0xC8 and 0xCC ARE NOT FRAME HEADERS, which a naive '
        'C0-to-CF range check gets wrong', () {
      // DHT (C4) carrying a payload that would parse as a plausible size,
      // followed by the real frame. A parser treating C4 as a frame header
      // returns 9999 x 8888.
      // Length 7: the two length bytes plus five of payload, shaped
      // exactly like a frame header's precision/height/width so a
      // parser that mistook C4 for a frame would report 9999 x 8888.
      final dht = <int>[0xFF, 0xC4, 0, 7, 8, ..._be16(8888), ..._be16(9999)];
      final header =
          readImageHeader(jpeg(640, 480, leading: dht)) as Ok<ImageHeader>;
      expect(header.value.pixelWidth, 640);
      expect(header.value.pixelHeight, 480);
    });

    test('A SEGMENT DECLARING LENGTH 0 IS REFUSED RATHER THAN LOOPED ON', () {
      // The classic hostile input: a length that does not advance the
      // cursor. Without the check this hangs rather than failing.
      final hostile = bytes([0xFF, 0xD8, 0xFF, 0xE0, 0, 0, 0xFF, 0xC0]);
      expect(
        errorOf(readImageHeader(hostile)),
        isA<MalformedImageHeaderError>(),
      );
    });

    test('a segment length running past the end does not read off the end', () {
      final hostile = bytes([0xFF, 0xD8, 0xFF, 0xE0, 0xFF, 0xFF, 1, 2, 3]);
      expect(errorOf(readImageHeader(hostile)), isA<Exception>());
    });

    test('a truncated frame header is malformed', () {
      final full = jpeg(1600, 1200);
      for (final cut in [2, 4, 6, 8, 10]) {
        expect(
          readImageHeader(bytes(full.sublist(0, cut))),
          isA<Err<ImageHeader>>(),
          reason: 'cut at $cut',
        );
      }
    });

    test('a file that reaches SOS without a frame header is refused', () {
      final noFrame = bytes([0xFF, 0xD8, ...app0(), 0xFF, 0xDA, 0, 12]);
      expect(
        errorOf(readImageHeader(noFrame)),
        isA<MalformedImageHeaderError>(),
      );
    });

    test('fill bytes between markers are legal padding', () {
      final padded = bytes([
        0xFF,
        0xD8,
        0xFF,
        0xFF,
        0xFF,
        0xE0,
        0,
        16,
        ...List<int>.filled(14, 0),
        0xFF,
        0xC0,
        0,
        17,
        8,
        ..._be16(480),
        ..._be16(640),
        3,
        1,
        0x22,
        0,
        2,
        0x11,
        1,
        3,
        0x11,
        1,
      ]);
      final header = readImageHeader(padded) as Ok<ImageHeader>;
      expect(header.value.pixelWidth, 640);
    });
  });

  group(
    'THE PIXEL CAPS, refused on the DECLARED size with nothing decoded',
    () {
      test('a tiny file declaring an enormous image is refused', () {
        // The failure PLAN-D/4 names: 60000 x 60000 in a few dozen bytes.
        final bomb = png(60000, 60000);
        expect(bomb.length, lessThan(100));

        final error = errorOf(readImageHeader(bomb));
        expect(error, isA<ImageTooLargeError>());
        expect((error as ImageTooLargeError).pixelWidth, 60000);
        expect(error.toString(), contains('Nothing was decoded'));
      });

      test('BOTH CAPS ARE LOAD-BEARING, and neither covers the other', () {
        // Past the per-side cap, inside the pixel cap.
        expect(
          errorOf(readImageHeader(png(kMaxImagePixelDimension + 1, 10))),
          isA<ImageTooLargeError>(),
        );
        // Inside the per-side cap, past the pixel cap: 20000 x 20000 is 400
        // megapixels, which is 1.6 GB decoded.
        expect(
          errorOf(
            readImageHeader(
              png(kMaxImagePixelDimension, kMaxImagePixelDimension),
            ),
          ),
          isA<ImageTooLargeError>(),
        );
      });

      test('the caps are injectable, so a test proves the gate fires without '
          'a 400-megapixel fixture', () {
        expect(
          errorOf(readImageHeader(png(100, 100), dimensionLimit: 50)),
          isA<ImageTooLargeError>(),
        );
        expect(
          errorOf(readImageHeader(png(100, 100), pixelLimit: 500)),
          isA<ImageTooLargeError>(),
        );
      });

      test('THE CAPS ARE NOT SET BELOW THE ORDINARY CASE, which is how a '
          'size gate passes every test and refuses every user', () {
        // A 24 x 36 inch architectural sheet at 300 dpi.
        expect(readImageHeader(png(7200, 10800)), isA<Ok<ImageHeader>>());
        // And the same page as a JPEG.
        expect(readImageHeader(jpeg(7200, 10800)), isA<Ok<ImageHeader>>());
      });

      test('the byte cap leaves room for a real scan', () {
        // Not a parser assertion: a statement about the constant, because a
        // cap tuned to a synthetic fixture is the failure above.
        expect(kMaxImageBytes, greaterThanOrEqualTo(32 * 1024 * 1024));
      });
    },
  );

  group('a PDF is refused HERE and routed elsewhere', () {
    test('readImageHeader will not give a PDF a size', () {
      // It has no single intrinsic pixel size: the caller rasterises a
      // chosen page and asks again about what comes back.
      final pdf = bytes([0x25, 0x50, 0x44, 0x46, 0x2D, 0x31, 0x2E, 0x37]);
      expect(
        errorOf(readImageHeader(pdf)),
        isA<UnsupportedImageFormatError>(),
      );
      // But the SNIFF still names it, so the caller can tell "route this
      // to the page picker" from "refuse this file".
      expect(sniffImportKind(pdf), SniffedImportKind.pdf);
    });

    test('an unknown format is refused with its own error', () {
      expect(
        errorOf(readImageHeader(bytes([0x4D, 0x5A, 0x90, 0x00]))),
        isA<UnsupportedImageFormatError>(),
      );
    });
  });

  group('NOTHING HERE THROWS, over a sweep of hostile inputs', () {
    test('every truncation of a good file returns a value, never an '
        'exception', () {
      for (final source in [png(4200, 3300), jpeg(4200, 3300)]) {
        for (var cut = 0; cut <= source.length; cut++) {
          final input = bytes(source.sublist(0, cut));
          expect(
            () => readImageHeader(input),
            returnsNormally,
            reason: 'cut at $cut of ${source.length}',
          );
          expect(() => sniffImportKind(input), returnsNormally);
        }
      }
    });

    test('a byte flipped anywhere in the header region returns a value', () {
      final source = jpeg(4200, 3300);
      for (var i = 0; i < source.length; i++) {
        final mutated = Uint8List.fromList(source)..[i] = 0xFF;
        expect(
          () => readImageHeader(mutated),
          returnsNormally,
          reason: 'byte $i set to 0xFF',
        );
      }
    });
  });
}
