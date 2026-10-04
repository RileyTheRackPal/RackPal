// packages/rackpal_ui/lib/src/export/export_preview_dialog.dart
// M6-I4 (`#355`), DR-230 §11.229: the export preview, which shows the REAL
// file before it is saved.
//
// ═════════════════════════════════════════════════════════════════════
// THE PAGES ARE THE BYTES
// ═════════════════════════════════════════════════════════════════════
// DR-230 §11.229.1: the export is generated once and these are its pages,
// rasterised by the vendored pdfium; Save… writes exactly what was shown.
// This widget never sees pdfium. It asks a [PreviewPageRenderer] for a
// page at a size, and the app answers through the rasteriser it already
// uses for floorplan import, so this package keeps its no-native-code
// shape and a test hands it a closure.
//
// THE LAYOUT IS THE USER'S CHOICE (2026-10-04): a large dialog, the page on
// the left, the sheet list and the notices on the right, because the
// notices are what say a sheet is wrong before a client does.
//
// A MISSING RENDERER NEVER HOLDS THE FILE (CR-023, G3): the page area says
// so, and Save… still writes.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rackpal_ui/src/theme/console_theme.dart';

/// What the renderer gives back for one page.
@immutable
sealed class PreviewRender {
  const PreviewRender();
}

/// The page, as PNG bytes.
final class PreviewImage extends PreviewRender {
  const PreviewImage(this.png);

  final Uint8List png;
}

/// No picture, and why, in a sentence.
final class PreviewUnavailable extends PreviewRender {
  const PreviewUnavailable(this.reason);

  final String reason;
}

/// Renders page [page] (0-based) at [width] by [height] pixels.
typedef PreviewPageRenderer =
    PreviewRender Function(int page, {required int width, required int height});

/// One page as the preview lists it.
@immutable
final class PreviewSheet {
  const PreviewSheet({
    required this.ncsId,
    required this.title,
    required this.widthPt,
    required this.heightPt,
  });

  final String ncsId;
  final String title;
  final double widthPt;
  final double heightPt;
}

/// Everything the preview shows.
@immutable
final class ExportPreview {
  const ExportPreview({
    required this.projectName,
    required this.sheets,
    required this.sizeLabel,
    required this.notices,
    required this.renderPage,
    this.countWarning,
    this.stampLine,
  });

  final String projectName;
  final List<PreviewSheet> sheets;

  /// `64 KB`.
  final String sizeLabel;
  final List<String> notices;
  final PreviewPageRenderer renderPage;

  /// Said beside the count when the set runs past 40 sheets (DR-230
  /// §11.229.2), or null.
  final String? countWarning;

  /// The stamp's outcome when one was asked for (DR-216), or null.
  final String? stampLine;
}

/// The dialog's title, before the project's name.
const String kExportPreviewTitle = 'Export preview';

/// The confirming button. The save dialog follows it.
const String kExportPreviewSave = 'Save…';

/// The heading over the sheet list.
const String kExportPreviewSheets = 'SHEETS';

/// The heading over the notices.
String exportPreviewNoticesHeading(int n) => 'NOTICES ($n)';

/// What the notices pane says when there are none.
const String kExportPreviewNoNotices = 'No notices.';

/// What the count says past 40 sheets (DR-230 §11.229.2).
const String kExportPreviewLargeSet = 'more sheets than a set usually needs';

/// `5 / 16`.
String exportPreviewPosition(int page, int pages) => '${page + 1} / $pages';

/// Shows [preview]. True when the user chose Save…, false when they
/// closed it, which writes nothing.
Future<bool> showExportPreviewDialog(
  BuildContext context,
  ExportPreview preview,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (_) => _ExportPreviewDialog(preview: preview),
    ) ??
    false;

class _ExportPreviewDialog extends StatefulWidget {
  const _ExportPreviewDialog({required this.preview});

  final ExportPreview preview;

  @override
  State<_ExportPreviewDialog> createState() => _ExportPreviewDialogState();
}

class _ExportPreviewDialogState extends State<_ExportPreviewDialog> {
  var _page = 0;

  /// Rendered pages by `(page, width)`. A page is rasterised once per size
  /// it is shown at, not once per frame.
  final Map<(int, int), PreviewRender> _rendered = {};

  int get _pages => widget.preview.sheets.length;

  void _go(int page) {
    if (page < 0 || page >= _pages || page == _page) return;
    setState(() => _page = page);
  }

  PreviewRender _render(int page, int width, int height) =>
      _rendered.putIfAbsent(
        (page, width),
        () => widget.preview.renderPage(page, width: width, height: height),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final p = widget.preview;
    final size = MediaQuery.sizeOf(context);
    final sheet = _pages == 0 ? null : p.sheets[_page];
    // BARE KEYS, READ BY THE FOCUS AND NOT BOUND AS CHORDS: D7 keeps every
    // modifier chord in the keymap registry, where arbitration can see it,
    // and an unmodified arrow inside one dialog is the palette's
    // Escape-and-Enter idiom rather than a binding.
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (HardwareKeyboard.instance.isControlPressed ||
            HardwareKeyboard.instance.isAltPressed ||
            HardwareKeyboard.instance.isMetaPressed ||
            HardwareKeyboard.instance.isShiftPressed) {
          return KeyEventResult.ignored;
        }
        final key = event.logicalKey;
        if (key == LogicalKeyboardKey.arrowLeft ||
            key == LogicalKeyboardKey.pageUp) {
          _go(_page - 1);
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowRight ||
            key == LogicalKeyboardKey.pageDown) {
          _go(_page + 1);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Dialog(
        insetPadding: EdgeInsets.symmetric(
          horizontal: size.width * 0.05,
          vertical: size.height * 0.05,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    '$kExportPreviewTitle · ${p.projectName} · '
                    '$_pages sheets · ${p.sizeLabel}',
                    style: theme.textTheme.titleMedium,
                  ),
                  if (p.countWarning case final warning?)
                    Text(
                      warning,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.error,
                      ),
                    ),
                  if (p.stampLine case final stamp?)
                    Text(stamp, style: theme.textTheme.bodySmall),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: sheet == null
                          ? const SizedBox.shrink()
                          : _PageView(
                              key: ValueKey('preview-page-$_page'),
                              sheet: sheet,
                              render: (w, h) => _render(_page, w, h),
                            ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(width: 300, child: _sidebar(theme)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  IconButton(
                    key: const ValueKey('preview-previous'),
                    tooltip: 'Previous sheet',
                    icon: const Icon(Icons.chevron_left),
                    onPressed: _page > 0 ? () => _go(_page - 1) : null,
                  ),
                  Text(exportPreviewPosition(_page, _pages)),
                  IconButton(
                    key: const ValueKey('preview-next'),
                    tooltip: 'Next sheet',
                    icon: const Icon(Icons.chevron_right),
                    onPressed: _page < _pages - 1 ? () => _go(_page + 1) : null,
                  ),
                  if (sheet != null) ...[
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '${sheet.ncsId} ${sheet.title}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(
                      MaterialLocalizations.of(context).closeButtonLabel,
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text(kExportPreviewSave),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sidebar(ThemeData theme) {
    final p = widget.preview;
    final heading = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.primary,
      fontWeight: kConsoleEmphasis,
      letterSpacing: 0.8,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(kExportPreviewSheets, style: heading),
        const SizedBox(height: 4),
        Expanded(
          flex: 3,
          child: ListView.builder(
            itemCount: _pages,
            itemBuilder: (context, i) {
              final s = p.sheets[i];
              return ListTile(
                key: ValueKey('preview-sheet-$i'),
                dense: true,
                visualDensity: VisualDensity.compact,
                selected: i == _page,
                title: Text(
                  '${s.ncsId}  ${s.title}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => _go(i),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Text(exportPreviewNoticesHeading(p.notices.length), style: heading),
        const SizedBox(height: 4),
        Expanded(
          flex: 2,
          child: p.notices.isEmpty
              ? Text(kExportPreviewNoNotices, style: theme.textTheme.bodySmall)
              : ListView(
                  children: [
                    for (final n in p.notices)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(n, style: theme.textTheme.bodySmall),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

/// One page, fitted to the space at its own proportions.
class _PageView extends StatelessWidget {
  const _PageView({required this.sheet, required this.render, super.key});

  final PreviewSheet sheet;
  final PreviewRender Function(int width, int height) render;

  /// The most pixels a page is rendered across: a 4K screen's worth, so a
  /// huge window does not ask pdfium for a poster.
  static const int _maxWidthPx = 2400;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final aspect = sheet.widthPt / sheet.heightPt;
        var w = box.maxWidth;
        var h = w / aspect;
        if (h > box.maxHeight) {
          h = box.maxHeight;
          w = h * aspect;
        }
        final dpr = MediaQuery.devicePixelRatioOf(context);
        final px = (w * dpr).round().clamp(1, _maxWidthPx);
        final rendered = render(px, (px / aspect).round());
        return Center(
          child: SizedBox(
            width: w,
            height: h,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: switch (rendered) {
                PreviewImage(:final png) => Image.memory(
                  png,
                  gaplessPlayback: true,
                ),
                PreviewUnavailable(:final reason) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      reason,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.black87),
                    ),
                  ),
                ),
              },
            ),
          ),
        );
      },
    );
  }
}
