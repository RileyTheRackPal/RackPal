// rackpal_core/src/persistence/image_header.dart — what an image SAYS it
// is, read without decoding it (PLAN-D/2 and PLAN-D/4, AC-058/D8).
//
// ═══════════════════════════════════════════════════════════════════════
// A HEADER PARSER IS NOT A DECODER, AND THE DISTINCTION IS THE WHOLE
// REASON THIS FILE IS IN CORE
// ═══════════════════════════════════════════════════════════════════════
// `rackpal_core` is decoder-free by design (docs/15 §3.1) and Flutter-free
// by gate. Nothing here decompresses a pixel, allocates anything
// proportional to the image, or touches `dart:ui`: it reads a signature
// and two integers out of a header that is a fixed shape in PNG and a
// short marker walk in JPEG.
//
// `PLAN-D/2` said the decode happens in the app layer and only the
// dimensions cross the boundary, and that is still true of the DECODE.
// What could not stay in the app layer is the CHECK, and `PLAN-D/4` is
// why: its third control is a pixel-dimension cap, and it names the
// failure that cap exists for. **A three-kilobyte PNG can declare
// 60000 x 60000 and the decoder allocates before anything has a chance to
// object.** A cap that runs after the decode is a cap that runs after the
// allocation it was written to prevent, which is `checkImportSize`'s own
// argument one format over: *"a cap that only fires after the allocation
// it was meant to prevent is decoration."*
//
// So the order is: sniff, read the declared size, refuse or accept, and
// only then hand the bytes to a decoder that now has a bound on what it
// is about to build.
//
// ═══════════════════════════════════════════════════════════════════════
// EVERY FUNCTION HERE READS HOSTILE BYTES AND NONE OF THEM THROWS
// ═══════════════════════════════════════════════════════════════════════
// AC-058/D8's rule, and CR-093's contract for the persistence layer. A
// truncated file, a lying length, a marker walk that runs off the end: all
// of them are `Err`, none of them is an exception and none of them is an
// out-of-range read. Every index is bounds-checked before it is used
// rather than after, because "after" is a `RangeError` escaping into an
// `unawaited` future in the shell, which reaches the user as the menu item
// doing nothing at all.
//
// ═══════════════════════════════════════════════════════════════════════
// THE CITATION HERE READ `AC-058/D12` UNTIL 2026-09-07, AND D12 IS
// LOCALISATION
// ═══════════════════════════════════════════════════════════════════════
// The import-hardening item is **D8**: *"zip-slip protection, entry-count
// and uncompressed-size limits, and JSON depth/size limits on every import
// path."* D12 is the DSL, the CSV synonym table and registry display names
// being structurally English-only, which this file has nothing to do with.
//
// **THE WRONG ID WAS NOT INVENTED HERE.** It came from docs/09's Plan view
// import row, written 2026-08-10 in `f423aa3`, and was copied into two
// source files and two derived documents without anybody reading the row it
// pointed at. A wrong ruling ID is worse than a missing one for exactly
// that reason: it resolves. Every check that verifies an ID EXISTS passes,
// and the authority of a real ruling is lent to a claim it does not make.
// The cheap post-condition is to grep the ID in canon and read the row,
// which is the same move `a stated cost is a hypothesis` prescribes for a
// number.
import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:rackpal_core/src/model/plan.dart';
import 'package:rackpal_core/src/util/outcome.dart';

/// The largest an underlay's source file may be, before decoding.
///
/// Generous on purpose: an architectural page scanned at 300 dpi is
/// routinely 10 to 20 MB, and a cap that refuses the ordinary case is a
/// cap somebody removes. It sits well under `kMaxContainerInflatedBytes`
/// so a container holding several is still inside the container's own
/// bound.
const int kMaxImageBytes = 64 * 1024 * 1024;

/// The largest either dimension of an underlay may be, in pixels.
///
/// **THIS IS THE ONE THAT GETS FORGOTTEN** (`PLAN-D/4`). Bytes and pixels
/// are independent: a compressed image declaring 60000 x 60000 costs
/// almost nothing on disk and 10.8 GB decoded. 20000 is roughly a 60-inch
/// architectural sheet at 300 dpi, which is past anything a residential
/// job produces.
const int kMaxImagePixelDimension = 20000;

/// The largest total pixel count, which is the number the allocation
/// actually follows.
///
/// NOT REDUNDANT WITH [kMaxImagePixelDimension], and the pair is the
/// point: 20000 x 20000 passes the per-side cap and is 400 megapixels,
/// which at four bytes each is 1.6 GB. Either cap alone leaves a hole the
/// other closes.
const int kMaxImagePixels = 120 * 1000 * 1000;

/// What an image file declares about itself.
@immutable
final class ImageHeader {
  const ImageHeader({
    required this.format,
    required this.pixelWidth,
    required this.pixelHeight,
  });

  final PlanImageFormat format;
  final int pixelWidth;
  final int pixelHeight;

  /// Total pixels. `int` is 64-bit here, so this cannot overflow at any
  /// size the caps admit.
  int get pixelCount => pixelWidth * pixelHeight;

  @override
  bool operator ==(Object other) =>
      other is ImageHeader &&
      other.format == format &&
      other.pixelWidth == pixelWidth &&
      other.pixelHeight == pixelHeight;

  @override
  int get hashCode => Object.hash(format, pixelWidth, pixelHeight);

  @override
  String toString() =>
      'ImageHeader(${format.name}, ${pixelWidth}x$pixelHeight)';
}

/// What the bytes look like, by CONTENT and never by extension.
///
/// **BY SNIFF, NOT BY EXTENSION** (`PLAN-D/4`, M4-M4's rule). A file
/// picker returns whatever the user chose and a name is not evidence:
/// `plan.png` that is really a PDF, or an executable, is the ordinary
/// shape of both an accident and an attack.
enum SniffedImportKind {
  png,
  jpeg,

  /// A PDF. Not an underlay on its own: it is rasterised at import and
  /// the member written to the container is still PNG or JPEG (DR-029
  /// §11.28.12), so this is the kind that routes to the page picker.
  pdf,

  /// None of the above. Refused.
  unknown;

  /// The stored format this kind becomes, or null for a PDF (which
  /// becomes whichever the rasteriser emits) and for [unknown].
  PlanImageFormat? get storedFormat => switch (this) {
    SniffedImportKind.png => PlanImageFormat.png,
    SniffedImportKind.jpeg => PlanImageFormat.jpeg,
    SniffedImportKind.pdf => null,
    SniffedImportKind.unknown => null,
  };
}

const List<int> _pngSignature = <int>[
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
];
const List<int> _pdfSignature = <int>[0x25, 0x50, 0x44, 0x46, 0x2D]; // %PDF-

bool _startsWith(Uint8List bytes, List<int> prefix) {
  if (bytes.length < prefix.length) return false;
  for (var i = 0; i < prefix.length; i++) {
    if (bytes[i] != prefix[i]) return false;
  }
  return true;
}

/// Classifies [bytes] by their leading signature.
SniffedImportKind sniffImportKind(Uint8List bytes) {
  if (_startsWith(bytes, _pngSignature)) return SniffedImportKind.png;
  if (_startsWith(bytes, _pdfSignature)) return SniffedImportKind.pdf;
  // JPEG: SOI. Deliberately NOT also requiring an APP0/APP1 marker after
  // it: cameras, scanners and every architectural export disagree about
  // what comes next, and a stricter sniff here refuses real files while
  // adding nothing, since the marker walk below is what actually has to
  // survive the content.
  if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xD8) {
    return SniffedImportKind.jpeg;
  }
  return SniffedImportKind.unknown;
}

/// The file is not one of the three kinds this product imports.
final class UnsupportedImageFormatError implements Exception {
  const UnsupportedImageFormatError();

  @override
  String toString() =>
      'UnsupportedImageFormatError: the file is not a PNG, a JPEG or a '
      'PDF. Classified by CONTENT rather than by its name.';
}

/// The signature matched and the header did not parse.
final class MalformedImageHeaderError implements Exception {
  const MalformedImageHeaderError(this.detail);

  final String detail;

  @override
  String toString() => 'MalformedImageHeaderError: $detail';
}

/// The image DECLARES a size past [kMaxImagePixelDimension] or
/// [kMaxImagePixels].
///
/// Its own error, carrying what was declared, because the sentence a
/// person needs is about the picture's size and not the file's:
/// `ContainerTooLargeError`'s doc comment makes the same distinction one
/// format over, for the same reason.
final class ImageTooLargeError implements Exception {
  const ImageTooLargeError({
    required this.pixelWidth,
    required this.pixelHeight,
    required this.dimensionLimit,
    required this.pixelLimit,
  });

  final int pixelWidth;
  final int pixelHeight;
  final int dimensionLimit;
  final int pixelLimit;

  @override
  String toString() =>
      'ImageTooLargeError: the file declares ${pixelWidth}x$pixelHeight '
      '(${pixelWidth * pixelHeight} pixels), against limits of '
      '$dimensionLimit per side and $pixelLimit total. Nothing was '
      'decoded.';
}

/// Reads [bytes]'s declared format and dimensions, refusing anything past
/// the caps, WITHOUT decoding a pixel.
///
/// Never throws (CR-093). A PDF is [UnsupportedImageFormatError] here on
/// purpose: it has no single intrinsic pixel size, and the caller routes
/// it to the rasteriser and calls this again on what comes back.
Outcome<ImageHeader> readImageHeader(
  Uint8List bytes, {
  int dimensionLimit = kMaxImagePixelDimension,
  int pixelLimit = kMaxImagePixels,
}) {
  final Outcome<ImageHeader> parsed;
  switch (sniffImportKind(bytes)) {
    case SniffedImportKind.png:
      parsed = _readPngHeader(bytes);
    case SniffedImportKind.jpeg:
      parsed = _readJpegHeader(bytes);
    case SniffedImportKind.pdf:
    case SniffedImportKind.unknown:
      return const Err(UnsupportedImageFormatError());
  }

  if (parsed case Err(:final error)) return Err(error);
  final header = (parsed as Ok<ImageHeader>).value;

  if (header.pixelWidth <= 0 || header.pixelHeight <= 0) {
    return const Err(
      MalformedImageHeaderError('a dimension is zero or negative'),
    );
  }
  if (header.pixelWidth > dimensionLimit ||
      header.pixelHeight > dimensionLimit ||
      header.pixelCount > pixelLimit) {
    return Err(
      ImageTooLargeError(
        pixelWidth: header.pixelWidth,
        pixelHeight: header.pixelHeight,
        dimensionLimit: dimensionLimit,
        pixelLimit: pixelLimit,
      ),
    );
  }
  return Ok(header);
}

/// PNG: the IHDR chunk is the FIRST chunk and its position is fixed by
/// the specification, so this is an offset read rather than a walk.
///
/// Layout: 8 signature, 4 length, 4 type (`IHDR`), then width and height
/// as big-endian uint32.
Outcome<ImageHeader> _readPngHeader(Uint8List bytes) {
  const ihdrTypeOffset = 12;
  const widthOffset = 16;
  const need = widthOffset + 8;
  if (bytes.length < need) {
    return const Err(
      MalformedImageHeaderError('truncated before the PNG IHDR chunk'),
    );
  }
  // The type is checked rather than assumed: a file with the PNG
  // signature and something else first is malformed, and treating
  // whatever bytes are at offset 16 as a size would invent a dimension.
  if (bytes[ihdrTypeOffset] != 0x49 || // I
      bytes[ihdrTypeOffset + 1] != 0x48 || // H
      bytes[ihdrTypeOffset + 2] != 0x44 || // D
      bytes[ihdrTypeOffset + 3] != 0x52) {
    return const Err(
      MalformedImageHeaderError('the first PNG chunk is not IHDR'),
    );
  }
  return Ok(
    ImageHeader(
      format: PlanImageFormat.png,
      pixelWidth: _uint32(bytes, widthOffset),
      pixelHeight: _uint32(bytes, widthOffset + 4),
    ),
  );
}

/// JPEG: a marker walk, because the frame header's position depends on
/// how many APPn, DQT and COM segments precede it.
///
/// ═══════════════════════════════════════════════════════════════════════
/// EVERY STEP IS BOUNDS-CHECKED BEFORE IT READS, NOT AFTER
/// ═══════════════════════════════════════════════════════════════════════
/// This walks a length field supplied by the file, which is the classic
/// way a parser is made to read off the end of a buffer. A declared
/// length of 0 or 1 would also make the cursor stand still, so the walk
/// refuses those rather than looping forever on a hostile file.
Outcome<ImageHeader> _readJpegHeader(Uint8List bytes) {
  var i = 2; // past SOI
  while (i + 1 < bytes.length) {
    if (bytes[i] != 0xFF) {
      // Fill bytes are legal between segments; anything else is not a
      // marker boundary and the file is malformed rather than merely
      // padded.
      i++;
      continue;
    }
    // A run of 0xFF is legal padding before a marker.
    var marker = bytes[i + 1];
    var markerAt = i + 1;
    while (marker == 0xFF && markerAt + 1 < bytes.length) {
      markerAt++;
      marker = bytes[markerAt];
    }

    // Standalone markers carry no length payload.
    if (marker == 0x01 || (marker >= 0xD0 && marker <= 0xD9)) {
      i = markerAt + 1;
      continue;
    }

    if (markerAt + 2 >= bytes.length) {
      return const Err(
        MalformedImageHeaderError('truncated inside a JPEG marker'),
      );
    }
    final length = (bytes[markerAt + 1] << 8) | bytes[markerAt + 2];
    if (length < 2) {
      return const Err(
        MalformedImageHeaderError('a JPEG segment declares a length below 2'),
      );
    }

    // The Start Of Frame markers, which are the ones carrying the size.
    // C4 (DHT), C8 (JPG) and CC (DAC) sit inside this range and are NOT
    // frame headers, which is the detail a naive `>= 0xC0 && <= 0xCF`
    // check gets wrong.
    final isFrameHeader =
        (marker >= 0xC0 && marker <= 0xC3) ||
        (marker >= 0xC5 && marker <= 0xC7) ||
        (marker >= 0xC9 && marker <= 0xCB) ||
        (marker >= 0xCD && marker <= 0xCF);

    if (isFrameHeader) {
      // Payload: precision (1), height (2), width (2).
      final payload = markerAt + 3;
      if (payload + 5 > bytes.length) {
        return const Err(
          MalformedImageHeaderError('truncated inside the JPEG frame header'),
        );
      }
      return Ok(
        ImageHeader(
          format: PlanImageFormat.jpeg,
          pixelHeight: (bytes[payload + 1] << 8) | bytes[payload + 2],
          pixelWidth: (bytes[payload + 3] << 8) | bytes[payload + 4],
        ),
      );
    }

    // Start Of Scan: the entropy-coded data begins and there is no frame
    // header after it. A file reaching here declared no size.
    if (marker == 0xDA) break;

    i = markerAt + 1 + length;
  }
  return const Err(
    MalformedImageHeaderError('no JPEG frame header found'),
  );
}

int _uint32(Uint8List b, int at) =>
    (b[at] << 24) | (b[at + 1] << 16) | (b[at + 2] << 8) | b[at + 3];
