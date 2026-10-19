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
//   2. Where the shipped app keeps it: beside the executable on Windows,
//      where the Windows build installs it, and in the bundle's
//      `Contents/Frameworks/` on macOS, where a `macos/` runner will (D1).
//   3. The platform's file under `third_party/pdfium/` in the repository,
//      walking up from the working directory, which is the developer and
//      CI case.
//
// ═══════════════════════════════════════════════════════════════════════
// ONE FILE PER OS, AND THE macOS ONE IS UNIVERSAL
// ═══════════════════════════════════════════════════════════════════════
// macOS gets one `libpdfium.dylib` holding both the x86_64 and the arm64
// slice (#468), so the loader never asks which chip it is on: `dlopen`
// picks the slice. DR-255's hosted macOS image is Intel and loads the
// first; an Apple Silicon Mac loads the second, which no CI here runs.
// `pdfium_vendoring_test.dart` reads the file's Mach-O header to prove the
// arm64 slice is at least present.
import 'dart:ffi';
import 'dart:io';

import 'package:rackpal_pdfium/src/pdfium_ffi.dart';

/// The environment variable that overrides the search.
const String kPdfiumPathVariable = 'RACKPAL_PDFIUM_DLL';

/// Where each platform's binary sits in the repository, relative to its
/// root, keyed by `Platform.operatingSystem`. A platform absent here has no
/// vendored pdfium, and the loader says so rather than guessing a name.
const Map<String, String> kVendoredPdfiumPaths = {
  'windows': 'third_party/pdfium/win-x64/pdfium.dll',
  'macos': 'third_party/pdfium/mac-univ/libpdfium.dylib',
};

/// The one command that fixes an absent binary.
const String kVendorCommand =
    'pwsh -File tools/vendor_pdfium.ps1 -Platform <win-x64|mac-univ> '
    '-Release <tag> -Bootstrap';

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
      'found $path but could not load it ($error). ${_loadHint()}',
    );
  }

  final bindings = PdfiumBindings(library)..initLibrary();
  return _bindings = bindings;
}

PdfiumBindings? _bindings;

/// What a load failure usually means on this OS. Each is the cause seen
/// most often there, not a diagnosis.
String _loadHint() => switch (Platform.operatingSystem) {
  'windows' =>
    'On Windows this is usually a 32-bit binary in a 64-bit process, or a '
        'missing Visual C++ runtime.',
  'macos' =>
    'On macOS this is usually a dylib without a slice for this CPU (check '
        '`lipo -archs`), or one quarantined by Gatekeeper after a download '
        'rather than a checkout.',
  _ => 'pdfium is vendored for Windows and macOS only.',
};

/// The path the loader will use, without loading it.
///
/// **THE THREE COLLABORATORS ARE PARAMETERS SO THE ORDER CAN BE TESTED.**
/// `Platform.environment` cannot be written from inside a Dart process,
/// and a test that spawned one to set a variable would be testing the
/// spawn; nor can a Windows test run as macOS. [environment], [exists] and
/// [operatingSystem] default to the real ones, which is the only
/// configuration that ships.
String pdfiumPath({
  Map<String, String>? environment,
  bool Function(String path)? exists,
  String? operatingSystem,
}) {
  final env = environment ?? Platform.environment;
  final present = exists ?? (String path) => File(path).existsSync();
  final os = operatingSystem ?? Platform.operatingSystem;

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

  final relative = kVendoredPdfiumPaths[os];
  if (relative == null) {
    throw PdfiumUnavailable(
      'pdfium is vendored for ${kVendoredPdfiumPaths.keys.join(' and ')} '
      'only, and this is $os.',
    );
  }

  final exeDir = File(Platform.resolvedExecutable).parent.path;
  final sep = Platform.pathSeparator;
  // The shipped app's copy. On macOS the executable is
  // `RackPal.app/Contents/MacOS/<name>`, so the bundle's frameworks are
  // one level up.
  final shipped = os == 'macos'
      ? '$exeDir$sep..${sep}Frameworks${sep}libpdfium.dylib'
      : '$exeDir${sep}pdfium.dll';
  if (present(shipped)) return shipped;

  final vendored = _walkUpFor(relative, present);
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
