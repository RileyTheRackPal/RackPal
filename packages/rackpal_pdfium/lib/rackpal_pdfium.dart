/// RackPal's binding over the vendored pdfium (DR-153 §11.152.4).
///
/// It turns a PDF page into pixels and does nothing else. **The rule for
/// how many pixels lives in `rackpal_core`**, so that the decision can be
/// tested on a machine with no native binary on it, and this package can
/// be replaced without taking a ruling with it.
library;

export 'src/pdfium_document.dart'
    show PdfiumDocument, PdfiumError, PdfiumPageSize, PdfiumRaster;
export 'src/pdfium_library.dart'
    show
        PdfiumUnavailable,
        kPdfiumPathVariable,
        kVendorCommand,
        kVendoredPdfiumPath,
        loadPdfium,
        pdfiumPath;
