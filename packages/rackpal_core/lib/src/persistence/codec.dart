// The persistence-layer seam (docs/03-architecture.md §9.1, CR-091):
// `RackDocument` <-> on-disk bytes, kept abstract so a v2 zip container
// (if one ever ships) costs nothing to add without touching call sites.
// `JsonDocumentCodec` (json_codec.dart) is the only implementation in M0.
import 'dart:typed_data';

import 'package:rackpal_core/src/model/rack_document.dart';
import 'package:rackpal_core/src/util/outcome.dart';

/// The first four bytes of every ZIP local-file-header record — the
/// standard `PK\x03\x04` magic number. `.rppj` is plain JSON in v1
/// (CR-091), but [DocumentCodec.read] sniffs for this prefix up front so
/// a zip file (a future v2 container, or simply the wrong file) comes
/// back as a clear, typed [Err] instead of a `FormatException` thrown
/// from a JSON parser that was never going to succeed.
const List<int> kZipMagicBytes = <int>[0x50, 0x4B, 0x03, 0x04];

/// True when [bytes] begins with [kZipMagicBytes].
bool looksLikeZip(List<int> bytes) {
  if (bytes.length < kZipMagicBytes.length) return false;
  for (var i = 0; i < kZipMagicBytes.length; i++) {
    if (bytes[i] != kZipMagicBytes[i]) return false;
  }
  return true;
}

/// [DocumentCodec.read] refuses a file that sniffs as a zip container —
/// this build only understands the plain-JSON `.rppj` shape.
final class UnsupportedZipContainerError implements Exception {
  const UnsupportedZipContainerError();

  @override
  String toString() =>
      'UnsupportedZipContainerError: this file begins with the ZIP magic '
      r'number (PK\x03\x04). A zip-based project container may arrive '
      "in a later milestone; this build's DocumentCodec only reads plain "
      'JSON (CR-091).';
}

/// `RackDocument` <-> on-disk bytes. [read] never throws (CR-093): every
/// failure — a foreign file, a too-new schema, malformed JSON — comes
/// back as an [Err]. [write] is not fallible: it only ever runs over a
/// `RackDocument` this package itself could construct, so there is
/// nothing for it to fail on.
abstract class DocumentCodec {
  const DocumentCodec();

  Outcome<RackDocument> read(Uint8List bytes);

  Uint8List write(RackDocument document);
}
