// rackpal_pdfium/src/pdfium_library.dart — finding the vendored binary,
// and saying so plainly when it is not there (DR-153 §11.152.3).
//
// ═══════════════════════════════════════════════════════════════════════
// A MISSING DLL IS A SENTENCE, NOT A CRASH
// ═══════════════════════════════════════════════════════════════════════
// The binary is placed by a person on purpose (CR-100), so "it is not
// there yet" is an ordinary state rather than a corrupt installation, and
// the message names the command that fixes it. `DynamicLibrary.open` on a
// missing file throws an `ArgumentError` whose text is a Windows error
// code, which tells nobody anything.
//
// ═══════════════════════════════════════════════════════════════════════
// THREE PLACES, IN THIS ORDER, AND EACH IS A REAL SITUATION
// ═══════════════════════════════════════════════════════════════════════
//   1. `RACKPAL_PDFIUM_DLL`, for a machine that keeps it elsewhere. An
//      override that exists and is wrong is an error rather than a
//      fallthrough: somebody set it deliberately.
//   2. Beside the running executable, which is where the Windows build
//      installs it and where the shipped app finds it.
//   3. `third_party/pdfium/win-x64/` in the repository, walking up from
//      the working directory, which is the developer and CI case.
import 'dart:ffi';
import 'dart:io';

import 'package:rackpal_pdfium/src/pdfium_ffi.dart';

/// The environment variable that overrides the search.
const String kPdfiumPathVariable = 'RACKPAL_PDFIUM_DLL';

/// Where the binary sits in the repository, relative to its root.
const String kVendoredPdfiumPath = 'third_party/pdfium/win-x64/pdfium.dll';

/// The one command that fixes an absent binary.
const String kVendorCommand =
    'pwsh -File tools/vendor_pdfium.ps1 -Release '
    '<tag> -Bootstrap';

/// pdfium could not be loaded, and the message says which of the two
/// reasons it was.
final class PdfiumUnavailable implements Exception {
  const PdfiumUnavailable(this.message);

  final String message;

  @override
  String toString() => 'PdfiumUnavailable: $message';
}

/// The vendored library, opened once per process.
///
/// **`FPDF_InitLibrary` IS CALLED ONCE AND NEVER PER DOCUMENT.** pdfium
/// keeps process-global state behind it, and initialising twice is
/// undefined rather than idempotent.
///
/// **AND IT IS NEVER DESTROYED.** `FPDF_DestroyLibrary` is not bound at
/// all, for the reason `pdfium_ffi.dart` gives: a symbol that must never
/// be called is better absent than available.
PdfiumBindings loadPdfium() {
  final existing = _bindings;
  if (existing != null) return existing;

  final path = pdfiumPath();
  final DynamicLibrary library;
  try {
    library = DynamicLibrary.open(path);
    // `DynamicLibrary.open` reports a load failure as an ArgumentError,
    // which is an Error rather than an Exception, so catching it is the
    // only way to turn a Windows error code into a sentence. The lint is
    // right in general and wrong about this one call.
    // ignore: avoid_catching_errors
  } on ArgumentError catch (error) {
    throw PdfiumUnavailable(
      'found $path but could not load it ($error). On Windows this is '
      'usually a 32-bit binary in a 64-bit process, or a missing Visual '
      'C++ runtime.',
    );
  }

  final bindings = PdfiumBindings(library)..initLibrary();
  return _bindings = bindings;
}

PdfiumBindings? _bindings;

/// The path the loader will use, without loading it.
///
/// **THE TWO COLLABORATORS ARE PARAMETERS SO THE ORDER CAN BE TESTED.**
/// `Platform.environment` cannot be written from inside a Dart process,
/// and a test that spawned one to set a variable would be testing the
/// spawn. [environment] and [exists] default to the real ones, which is
/// the only configuration that ships.
String pdfiumPath({
  Map<String, String>? environment,
  bool Function(String path)? exists,
}) {
  final env = environment ?? Platform.environment;
  final present = exists ?? (String path) => File(path).existsSync();

  final override = env[kPdfiumPathVariable];
  if (override != null && override.trim().isNotEmpty) {
    if (!present(override)) {
      throw PdfiumUnavailable(
        '$kPdfiumPathVariable is set to $override and there is no file '
        'there. An override that is wrong is not a fallback.',
      );
    }
    return override;
  }

  final exeDir = File(Platform.resolvedExecutable).parent.path;
  final beside = '$exeDir${Platform.pathSeparator}pdfium.dll';
  if (present(beside)) return beside;

  final vendored = _walkUpFor(kVendoredPdfiumPath, present);
  if (vendored != null) return vendored;

  throw const PdfiumUnavailable(
    'pdfium is not vendored. It is committed to the repository rather '
    'than downloaded (CR-100), and it is placed by a person, so this is '
    'an ordinary state and not a broken install.\n'
    'Fix: $kVendorCommand\n'
    'Then: pwsh -File tools/vendor_pdfium.ps1 -Verify',
  );
}

/// [relative] resolved against the working directory or any ancestor.
///
/// Tests run from a package directory and the app runs from wherever it
/// was launched, so neither can name the repository root.
String? _walkUpFor(String relative, bool Function(String path) exists) {
  var dir = Directory.current.absolute;
  // Bounded rather than `while (true)`: a symlink loop is somebody else's
  // filesystem and this is not the place to discover it.
  for (var depth = 0; depth < 16; depth++) {
    final candidate = '${dir.path}${Platform.pathSeparator}$relative';
    if (exists(candidate)) return candidate;
    final parent = dir.parent;
    if (parent.path == dir.path) return null;
    dir = parent;
  }
  return null;
}
