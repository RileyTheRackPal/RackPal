// rackpal_core/src/persistence/pdf_page_lift.dart — the page a PDF already
// contains, lifted rather than re-drawn (DR-138, PLAN-D/3).
//
// ═══════════════════════════════════════════════════════════════════════
// THIS IS NOT A PDF READER AND MUST NEVER BECOME ONE
// ═══════════════════════════════════════════════════════════════════════
// It answers exactly one question: **is this page nothing but one
// full-page image, and if so, which bytes are that image?** Everything it
// cannot prove it understands is REFUSED, by name, with the reason.
//
// The alternative was pdfium, and DR-138 records why it is not here yet:
// every `pdfrx` route downloads pdfium at build time and CR-100 rules that
// pdfium is vendored rather than downloaded, so the package chosen to make
// vendoring "one problem paid once" cannot accept a vendored binary.
//
// **LIFTING IS NOT A CHEAPER RASTERISATION, IT IS A BETTER ONE.**
// Rasterising a page whose only content is a JPEG decodes that JPEG and
// re-encodes the result: it loses a generation and cannot gain a pixel,
// which DR-137 §11.136.4 settled with a measurement. Lifting yields the
// exact bytes the architect's office exported.
//
// ═══════════════════════════════════════════════════════════════════════
// THE DETECTION IS A PARSE, NOT A HEURISTIC, AND THAT IS THE WHOLE SAFETY
// ARGUMENT
// ═══════════════════════════════════════════════════════════════════════
// A page qualifies only when ALL of these hold:
//
//   1. `/Resources /XObject` names **exactly one** object.
//   2. That object is `/Subtype /Image` with `/Filter /DCTDecode`.
//   3. The content stream contains **exactly one** `Do`, and it names
//      that XObject.
//   4. **No text-showing and no path-painting operator appears at all.**
//      An empty `BT`/`ET` pair is fine and is what the real corpus emits;
//      a `Tj` inside it is a stamp, a revision cloud or a redaction, and
//      lifting the image alone would silently drop it.
//   5. The `cm` matrix scales the unit square to within a small tolerance
//      of the `MediaBox`, so a thumbnail pasted in a corner is not
//      mistaken for the sheet.
//
// Rule 4 is the one that earns its keep. Rules 1 to 3 can all hold on a
// page that ALSO has a "VOID" stamped across it, and a lifter that
// dropped that would hand an installer a superseded drawing.
//
// ═══════════════════════════════════════════════════════════════════════
// EVERY BYTE HERE IS HOSTILE AND NOTHING THROWS
// ═══════════════════════════════════════════════════════════════════════
// AC-058/D8 and CR-093, the same contract `image_header.dart` keeps one
// file over. A truncated file, a lying `/Length`, an object offset past
// the end, a cyclic page tree: all are `Err`, none is an exception and
// none is an out-of-range read. Recursion is depth-bounded and object
// resolution is cycle-guarded, because a PDF is a graph a stranger wrote.
import 'dart:convert';
import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:rackpal_core/src/persistence/image_header.dart';
import 'package:rackpal_core/src/persistence/json_limits.dart';
import 'package:rackpal_core/src/util/outcome.dart';

/// The largest PDF the lifter will look at (AC-058/D8).
///
/// Matches [kMaxImageBytes] deliberately: a plan set is a bundle of the
/// same pages this cap already admits one of, and an 18-sheet permit set
/// measured 9.7 MB (docs/12 §5.9.5), so 64 MB is generous without being
/// an invitation.
const int kMaxPdfBytes = kMaxImageBytes;

/// The most pages the picker will enumerate.
///
/// **A COUNT CAP, NOT A SIZE CAP, AND IT IS A DIFFERENT DEFENCE.** The
/// byte cap above bounds what is read; this bounds what is BUILT, because
/// the picker decodes a thumbnail per page and a file declaring 100,000
/// pages would exhaust memory inside a cap it never breached. A permit
/// set is tens of sheets.
const int kMaxPdfPages = 512;

/// How far object resolution will follow indirect references.
///
/// A PDF is a graph written by a stranger, so `5 0 R` can point at `6 0 R`
/// pointing back at `5 0 R`. The cycle guard catches that; this catches
/// the legal-but-absurd chain that is not a cycle.
const int kMaxPdfRefDepth = 32;

/// How far the `/Pages` tree is walked. Page trees are shallow in
/// practice and a deep one is a fuzzer's, not an architect's.
const int kMaxPdfPageTreeDepth = 32;

/// The `cm` matrix must cover the MediaBox to within this fraction.
///
/// Not zero, because the real corpus places a 2160 px image on a 2592 pt
/// sheet with a 54 pt margin: 2484/2592 is 95.8% of the width. A page
/// whose image covers less than this is an illustration on a sheet, not
/// the sheet.
const int kMinPageCoveragePermille = 900;

// ─────────────────────────────────────────────────────────────────────────
// FAILURES, EACH SAYING WHAT IT WOULD TAKE
// ─────────────────────────────────────────────────────────────────────────
// On `PdfImportNotAvailableError`'s precedent (DR-029 §11.28.5): a refusal
// reading "not supported" tells somebody the product decided something it
// has not, and sends them to convert the file by hand believing they must.

/// The bytes are not a PDF at all.
final class NotAPdfError implements Exception {
  const NotAPdfError();

  @override
  String toString() => 'NotAPdfError: the file does not begin with %PDF-.';
}

/// The file is structurally damaged, or uses something the lifter cannot
/// see past. [detail] says which.
final class PdfUnreadableError implements Exception {
  const PdfUnreadableError(this.detail);

  final String detail;

  @override
  String toString() => 'PdfUnreadableError: $detail';
}

/// The PDF hides its objects in a cross-reference stream (PDF 1.5+).
///
/// **ITS OWN ERROR BECAUSE IT IS ITS OWN PROBLEM.** The objects are there
/// and are perfectly valid; they are inside a compressed stream this
/// lifter does not decompress, so it cannot even see whether the page
/// would have qualified. That is a different sentence from "this page has
/// vector content", and conflating them would send somebody looking for
/// drawing content that is not the issue.
final class PdfCompressedCrossReferenceError implements Exception {
  const PdfCompressedCrossReferenceError();

  @override
  String toString() =>
      'PdfCompressedCrossReferenceError: this PDF stores its objects in a '
      'cross-reference stream, which needs a full renderer to read '
      '(PLAN-D/3, DR-138). Export the page as PNG or JPEG for now.';
}

/// The page is not one full-page image, and [reason] says which rule it
/// failed.
final class PdfPageNotLiftableError implements Exception {
  const PdfPageNotLiftableError({
    required this.pageIndex,
    required this.reason,
    this.sheetWidthPt,
    this.sheetHeightPt,
  });

  /// Zero-based.
  final int pageIndex;
  final String reason;

  /// The sheet in PostScript points, when the refusal came AFTER the
  /// `/MediaBox` was read, and null for the three refusals that are about
  /// the box itself.
  ///
  /// ═══════════════════════════════════════════════════════════════════
  /// A REFUSAL THAT CARRIES THE PAGE'S SIZE IS WHAT LETS SOMETHING ELSE
  /// RENDER IT (DR-153, `PLAN-K/4`)
  /// ═══════════════════════════════════════════════════════════════════
  /// `draws no image` is the ordinary answer for a CAD plot, and the
  /// caller's next question is how many pixels that page should become,
  /// which is a function of its size (§11.152.5). Reporting it here means
  /// the rasteriser is asked to DRAW rather than to re-parse a file this
  /// parser has already walked.
  ///
  /// It stays null for `declares no usable MediaBox`, `has a malformed
  /// MediaBox` and `has an empty MediaBox`, because there the size is the
  /// thing that failed.
  final double? sheetWidthPt;
  final double? sheetHeightPt;

  /// True when this page could be rendered by something that can draw
  /// vectors: the parse got far enough to know how big it is.
  bool get hasSheetSize => sheetWidthPt != null && sheetHeightPt != null;

  /// **IT SAYS WHAT THIS PARSER FOUND AND NOTHING ABOUT THE REMEDY**, and
  /// it used to say both. Until `PLAN-K` it ended *"cannot be lifted
  /// without a renderer ... Export the page as PNG or JPEG for now"*,
  /// which was advice about a feature that did not exist. It exists now
  /// (DR-153), and whether it is AVAILABLE is a fact about the caller
  /// rather than about this page, so the caller's own sentence says so.
  /// The same file one package over already carries a scar from copy that
  /// told somebody to convert by hand a file this product can open.
  @override
  String toString() =>
      'PdfPageNotLiftableError: page ${pageIndex + 1} $reason, so it has no '
      'image to lift (PLAN-D/3, DR-138).';
}

/// One page of a PDF whose image can be lifted whole.
@immutable
final class LiftedPdfPage {
  const LiftedPdfPage({
    required this.pageIndex,
    required this.bytes,
    required this.header,
    required this.sheetWidthPt,
    required this.sheetHeightPt,
  });

  /// Zero-based, in the document's own page order.
  final int pageIndex;

  /// The embedded image, byte for byte as the PDF carries it.
  final Uint8List bytes;

  /// What [bytes] declares, read without decoding it.
  final ImageHeader header;

  /// The sheet, in PostScript points (72 per inch). An ARCH D landscape
  /// sheet is 2592 x 1728.
  final double sheetWidthPt;
  final double sheetHeightPt;

  /// Effective resolution of the lifted image over the sheet, in dots per
  /// inch, or null when the sheet has no width.
  ///
  /// **THE NUMBER DR-137 §11.136.4 TURNS ON.** It is the ceiling on any
  /// useful rasterisation of this page, and reporting it lets the picker
  /// say so rather than leaving somebody to wonder why a 36 inch sheet
  /// looks soft.
  double? get effectiveDpi =>
      sheetWidthPt <= 0 ? null : header.pixelWidth / (sheetWidthPt / 72.0);
}

/// Every page of [bytes] that is one full-page image.
///
/// Returns one entry per page **in page order**, each either a
/// [LiftedPdfPage] or the reason that page was refused, so the picker can
/// grey a page out and say why rather than dropping it silently. A
/// document with no liftable page at all is still `Ok`: the caller decides
/// whether that is an error, because "eighteen pages and none of them
/// liftable" is a different message from "this is not a PDF".
Outcome<List<Outcome<LiftedPdfPage>>> liftPdfPages(
  Uint8List bytes, {
  int maxBytes = kMaxPdfBytes,
  int maxPages = kMaxPdfPages,
}) {
  switch (checkImportSize(bytes.length, limit: maxBytes)) {
    case Err(:final error):
      return Err(error);
    case Ok<void>():
      break;
  }
  if (sniffImportKind(bytes) != SniffedImportKind.pdf) {
    return const Err(NotAPdfError());
  }

  final doc = _PdfObjects.scan(bytes);
  if (doc case Err(:final error)) return Err(error);
  final objects = (doc as Ok<_PdfObjects>).value;

  final pages = objects.findPages(maxPages: maxPages);
  if (pages case Err(:final error)) return Err(error);
  final pageObjects = (pages as Ok<List<Map<String, Object?>>>).value;

  return Ok([
    for (var i = 0; i < pageObjects.length; i++)
      objects.liftPage(pageObjects[i], i),
  ]);
}

// ═══════════════════════════════════════════════════════════════════════
// OBJECT ACCESS, BY SCAN RATHER THAN BY CROSS-REFERENCE TABLE
// ═══════════════════════════════════════════════════════════════════════
// A classic xref table is a list of byte offsets, and following it is the
// correct way to read a PDF. This scans for `N G obj` instead, and the
// reason is that the scan is STRICTLY MORE ROBUST FOR THE ONE QUESTION
// BEING ASKED: it survives a wrong offset, an incrementally-updated file
// whose earlier xref is stale, and a file whose trailer is damaged, all
// of which are ordinary in files that have been through three offices.
//
// The scan's real weakness is not offsets, it is OBJECT STREAMS: a PDF
// 1.5+ file can pack objects inside a compressed `/ObjStm`, where no scan
// will find them. That case is DETECTED and REFUSED by name rather than
// guessed at, which is what `PdfCompressedCrossReferenceError` is for.
//
// A later generation of the same object number wins, which is what an
// incremental update means.
final class _PdfObjects {
  _PdfObjects._(this._bytes, this._offsets);

  final Uint8List _bytes;
  final Map<int, int> _offsets;

  static final RegExp _objPattern = RegExp(r'(\d{1,10})\s+(\d{1,5})\s+obj');

  static Outcome<_PdfObjects> scan(Uint8List bytes) {
    // Latin-1 is a byte-preserving decode, so an offset in the string is
    // an offset in the file. UTF-8 would not be: a stream's arbitrary
    // bytes are not valid UTF-8 and every replacement character would
    // shift every offset after it.
    final text = latin1.decode(bytes, allowInvalid: true);

    if (text.contains('/ObjStm')) {
      return const Err(PdfCompressedCrossReferenceError());
    }

    final offsets = <int, int>{};
    for (final m in _objPattern.allMatches(text)) {
      // A digit immediately before the match means this is the tail of a
      // longer number inside a stream, not an object header.
      if (m.start > 0 && _isDigit(text.codeUnitAt(m.start - 1))) continue;
      final num = int.tryParse(m.group(1)!);
      if (num == null) continue;
      // Later definition wins: incremental updates append.
      offsets[num] = m.end;
    }
    if (offsets.isEmpty) {
      return const Err(PdfUnreadableError('no objects found'));
    }
    return Ok(_PdfObjects._(bytes, offsets));
  }

  /// The DICTIONARY text of object [number], or null.
  ///
  /// **IT STOPS AT `stream` AS WELL AS AT `endobj`, AND THE FIRST DRAFT
  /// DID NOT.** An image XObject is a dictionary followed by hundreds of
  /// kilobytes of JPEG, so scanning to `endobj` inside a 64 KB bound
  /// found neither and returned null: every page of the real plan set was
  /// refused with "has an unreadable image object" while the parser was
  /// working perfectly. Nothing here ever wants the stream body as text,
  /// so `stream` is a correct terminator and a much closer one.
  ///
  /// The bound stays, because scanning a damaged file to the end for
  /// every lookup is the failure it was there to prevent.
  String? _body(int number) {
    final start = _offsets[number];
    if (start == null || start >= _bytes.length) return null;
    final endObj = _indexOf('endobj', start, limit: 1 << 16);
    final endStream = _indexOf('stream', start, limit: 1 << 16);
    final end = switch ((endObj, endStream)) {
      (< 0, < 0) => -1,
      (< 0, final s) => s,
      (final o, < 0) => o,
      (final o, final s) => o < s ? o : s,
    };
    if (end < 0) return null;
    return latin1.decode(
      Uint8List.sublistView(_bytes, start, end),
      allowInvalid: true,
    );
  }

  int _indexOf(String needle, int from, {required int limit}) {
    final stop = (from + limit).clamp(0, _bytes.length);
    final units = needle.codeUnits;
    outer:
    for (var i = from; i + units.length <= stop; i++) {
      for (var j = 0; j < units.length; j++) {
        if (_bytes[i + j] != units[j]) continue outer;
      }
      return i;
    }
    return -1;
  }

  /// Resolves [value] through indirect references until it is not one.
  Object? resolve(Object? value, {int depth = 0}) {
    if (value is! _Ref) return value;
    if (depth >= kMaxPdfRefDepth) return null;
    final body = _body(value.number);
    if (body == null) return null;
    return resolve(_parseValue(body, 0).value, depth: depth + 1);
  }

  Map<String, Object?>? resolveDict(Object? value, {int depth = 0}) {
    final r = resolve(value, depth: depth);
    return r is Map<String, Object?> ? r : null;
  }

  /// Every page dictionary, in order.
  ///
  /// **THE ROOT IS FOUND BY SCANNING FOR `/Type /Pages` WITH NO PARENT**
  /// rather than through the trailer's `/Root`, for the same reason the
  /// objects are scanned: a damaged or stale trailer is ordinary and the
  /// page tree itself is not.
  Outcome<List<Map<String, Object?>>> findPages({required int maxPages}) {
    Map<String, Object?>? root;
    for (final number in _offsets.keys) {
      final body = _body(number);
      if (body == null) continue;
      if (!body.contains('/Pages')) continue;
      final dict = _parseValue(body, 0).value;
      if (dict is! Map<String, Object?>) continue;
      if (dict['Type'] != const _Name('Pages')) continue;
      if (dict.containsKey('Parent')) continue;
      root = dict;
      break;
    }
    if (root == null) {
      return const Err(PdfUnreadableError('no page tree root'));
    }

    final out = <Map<String, Object?>>[];
    final seen = <int>{};
    final overflowed = _walk(root, out, seen, 0, maxPages);
    if (overflowed) {
      return Err(
        PdfUnreadableError(
          'the page tree declares more than $maxPages pages, which is past '
          'anything a drawing set contains',
        ),
      );
    }
    if (out.isEmpty) {
      return const Err(PdfUnreadableError('the page tree holds no pages'));
    }
    return Ok(out);
  }

  /// Returns true if the page cap was exceeded.
  bool _walk(
    Map<String, Object?> node,
    List<Map<String, Object?>> out,
    Set<int> seen,
    int depth,
    int maxPages,
  ) {
    if (depth >= kMaxPdfPageTreeDepth) return false;
    final kids = resolve(node['Kids']);
    if (kids is! List<Object?>) return false;
    for (final kid in kids) {
      if (out.length > maxPages) return true;
      // CYCLE GUARD ON THE REFERENCE, not on the resolved dict: two
      // distinct objects may be equal maps, and refusing the second
      // would drop a legitimate repeated page.
      if (kid is _Ref) {
        if (!seen.add(kid.number)) continue;
      }
      final dict = resolveDict(kid);
      if (dict == null) continue;
      final type = dict['Type'];
      if (type == const _Name('Page')) {
        out.add(_inherited(dict, node));
        if (out.length > maxPages) return true;
      } else if (type == const _Name('Pages') || dict.containsKey('Kids')) {
        if (_walk(_inherited(dict, node), out, seen, depth + 1, maxPages)) {
          return true;
        }
      }
    }
    return false;
  }

  /// `/MediaBox` and `/Resources` are inheritable, so a page that omits
  /// them takes its parent's. Missing this makes an entire real-world
  /// class of file look like it has no sheet size.
  Map<String, Object?> _inherited(
    Map<String, Object?> child,
    Map<String, Object?> parent,
  ) {
    final merged = Map<String, Object?>.of(child);
    for (final key in const ['MediaBox', 'Resources', 'Rotate']) {
      if (!merged.containsKey(key) && parent.containsKey(key)) {
        merged[key] = parent[key];
      }
    }
    return merged;
  }

  /// The five rules, in the order that makes a refusal say the most
  /// useful thing.
  Outcome<LiftedPdfPage> liftPage(Map<String, Object?> page, int index) {
    // SET ONCE THE BOX IS READ, so every refusal BELOW that point carries
    // the page's size and something that can draw vectors knows how big
    // to draw it (DR-153 §11.152.5). The three refusals above it leave
    // these null, because there the size is what failed.
    double? knownW;
    double? knownH;
    Err<LiftedPdfPage> no(String reason) => Err(
      PdfPageNotLiftableError(
        pageIndex: index,
        reason: reason,
        sheetWidthPt: knownW,
        sheetHeightPt: knownH,
      ),
    );

    // ---- the sheet ---------------------------------------------------
    final box = resolve(page['MediaBox']);
    if (box is! List<Object?> || box.length != 4) {
      return no('declares no usable MediaBox');
    }
    final nums = [for (final v in box) _asDouble(resolve(v))];
    if (nums.any((v) => v == null)) return no('has a malformed MediaBox');
    final sheetW = (nums[2]! - nums[0]!).abs();
    final sheetH = (nums[3]! - nums[1]!).abs();
    if (sheetW <= 0 || sheetH <= 0) return no('has an empty MediaBox');
    knownW = sheetW;
    knownH = sheetH;

    // ---- rule 1: exactly one XObject ---------------------------------
    final resources = resolveDict(page['Resources']);
    if (resources == null) return no('has no resources');
    final xobjects = resolveDict(resources['XObject']);
    if (xobjects == null || xobjects.isEmpty) {
      return no('draws no image');
    }
    if (xobjects.length != 1) {
      return no('draws ${xobjects.length} images rather than one');
    }
    final xname = xobjects.keys.first;
    final xdict = resolveDict(xobjects[xname]);
    if (xdict == null) return no('has an unreadable image object');

    // ---- rule 2: it is a DCTDecode image ------------------------------
    if (xdict['Subtype'] != const _Name('Image')) {
      return no('draws a form rather than an image');
    }
    final filter = resolve(xdict['Filter']);
    final filterName = filter is List<Object?> && filter.length == 1
        ? resolve(filter.first)
        : filter;
    if (filterName != const _Name('DCTDecode')) {
      final shown = filterName is _Name ? '/${filterName.value}' : 'no filter';
      return no(
        'stores its image as $shown rather than DCTDecode, which would have '
        'to be re-encoded rather than lifted',
      );
    }

    // ---- rules 3 and 4: the content stream ----------------------------
    final content = _contentStreamText(page);
    if (content == null) return no('has an unreadable content stream');
    final shape = _readContentShape(content, xname);
    if (shape.reason != null) return no(shape.reason!);

    // ---- rule 5: it covers the sheet ----------------------------------
    final sx = shape.scaleX;
    final sy = shape.scaleY;
    if (sx == null || sy == null) return no('places its image without a scale');
    final coverW = (sx.abs() / sheetW * 1000).round();
    final coverH = (sy.abs() / sheetH * 1000).round();
    if (coverW < kMinPageCoveragePermille ||
        coverH < kMinPageCoveragePermille) {
      return no(
        'places its image over ${(coverW / 10).toStringAsFixed(1)}% by '
        '${(coverH / 10).toStringAsFixed(1)}% of the sheet, so it is an '
        'illustration on a page rather than the page',
      );
    }

    // ---- the bytes ----------------------------------------------------
    final raw = _streamBytesOf(xobjects[xname]);
    if (raw == null) return no('has an image stream that could not be read');
    final header = readImageHeader(raw);
    if (header case Err(:final error)) return Err(error);

    return Ok(
      LiftedPdfPage(
        pageIndex: index,
        bytes: raw,
        header: (header as Ok<ImageHeader>).value,
        sheetWidthPt: sheetW,
        sheetHeightPt: sheetH,
      ),
    );
  }

  /// The page's content, concatenated when `/Contents` is an array.
  ///
  /// **ONLY UNCOMPRESSED OR FLATE-FREE CONTENT IS READ AS TEXT**, and a
  /// compressed one is treated as unreadable rather than guessed at. A
  /// content stream this lifter cannot read is a page it cannot clear
  /// rule 4 on, and rule 4 is the one keeping a "VOID" stamp from being
  /// silently dropped.
  String? _contentStreamText(Map<String, Object?> page) {
    final contents = page['Contents'];
    final refs = <Object?>[];
    final resolved = resolve(contents);
    if (resolved is List<Object?>) {
      refs.addAll(contents is List<Object?> ? contents : resolved);
    } else {
      refs.add(contents);
    }
    final buffer = StringBuffer();
    for (final ref in refs) {
      final raw = _streamBytesOf(ref);
      if (raw == null) return null;
      buffer
        ..write(latin1.decode(raw, allowInvalid: true))
        ..write('\n');
    }
    return buffer.toString();
  }

  /// The undecoded bytes of the stream in object [ref].
  Uint8List? _streamBytesOf(Object? ref) {
    if (ref is! _Ref) return null;
    final start = _offsets[ref.number];
    if (start == null) return null;
    final head = _indexOf('stream', start, limit: 1 << 16);
    if (head < 0) return null;
    final dictText = latin1.decode(
      Uint8List.sublistView(_bytes, start, head),
      allowInvalid: true,
    );
    if (dictText.contains('/FlateDecode')) return null;
    final length = _asInt(resolve(_parseDictValue(dictText, 'Length')));
    if (length == null || length < 0) return null;

    var i = head + 'stream'.length;
    if (i < _bytes.length && _bytes[i] == 0x0D) i++;
    if (i < _bytes.length && _bytes[i] == 0x0A) i++;
    if (i + length > _bytes.length) return null;
    return Uint8List.sublistView(_bytes, i, i + length);
  }

  Object? _parseDictValue(String dictText, String key) {
    final dict = _parseValue(dictText, 0).value;
    return dict is Map<String, Object?> ? dict[key] : null;
  }
}

/// What a content stream turned out to contain.
final class _ContentShape {
  const _ContentShape({this.scaleX, this.scaleY, this.reason});

  final double? scaleX;
  final double? scaleY;
  final String? reason;
}

/// Operators that mean the page draws something other than its image.
///
/// **THE LIST IS DELIBERATELY LONG AND ERRS TOWARDS REFUSING.** A page
/// this lifter wrongly refuses costs somebody an export from their PDF
/// viewer. A page it wrongly accepts hands an installer a drawing with the
/// revision cloud, the "NOT FOR CONSTRUCTION" stamp, or the redaction box
/// quietly missing, and nothing downstream can detect that.
const Set<String> _kDrawingOperators = {
  // text showing
  'Tj', 'TJ', "'", '"',
  // path painting
  'S', 's', 'f', 'F', 'f*', 'B', 'B*', 'b', 'b*',
  // shading and inline images
  'sh', 'BI', 'ID', 'EI',
};

_ContentShape _readContentShape(String content, String expectedXObject) {
  final tokens = _tokenizeContent(content);
  var doCount = 0;
  double? sx;
  double? sy;
  var sawExpected = false;

  for (var i = 0; i < tokens.length; i++) {
    final t = tokens[i];
    if (t.startsWith('/')) continue;
    if (_kDrawingOperators.contains(t)) {
      return _ContentShape(
        reason:
            'paints its own content (a `$t` operator), so lifting the '
            'image alone would drop a stamp, a revision cloud or a '
            'redaction',
      );
    }
    if (t == 'Do') {
      doCount++;
      if (i > 0 && tokens[i - 1] == '/$expectedXObject') sawExpected = true;
    } else if (t == 'cm' && i >= 6) {
      final a = double.tryParse(tokens[i - 6]);
      final d = double.tryParse(tokens[i - 3]);
      // The LAST cm before the Do wins, which is what a nested q/Q means
      // in the shape this lifter accepts: one save, one transform, one
      // draw, one restore.
      if (a != null && d != null) {
        sx = a;
        sy = d;
      }
    }
  }

  if (doCount == 0) return const _ContentShape(reason: 'draws nothing');
  if (doCount > 1) {
    return _ContentShape(
      reason: 'draws $doCount objects rather than one',
    );
  }
  if (!sawExpected) {
    return const _ContentShape(
      reason: 'draws something other than its own image',
    );
  }
  return _ContentShape(scaleX: sx, scaleY: sy);
}

/// Splits a content stream into operands and operators.
///
/// String literals are SKIPPED rather than tokenised, because `(Tj)` is
/// text content and not an operator, and a tokeniser that could not tell
/// them apart would refuse every page carrying a title block string.
List<String> _tokenizeContent(String s) {
  final out = <String>[];
  final buf = StringBuffer();
  var i = 0;
  while (i < s.length) {
    final c = s[i];
    if (c == '(') {
      if (buf.isNotEmpty) {
        out.add(buf.toString());
        buf.clear();
      }
      var depth = 1;
      i++;
      while (i < s.length && depth > 0) {
        if (s[i] == r'\') {
          i += 2;
          continue;
        }
        if (s[i] == '(') depth++;
        if (s[i] == ')') depth--;
        i++;
      }
      // A literal string is an OPERAND, and emitting a placeholder keeps
      // the operand positions before `cm` honest.
      out.add('()');
      continue;
    }
    if (c == '<' && i + 1 < s.length && s[i + 1] != '<') {
      if (buf.isNotEmpty) {
        out.add(buf.toString());
        buf.clear();
      }
      while (i < s.length && s[i] != '>') {
        i++;
      }
      i++;
      out.add('<>');
      continue;
    }
    if (c.trim().isEmpty) {
      if (buf.isNotEmpty) {
        out.add(buf.toString());
        buf.clear();
      }
      i++;
      continue;
    }
    buf.write(c);
    i++;
  }
  if (buf.isNotEmpty) out.add(buf.toString());
  return out;
}

// ─────────────────────────────────────────────────────────────────────────
// A DELIBERATELY SMALL OBJECT PARSER
// ─────────────────────────────────────────────────────────────────────────
// Dictionaries, arrays, names, numbers, references, booleans and null.
// Strings are consumed and returned as a placeholder, because nothing here
// needs their value and parsing escapes properly is work with no consumer.

@immutable
final class _Name {
  const _Name(this.value);

  final String value;

  @override
  bool operator ==(Object other) => other is _Name && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => '/$value';
}

@immutable
final class _Ref {
  const _Ref(this.number);

  final int number;

  @override
  bool operator ==(Object other) => other is _Ref && other.number == number;

  @override
  int get hashCode => number.hashCode;
}

final class _Parsed {
  const _Parsed(this.value, this.next);

  final Object? value;
  final int next;
}

_Parsed _parseValue(String s, int start, {int depth = 0}) {
  final i = _skipWhitespace(s, start);
  if (depth >= kMaxPdfRefDepth || i >= s.length) return _Parsed(null, i);

  if (s.startsWith('<<', i)) return _parseDict(s, i + 2, depth);
  if (s.startsWith('[', i)) return _parseArray(s, i + 1, depth);
  if (s.startsWith('/', i)) {
    var j = i + 1;
    while (j < s.length && !_isDelimiter(s.codeUnitAt(j))) {
      j++;
    }
    return _Parsed(_Name(s.substring(i + 1, j)), j);
  }
  if (s.startsWith('(', i)) {
    var depthP = 1;
    var j = i + 1;
    while (j < s.length && depthP > 0) {
      if (s[j] == r'\') {
        j += 2;
        continue;
      }
      if (s[j] == '(') depthP++;
      if (s[j] == ')') depthP--;
      j++;
    }
    return _Parsed('', j);
  }
  if (s.startsWith('true', i)) return _Parsed(true, i + 4);
  if (s.startsWith('false', i)) return _Parsed(false, i + 5);
  if (s.startsWith('null', i)) return _Parsed(null, i + 4);

  // A number, or the `N G R` reference that starts like one.
  var j = i;
  while (j < s.length && !_isDelimiter(s.codeUnitAt(j))) {
    j++;
  }
  final token = s.substring(i, j);
  final asInt = int.tryParse(token);
  if (asInt != null) {
    final after = _skipWhitespace(s, j);
    var k = after;
    while (k < s.length && !_isDelimiter(s.codeUnitAt(k))) {
      k++;
    }
    final gen = s.substring(after, k);
    if (int.tryParse(gen) != null) {
      final afterGen = _skipWhitespace(s, k);
      if (afterGen < s.length && s[afterGen] == 'R') {
        return _Parsed(_Ref(asInt), afterGen + 1);
      }
    }
    return _Parsed(asInt, j);
  }
  final asDouble = double.tryParse(token);
  if (asDouble != null) return _Parsed(asDouble, j);
  return _Parsed(null, j == i ? i + 1 : j);
}

_Parsed _parseDict(String s, int i, int depth) {
  final out = <String, Object?>{};
  var cursor = i;
  while (cursor < s.length) {
    cursor = _skipWhitespace(s, cursor);
    if (s.startsWith('>>', cursor)) return _Parsed(out, cursor + 2);
    if (!s.startsWith('/', cursor)) {
      // Not a key. Step over it rather than spinning.
      final skipped = _parseValue(s, cursor, depth: depth + 1);
      if (skipped.next <= cursor) return _Parsed(out, cursor + 1);
      cursor = skipped.next;
      continue;
    }
    var j = cursor + 1;
    while (j < s.length && !_isDelimiter(s.codeUnitAt(j))) {
      j++;
    }
    final key = s.substring(cursor + 1, j);
    final value = _parseValue(s, j, depth: depth + 1);
    out[key] = value.value;
    cursor = value.next <= j ? j + 1 : value.next;
  }
  return _Parsed(out, cursor);
}

_Parsed _parseArray(String s, int i, int depth) {
  final out = <Object?>[];
  var cursor = i;
  while (cursor < s.length) {
    cursor = _skipWhitespace(s, cursor);
    if (s.startsWith(']', cursor)) return _Parsed(out, cursor + 1);
    final value = _parseValue(s, cursor, depth: depth + 1);
    if (value.next <= cursor) return _Parsed(out, cursor + 1);
    out.add(value.value);
    cursor = value.next;
  }
  return _Parsed(out, cursor);
}

int _skipWhitespace(String s, int i) {
  var j = i;
  while (j < s.length) {
    final c = s.codeUnitAt(j);
    if (c == 0x25) {
      // A comment runs to the end of the line.
      while (j < s.length && s.codeUnitAt(j) != 0x0A) {
        j++;
      }
      continue;
    }
    if (c != 0x20 && c != 0x0A && c != 0x0D && c != 0x09 && c != 0x00) break;
    j++;
  }
  return j;
}

bool _isDelimiter(int c) =>
    c == 0x20 ||
    c == 0x0A ||
    c == 0x0D ||
    c == 0x09 ||
    c == 0x00 ||
    c == 0x2F || // /
    c == 0x5B || // [
    c == 0x5D || // ]
    c == 0x3C || // <
    c == 0x3E || // >
    c == 0x28 || // (
    c == 0x29 || // )
    c == 0x7B ||
    c == 0x7D;

bool _isDigit(int c) => c >= 0x30 && c <= 0x39;

double? _asDouble(Object? v) => switch (v) {
  final int i => i.toDouble(),
  final double d => d,
  _ => null,
};

int? _asInt(Object? v) => switch (v) {
  final int i => i,
  final double d => d.round(),
  _ => null,
};
