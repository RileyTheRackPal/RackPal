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
    this.members = const <String, Uint8List>{},
    this.issuedForConstruction = false,
  });

  /// Whether the caller ASKED for the ISSUED FOR CONSTRUCTION stamp
  /// (CR-022's `ExportSpec.issuedForConstruction`, DR-216 §11.215.1). A
  /// request, not a promise: an open error withholds the stamp and never the
  /// bytes, and [ExportedDocument.stamped] says which happened.
  final bool issuedForConstruction;

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

  /// The container's binary members, keyed by member path
  /// (`underlays/<uuid>.png`, docs/15 section 2).
  ///
  /// =====================================================================
  /// THE EXPORT PATH COULD NOT REACH AN UNDERLAY UNTIL THIS FIELD EXISTED
  /// =====================================================================
  /// `DiagramCanvas.drawImage` shipped at PLAN-A, `PdfDiagramCanvas` draws
  /// it, and `PdfImageResolver` has been a typedef with ZERO production
  /// call sites ever since, because no sheet asked for an image. T1.01 is
  /// the first caller, and it could not have worked: the bytes live in
  /// `DocumentSession.members` and nothing carried them across. DR-149
  /// section 11.148.1 records the census.
  ///
  /// It is `Uint8List` and a `String` key, so it crosses an isolate
  /// exactly as `fontBytes` does and this file's whole argument is
  /// untouched (section 8.2). It DEFAULTS TO EMPTY, which is the same
  /// mechanism that makes T1.01 AUTO: a project with no floorplan builds
  /// the identical request it built before this field existed, and every
  /// existing caller compiles unchanged.
  ///
  /// A SNAPSHOT, LIKE THE JSON BESIDE IT. The map is passed by reference
  /// and `DocumentSession` replaces it wholesale rather than mutating it
  /// (`_members = {..._members, name: bytes}`), so an import racing an
  /// export cannot half-appear.
  final Map<String, Uint8List> members;
}

/// One page of a finished export, as the preview lists it (DR-230).
final class ExportedSheet {
  const ExportedSheet({
    required this.ncsId,
    required this.title,
    required this.widthPt,
    required this.heightPt,
  });

  /// `T2.01`.
  final String ncsId;

  /// `RACK ELEVATION — FRONT · RK-1`, from `sheetTitle`, the drawing
  /// index's own naming.
  final String title;

  /// The page's size, so a preview renders it at its own proportions:
  /// a set mixes ANSI B portrait elevations with ANSI A landscape
  /// schedules.
  final double widthPt;
  final double heightPt;
}

/// A finished export.
final class ExportedDocument {
  const ExportedDocument({
    required this.bytes,
    required this.sheetCount,
    required this.notices,
    this.sheets = const <ExportedSheet>[],
    this.stamped = false,
    this.stampWithheld,
  });

  /// Every page, in file order: page `i` of [bytes] is `sheets[i]`.
  final List<ExportedSheet> sheets;

  final Uint8List bytes;

  /// Whether every sheet carries the ISSUED FOR CONSTRUCTION stamp. False
  /// whenever it was not asked for, AND when it was asked for over an open
  /// error (CR-022), in which case [stampWithheld] says why.
  final bool stamped;

  /// Why a requested stamp was withheld, as the status line prints it
  /// (`not stamped: 3 open errors, see T0.02`), or `null` when the stamp was
  /// not requested or was applied. Not one of [notices]: those are counted,
  /// and this is the answer to what the user asked for (DR-216 §11.215.1).
  final String? stampWithheld;

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

/// The most sheets one export will produce (AC-050/A7.4, DR-230
/// §11.229.2). Past it the export is refused before a page is emitted.
const int kMaxExportSheets = 2000;

/// Past this many sheets the set is said to be large, in a notice and in
/// the preview's header, and nothing is asked (DR-230 §11.229.2).
const int kLargeSetSheets = 40;

/// The notice a set past [kLargeSetSheets] raises.
///
/// SAID, NOT ASKED. At about 6 ms a sheet, forty sheets is a quarter of a
/// second, so this guards against a broken project and not against a long
/// wait; a commercial job may legitimately run to sixty and would click
/// through a prompt on every export.
String largeSetNotice(int sheets) =>
    'This set is $sheets sheets, more than the $kLargeSetSheets a set '
    'usually needs. If that is not expected, check the sheet list for '
    'duplicate racks, plans or pages.';

/// The set would run past [kMaxExportSheets].
///
/// REFUSED BEFORE ANY PAGE IS EMITTED, from the sheet set's own dry run:
/// two thousand sheets is a project where something upstream is wrong, and
/// the place to find that out is before the file, not inside it.
final class ExportTooManySheets extends ExportError {
  const ExportTooManySheets(this.sheets);

  /// How many sheets the dry run resolved.
  final int sheets;

  @override
  String get message =>
      'This project would print $sheets sheets, and an export stops at '
      '$kMaxExportSheets. A set that large usually means something upstream '
      'is wrong: check for duplicated racks, plans or schedules.';
}

/// A font the sheets need was not supplied.
final class ExportFontMissing extends ExportError {
  const ExportFontMissing(this.font);

  final FontRef font;

  @override
  String get message =>
      'The font ${font.family} was not supplied to the exporter.';
}
