// THE ONLY `skip:` REASON IN THIS PACKAGE, AND IT HAS AN END DATE.
//
// third_party/pdfium/ vendors win-x64 alone (DR-153, CR-100), so on macOS
// the loader finds the Windows DLL and dlopen refuses it. Every test that
// renders through the real binary failed there on the first macOS run
// (build 481, DR-255), each with that one message. A check that is red
// for a known reason cannot show a new one, so these tests skip on macOS,
// and the macOS floor in tools/ci/run_suite.ps1 is lower by exactly the
// cases that use this constant.
//
// Chapter #468 (Story #61) vendors the macOS binary and its loader. It
// deletes this file, every use of it, and the macOS floor rows, in the
// same change. Windows never skips: a missing DLL there is a failure.
import 'dart:io';

final String? noMacOSPdfium = Platform.isMacOS
    ? 'no macOS pdfium is vendored yet (Story #61, Chapter #468)'
    : null;
