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
import 'package:rackpal/src/session/document_session.dart';
import 'package:rackpal/src/session/file_picker.dart';
import 'package:rackpal/src/session/pdf_rasteriser.dart';
import 'package:rackpal/src/storage/file_store.dart';
import 'package:rackpal/src/storage/import_guard.dart';
import 'package:rackpal_core/rackpal_core.dart';

/// A PDF reached the raster import path, which means the page picker was
/// skipped.
///
/// **ITS OWN ERROR RATHER THAN "unsupported format"**, because those are
/// different sentences and only one of them is true: DR-029 §11.28.5
/// bought PDF import deliberately, so a person handed "that is not a
/// supported format" would be told the product has decided something it
/// has not.
///
/// ═══════════════════════════════════════════════════════════════════════
/// THIS SAID "NOT YET BUILT" UNTIL 2026-09-08, AND THE SAME FILE ALREADY
/// SAID OTHERWISE
/// ═══════════════════════════════════════════════════════════════════════
/// DR-138 built PDF import and DR-138's own sweep updated
/// [PdfHasNoLiftablePageError] below, whose doc comment says this error
/// "means the picker was skipped". It did not update this class, so one
/// file carried both sentences: *the picker was skipped* and *the
/// rasteriser is not built yet (PLAN-D/3). Export the page as PNG or JPEG
/// for now.* The second is now false twice over, and it told somebody to
/// go and convert by hand a file this product can open.
///
/// **A TEST WAS PINNING THE STALE SENTENCE**, asserting
/// `contains('not built yet')`, which is this repository's own house rule
/// about a test that survives the behaviour it was protecting. Found by
/// `PLAN-E/1`'s census (docs/12 §5.9.7) rather than by anything watching
/// this path.
///
/// The name is left alone deliberately: from the caller's side PDF import
/// really is not available *on this route*, and renaming a thrown type to
/// improve a comment is a bigger change than the comment was worth.
final class PdfImportNotAvailableError implements Exception {
  const PdfImportNotAvailableError();

  @override
  String toString() =>
      'PdfImportNotAvailableError: PDF floorplans are supported (DR-029, '
      'DR-138) and a PDF must go through the page picker, which lifts one '
      "page's image. This path takes PNG or JPEG bytes only, so reaching "
      'it with a PDF means the picker was skipped.';
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

/// Steps 1 and 2 of the sequence: cap the file, then read it.
///
/// ═══════════════════════════════════════════════════════════════════════
/// EXTRACTED SO THE PDF BRANCH SHARES THEM RATHER THAN SKIPPING THEM
/// ═══════════════════════════════════════════════════════════════════════
/// A caller has to know whether the bytes are a PDF **before** it can
/// choose between the page picker and the raster path, and it cannot know
/// that from the extension: this file's own step 2 says a dialog filter is
/// a courtesy and `plan.png` may be anything. So the bytes must be in hand
/// first, and the only ways to get them are to share this or to write it
/// again with the cap left out.
///
/// [maxBytes] IS INJECTABLE for `JsonLimits`' and `ContainerLimits`'
/// reason, stated a third time: proving a size gate fires must not cost a
/// fixture the size of the gate, and a test that allocates 64 MB to watch
/// a refusal is a test somebody deletes.
///
/// THE CAP IS PASSED EXPLICITLY THOUGH IT EQUALS THE DEFAULT TODAY, and
/// the lint is suppressed rather than obeyed. `kMaxImageBytes` and
/// `kMaxDocumentBytes` are two caps over two different things that happen
/// to agree at 64 MB; obeying the lint would make this call INHERIT the
/// document cap, so moving either constant would silently move this path
/// with it. Naming it is what makes a future divergence a one-line change
/// instead of a discovery.
Future<Outcome<Uint8List>> readImportedBytes({
  required FileStore fs,
  required String path,
  int maxBytes = kMaxImageBytes,
}) async {
  // ---- 1. STAT, BEFORE READING (AC-058/D8). -------------------------
  // ignore: avoid_redundant_argument_values
  final sized = await checkImportedFileSize(fs, path, maxBytes: maxBytes);
  if (sized case Err(:final error)) return Err(error);
  try {
    return Ok(await fs.readBytes(path));
    // `on Object`, not `on Exception`: `FileStore.readBytes` declares no
    // typed failure, so this catches the interface's contract rather than
    // one implementation's exception class.
  } on Object catch (e) {
    return Err(ImageDecodeFailedError('could not read the file ($e)'));
  }
}

/// The half that has bytes and no file system; [readImportedBytes] is the
/// other, and `FloorplanIo` composes the two.
Outcome<ImportedFloorplan> importFloorplanBytes({
  required Uint8List bytes,
  required Uuid id,
  required String name,
  required FracIndex order,
  required EntityMeta meta,
  Uuid? locationId,
  PlanSourcePage? sourcePage,
  int rotationQuarterTurns = 0,
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
        // PRESENT ONLY FOR A RENDERED PAGE (DR-153 §11.152.6). A lifted
        // page's stored bytes already ARE the source, so a copy of the
        // PDF beside it would store one drawing twice.
        sourcePage: sourcePage,
        // A LIFTED PAGE'S OWN `/Rotate` (DR-184 §11.183.6), and 0 for
        // everything else: an image file has no turn to carry and pdfium
        // has already turned a rendered page.
        rotationQuarterTurns: rotationQuarterTurns,
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

  /// **THE ADVICE CHANGED WHEN THE RENDERER LANDED.** It ended *"Export
  /// the page you want as PNG or JPEG for now"* until `PLAN-K`, which was
  /// the workaround for a missing rasteriser and read as an instruction
  /// to go and convert by hand. A page that reaches this sentence now is
  /// one pdfium ALSO declined, so the remedy is a different viewer rather
  /// than a different format, and the "for now" is gone because there is
  /// no longer anything being waited for.
  @override
  String toString() =>
      'PdfHasNoLiftablePageError: this PDF has $pageCount page'
      '${pageCount == 1 ? '' : 's'} and none of them can be used as an '
      'underlay (DR-153). The first page $firstReason. If another viewer '
      'opens this file, exporting that page as PNG or JPEG will import.';
}

/// The width a page preview is rendered at for the picker's grid.
///
/// A LITTLE ABOVE THE TILE, matching what the dialog asks its decoder for
/// (`kPageThumbnailDecodeWidth`), so a high-DPI screen is not painting an
/// upscaled thumbnail. It is stated here rather than imported from
/// `rackpal_ui` because this layer may not depend on that one, and the
/// two being equal is a coincidence worth keeping rather than a coupling
/// worth building.
const int kPagePreviewWidth = 320;

/// Every page of the PDF in [bytes], for the picker.
///
/// **THIN ON PURPOSE.** The lifting is `rackpal_core`'s and the picker is
/// `rackpal_ui`'s; what lives here is the sentence the app says when the
/// answer is "none of them", which needs the page count and a reason and
/// is therefore neither layer's business alone.
Outcome<List<Outcome<PdfPageOption>>> readPdfPages(
  Uint8List bytes, {
  PdfRasteriser? rasteriser,
  int previewWidth = kPagePreviewWidth,
}) {
  final lifted = liftPdfPages(bytes);
  if (lifted case Err(:final error)) return Err(error);
  final lifts = (lifted as Ok<List<Outcome<LiftedPdfPage>>>).value;

  final pages = <Outcome<PdfPageOption>>[
    for (final lift in lifts)
      switch (lift) {
        Ok(:final value) => Ok(LiftedPageOption(value)),
        // A REFUSAL IS OFFERED TO THE RENDERER BEFORE IT IS PASSED ON.
        // The lifter's job is unchanged and its answer is still preferred
        // where it has one: lifting is lossless and rendering is not
        // (DR-138 §11.137.3).
        Err(:final error) => _renderOption(
          bytes,
          error,
          rasteriser,
          previewWidth,
        ),
      },
  ];

  if (pages.every((p) => p is Err)) {
    final first = pages.first as Err<PdfPageOption>;
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

/// A refused page, rendered instead when something can draw it.
///
/// **THE REFUSAL IS RETURNED UNCHANGED WHEN IT CANNOT BE**, which is the
/// three cases worth naming: there is no rasteriser (the flow was handed
/// none), the refusal is about the `/MediaBox` itself so nothing knows how
/// big to draw (`hasSheetSize`), or the render failed on its own terms.
/// In each the person gets the reason the parser gave rather than a
/// second, vaguer one from here.
Outcome<PdfPageOption> _renderOption(
  Uint8List pdf,
  Object error,
  PdfRasteriser? rasteriser,
  int previewWidth,
) {
  if (rasteriser == null) return Err(error);
  if (error is! PdfPageNotLiftableError) return Err(error);
  if (!error.hasSheetSize) return Err(error);

  final plan = planRasterFor(error.sheetWidthPt!, error.sheetHeightPt!);
  if (plan == null) return Err(error);

  // THE PREVIEW IS SMALL AND THE PLAN IS NOT. The grid draws thumbnails,
  // and rendering every page of a drawing set at 300 dpi to fill it would
  // be hundreds of megapixels of work to show pictures a few hundred
  // pixels wide. The chosen page is rendered again at full size.
  final previewHeight = (previewWidth * plan.height / plan.width).round();
  final preview = rasteriser(
    pdf,
    error.pageIndex,
    width: previewWidth,
    height: previewHeight < 1 ? 1 : previewHeight,
  );
  if (preview case Err(:final error)) return Err(error);

  return Ok(
    RenderedPageOption(
      pageIndex: error.pageIndex,
      plan: plan,
      previewBytes: (preview as Ok<Uint8List>).value,
    ),
  );
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
  // THE PAGE ARRIVES THE WAY A PDF VIEWER SHOWS IT (DR-184 §11.183.6).
  // Until the ruling this line did not exist and a `/Rotate 90` page came
  // in sideways, while the same page rendered came in upright.
  rotationQuarterTurns: page.quarterTurns,
);

/// The member a rendered page's source PDF is stored at.
String planSourceMemberFor(Uuid id) => '$kPlanSourceMemberDir${id.v}.pdf';

/// Renders a page at full size and imports it, keeping the source.
///
/// **IT GOES THROUGH [importFloorplanBytes] LIKE A LIFTED PAGE DOES**, for
/// the reason that function's own header gives: the bytes are untrusted
/// whoever produced them, and this product producing them is not a reason
/// to skip the header, the caps or the decode re-check. They are PNG by
/// the time they arrive (DR-153 §11.152.5).
Outcome<ImportedFloorplan> importRenderedPdfPage({
  required Uint8List pdf,
  required RenderedPageOption option,
  required PdfRasteriser rasteriser,
  required Uuid id,
  required String name,
  required FracIndex order,
  required EntityMeta meta,
  Uuid? locationId,
}) {
  final rendered = rasteriser(
    pdf,
    option.pageIndex,
    width: option.plan.width,
    height: option.plan.height,
  );
  if (rendered case Err(:final error)) return Err(error);

  return importFloorplanBytes(
    bytes: (rendered as Ok<Uint8List>).value,
    id: id,
    name: name,
    order: order,
    meta: meta,
    locationId: locationId,
    // THE SOURCE IS KEPT BECAUSE THE VECTOR WAS THROWN AWAY
    // (DR-153 §11.152.6). The hash is over the PDF rather than over the
    // page, because the member holds the whole file.
    sourcePage: PlanSourcePage(
      member: planSourceMemberFor(id),
      pageIndex: option.pageIndex,
      contentHash: '$kSha256Prefix${sha256.convert(pdf)}',
    ),
  );
}

/// `File ▸ Import floorplan…`, the caller this whole file did not have
/// (DR-143 §11.142).
///
/// ═══════════════════════════════════════════════════════════════════════
/// A FOURTH SIBLING OF `ExportController`, ON `LibraryIo`'s PRECEDENT
/// ═══════════════════════════════════════════════════════════════════════
/// Every function above this line was built by `PLAN-D`, tested, and
/// reachable from nothing: censused at `PLAN-E/5`, `pickAndImportFloorplan`,
/// `importFloorplanFrom`, `importFloorplanBytes`, `readPdfPages`,
/// `importLiftedPdfPage` and `PdfPagePickerDialog` had **zero call sites**
/// in `lib/`. So `AddPlanUnderlayCommand` had no producer and no project
/// could hold a floorplan. (All but two gained a caller through this
/// class. `pickAndImportFloorplan` and `importFloorplanFrom` never did:
/// this class reads with `readImportedBytes` and decodes with
/// `importFloorplanBytes` itself, so `#945` deleted both. It first deleted
/// only the one, and said here that this class called the other; that was
/// wrong, and a second census run found `importFloorplanFrom` orphaned.)
///
/// This class is the shape the three existing import/export families
/// already use: it holds the picker and the file store, takes the dialog
/// as a CALLBACK so the sequence is testable with no `BuildContext`, and
/// owns nothing else.
///
/// ═══════════════════════════════════════════════════════════════════════
/// TWO WRITES, ONE OF WHICH IS NOT UNDOABLE, AND THAT IS RULED
/// ═══════════════════════════════════════════════════════════════════════
/// The member goes to `DocumentSession.addMember` and the entity goes
/// through `AddPlanUnderlayCommand`. Undo therefore removes the underlay
/// and leaves the bytes, which `RemovePlanUnderlayCommand`'s own doc calls
/// correct: *"the member is cheap, the bytes are the architect's, and
/// deleting them on an undo would make a redo unable to find them."*
///
/// **THE MEMBER IS WRITTEN FIRST.** If the command ran first and the member
/// write failed, the document would carry an underlay naming bytes the
/// container does not hold, which is a dangling reference in a saved file.
/// This order can only ever leave an orphaned member, which is the state
/// the model already tolerates by name.
final class FloorplanIo {
  const FloorplanIo({
    required this.session,
    required this.picker,
    required this.fs,
    this.initialDirectory,
    this.rasteriser = pdfiumRenderPng,
  });

  final DocumentSession session;
  final FilePicker picker;
  final FileStore fs;
  final Future<String?> Function()? initialDirectory;

  /// What draws a page of vectors (DR-153). Defaulted to the real one, so
  /// the app wires nothing and a test that wants to run without the
  /// vendored binary passes its own.
  final PdfRasteriser rasteriser;

  /// Asks for a file, imports it, and puts it in the open document.
  ///
  /// Returns the underlay on success, `null` when the user cancelled
  /// either dialog, and an `Err` carrying the refusal when the file was
  /// read and declined. **Cancelled and refused are different answers**
  /// and the shell says something for only one of them.
  ///
  /// [pickPage] is called only for a PDF, with every page the lifter
  /// produced. Returning null from it is a cancel, not a failure: a person
  /// who opens an 80-page drawing set and closes the grid has not hit an
  /// error.
  ///
  /// [confirmDetails] is DR-185 §11.184.2: once the page is read, the
  /// name and place this proposes are offered for a person to change.
  /// **Null from it keeps the proposal and still imports**, because the
  /// page is already picked and dismissing a naming dialog is not a
  /// request to throw it away. [proposedLocation] is the Site tree's
  /// selection, and one this document does not hold proposes none.
  Future<Outcome<PlanUnderlay>?> import({
    required Future<PdfPageOption?> Function(
      List<Outcome<PdfPageOption>> pages,
      String fileName,
    )
    pickPage,
    Uuid? proposedLocation,
    Future<({String name, Uuid? locationId})?> Function(
      ({String name, Uuid? locationId}) proposed,
    )?
    confirmDetails,
  }) async {
    // THE CONTROLLER'S OWN CLOCK AND ACTOR, not `DateTime.now()`. Every
    // other command in this product stamps its `EntityMeta` from the
    // injected clock, which is what makes a fixture's timestamps
    // reproducible and a byte round-trip comparable (CR-117).
    final controller = session.controller;
    final now = controller.clock.nowUtc();
    final actor = controller.actor;
    final path = await picker.pickOpen(
      initialDirectory: await initialDirectory?.call(),
      type: FileDialogType.floorplan,
    );
    if (path == null) return null;

    // THE CAP IS LEFT AT THE DEFAULT HERE, deliberately, and the reason it
    // is NAMED one level down is the one `readImportedBytes` documents:
    // that site distinguishes the image cap from the document cap, and
    // this one has nothing to add by repeating it.
    final read = await readImportedBytes(fs: fs, path: path);
    if (read case Err(:final error)) return Err(error);
    final bytes = (read as Ok<Uint8List>).value;

    final doc = session.document;
    final id = newEntityId();
    // THE FILE'S OWN NAME, which is what the architect called it and what
    // the person will look for in the list. `PlanUnderlay.name` is
    // editable through the property table afterwards.
    // `p.Context`, NOT A HAND-ROLLED SPLIT. The session already carries
    // one and it is the platform's own, so a UNC path, a trailing
    // separator and a name with dots in it all come out right. The first
    // draft used a regex here and returned the whole path.
    final ctx = session.context;
    final fileName = ctx.basename(path);
    final underlayName = ctx.basenameWithoutExtension(path);
    final meta = EntityMeta(createdAt: now, updatedAt: now, updatedBy: actor);
    final order = nextUnderlayOrder(doc);

    // SNIFFED BY CONTENT, NOT BY EXTENSION. Step 2 of this file's own
    // sequence: a dialog filter is a courtesy, and `plan.png` that is
    // really a PDF must reach the page picker rather than the raster path
    // that would refuse it by name.
    final Outcome<ImportedFloorplan> imported;
    if (sniffImportKind(bytes) == SniffedImportKind.pdf) {
      final pages = readPdfPages(bytes, rasteriser: rasteriser);
      if (pages case Err(:final error)) return Err(error);
      final chosen = await pickPage(
        (pages as Ok<List<Outcome<PdfPageOption>>>).value,
        fileName,
      );
      if (chosen == null) return null;
      // THE PAGE IS IN THE NAME WHEN THERE IS MORE THAN ONE (§11.184.2).
      // Three pages of `A-101 REV3.pdf` were three rows reading the same
      // words; a one-page PDF gains nothing from saying "p.1".
      final pageCount = pages.value.length;
      final pageName = pageCount > 1
          ? '$underlayName, p.${chosen.pageIndex + 1}'
          : underlayName;
      imported = switch (chosen) {
        LiftedPageOption(:final page) => importLiftedPdfPage(
          page: page,
          id: id,
          name: pageName,
          order: order,
          meta: meta,
        ),
        // RENDERED AT FULL SIZE ONLY NOW. The grid showed a preview; what
        // the document keeps is the page at DR-153 §11.152.5's resolution.
        RenderedPageOption() => importRenderedPdfPage(
          pdf: bytes,
          option: chosen,
          rasteriser: rasteriser,
          id: id,
          name: pageName,
          order: order,
          meta: meta,
        ),
      };
    } else {
      imported = importFloorplanBytes(
        bytes: bytes,
        id: id,
        name: underlayName,
        order: order,
        meta: meta,
      );
    }
    if (imported case Err(:final error)) return Err(error);
    final floorplan = (imported as Ok<ImportedFloorplan>).value;

    // ASKED AFTER THE PAGE IS READ AND BEFORE ANYTHING IS WRITTEN
    // (DR-185 §11.184.2), so a file refused above never gets a dialog, and
    // the details land inside the ONE command below: the import and its
    // name are one undo entry.
    bool known(Uuid? id) => id != null && doc.locations.containsKey(id);
    final proposed = (
      name: floorplan.underlay.name,
      locationId: known(proposedLocation) ? proposedLocation : null,
    );
    final details = await confirmDetails?.call(proposed) ?? proposed;
    final typed = details.name.trim();
    floorplan.underlay
      ..name = typed.isEmpty ? proposed.name : typed
      ..locationId = known(details.locationId) ? details.locationId : null;

    // See the class header on why the member is written first.
    session.addMember(
      floorplan.underlay.imageMember,
      floorplan.memberBytes,
    );
    // AND THE SOURCE PDF WHEN THE PAGE WAS RENDERED, before the command
    // for the same reason: a document naming a member the container does
    // not hold is a dangling reference in a saved file. `sourcePage` is
    // null for every other route, so this arm is the rendered one and
    // needs no second test to say which (DR-153 §11.152.6).
    final source = floorplan.underlay.sourcePage;
    if (source != null) session.addMember(source.member, bytes);
    controller.run(AddPlanUnderlayCommand(underlay: floorplan.underlay));
    return Ok(floorplan.underlay);
  }
}
