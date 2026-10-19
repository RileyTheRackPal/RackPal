// THE VENDORED BINARY REACHES THE PACKAGED APP (DR-153 §11.152.3).
//
// ═══════════════════════════════════════════════════════════════════════
// WHY THIS CANNOT BE LEFT TO SOMEBODY NOTICING
// ═══════════════════════════════════════════════════════════════════════
// `rackpal_pdfium` finds its library in three places, in order: an
// environment override, BESIDE THE EXECUTABLE, and the repository copy at
// `third_party/pdfium/win-x64/`.
//
// **The third arm hides the absence of the second.** A developer running
// `flutter run` from inside the working tree walks up and finds the
// committed DLL, so every local build works with no install rule at all,
// and the first failure would be on somebody else's machine holding a
// packaged copy that cannot open a PDF. That is the worst shape a defect
// can have in this product: it appears only where nobody is looking.
//
// pdfium is not a Flutter plugin and not a native asset, so neither
// `PLUGIN_BUNDLED_LIBRARIES` nor the native-assets directory carries it.
// The rule is one `install(FILES ...)` in `windows/CMakeLists.txt` and
// this file is the reason the next person cannot delete it quietly.
//
// ═══════════════════════════════════════════════════════════════════════
// A SOURCE GATE, AND ITS LIMIT IS STATED
// ═══════════════════════════════════════════════════════════════════════
// The same family as `gitattributes_byte_exactness_test.dart`, and the
// same honesty about scope: it reads the CMake file and the working tree,
// so it proves the RULE IS PRESENT AND POINTS AT A REAL FILE. It does not
// prove CMake obeyed it. The build gate does that, by building.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The repository root, from the package directory tests run in.
const String kRepoRoot = '../..';

/// Where the loader looks, and where the install rule must point.
const String kVendoredPath = 'third_party/pdfium/win-x64/pdfium.dll';

void main() {
  group('pdfium is installed beside the executable', () {
    late String cmake;

    setUpAll(() {
      cmake = File('windows/CMakeLists.txt').readAsStringSync();
    });

    test('the Windows build names the vendored DLL', () {
      expect(
        cmake,
        contains(kVendoredPath),
        reason:
            'nothing else in this file carries pdfium: it is not a plugin '
            'and not a native asset',
      );
    });

    test('and installs it into the bundle, not merely mentions it', () {
      // A `set()` with no `install()` is a variable nobody reads, which is
      // exactly what a half-finished edit leaves behind.
      expect(
        cmake,
        contains(r'install(FILES "${PDFIUM_DLL}"'),
        reason: 'the file has to be COPIED, not just located',
      );
      expect(cmake, contains(r'DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"'));
    });

    test(
      'a missing binary fails the build rather than shipping without it',
      () {
        // An installable app that cannot open a PDF is the quieter failure,
        // and the message names the command that fixes it.
        expect(cmake, contains('FATAL_ERROR'));
        expect(cmake, contains('vendor_pdfium.ps1'));
      },
    );

    test('the path it names is where the binary actually is', () {
      // The rule and the tree agreeing is the whole point: a path that is
      // subtly wrong installs nothing and fails at FATAL_ERROR instead,
      // which is loud but is a different failure from the one under test.
      expect(
        File('$kRepoRoot/$kVendoredPath').existsSync(),
        isTrue,
        reason:
            'pdfium is not vendored. It is committed rather than downloaded '
            '(CR-100) and placed by a person: '
            'pwsh -File tools/vendor_pdfium.ps1 -Release <tag> -Bootstrap',
      );
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  // THE SAME RULE ON macOS (DR-153, DR-256)
  // ═════════════════════════════════════════════════════════════════════
  // The loader looks for `Contents/Frameworks/libpdfium.dylib` inside the
  // `.app`, and the repository-copy arm hides its absence here exactly as it
  // does on Windows: `flutter run` from the working tree finds the committed
  // dylib, so a project file that bundles nothing still works on the
  // author's Mac and fails on the first packaged copy.
  //
  // The Xcode equivalent of `install(FILES ...)` is a file reference, a
  // build file for it, and a Copy Files phase aimed at Frameworks, and that
  // phase has to be one of the Runner target's `buildPhases` or Xcode never
  // runs it. Four separate links, any one of which an Xcode edit can drop
  // without a compile error, so each is its own test. These read the
  // `project.pbxproj` text; whether Xcode copies and signs the file is for a
  // Mac build to prove, and this gate only proves the wiring is all there.
  group('libpdfium.dylib is bundled into the macOS app', () {
    const vendoredSuffix = 'third_party/pdfium/mac-univ/libpdfium.dylib';
    const id = '[0-9A-F]{24}';

    late String pbxproj;

    setUpAll(() {
      // CR STRIPPED, because the regexes below anchor on `\n` and a
      // checkout is not the only way the file arrives. `.gitattributes`
      // pins the tree LF, but `flutter create` on Windows writes CRLF, and
      // a freshly generated runner failed two of these four cases on the
      // machine that generated it while a clean checkout would have passed.
      pbxproj = File(
        'macos/Runner.xcodeproj/project.pbxproj',
      ).readAsStringSync().replaceAll('\r\n', '\n');
    });

    /// The `PBXFileReference` line for the vendored dylib: its object id and
    /// the whole line, so a test can read the path and the source tree off it.
    RegExpMatch fileReference() {
      final match = RegExp(
        '^\\s*($id) /\\* [^*]* \\*/ = \\{isa = PBXFileReference;'
        '[^\\n]*path = ([^;]*${RegExp.escape(vendoredSuffix)});[^\\n]*\$',
        multiLine: true,
      ).firstMatch(pbxproj);
      expect(
        match,
        isNotNull,
        reason:
            'no file reference ends in $vendoredSuffix; the app would '
            'ship without pdfium',
      );
      return match!;
    }

    /// The `PBXBuildFile` line that wraps [fileRefId], or null.
    RegExpMatch? buildFileFor(String fileRefId) => RegExp(
      '^\\s*($id) /\\* [^*]* \\*/ = \\{isa = PBXBuildFile;'
      '[^\\n]*fileRef = $fileRefId[^\\n]*\$',
      multiLine: true,
    ).firstMatch(pbxproj);

    /// The id of the Copy Files phase aimed at Frameworks (`dstSubfolderSpec
    /// = 10`) whose `files` list holds [buildFileId], or null.
    String? frameworksPhaseHolding(String buildFileId) {
      final phase = RegExp(
        '^\\t\\t($id) /\\* [^*]* \\*/ = \\{\\n'
        r'\t\t\tisa = PBXCopyFilesBuildPhase;(.*?)\n\t\t\};',
        multiLine: true,
        dotAll: true,
      );
      for (final m in phase.allMatches(pbxproj)) {
        final body = m.group(2)!;
        final toFrameworks = body.contains('dstSubfolderSpec = 10;');
        final files = RegExp(
          r'files = \((.*?)\);',
          dotAll: true,
        ).firstMatch(body);
        if (toFrameworks && files!.group(1)!.contains(buildFileId)) {
          return m.group(1);
        }
      }
      return null;
    }

    test('the project file references the vendored dylib, and it exists', () {
      // `macos/` is the directory holding `Runner.xcodeproj`, which is what
      // SOURCE_ROOT means, so the path is resolved from there. A reference
      // to a moved dylib would otherwise surface as an Xcode "file not
      // found" on a Mac, which is the wrong place and the wrong time.
      final line = fileReference().group(0)!;
      expect(line, contains('sourceTree = SOURCE_ROOT;'));
      final path = fileReference().group(2)!;
      expect(
        File('macos/$path').existsSync(),
        isTrue,
        reason:
            '`$path` from the Xcode project directory is not the committed '
            'dylib. It is committed rather than downloaded (CR-100).',
      );
    });

    test('a build file for it is signed on copy', () {
      // Notarisation rejects an app holding a nested Mach-O that does not
      // carry the app's signature, and a dylib copied without
      // CodeSignOnCopy keeps whatever signature it was vendored with.
      final buildFile = buildFileFor(fileReference().group(1)!);
      expect(
        buildFile,
        isNotNull,
        reason: 'a file reference nothing builds is a reference, not a copy',
      );
      expect(buildFile!.group(0), contains('CodeSignOnCopy'));
    });

    test('and a Frameworks copy phase lists that build file', () {
      // `dstSubfolderSpec = 10` is Frameworks, i.e.
      // `Contents/Frameworks/`, which is the directory the loader tries.
      // Any other destination installs the file somewhere nothing looks.
      final buildFileId = buildFileFor(
        fileReference().group(1)!,
      )!.group(1)!;
      expect(
        frameworksPhaseHolding(buildFileId),
        isNotNull,
        reason:
            'no PBXCopyFilesBuildPhase with dstSubfolderSpec = 10 lists '
            '$buildFileId, so the dylib is built but never copied',
      );
    });

    test('and the Runner target runs that phase', () {
      // A phase declared but absent from `buildPhases` is a variable nobody
      // reads, the same half-finished edit as a `set()` with no `install()`.
      final buildFileId = buildFileFor(
        fileReference().group(1)!,
      )!.group(1)!;
      final phaseId = frameworksPhaseHolding(buildFileId)!;
      final runner = RegExp(
        '^\\t\\t$id /\\* Runner \\*/ = \\{\\n'
        r'\t\t\tisa = PBXNativeTarget;(.*?)\n\t\t\};',
        multiLine: true,
        dotAll: true,
      ).firstMatch(pbxproj);
      expect(runner, isNotNull, reason: 'no PBXNativeTarget named Runner');
      final phases = RegExp(
        r'buildPhases = \((.*?)\);',
        dotAll: true,
      ).firstMatch(runner!.group(1)!);
      expect(phases!.group(1), contains(phaseId));
    });
  });
}
