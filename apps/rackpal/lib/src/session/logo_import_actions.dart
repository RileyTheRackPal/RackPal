// The integrator's logo: File ▸ Sheet set…'s `Choose logo…` (`#590`,
// DR-030, DR-217).
//
// ═══════════════════════════════════════════════════════════════════════
// FOUR FORMATS IN, ONE KIND OF MEMBER OUT
// ═══════════════════════════════════════════════════════════════════════
// DR-217 §11.216.1 takes PNG, JPEG, PDF and SVG, and §11.216.2 stores a
// raster, so `ProjectLogo` mirrors `PlanUnderlay` and `rackpal_core` needs
// no decoder:
//
//   PNG, JPEG   -> verbatim, flattened only over alpha
//   PDF         -> page one rendered by pdfium to fit the logo box at
//                  600 dpi, 834 x 375 px
//   SVG         -> drawn as a one-page PDF by the `pdf` package, then as
//                  a PDF
//
// AND EVERY ONE OF THEM ENDS IN `storeImportedRaster`, the floorplan's own
// sequence: sniff, header under the caps, decode, re-check, flatten. A
// raster this file rendered is still checked, on `importRenderedPdfPage`'s
// reason: producing the bytes is not a reason to trust them.
//
// ═══════════════════════════════════════════════════════════════════════
// THE SVG IS CHECKED BEFORE ANYTHING DRAWS IT
// ═══════════════════════════════════════════════════════════════════════
// `pdf`'s SVG support decodes every embedded `data:` image with no cap,
// and throws on one it cannot decode. So the text is capped at 4 MB before
// it is parsed, an `<!ENTITY` declaration is refused outright (`xml`
// expands none, and a logo has no use for one), and every embedded image
// goes through `readImageHeader`'s caps before `pdf` sees it. Nothing in
// either parser touches a file or the network: `pdf` follows `data:` hrefs
// only.
import 'dart:convert';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:rackpal/src/session/document_session.dart';
import 'package:rackpal/src/session/file_picker.dart';
import 'package:rackpal/src/session/pdf_rasteriser.dart';
import 'package:rackpal/src/session/plan_import_actions.dart';
import 'package:rackpal/src/storage/file_store.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_pdfium/rackpal_pdfium.dart';
import 'package:xml/xml.dart';

/// The most bytes of SVG text this reads (DR-217 §11.216.2). Parsed before
/// anything else bounds it, so it is capped well below the image cap.
const int kMaxLogoSvgBytes = 4 * 1024 * 1024;

/// The pixel box a PDF or SVG logo is rendered to fit: the 100 x 45 pt
/// logo box at 600 dpi (DR-217 §11.216.2).
const int kLogoRenderWidthPx = 834;
const int kLogoRenderHeightPx = 375;

/// The longer side of the page an SVG is drawn on, in points. The page
/// takes the SVG's aspect; its size only has to be sane, since pdfium
/// renders it to [kLogoRenderWidthPx] by [kLogoRenderHeightPx] regardless.
const double _kSvgPagePt = 1000;

/// The file is none of the four formats.
final class LogoFormatError implements Exception {
  const LogoFormatError();

  @override
  String toString() => 'A logo must be a PNG, JPEG, PDF or SVG file.';
}

/// An SVG over [kMaxLogoSvgBytes].
final class LogoSvgTooLargeError implements Exception {
  const LogoSvgTooLargeError(this.bytes);

  final int bytes;

  @override
  String toString() =>
      'That SVG is ${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB; a logo '
      'SVG may be at most ${kMaxLogoSvgBytes ~/ (1024 * 1024)} MB.';
}

/// An SVG this will not draw, and why.
final class LogoSvgRefusedError implements Exception {
  const LogoSvgRefusedError(this.reason);

  final String reason;

  @override
  String toString() => 'That SVG cannot be used as a logo: $reason.';
}

/// A PDF with no page to take.
final class LogoPdfEmptyError implements Exception {
  const LogoPdfEmptyError();

  @override
  String toString() => 'That PDF has no pages.';
}

/// Renders page one of a PDF to fit `maxWidth` by `maxHeight` pixels,
/// aspect kept, as PNG bytes.
typedef LogoPdfRenderer =
    Outcome<Uint8List> Function(
      Uint8List pdf, {
      required int maxWidth,
      required int maxHeight,
    });

/// A logo, ready to become `ProjectInfo.logo`: the value and the container
/// member it names, together for `ImportedFloorplan`'s reason.
final class ImportedLogo {
  const ImportedLogo({required this.logo, required this.memberBytes});

  final ProjectLogo logo;

  /// What must be written to the container at `logo.imageMember`.
  final Uint8List memberBytes;
}

/// The largest whole-pixel size of [widthPt] : [heightPt] inside
/// [maxWidth] by [maxHeight], never below one pixel.
(int, int) fitPixels(
  double widthPt,
  double heightPt, {
  required int maxWidth,
  required int maxHeight,
}) {
  final aspect = widthPt / heightPt;
  if (aspect >= maxWidth / maxHeight) {
    final h = (maxWidth / aspect).round();
    return (maxWidth, h < 1 ? 1 : h);
  }
  final w = (maxHeight * aspect).round();
  return (w < 1 ? 1 : w, maxHeight);
}

/// The real [LogoPdfRenderer], over the vendored pdfium (DR-153).
Outcome<Uint8List> pdfiumRenderFirstPageToFit(
  Uint8List pdf, {
  required int maxWidth,
  required int maxHeight,
}) {
  final opened = PdfiumDocument.open(pdf);
  if (opened case Err(:final error)) return Err(error);
  final document = (opened as Ok<PdfiumDocument>).value;
  final (int, int) pixels;
  // CLOSED BEFORE THE RENDER OPENS IT AGAIN, and whatever happened: native
  // memory nothing else reclaims (`pdfiumRenderPng`'s own reason).
  try {
    if (document.pageCount < 1) return const Err(LogoPdfEmptyError());
    final sized = document.sizeOf(0);
    if (sized case Err(:final error)) return Err(error);
    final size = (sized as Ok<PdfiumPageSize>).value;
    pixels = fitPixels(
      size.widthPt,
      size.heightPt,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
    );
  } finally {
    document.close();
  }
  return pdfiumRenderPng(pdf, 0, width: pixels.$1, height: pixels.$2);
}

/// Whether [bytes] read as SVG text: markup first, and an `<svg` tag near
/// the top. A sniff and not a check; [svgLogoToPdf] is the check.
bool looksLikeSvg(Uint8List bytes) {
  final head = latin1.decode(
    bytes.length > 4096 ? bytes.sublist(0, 4096) : bytes,
    allowInvalid: true,
  );
  // A UTF-8 byte-order mark reads as these three characters in Latin-1.
  final text = head.startsWith('ï»¿') ? head.substring(3) : head;
  return text.trimLeft().startsWith('<') && text.contains('<svg');
}

/// The SVG's own aspect, as `pdf` reads it: the `viewBox`, else `width`
/// and `height`, else 1000 by 1000.
(double, double)? _svgSize(XmlElement root) {
  double? number(String? raw) {
    if (raw == null) return null;
    final m = RegExp(r'^\s*([0-9]*\.?[0-9]+(?:[eE][-+]?[0-9]+)?)').firstMatch(
      raw,
    );
    return m == null ? null : double.tryParse(m.group(1)!);
  }

  final viewBox = root.getAttribute('viewBox');
  if (viewBox != null) {
    final parts = viewBox
        .split(RegExp(r'[\s,]+'))
        .where((p) => p.isNotEmpty)
        .map(double.tryParse)
        .toList();
    if (parts.length != 4 || parts.any((p) => p == null)) return null;
    return (parts[2]!, parts[3]!);
  }
  final w = number(root.getAttribute('width'));
  final h = number(root.getAttribute('height'));
  return (w ?? 1000, h ?? 1000);
}

/// Draws an SVG logo as a one-page PDF, after the checks this file's
/// header lists.
Future<Outcome<Uint8List>> svgLogoToPdf(Uint8List bytes) async {
  if (bytes.length > kMaxLogoSvgBytes) {
    return Err(LogoSvgTooLargeError(bytes.length));
  }
  final String text;
  try {
    text = utf8.decode(bytes);
  } on FormatException {
    return const Err(LogoSvgRefusedError('it is not UTF-8 text'));
  }
  if (text.contains('<!ENTITY')) {
    return const Err(LogoSvgRefusedError('it declares XML entities'));
  }
  final XmlDocument xml;
  try {
    xml = XmlDocument.parse(text);
  } on Object {
    return const Err(LogoSvgRefusedError('it is not well-formed XML'));
  }
  final root = xml.rootElement;
  if (root.localName != 'svg') {
    return const Err(LogoSvgRefusedError('its root element is not <svg>'));
  }
  final size = _svgSize(root);
  if (size == null ||
      !size.$1.isFinite ||
      !size.$2.isFinite ||
      size.$1 <= 0 ||
      size.$2 <= 0) {
    return const Err(LogoSvgRefusedError('it has no usable size'));
  }

  // EVERY EMBEDDED IMAGE `pdf` WILL DECODE, through the floorplan's caps
  // first. The same test `pdf` applies to decide what it decodes, so what
  // passes here is exactly what it would have drawn.
  //
  // AND RE-ENCODED AS RGBA, because `pdf` HANDS THE DECODED BUFFER ON AS IF
  // IT WERE ALWAYS FOUR CHANNELS: an RGB PNG or any JPEG throws a
  // `RangeError` inside it (found by this file's own test). A logo SVG with
  // an embedded JPEG is an ordinary Illustrator export, so the image is
  // decoded here under the caps, given its alpha channel, and put back.
  for (final image in xml.descendantElements.where(
    (e) => e.localName == 'image',
  )) {
    final attribute =
        image.getAttributeNode('href') ??
        image.getAttributeNode(
          'href',
          namespaceUri: 'http://www.w3.org/1999/xlink',
        );
    final href = attribute?.value;
    if (attribute == null || href == null || !href.startsWith('data:')) {
      continue;
    }
    final payload = href.substring(href.indexOf(';') + 1);
    if (!payload.startsWith('base64,')) continue;
    final Uint8List data;
    try {
      data = base64.decode(payload.substring(7).replaceAll(RegExp(r'\s'), ''));
    } on FormatException {
      return const Err(
        LogoSvgRefusedError('an embedded image is not valid base64'),
      );
    }
    final headerRead = readImageHeader(data);
    if (headerRead case Err(:final error)) {
      return Err(LogoSvgRefusedError('an embedded image is refused ($error)'));
    }
    final header = (headerRead as Ok<ImageHeader>).value;
    final img.Image? decoded;
    try {
      decoded = img.decodeImage(data);
    } on Object {
      return const Err(
        LogoSvgRefusedError('an embedded image will not decode'),
      );
    }
    if (decoded == null ||
        decoded.width != header.pixelWidth ||
        decoded.height != header.pixelHeight) {
      return const Err(
        LogoSvgRefusedError('an embedded image will not decode'),
      );
    }
    final rgba = img.encodePng(decoded.convert(numChannels: 4));
    attribute.value = 'data:image/png;base64,${base64.encode(rgba)}';
  }

  final scale = _kSvgPagePt / (size.$1 > size.$2 ? size.$1 : size.$2);
  final page = PdfPageFormat(size.$1 * scale, size.$2 * scale);
  final checked = xml.toXmlString();
  final document = pw.Document()
    ..addPage(
      pw.Page(
        pageFormat: page,
        build: (_) => pw.SvgImage(svg: checked),
      ),
    );
  try {
    return Ok(await document.save());
    // `on Object`: `pdf`'s SVG support is partial and throws what it
    // throws (a `!` on an image it cannot decode, among others). Any of it
    // is "this SVG cannot be drawn", which is the answer a person can use.
  } on Object catch (e) {
    return Err(LogoSvgRefusedError('it could not be drawn ($e)'));
  }
}

/// Turns a file's bytes into a logo, whatever the four formats it is.
Future<Outcome<ImportedLogo>> importLogoBytes({
  required Uint8List bytes,
  required Uuid id,
  LogoPdfRenderer renderPdf = pdfiumRenderFirstPageToFit,
}) async {
  Outcome<Uint8List> render(Uint8List pdf) => renderPdf(
    pdf,
    maxWidth: kLogoRenderWidthPx,
    maxHeight: kLogoRenderHeightPx,
  );

  final Uint8List raster;
  switch (sniffImportKind(bytes)) {
    case SniffedImportKind.png || SniffedImportKind.jpeg:
      raster = bytes;
    case SniffedImportKind.pdf:
      final rendered = render(bytes);
      if (rendered case Err(:final error)) return Err(error);
      raster = (rendered as Ok<Uint8List>).value;
    case SniffedImportKind.unknown:
      if (!looksLikeSvg(bytes)) return const Err(LogoFormatError());
      final pdf = await svgLogoToPdf(bytes);
      if (pdf case Err(:final error)) return Err(error);
      final rendered = render((pdf as Ok<Uint8List>).value);
      if (rendered case Err(:final error)) return Err(error);
      raster = (rendered as Ok<Uint8List>).value;
  }

  final stored = storeImportedRaster(raster);
  if (stored case Err(:final error)) return Err(error);
  final r = (stored as Ok<StoredRaster>).value;
  return Ok(
    ImportedLogo(
      logo: ProjectLogo(
        imageMember: '$kLogoMemberDir${id.v}.${r.format.extension}',
        format: r.format,
        pixelWidth: r.pixelWidth,
        pixelHeight: r.pixelHeight,
        contentHash: r.contentHash,
      ),
      memberBytes: r.bytes,
    ),
  );
}

/// `Choose logo…` and `Replace logo…`, a sibling of `FloorplanIo`.
///
/// **THE MEMBER IS WRITTEN FIRST**, then the command, for `FloorplanIo`'s
/// reason: the reverse order can leave a document naming bytes the
/// container does not hold. A replaced logo's old member stays, as an
/// undone floorplan's does, so Undo can find it.
final class LogoIo {
  const LogoIo({
    required this.session,
    required this.picker,
    required this.fs,
    this.initialDirectory,
    this.renderPdf = pdfiumRenderFirstPageToFit,
  });

  final DocumentSession session;
  final FilePicker picker;
  final FileStore fs;
  final Future<String?> Function()? initialDirectory;
  final LogoPdfRenderer renderPdf;

  /// Asks for a file and makes it the logo: the logo on success, `null`
  /// when the person cancelled, an `Err` carrying the refusal.
  Future<Outcome<ProjectLogo>?> choose() async {
    final path = await picker.pickOpen(
      initialDirectory: await initialDirectory?.call(),
      type: FileDialogType.logo,
    );
    if (path == null) return null;

    final read = await readImportedBytes(fs: fs, path: path);
    if (read case Err(:final error)) return Err(error);

    final imported = await importLogoBytes(
      bytes: (read as Ok<Uint8List>).value,
      id: newEntityId(),
      renderPdf: renderPdf,
    );
    if (imported case Err(:final error)) return Err(error);
    final logo = (imported as Ok<ImportedLogo>).value;

    session.addMember(logo.logo.imageMember, logo.memberBytes);
    session.controller.run(
      SetProjectLogoCommand.to(session.document.info, logo.logo),
    );
    return Ok(logo.logo);
  }
}
