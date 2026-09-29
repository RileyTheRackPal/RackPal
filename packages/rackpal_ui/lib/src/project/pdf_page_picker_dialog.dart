// DR-037 §11.36.2's page picker: "rasterise at thumbnail size, show a
// grid, one click, one page, one underlay" (PLAN-D/3, DR-138).
//
// ═══════════════════════════════════════════════════════════════════════
// WHY THIS DIALOG EXISTS AT ALL, WHICH IS NOT OBVIOUS FROM ITS SIZE
// ═══════════════════════════════════════════════════════════════════════
// Canon: *"the electrical sheet is not page 1 of an architectural set, and
// first-page-only would reinstate the manual conversion step DR-029 spent
// 2 to 3 weeks buying out."* An 18-sheet permit set puts the first floor
// plan at A-2.1, which was page 3 of the one real set this project has
// seen. A picker is the difference between importing a plan and importing
// a cover sheet.
//
// ═══════════════════════════════════════════════════════════════════════
// ONE CLICK IMPORTS, AND THE SAFETY ARGUMENT IS UNDO RATHER THAN A PROMPT
// ═══════════════════════════════════════════════════════════════════════
// The ruling says "one click", and a confirm button would make it two. A
// misclick lands the wrong sheet, and removing an underlay is an ordinary
// command with undo (`RemovePlanUnderlayCommand`), so the cost of the
// wrong page is Ctrl+Z. A confirmation whose consequence is one undo away
// is the nag that teaches people to click through prompts, which
// `delete_device_dialog.dart` argues at greater length one folder over.
//
// ═══════════════════════════════════════════════════════════════════════
// A PAGE ARRIVES TWO WAYS AND THE GRID DOES NOT SAY WHICH
// ═══════════════════════════════════════════════════════════════════════
// A page that is one full-page image is LIFTED whole; a page of vectors is
// RENDERED by pdfium (DR-153, PLAN-K/4). Both produce a picture, a pixel
// count and a resolution, so `PdfPageOption` answers all three and the
// tile draws the same either way.
//
// **THE DIFFERENCE IS NOT SURFACED, AND THAT IS A CHOICE.** The person is
// choosing a drawing, not an import mechanism, and a badge saying
// "rendered" would be this product talking about itself. What is surfaced
// is the resolution, which is the part that affects what they get.
//
// ═══════════════════════════════════════════════════════════════════════
// A PAGE THAT CANNOT BE USED IS SHOWN, DISABLED, WITH ITS REASON
// ═══════════════════════════════════════════════════════════════════════
// DR-138 has the lifter return a reason per page precisely so this grid
// can say which rule a page failed rather than dropping it. A set where
// page 7 is a scan and the rest are exports should show seventeen live
// tiles and one that says why, not seventeen tiles and a silence.
//
// **IT IS A RARER TILE THAN IT WAS.** Before PLAN-K a whole CAD plot came
// back refused; now the refusals left are damage and the cases pdfium
// itself declines.
//
// **THE ALL-REFUSED CASE DOES NOT REACH THIS DIALOG.** A grid where
// nothing is clickable reads as a broken dialog rather than an unsupported
// file, so the import refuses first and shows a sentence instead: see
// `PdfHasNoLiftablePageError` in apps/rackpal's plan_import_actions.dart.
// (A `pdfHasLiftablePage` guard here was never called, since the import
// already made the check; `#945` deleted it.)
//
// ═══════════════════════════════════════════════════════════════════════
// THE THUMBNAIL IS FLUTTER'S DECODER, NOT THE `image` PACKAGE
// ═══════════════════════════════════════════════════════════════════════
// `Image.memory(..., cacheWidth:)` decodes at reduced resolution, so an
// 18-sheet set costs about 150 KB per tile rather than 9 MB. It also keeps
// `image` out of `rackpal_ui`, which has no other reason to decode a
// pixel: the app layer owns the decode on the import path, and this only
// needs to paint.

import 'package:flutter/material.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/src/keymap/keymap.dart' show dialogDismissShortcut;

/// Width the grid decodes thumbnails at.
///
/// Not the tile's layout width: it is what the decoder is asked for, and
/// a little above the tile so a high-DPI screen is not painting an
/// upscaled thumbnail.
const int kPageThumbnailDecodeWidth = 320;

/// Shows the grid and returns the chosen page, or null if cancelled.
Future<PdfPageOption?> pickPdfPage(
  BuildContext context, {
  required List<Outcome<PdfPageOption>> pages,
  required String fileName,
}) => showDialog<PdfPageOption>(
  context: context,
  builder: (context) => PdfPagePickerDialog(pages: pages, fileName: fileName),
);

/// The grid itself. Public so a widget test can pump it without a route.
class PdfPagePickerDialog extends StatelessWidget {
  const PdfPagePickerDialog({
    required this.pages,
    required this.fileName,
    super.key,
  });

  final List<Outcome<PdfPageOption>> pages;
  final String fileName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final usable = pages.whereType<Ok<PdfPageOption>>().length;

    return CallbackShortcuts(
      // Through the keymap registry rather than a literal `Esc`, so the row
      // is in the generated table and arbitration can see it (CR-101).
      bindings: dialogDismissShortcut(() => Navigator.of(context).pop()),
      child: AlertDialog(
        title: const Text('Choose a page'),
        content: SizedBox(
          width: 720,
          height: 480,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                // THE COUNTS ARE BOTH STATED. "18 pages" alone hides that
                // one of them cannot be used; "17 pages" would be a lie
                // about the file.
                usable == pages.length
                    ? '$fileName, ${pages.length} pages'
                    : '$fileName, $usable of ${pages.length} pages can be '
                          'used',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 220,
                    childAspectRatio: 0.78,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                  ),
                  itemCount: pages.length,
                  itemBuilder: (context, i) => _PageTile(
                    outcome: pages[i],
                    pageNumber: i + 1,
                    onPick: (page) => Navigator.of(context).pop(page),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}

class _PageTile extends StatelessWidget {
  const _PageTile({
    required this.outcome,
    required this.pageNumber,
    required this.onPick,
  });

  final Outcome<PdfPageOption> outcome;
  final int pageNumber;
  final void Function(PdfPageOption) onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return switch (outcome) {
      Ok(:final value) => _liveTile(context, theme, value),
      Err(:final error) => _deadTile(theme, error),
    };
  }

  Widget _liveTile(BuildContext context, ThemeData theme, PdfPageOption page) {
    final dpi = page.resultDpi;
    // THE SIZE AS SEEN, which is what the tile shows above it. A lifted page
    // with an odd `/Rotate` is stored one way and shown the other
    // (DR-184 §11.183.6), and a portrait pair of numbers under a landscape
    // picture reads as a mistake.
    final turned = page.quarterTurns.isOdd;
    final seenW = turned ? page.resultHeight : page.resultWidth;
    final seenH = turned ? page.resultWidth : page.resultHeight;
    return Tooltip(
      message: 'Page $pageNumber',
      child: InkWell(
        onTap: () => onPick(page),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: theme.dividerColor),
                  color: Colors.white,
                ),
                // TURNED THE WAY THE PLAN WILL ARRIVE (DR-184 §11.183.6).
                // A lifted page previews its embedded image as stored, and
                // before the ruling a `/Rotate 90` page showed sideways here
                // and then imported sideways too. `RotatedBox` turns the
                // LAYOUT, so the tile's `contain` fit reads the turned
                // aspect rather than letterboxing a sideways one.
                child: RotatedBox(
                  quarterTurns: page.quarterTurns,
                  child: Image.memory(
                    page.previewBytes,
                    cacheWidth: kPageThumbnailDecodeWidth,
                    fit: BoxFit.contain,
                    // A page whose bytes will not decode is not a crash:
                    // the header parsed, so the file lied or is damaged,
                    // and the tile says so rather than taking the dialog
                    // down. TURNED BACK, because it sits inside the
                    // `RotatedBox` and words are not a picture.
                    errorBuilder: (_, _, _) => RotatedBox(
                      quarterTurns: (4 - page.quarterTurns) % 4,
                      child: Center(
                        child: Text(
                          'Preview unavailable',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text('Page $pageNumber', style: theme.textTheme.labelMedium),
            Text(
              // THE RESOLUTION IS SHOWN BECAUSE DR-137 MADE IT MEANINGFUL:
              // it is the ceiling on what this page can ever show, and a
              // person wondering why a 36-inch sheet looks soft is owed the
              // number rather than left to guess.
              dpi == null
                  ? '$seenW x $seenH'
                  : '$seenW x $seenH, ${dpi.round()} dpi',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _deadTile(ThemeData theme, Object error) {
    final reason = error is PdfPageNotLiftableError
        ? error.reason
        : 'could not be read';
    return Opacity(
      opacity: 0.55,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: theme.dividerColor),
                color: theme.colorScheme.surfaceContainerHighest,
              ),
              child: Center(
                child: Icon(
                  Icons.block_outlined,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text('Page $pageNumber', style: theme.textTheme.labelMedium),
          Text(
            // THE REASON, NOT "unsupported". DR-138 §11.137.4: a refusal
            // that says "not supported" tells somebody the product decided
            // something it has not.
            reason,
            style: theme.textTheme.bodySmall,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
