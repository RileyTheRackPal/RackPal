// rackpal_pdfium/src/pdfium_ffi.dart — the raw C surface, and nothing
// above it (DR-153 §11.152.4, `PLAN-K/1`).
//
// ═══════════════════════════════════════════════════════════════════════
// THE SMALLEST SURFACE THAT TURNS A PAGE INTO PIXELS
// ═══════════════════════════════════════════════════════════════════════
// pdfium exposes several hundred entry points: form filling, text
// extraction, annotations, editing, JavaScript. This product needs one
// thing. Every symbol bound here is one somebody has to keep working
// across a pin bump, and every one not bound is a whole area of that
// library this repository has no opinion about.
//
// `FPDF_DestroyLibrary` IS NOT BOUND AT ALL, which is stronger than not
// calling it. Tearing down process-global state while another isolate may
// hold a document turns a clean shutdown into a crash, and the OS reclaims
// the memory regardless. A symbol that must never be called is better
// absent than available.
//
// ═══════════════════════════════════════════════════════════════════════
// THE BUFFER LIFETIME IS THE ONE THING A READER MUST NOT GET WRONG
// ═══════════════════════════════════════════════════════════════════════
// `FPDF_LoadMemDocument` DOES NOT COPY. pdfium reads the bytes lazily out
// of the caller's buffer for as long as the document is open, so a Dart
// `Uint8List` handed to it would be a use-after-free the moment the
// garbage collector moved or reclaimed it. `PdfiumDocument` therefore
// copies the file into native memory and holds it until `close`, and that
// allocation is why this file has a `calloc` in it at all.
//
// The same rule applies to the bitmap: `FPDFBitmap_CreateEx` takes a
// buffer the caller owns and pdfium writes into it.
import 'dart:ffi';

import 'package:ffi/ffi.dart';

/// `FPDF_DOCUMENT`, `FPDF_PAGE` and `FPDF_BITMAP` are all opaque pointers.
typedef FpdfHandle = Pointer<Void>;

/// `FPDFBitmap_BGR`: three bytes per pixel, blue first, no alpha.
///
/// **NO ALPHA BY CONSTRUCTION**, which is the same discipline `PLAN-H/2`
/// applied one package over: an underlay reaches the PDF as opaque pixels
/// and no `/SMask` is ever emitted.
///
/// `FPDFBitmap_Gray` would cut the buffer to a third and the sheet prints
/// greyscale anyway (AC-054). It is not taken, because the EDITOR shows
/// the plan on screen, an architect's plan uses colour to separate layers,
/// and a lifted JPEG arrives in colour. Making the two import paths differ
/// in that would be a decision nobody asked for.
const int kFpdfBitmapBgr = 2;

/// `FPDF_ANNOT`: draw annotations.
///
/// A stamp is an annotation, and a page with `VOID` across it must print
/// with `VOID` across it. `pdf_page_lift.dart` refuses to lift such a page
/// for exactly this reason; the renderer does not have to refuse it,
/// because it can draw the stamp.
const int kFpdfAnnot = 0x01;

/// `FPDF_NO_NATIVETEXT`: use pdfium's own text rasteriser rather than the
/// platform's.
///
/// **FOR DETERMINISM, NOT FOR LOOKS.** GDI text rendering depends on the
/// machine, and this repository's standing requirement is that the same
/// document produces the same bytes.
const int kFpdfNoNativeText = 0x04;

/// `FPDF_PRINTING`: render as for print rather than for a screen.
const int kFpdfPrinting = 0x800;

/// `FS_SIZEF`, a pair of floats, which is how a page's size comes back
/// without loading the page.
final class FsSizeF extends Struct {
  @Float()
  external double width;

  @Float()
  external double height;
}

// ── the C surface ────────────────────────────────────────────────────
//
// THE C SIGNATURE SITS AT THE LOOKUP AND THE DART ONE IS A TYPEDEF. Each
// C shape is used exactly once, so a named typedef for it would be a name
// to keep in step with a single call site; the Dart shapes are the
// declared type of every field below and are named for that reason.

typedef FpdfVoidCall = void Function();
typedef FpdfLoadMemDocument =
    FpdfHandle Function(Pointer<Void> buf, int size, Pointer<Utf8> password);
typedef FpdfHandleCall = void Function(FpdfHandle handle);
typedef FpdfCountCall = int Function(FpdfHandle document);
typedef FpdfPageSizeCall =
    int Function(FpdfHandle document, int index, Pointer<FsSizeF> size);
typedef FpdfLoadPage = FpdfHandle Function(FpdfHandle document, int index);
typedef FpdfBitmapCreateEx =
    FpdfHandle Function(
      int width,
      int height,
      int format,
      Pointer<Void> firstScan,
      int stride,
    );
typedef FpdfBitmapFillRect =
    void Function(
      FpdfHandle bitmap,
      int left,
      int top,
      int width,
      int height,
      int colour,
    );
typedef FpdfRenderPageBitmap =
    void Function(
      FpdfHandle bitmap,
      FpdfHandle page,
      int startX,
      int startY,
      int sizeX,
      int sizeY,
      int rotate,
      int flags,
    );
typedef FpdfLastError = int Function();

/// Every pdfium symbol this product uses, looked up once.
///
/// A lookup that fails throws `ArgumentError` from `dart:ffi` itself, and
/// that is deliberately not caught: a DLL that loads but has no
/// `FPDF_RenderPageBitmap` in it is not a pdfium, and pretending otherwise
/// would turn a mis-vendored binary into a mysterious blank page.
final class PdfiumBindings {
  PdfiumBindings(DynamicLibrary library)
    : initLibrary = library.lookupFunction<Void Function(), FpdfVoidCall>(
        'FPDF_InitLibrary',
      ),
      loadMemDocument = library
          .lookupFunction<
            FpdfHandle Function(Pointer<Void>, Int32, Pointer<Utf8>),
            FpdfLoadMemDocument
          >('FPDF_LoadMemDocument'),
      closeDocument = library
          .lookupFunction<Void Function(FpdfHandle), FpdfHandleCall>(
            'FPDF_CloseDocument',
          ),
      getPageCount = library
          .lookupFunction<Int32 Function(FpdfHandle), FpdfCountCall>(
            'FPDF_GetPageCount',
          ),
      getPageSizeByIndex = library
          .lookupFunction<
            Int32 Function(FpdfHandle, Int32, Pointer<FsSizeF>),
            FpdfPageSizeCall
          >('FPDF_GetPageSizeByIndexF'),
      loadPage = library
          .lookupFunction<FpdfHandle Function(FpdfHandle, Int32), FpdfLoadPage>(
            'FPDF_LoadPage',
          ),
      closePage = library
          .lookupFunction<Void Function(FpdfHandle), FpdfHandleCall>(
            'FPDF_ClosePage',
          ),
      bitmapCreateEx = library
          .lookupFunction<
            FpdfHandle Function(Int32, Int32, Int32, Pointer<Void>, Int32),
            FpdfBitmapCreateEx
          >('FPDFBitmap_CreateEx'),
      bitmapFillRect = library
          .lookupFunction<
            // `FPDF_DWORD` is `unsigned long`, which is 32-bit on Windows
            // and 64 elsewhere. Bound as the C type rather than as the
            // width it happens to have on the one platform vendored
            // today, so a macOS binary does not need this line found
            // again.
            Void Function(FpdfHandle, Int32, Int32, Int32, Int32, UnsignedLong),
            FpdfBitmapFillRect
          >('FPDFBitmap_FillRect'),
      renderPageBitmap = library
          .lookupFunction<
            Void Function(
              FpdfHandle,
              FpdfHandle,
              Int32,
              Int32,
              Int32,
              Int32,
              Int32,
              Int32,
            ),
            FpdfRenderPageBitmap
          >('FPDF_RenderPageBitmap'),
      bitmapDestroy = library
          .lookupFunction<Void Function(FpdfHandle), FpdfHandleCall>(
            'FPDFBitmap_Destroy',
          ),
      getLastError = library
          .lookupFunction<UnsignedLong Function(), FpdfLastError>(
            'FPDF_GetLastError',
          );

  final FpdfVoidCall initLibrary;
  final FpdfLoadMemDocument loadMemDocument;
  final FpdfHandleCall closeDocument;
  final FpdfCountCall getPageCount;
  final FpdfPageSizeCall getPageSizeByIndex;
  final FpdfLoadPage loadPage;
  final FpdfHandleCall closePage;
  final FpdfBitmapCreateEx bitmapCreateEx;
  final FpdfBitmapFillRect bitmapFillRect;
  final FpdfRenderPageBitmap renderPageBitmap;
  final FpdfHandleCall bitmapDestroy;
  final FpdfLastError getLastError;
}
