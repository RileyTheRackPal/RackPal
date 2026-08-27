// rackpal_export/lib/src/document/export_request.dart -- the isolate-ready
// export request, and what comes back.
//
// =====================================================================
// WHY THE DOCUMENT CROSSES AS BYTES AND NOT AS A `RackDocument`
// =====================================================================
// docs/08-pdf-export.md section 8.2 rules that PDF generation runs off the
// main isolate (CR-099: `Isolate.spawn` plus a `SendPort` pair, so progress
// and cancellation are possible), and names the constraint that catches
// everyone: "a background isolate has no rootBundle, no plugins, no
// platform channels, no BuildContext. Load every font to `Uint8List` on the
// main isolate, then send plain bytes and JSON."
//
// M1 does NOT spawn an isolate -- three sheets sit under section 8.2's own
// 400 ms "do not show progress" threshold, so a synchronous call on the
// main isolate is the right amount of machinery. But the SIGNATURE is the
// isolate-ready one from the start, because retrofitting it later means
// touching the whole export path, and because the shape has a second,
// immediate benefit: passing the encoded document rather than the live
// object graph makes the snapshot EXPLICIT.
//
// That second reason is the same one `apps/rackpal/src/storage/
// serialization.dart` is built around: a closure capturing the live,
// mutable `RackDocument` may be serialized for transfer at an unspecified
// instant, so a user edit racing the export can be half-included. What
// crosses here is a `String` -- already immutable, already a snapshot of
// one state.
//
// There is NO Flutter type, no `BuildContext` and no `rootBundle` reference
// anywhere in this file, and a test asserts that against the source.

import 'dart:typed_data';

import 'package:rackpal_core/rackpal_core.dart';

/// Everything one export needs, and nothing that cannot cross an isolate
/// boundary.
final class ExportRequest {
  const ExportRequest({
    required this.documentJson,
    required this.fontBytes,
    required this.fileName,
    required this.issuedAt,
  });

  /// The document, encoded (`encodeJsonTreeBytes(encodeToJsonTree(doc))`).
  ///
  /// Bytes rather than a `RackDocument` -- see the file header.
  final Uint8List documentJson;

  /// Every bundled TTF, already read. `rackpal_export` is pure Dart and
  /// has no asset bundle; the caller reads them.
  final Map<FontRef, Uint8List> fontBytes;

  /// The document's own file name, for the title block's FILE field. Data
  /// about the project, not annotation about the drawing -- see
  /// `title_block.dart`'s header on why nothing else here is a `String` the
  /// user could have typed.
  final String fileName;

  /// THE ONE clock value for the whole export (section 8.4). Injected;
  /// nothing in the export path calls `DateTime.now()`, and a test asserts
  /// that against the source of every file under `document/` and
  /// `sheets/`.
  final DateTime issuedAt;
}

/// A finished export.
final class ExportedDocument {
  const ExportedDocument({
    required this.bytes,
    required this.sheetCount,
    required this.notices,
  });

  final Uint8List bytes;

  /// How many sheets were emitted -- `2N + equipment pages`, and what the
  /// status line reports.
  final int sheetCount;

  /// Non-blocking notices: NCS id validation, section 6.2's legibility
  /// check. Reported in the export summary and NEVER a gate (CR-023, G3 --
  /// "a heuristic may never hold a user's deliverable hostage").
  final List<String> notices;
}

/// Why an export could not be produced. A VALUE, not an exception
/// (CR-093).
sealed class ExportError {
  const ExportError();

  /// One sentence for the user.
  String get message;
}

/// The document bytes did not decode.
///
/// Reachable in practice only through a caller that encoded something
/// other than a `RackDocument`; kept as a branch rather than an assert
/// because the alternative is an unhandled exception inside what a user
/// experiences as "Export PDF".
final class ExportDocumentUnreadable extends ExportError {
  const ExportDocumentUnreadable(this.cause);

  final Object cause;

  @override
  String get message =>
      'RackPal could not read this project back in order to export it.';
}

/// The project has no racks, so there is no elevation to draw.
///
/// REFUSED OUT LOUD rather than producing a one-sheet PDF of nothing --
/// "never silently do nothing", and a PDF that appears to be a deliverable
/// and contains no rack is worse than a refusal.
final class ExportNoRacks extends ExportError {
  const ExportNoRacks();

  @override
  String get message => 'Nothing to export — this project has no racks.';
}

/// A font the sheets need was not supplied.
final class ExportFontMissing extends ExportError {
  const ExportFontMissing(this.font);

  final FontRef font;

  @override
  String get message =>
      'The font ${font.family} was not supplied to the exporter.';
}
