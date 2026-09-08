// `Plan ▸ Import floorplan…` (PLAN-D/2 and PLAN-D/4, DR-029, DR-037).
//
// ─────────────────────────────────────────────────────────────────────────
// THIN, ON library_io_actions.dart's PRECEDENT
// ─────────────────────────────────────────────────────────────────────────
// Every decision is somewhere else already: `image_header.dart` decides
// what is accepted and how big it may be, `import_guard.dart` decides how
// big a FILE may be, `container.dart` decides where the bytes live,
// `plan_commands.dart` decides what an underlay is once it exists, and the
// dialog asks the person. What is left here is the SEQUENCE and the places
// it ends early.
//
// ═══════════════════════════════════════════════════════════════════════
// THE ORDER OF THE FIRST FOUR STEPS IS THE WHOLE OF PLAN-D/4
// ═══════════════════════════════════════════════════════════════════════
//   1. STAT, before reading. `checkImportedFileSize`, the same call the
//      three existing import paths make. A file too big to read is
//      refused without reading it.
//   2. SNIFF, by content. A dialog filter is a courtesy; `plan.png` that
//      is really an executable passes any filter ever written.
//   3. READ THE HEADER, which is two integers and no pixels. This is
//      where a three-kilobyte file declaring 60000 x 60000 is refused,
//      and it has to be here rather than after the decode, because a cap
//      that fires after the allocation it prevents is decoration.
//   4. ONLY THEN DECODE, with a bound already established on what is
//      about to be built.
//
// ═══════════════════════════════════════════════════════════════════════
// AND THE DECODE RE-CHECKS WHAT THE HEADER CLAIMED
// ═══════════════════════════════════════════════════════════════════════
// The header is a claim by the file, and step 3 refuses on that claim. A
// file whose header understates its real size would slip a cap that
// trusted it, so the decoded dimensions are compared with the declared
// ones and a mismatch is refused. Cheap, and it is the difference between
// a cap and a suggestion.
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as img;
import 'package:rackpal/src/session/file_picker.dart';
import 'package:rackpal/src/storage/file_store.dart';
import 'package:rackpal/src/storage/import_guard.dart';
import 'package:rackpal_core/rackpal_core.dart';

/// PDF import is chosen and not yet built (`PLAN-D/3`).
///
/// **ITS OWN ERROR RATHER THAN "unsupported format"**, because those are
/// different sentences and only one of them is true: DR-029 §11.28.5
/// bought PDF import deliberately, so a person handed "that is not a
/// supported format" would be told the product has decided something it
/// has not. "Not yet" is the honest word, and it stops somebody
/// converting the file by hand in the belief that they must.
final class PdfImportNotAvailableError implements Exception {
  const PdfImportNotAvailableError();

  @override
  String toString() =>
      'PdfImportNotAvailableError: PDF floorplans are supported by design '
      '(DR-029) and the rasteriser is not built yet (PLAN-D/3). Export '
      'the page as PNG or JPEG for now.';
}

/// The image decoded to different dimensions than its header declared.
///
/// **NOT A CURIOSITY.** The caps in `readImageHeader` run on the DECLARED
/// size, so a file that understates itself would pass a cap and then
/// allocate what it liked. This is the check that makes the cap a cap.
final class ImageHeaderMismatchError implements Exception {
  const ImageHeaderMismatchError({
    required this.declared,
    required this.actualWidth,
    required this.actualHeight,
  });

  final ImageHeader declared;
  final int actualWidth;
  final int actualHeight;

  @override
  String toString() =>
      'ImageHeaderMismatchError: the file declares '
      '${declared.pixelWidth}x${declared.pixelHeight} and decodes to '
      '${actualWidth}x$actualHeight.';
}

/// The bytes matched a supported signature and would not decode.
final class ImageDecodeFailedError implements Exception {
  const ImageDecodeFailedError(this.detail);

  final String detail;

  @override
  String toString() => 'ImageDecodeFailedError: $detail';
}

/// A floorplan, ready to become an underlay: the entity and the container
/// member it names.
///
/// The two travel together because neither is useful alone, and returning
/// them separately is how a caller ends up adding the entity and
/// forgetting the bytes.
final class ImportedFloorplan {
  const ImportedFloorplan({required this.underlay, required this.memberBytes});

  final PlanUnderlay underlay;

  /// What must be written to the container at `underlay.imageMember`.
  final Uint8List memberBytes;
}

/// Reads the floorplan at [path] and turns it into an underlay.
///
/// Separate from the picking so a caller with bytes already in hand (a
/// test, a drag and drop, a future PDF page picker handing over a
/// rasterised page) reaches the identical checks. One implementation
/// means the hardening cannot differ between the route the user usually
/// takes and the routes they take on a bad day, which is
/// `DocumentStore.decodeBytes`'s reason one layer down.
Future<Outcome<ImportedFloorplan>> importFloorplanFrom({
  required FileStore fs,
  required String path,
  required Uuid id,
  required String name,
  required FracIndex order,
  required EntityMeta meta,
  Uuid? locationId,
  int maxBytes = kMaxImageBytes,
}) async {
  // ---- 1. STAT, BEFORE READING (AC-058/D8). -------------------------
  // [maxBytes] IS INJECTABLE for `JsonLimits`' and `ContainerLimits`'
  // reason, stated a third time: proving a size gate fires must not cost
  // a fixture the size of the gate, and a test that allocates 64 MB to
  // watch a refusal is a test somebody deletes.
  //
  // THE CAP IS PASSED EXPLICITLY THOUGH IT EQUALS THE DEFAULT TODAY, and
  // the lint is suppressed rather than obeyed. `kMaxImageBytes` and
  // `kMaxDocumentBytes` are two caps over two different things that
  // happen to agree at 64 MB; obeying the lint would make this call
  // INHERIT the document cap, so moving either constant would silently
  // move this path with it. Naming it is what makes a future divergence a
  // one-line change instead of a discovery.
  // ignore: avoid_redundant_argument_values
  final sized = await checkImportedFileSize(fs, path, maxBytes: maxBytes);
  if (sized case Err(:final error)) return Err(error);

  final Uint8List bytes;
  try {
    bytes = await fs.readBytes(path);
    // `on Object`, not `on Exception`: `FileStore.readBytes` declares no
    // typed failure, so this catches the interface's contract rather than
    // one implementation's exception class.
  } on Object catch (e) {
    return Err(ImageDecodeFailedError('could not read the file ($e)'));
  }

  return importFloorplanBytes(
    bytes: bytes,
    id: id,
    name: name,
    order: order,
    meta: meta,
    locationId: locationId,
  );
}

/// The half that has bytes and no file system. See [importFloorplanFrom].
Outcome<ImportedFloorplan> importFloorplanBytes({
  required Uint8List bytes,
  required Uuid id,
  required String name,
  required FracIndex order,
  required EntityMeta meta,
  Uuid? locationId,
}) {
  // ---- 2. SNIFF, BY CONTENT (PLAN-D/4, M4-M4's rule). ---------------
  //
  // A PDF DOES NOT ARRIVE HERE ANY MORE (DR-138). It goes through
  // [liftPdfPages] and the page picker first, and what comes back is one
  // page's embedded image, which re-enters this function as bytes. The arm
  // is kept as a REFUSAL rather than deleted, because this function is the
  // one every route reaches (a test, a drag and drop, a future caller),
  // and a PDF reaching it means somebody skipped the picker rather than
  // that PDFs are unsupported.
  final kind = sniffImportKind(bytes);
  if (kind == SniffedImportKind.pdf) {
    return const Err(PdfImportNotAvailableError());
  }

  // ---- 3. THE HEADER, AND THE CAPS, WITH NOTHING DECODED. -----------
  final headerRead = readImageHeader(bytes);
  if (headerRead case Err(:final error)) return Err(error);
  final header = (headerRead as Ok<ImageHeader>).value;

  // ---- 4. ONLY NOW DECODE. ------------------------------------------
  final img.Image? decoded;
  try {
    decoded = img.decodeImage(bytes);
  } on Object catch (e) {
    return Err(ImageDecodeFailedError(e.toString()));
  }
  if (decoded == null) {
    return const Err(
      ImageDecodeFailedError(
        'the decoder returned nothing for a file whose '
        'signature and header both parsed',
      ),
    );
  }

  if (decoded.width != header.pixelWidth ||
      decoded.height != header.pixelHeight) {
    return Err(
      ImageHeaderMismatchError(
        declared: header,
        actualWidth: decoded.width,
        actualHeight: decoded.height,
      ),
    );
  }

  // ---- 5. FLATTEN, AND STORE OPAQUE RGB. ----------------------------
  // TWO OBLIGATIONS, NOT ONE (`#624`). The SCREENING percentage belongs
  // in the export backend where it can be changed without re-importing
  // every underlay in every project a user owns (DR-037 §11.36.3). An
  // ALPHA CHANNEL IN THE STORED BYTES is a hazard either way, because
  // `PdfImage(..., alpha: true)` emits an `/SMask` and docs/08 row 9
  // forbids alpha absolutely. So the screening moved and the flatten
  // stayed.
  //
  // COMPOSITED OVER WHITE, which is what paper is. A floorplan's
  // transparency is nearly always the page background, and the
  // alternative default, black, turns an ordinary architectural export
  // into a solid dark sheet with white lines.
  final Uint8List stored;
  final PlanImageFormat storedFormat;
  if (decoded.hasAlpha) {
    final flat = img.Image(width: decoded.width, height: decoded.height)
      ..clear(img.ColorRgb8(255, 255, 255));
    img.compositeImage(flat, decoded);
    stored = img.encodePng(flat);
    storedFormat = PlanImageFormat.png;
  } else {
    // NO RE-ENCODE WHEN THERE IS NOTHING TO FLATTEN, which is not an
    // optimisation. Re-encoding a JPEG loses generation, and re-encoding
    // a PNG would make the stored member differ from the architect's
    // file for no reason a person could see. The bytes on the shelf are
    // the bytes they sent, which is `library_io_actions.dart`'s rule.
    stored = bytes;
    storedFormat = header.format;
  }

  return Ok(
    ImportedFloorplan(
      underlay: PlanUnderlay(
        id: id,
        name: name,
        imageMember: '$kUnderlayMemberDir${id.v}.${storedFormat.extension}',
        format: storedFormat,
        pixelWidth: decoded.width,
        pixelHeight: decoded.height,
        contentHash: '$kSha256Prefix${sha256.convert(stored)}',
        order: order,
        meta: meta,
        locationId: locationId,
        // NO SCALE. An imported plan is UNCALIBRATED and that is a fact
        // rather than a gap (G4): it locates every drop already, and it
        // yields no lengths until somebody picks two points and types a
        // distance. Inventing a 1:1 here would make every length on it
        // wrong and confident.
      ),
      memberBytes: stored,
    ),
  );
}

/// A PDF that was read but yielded no page anybody can use.
///
/// **SEPARATE FROM [PdfImportNotAvailableError] BECAUSE THE TWO SAY
/// DIFFERENT THINGS.** That one means the picker was skipped. This one
/// means the picker ran, read the file correctly, and every page needs a
/// renderer that is not built yet (`PLAN-D/3`, DR-138). Telling somebody
/// "PDF import is not available" about a file this product just parsed
/// eighteen pages of would be false.
final class PdfHasNoLiftablePageError implements Exception {
  const PdfHasNoLiftablePageError({
    required this.pageCount,
    required this.firstReason,
  });

  final int pageCount;

  /// Why the first page was refused, so the message is specific.
  ///
  /// **IT KEEPS THE UNDERLYING ERROR'S OWN WORDS WHEN THERE ARE ANY.** The
  /// first draft collapsed everything that was not a
  /// `PdfPageNotLiftableError` to "could not be read", which is how a page
  /// refused by the PIXEL CAP came out sounding like a damaged file. Those
  /// are different problems with different remedies, and the cap's message
  /// already says which.
  final String firstReason;

  @override
  String toString() =>
      'PdfHasNoLiftablePageError: this PDF has $pageCount page'
      '${pageCount == 1 ? '' : 's'} and none of them can be used as an '
      'underlay (PLAN-D/3, DR-138). The first page $firstReason. Export '
      'the page you want as PNG or JPEG for now.';
}

/// Every page of the PDF in [bytes], for the picker.
///
/// **THIN ON PURPOSE.** The lifting is `rackpal_core`'s and the picker is
/// `rackpal_ui`'s; what lives here is the sentence the app says when the
/// answer is "none of them", which needs the page count and a reason and
/// is therefore neither layer's business alone.
Outcome<List<Outcome<LiftedPdfPage>>> readPdfPages(Uint8List bytes) {
  final lifted = liftPdfPages(bytes);
  if (lifted case Err(:final error)) return Err(error);
  final pages = (lifted as Ok<List<Outcome<LiftedPdfPage>>>).value;

  if (pages.every((p) => p is Err)) {
    final first = pages.first as Err<LiftedPdfPage>;
    final error = first.error;
    return Err(
      PdfHasNoLiftablePageError(
        pageCount: pages.length,
        // A LIFTABILITY RULE READS AS A CLAUSE; ANYTHING ELSE KEEPS ITS
        // OWN SENTENCE. `PdfPageNotLiftableError.reason` is written to
        // follow "the first page", and an `ImageTooLargeError` is not, so
        // flattening both into one phrase would either mangle the grammar
        // or throw away the cap's numbers.
        firstReason: error is PdfPageNotLiftableError
            ? error.reason
            : 'could not be read ($error)',
      ),
    );
  }
  return Ok(pages);
}

/// Turns a page the user picked into an underlay.
///
/// **IT GOES THROUGH [importFloorplanBytes] LIKE ANY OTHER FILE, AND THAT
/// IS THE POINT** (DR-138 §11.137.6). Every control `PLAN-D/4` built runs
/// on these bytes: the content sniff, the declared-size caps before any
/// decode, the decoded-versus-declared re-check, and the alpha flatten. A
/// lifted page is an untrusted image that happens to have come out of a
/// file this product parsed, and exempting it from a check on the grounds
/// that we produced it would be exempting it on the grounds that we
/// trusted the stranger who sent it.
Outcome<ImportedFloorplan> importLiftedPdfPage({
  required LiftedPdfPage page,
  required Uuid id,
  required String name,
  required FracIndex order,
  required EntityMeta meta,
  Uuid? locationId,
}) => importFloorplanBytes(
  bytes: page.bytes,
  id: id,
  name: name,
  order: order,
  meta: meta,
  locationId: locationId,
);

/// Asks the user for a floorplan and imports it. Null means cancelled.
Future<Outcome<ImportedFloorplan>?> pickAndImportFloorplan({
  required FilePicker picker,
  required FileStore fs,
  required Uuid id,
  required String name,
  required FracIndex order,
  required EntityMeta meta,
  String? initialDirectory,
  Uuid? locationId,
}) async {
  final path = await picker.pickOpen(
    initialDirectory: initialDirectory,
    type: FileDialogType.floorplan,
  );
  if (path == null) return null;
  return importFloorplanFrom(
    fs: fs,
    path: path,
    id: id,
    name: name,
    order: order,
    meta: meta,
    locationId: locationId,
  );
}
