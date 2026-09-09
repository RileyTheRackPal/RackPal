// rackpal_export/lib/src/draw/plan_image.dart -- the underlay's lightening
// pass, and the implementation `PdfImageResolver` never had.
//
// =====================================================================
// A TYPEDEF WITH NO IMPLEMENTATION IS A SEAM, NOT A FEATURE
// =====================================================================
// That sentence is `rackpal_ui/src/draw/plan_image_cache.dart`'s, written
// at PLAN-E/2 when its census found nothing in the tree supplied a
// `FlutterImageResolver`. The export backend has been in exactly the same
// state since PLAN-A and nobody noticed, because no sheet asked for an
// image: `PdfImageResolver` had ZERO production call sites and
// `ExportRequest` had nowhere to put the bytes. T1.01 is the first caller.
// DR-149 section 11.148.1 carries the census.
//
// =====================================================================
// NO ALPHA, EVER, AND THE THREAT IS NOT THE ONE ROW 9 WAS WRITTEN ABOUT
// =====================================================================
// docs/08 row 9 forbids alpha "absolutely, with no exception" and was
// written about `ExtGState`. Reading pdf-3.13.0/lib/src/pdf/obj/image.dart
// found the second path: `PdfImage(..., alpha: true)` -- WHICH IS THE
// DEFAULT -- builds a second image object and writes
// `params['/SMask'] = PdfIndirect(...)`. A PNG underlay carrying an alpha
// channel would emit an alpha path into the document without anybody
// calling `setGraphicState`.
//
// So this file flattens to opaque RGB against WHITE and passes
// `alpha: false` as the only call shape. A transparent pixel becomes
// paper, which is what it looked like on screen anyway.
//
// `PdfImage.file` IS DELIBERATELY NOT USED. It hands a JPEG straight to
// `PdfImage.jpeg`, which embeds the source bytes verbatim under
// `/DCTDecode` -- cheap, and it would ship the architect's page at FULL
// VALUE with the callouts fighting it. The screening is the point.
//
// =====================================================================
// RAW RGB IS NOT A SIZE DECISION, IT IS THE ONLY DOOR
// =====================================================================
// dart_pdf has exactly two image paths: `PdfImage.jpeg`, verbatim source
// bytes, and `PdfImage`, raw RGB(A) samples. There is no "embed this PNG"
// path, so every non-JPEG image in every document this product has ever
// written was already raw RGB. What saves it is `/FlateDecode`, applied by
// `dict_stream.dart` whenever the deflated form is smaller -- and a
// SCREENED floorplan is the best case deflate has: line art (DR-137's
// finding about this exact class of image) whose ink has just been pulled
// three quarters of the way to white, so most of the page is one repeated
// value.
//
// THAT IS AN ARGUMENT AND NOT A MEASUREMENT. `plan_image_test.dart`
// measures the emitted bytes, because "already-compressed rasters do not
// deflate" is true of photographs and false of line art, and this
// repository has been wrong about that class of claim before.
import 'dart:typed_data';

import 'package:image/image.dart' as im;
import 'package:pdf/pdf.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_export/src/draw/pdf_canvas.dart';

/// How much of the underlay's ink survives the screening, in per-mille.
///
/// =====================================================================
/// 25%, AND THE NUMBER IS CONFIRMED BY A LASER RATHER THAN BY THIS FILE
/// =====================================================================
/// DR-149 section 11.148.4. Chosen over 18%, the legend chip's tint,
/// because a chip is a swatch behind a single rule and an architect's
/// floorplan is line art whose walls, doors and dimension strings have to
/// survive; and over 40%, because AC-054 requires every callout legible
/// over the screened underlay and PAL-1's own exclusion block calls that
/// "the only new legibility question this palette has met".
///
/// ONE CONSTANT, WHICH IS WHY THE PASS IS HERE AND NOT AT IMPORT
/// (docs/15 section 7): changing this is a one-line edit, where a
/// pre-composited import would need every underlay in every project file
/// a user owns to be imported again.
///
/// PLAN-J's print drill is the evidence. Moving this afterwards is
/// expected rather than a defect.
const Permille kUnderlayInkRetained = Permille(250);

/// The colour the underlay is screened toward, and flattened against.
///
/// White, because the sheet is white: a screened background reference
/// approaches the paper, and a transparent pixel that becomes paper is
/// indistinguishable from the transparency it replaced.
const int _towardWhite = 255;

/// Builds a [PdfImageResolver] over one export's container members.
///
/// =====================================================================
/// IT CACHES, AND THE REASON IS THE SAME ONE THE SCREEN HAS
/// =====================================================================
/// `PdfDiagramCanvas.drawImage` calls the resolver on every `OpImage`, and
/// a document with three plan sheets over one underlay would otherwise
/// decode and screen the same megabytes three times. `plan_image_cache`
/// makes the same argument about frames of a pan.
///
/// It also makes the output DETERMINISTIC in a way a per-call decode is
/// not obliged to be: one `PdfImage` object per member means one XObject in
/// the document, so `export_determinism_test.dart`'s byte comparison sees
/// one image rather than N identical ones.
PdfImageResolver planImageResolver(
  PdfDocument document,
  Map<String, Uint8List> members,
) {
  final cache = <String, PdfImage>{};
  return (ImageRef ref) {
    final hit = cache[ref.member];
    if (hit != null) return hit;

    final bytes = members[ref.member];
    if (bytes == null) return null;

    // A MEMBER THAT WILL NOT DECODE RESOLVES TO NULL, and the CANVAS
    // decides what that means: `PdfDiagramCanvas.drawImage` throws
    // `MissingImageError`, because docs/15 section 7 rules that a T1.01
    // which is "a title block over white paper is indistinguishable from a
    // plan with no drops on it". Reporting it here would be this file
    // choosing a policy that already has an owner.
    //
    // THE `try` IS NOT DEFENSIVE PADDING AND A TEST FOUND IT.
    // `im.decodeImage` is documented as returning null for an unknown
    // format and it THROWS on bytes that look like a format it knows and
    // then are not. A container is on disk and CR-093 rules that reading
    // one never throws, so the two failures are collapsed into the one
    // answer this function is allowed to give.
    final im.Image? decoded;
    try {
      decoded = im.decodeImage(bytes);
    } on Object {
      return null;
    }
    if (decoded == null) return null;

    final built = PdfImage(
      document,
      image: _screen(decoded),
      width: decoded.width,
      height: decoded.height,
      // THE WHOLE POINT. `true` is the default and writes an `/SMask`.
      alpha: false,
    );
    cache[ref.member] = built;
    return built;
  };
}

/// Flattens [source] against white and lightens it to
/// [kUnderlayInkRetained], returning packed RGB.
///
/// INTEGER ARITHMETIC IN PER-MILLE (CR-001). A `double` factor would be
/// the obvious spelling and would put a float in the one place two
/// machines have to agree byte for byte: `export_determinism_test.dart`
/// compares whole documents, and this buffer is in one.
Uint8List _screen(im.Image source) {
  final out = Uint8List(source.width * source.height * 3);
  final keep = kUnderlayInkRetained.v;
  final whole = Permille.whole.v;
  var i = 0;

  for (final pixel in source) {
    // ALPHA IS COMPOSITED, NOT DISCARDED. Dropping it would turn a
    // transparent pixel into whatever colour happened to sit under it in
    // the file, which for a PNG exported from CAD is usually black.
    final a = pixel.a.toInt();
    final r = _flatten(pixel.r.toInt(), a);
    final g = _flatten(pixel.g.toInt(), a);
    final b = _flatten(pixel.b.toInt(), a);

    // value + (255 - value) * (1 - keep), rearranged so the division
    // happens once per channel and never on a fraction.
    out[i++] = _towardWhite - ((_towardWhite - r) * keep) ~/ whole;
    out[i++] = _towardWhite - ((_towardWhite - g) * keep) ~/ whole;
    out[i++] = _towardWhite - ((_towardWhite - b) * keep) ~/ whole;
  }
  return out;
}

/// One channel composited over white at alpha [a].
int _flatten(int channel, int a) =>
    a >= 255 ? channel : (channel * a + _towardWhite * (255 - a)) ~/ 255;
