// rackpal_pdfium/src/pdfium_document.dart — a PDF opened once, measured
// and rendered (DR-153 §11.152, `PLAN-K/1`).
//
// ═══════════════════════════════════════════════════════════════════════
// A HANDLE RATHER THAN THREE FUNCTIONS THAT EACH REPARSE
// ═══════════════════════════════════════════════════════════════════════
// A three-page plan set is measured, then rendered page by page. Free
// functions taking bytes would parse the file four times, and pdfium's
// parse is the expensive half on a 1.2 MB CAD plot.
//
// ═══════════════════════════════════════════════════════════════════════
// EVERY NATIVE ALLOCATION HAS EXACTLY ONE OWNER AND A `finally`
// ═══════════════════════════════════════════════════════════════════════
// Three of them, and they have different lifetimes, which is why they are
// not managed the same way:
//
//   * THE FILE BUFFER lives as long as the document, because
//     `FPDF_LoadMemDocument` does not copy and reads out of it lazily.
//     Freed by [close].
//   * THE PAGE is per render call. Freed in a `finally`.
//   * THE BITMAP and its pixels are per render call and are copied into
//     Dart memory before being freed, also in a `finally`.
//
// A render that fails halfway must not leak, and `Outcome` means the
// failure path is an ordinary return rather than a throw, so the `finally`
// is what makes the two paths agree.
//
// ═══════════════════════════════════════════════════════════════════════
// NOTHING HERE THROWS ON A BAD FILE (CR-093)
// ═══════════════════════════════════════════════════════════════════════
// The same contract `pdf_page_lift.dart` keeps on the pure-Dart side. A
// truncated PDF, a password-protected one, a page index past the end: all
// are `Err`. `PdfiumUnavailable` is the exception to that and is thrown,
// because a missing binary is a fact about the INSTALLATION rather than
// about the file, and swallowing it into the same channel would make
// "this PDF is broken" the message for "you have not vendored pdfium yet".
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:meta/meta.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_pdfium/src/pdfium_ffi.dart';
import 'package:rackpal_pdfium/src/pdfium_library.dart';

/// A page's size in PDF points, as pdfium reports it.
///
/// **AFTER `/Rotate`.** pdfium applies the page's own rotation before
/// answering, so a landscape page that is stored portrait with `/Rotate 90`
/// measures landscape here, which is also how it renders.
@immutable
final class PdfiumPageSize {
  const PdfiumPageSize({required this.widthPt, required this.heightPt});

  final double widthPt;
  final double heightPt;

  @override
  String toString() => 'PdfiumPageSize($widthPt x $heightPt pt)';
}

/// One rendered page: opaque pixels, blue first, three bytes each.
@immutable
final class PdfiumRaster {
  const PdfiumRaster({
    required this.width,
    required this.height,
    required this.bgr,
  });

  final int width;
  final int height;

  /// `width * height * 3` bytes, row-major, no padding and no alpha.
  final Uint8List bgr;
}

/// pdfium could not do something with this file.
///
/// A plain class rather than a member of some error hierarchy, because
/// `Err.error` is deliberately a bare `Object` and `outcome.dart` says
/// why: callers that care test for the type.
@immutable
final class PdfiumError {
  const PdfiumError(this.message);

  final String message;

  @override
  String toString() => message;
}

/// An open PDF. Call [close] when finished; nothing else frees it.
final class PdfiumDocument {
  PdfiumDocument._(this._api, this._handle, this._buffer, this.pageCount);

  /// Opens [bytes], which are copied into native memory.
  ///
  /// Throws [PdfiumUnavailable] when the binary is not vendored; returns
  /// `Err` for anything about the FILE.
  static Outcome<PdfiumDocument> open(Uint8List bytes) {
    if (bytes.isEmpty) {
      return const Err(PdfiumError('the file is empty'));
    }
    final api = loadPdfium();

    // COPIED, BECAUSE pdfium DOES NOT COPY. This buffer must outlive
    // every read pdfium makes, which is until the document is closed.
    final buffer = calloc<Uint8>(bytes.length);
    buffer.asTypedList(bytes.length).setAll(0, bytes);

    final handle = api.loadMemDocument(
      buffer.cast<Void>(),
      bytes.length,
      nullptr,
    );
    if (handle == nullptr) {
      calloc.free(buffer);
      return Err(PdfiumError(_lastError(api)));
    }

    final count = api.getPageCount(handle);
    if (count <= 0) {
      api.closeDocument(handle);
      calloc.free(buffer);
      return const Err(PdfiumError('the document has no pages'));
    }
    return Ok(PdfiumDocument._(api, handle, buffer, count));
  }

  final PdfiumBindings _api;
  final FpdfHandle _handle;
  final Pointer<Uint8> _buffer;

  /// How many pages the document has. Always at least one.
  final int pageCount;

  bool _closed = false;

  /// The size of page [index] in points, without loading the page.
  Outcome<PdfiumPageSize> sizeOf(int index) {
    final guard = _guard(index);
    if (guard != null) return Err(guard);

    final size = calloc<FsSizeF>();
    try {
      final ok = _api.getPageSizeByIndex(_handle, index, size);
      if (ok == 0) {
        return Err(PdfiumError('page ${index + 1} has no readable size'));
      }
      return Ok(
        PdfiumPageSize(widthPt: size.ref.width, heightPt: size.ref.height),
      );
    } finally {
      calloc.free(size);
    }
  }

  /// Page [index] drawn at exactly [width] by [height] pixels.
  ///
  /// The caller decides the size, and DR-153 §11.152.5's rule for
  /// deciding it lives in `rackpal_core` so that the rule can be tested
  /// on a machine with no binary on it.
  Outcome<PdfiumRaster> render(
    int index, {
    required int width,
    required int height,
  }) {
    final guard = _guard(index);
    if (guard != null) return Err(guard);
    if (width <= 0 || height <= 0) {
      return Err(PdfiumError('a ${width}x$height raster is not a raster'));
    }

    final stride = width * 3;
    final pixels = calloc<Uint8>(stride * height);
    FpdfHandle bitmap = nullptr;
    FpdfHandle page = nullptr;
    try {
      bitmap = _api.bitmapCreateEx(
        width,
        height,
        kFpdfBitmapBgr,
        pixels.cast<Void>(),
        stride,
      );
      if (bitmap == nullptr) {
        return Err(PdfiumError('could not allocate a ${width}x$height bitmap'));
      }

      // WHITE FIRST, BECAUSE A PDF PAGE HAS NO BACKGROUND. Everything a
      // page does not paint is transparent, and transparent over a zeroed
      // buffer is black: a plan rendered onto an unfilled bitmap comes
      // out as white linework on a solid black sheet.
      _api.bitmapFillRect(bitmap, 0, 0, width, height, 0xFFFFFFFF);

      page = _api.loadPage(_handle, index);
      if (page == nullptr) {
        return Err(PdfiumError('page ${index + 1}: ${_lastError(_api)}'));
      }

      _api.renderPageBitmap(
        bitmap,
        page,
        0,
        0,
        width,
        height,
        0,
        kFpdfAnnot | kFpdfNoNativeText | kFpdfPrinting,
      );

      // COPIED OUT BEFORE THE `finally` FREES IT. `asTypedList` is a view
      // onto native memory, so returning it would hand back a pointer to
      // freed pages that reads as ordinary bytes until it does not.
      return Ok(
        PdfiumRaster(
          width: width,
          height: height,
          bgr: Uint8List.fromList(pixels.asTypedList(stride * height)),
        ),
      );
    } finally {
      if (page != nullptr) _api.closePage(page);
      if (bitmap != nullptr) _api.bitmapDestroy(bitmap);
      calloc.free(pixels);
    }
  }

  /// Frees the document and the buffer pdfium has been reading from.
  ///
  /// Idempotent, because a `finally` in a caller and an explicit call in
  /// the happy path is the shape that produces a double free.
  void close() {
    if (_closed) return;
    _closed = true;
    _api.closeDocument(_handle);
    calloc.free(_buffer);
  }

  PdfiumError? _guard(int index) {
    if (_closed) return const PdfiumError('the document is closed');
    if (index < 0 || index >= pageCount) {
      return PdfiumError(
        'page ${index + 1} does not exist; the document has $pageCount',
      );
    }
    return null;
  }
}

/// pdfium's own reason for the last failure, in words.
///
/// The codes are from `fpdfview.h` and are worth spelling out: a password
/// prompt and a corrupt file are different problems for the person holding
/// the drawing, and "error 4" is neither.
String _lastError(PdfiumBindings api) {
  final code = api.getLastError();
  return switch (code) {
    1 => 'pdfium failed for an unknown reason',
    2 => 'the file could not be found or opened',
    3 => 'the file is not a PDF, or it is damaged',
    4 => 'the file is password-protected',
    5 => 'the file uses an unsupported security scheme',
    6 => 'the page could not be loaded',
    _ => 'pdfium error $code',
  };
}
