// THE PORTABLE SEAM. One resolution function plus a marker check — not a
// configuration system, and deliberately kept small enough to read in one
// sitting.
//
// ==================================================================
// WHY THIS EXISTS NOW RATHER THAN IN M2
// ==================================================================
// A fully portable build — run from a USB stick or a copied folder,
// keeping its state beside the executable — is a committed M2 deliverable.
// The only thing that makes it hard is WHERE persistence writes its
// out-of-document state: recovery snapshots, pre-update snapshots,
// recents, window prefs, logs. Retrofitting that after five stores have
// each independently reached for `getApplicationSupportDirectory()` means
// touching five places and missing one. So the seam goes in at the single
// point where the data root is resolved, before any of those stores exist.
//
// The mechanism that keeps it that way is not discipline: it is a grep
// test asserting `getApplicationSupportDirectory` appears in exactly ONE
// file, this one. Every store takes its root as a constructor argument.
//
// ONE BUILD SATISFIES BOTH MODES. Nothing is compiled differently. The
// portable ZIP ships with `portable.txt` beside `rackmate.exe`; the
// installer does not.
//
// RACKMATE'S OWN CODE WRITES NO REGISTRY KEY — no `Reg*` call, no
// registry package, nothing under HKCU or HKLM from any line we ship, and
// `registry_claim_test.dart` derives that from the source rather than
// trusting this sentence. The packages that could plausibly have written
// one do not: `path_provider_windows` calls `SHGetKnownFolderPath`, which
// is read-only, and window geometry is persisted by us into prefs.json
// rather than by `window_manager`, which stores nothing itself. WRITES is
// the word, and it is meant precisely: the Flutter runner template in
// `windows/runner/win32_window.cpp` READS `AppsUseLightTheme` under HKCU
// to pick the title-bar theme. It creates nothing and changes nothing,
// and it is named here rather than glossed because the whole point of
// this paragraph is that it survives being checked.
//
// THE HOST IS STILL WRITTEN TO BY THE SHELL, and the honest version of
// that sentence is the one that matters, because a claim about it has now
// been wrong FOUR times — every time by naming the keys that had been
// measured and closing the list, and every time a later measurement found
// another one. Windows' `IFileDialog` records what was opened under
// HKCU\...\Explorer\ComDlg32. RackMate drives the dialog itself
// (`windows/runner/file_dialog_channel.cpp`, reached only through
// `session/file_picker.dart`) and sets FOS_DONTADDTORECENT, which — as
// measured against the shipped binary — keeps everything out of
// `OpenSavePidlMRU` and out of `%APPDATA%\Microsoft\Windows\Recent`, so no
// project FILE NAME reaches the host.
//
// The rest is not ours: the shell writes values under ComDlg32 that
// RackMate does not control — at minimum `LastVisitedPidlMRU` (this
// executable's name plus the last folder browsed) and `CIDSizeMRU` (this
// executable's name, written even when the dialog is cancelled), both
// measured, both examples rather than an inventory — and no supported
// option prevents them while the common dialog is the dialog. A portable
// build therefore leaves shell-owned HKCU entries on a client's machine
// naming this executable and the folders it browsed, `E:\Jobs` and not
// `E:\Jobs\Smith Residence.rackmate`, and they survive the stick being
// pulled. See `session/file_picker.dart`'s header for the measurement and
// `test/session/registry_claim_test.dart` for the gate that keeps this
// paragraph matching the C++.
import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider_windows/path_provider_windows.dart';
import 'package:rackmate/src/storage/file_store.dart';

/// Presence of a file with this name BESIDE THE EXECUTABLE switches the
/// app to portable mode. Its CONTENT is never read — see
/// [resolveDataRoot]. Presence is the entire signal, which is what stops
/// this from quietly becoming a config file.
const String kPortableMarkerFileName = 'portable.txt';

/// The directory created beside the executable in portable mode.
///
/// ==================================================================
/// WHY THIS IS NOT `data`, WHICH IS THE OBVIOUS NAME
/// ==================================================================
/// `data` IS THE FLUTTER WINDOWS ASSET BUNDLE. `windows/runner/main.cpp`
/// says `flutter::DartProject project(L"data")`, and a Release build puts
/// `app.so`, `icudtl.dat` and `flutter_assets/` in exactly
/// `<exeDir>\data`. Resolving the portable root there would interleave
/// recovery snapshots, recents and prefs with the AOT snapshot — and then
/// the normal way to update a portable build, unzipping a new release
/// over the folder, would REPLACE `data/` and silently destroy every
/// recovery snapshot in it, including one holding work from a crash
/// minutes earlier.
///
/// So the writable root is a sibling the release ZIP does not contain.
/// The portable layout is:
///
///   RackMate\
///     rackmate.exe
///     flutter_windows.dll, *_plugin.dll
///     data\                 <- SHIPPED. Overwritten by every update.
///     portable.txt          <- shipped; presence is the mode switch
///     RackMateData\         <- OURS. Never in the ZIP, never replaced.
///
/// `test/storage/data_root_test.dart` reads `main.cpp` and asserts these
/// two names differ, so the collision cannot come back by editing either
/// end alone.
const String kPortableDataDirName = 'RackMateData';

/// The file written and deleted to prove the root is actually writable.
/// A directory that exists is not a directory you can write to — a
/// read-only USB stick and a locked-down corporate profile both fail at
/// the write, not at the create.
const String kWritableProbeFileName = '.rackmate-write-probe';

/// The outcome of resolving where out-of-document state lives.
sealed class DataRoot {
  const DataRoot();
}

/// Resolved and writable.
final class DataRootReady extends DataRoot {
  const DataRootReady(this.path, {required this.portable});

  /// The directory every store writes under.
  final String path;

  /// True when the marker file put us in portable mode.
  final bool portable;

  @override
  String toString() => 'DataRootReady($path, portable: $portable)';
}

/// The intended root could not be created or written to.
///
/// THE PRODUCT RULING: THERE IS NO SILENT FALLBACK. Falling back to
/// %APPDATA% when the user explicitly asked for portable would write the
/// client's file paths onto a machine the user deliberately chose not to
/// touch — the precise thing portable mode exists to prevent. Instead the
/// app STARTS, with out-of-document persistence DISABLED for the session
/// and a persistent, dismissible status-bar warning. Documents still open
/// and save normally, because those write to the user's chosen directory
/// and not to the data root.
///
/// The same degraded mode covers an INSTALLED app whose app-support
/// directory is unwritable, so there is one code path for both.
final class DataRootUnusable extends DataRoot {
  const DataRootUnusable({
    required this.attemptedPath,
    required this.portable,
    required this.cause,
  });

  final String attemptedPath;
  final bool portable;
  final Object cause;

  @override
  String toString() =>
      'DataRootUnusable($attemptedPath, portable: $portable): $cause';
}

/// Resolves the one directory all out-of-document state lives under.
///
/// Called EXACTLY ONCE at startup; the resulting path is then passed to
/// `RecentsStore`, `PrefsStore`, `RecoveryStore`, `SnapshotStore` and the
/// log sink as a constructor argument.
///
/// BOTH ENVIRONMENT INPUTS ARE INJECTED, which is what makes this
/// testable at all. `Platform.resolvedExecutable` under `flutter test`
/// points at the test runner, so the executable directory can never be
/// read inside this function. Production wires
/// [productionExecutableDirectory] and
/// [productionApplicationSupportDirectory] from `main()`; tests wire
/// literals and a `p.Style.windows` context, so the portable cases run
/// green on a Linux CI runner.
Future<DataRoot> resolveDataRoot({
  required FileStore fs,
  required String executableDirectory,
  required Future<String> Function() applicationSupportDirectory,
  p.Context? context,
}) async {
  final ctx = context ?? p.context;
  final marker = ctx.join(executableDirectory, kPortableMarkerFileName);

  if (await fs.exists(marker)) {
    final root = ctx.join(executableDirectory, kPortableDataDirName);
    try {
      await fs.createDirectory(root);
      await _probeWritable(fs, ctx, root);
    } on Object catch (e) {
      return DataRootUnusable(
        attemptedPath: root,
        portable: true,
        cause: e,
      );
    }
    // NOTE the thing that did NOT happen: applicationSupportDirectory was
    // never called. The portable test asserts zero invocations, and that
    // assertion is what fails if someone later adds a "just in case"
    // lookup — which is exactly how a "we write nothing outside our own
    // folder" promise gets quietly broken.
    return DataRootReady(root, portable: true);
  }

  // THE LOOKUP IS INSIDE THE TRY, AND THAT IS THE WHOLE POINT.
  // `getApplicationSupportDirectory()` is not a string lookup: on Windows
  // path_provider's `_createApplicationSubdirectory` itself runs
  // `directory.create(recursive: true)` on %APPDATA%\<Company>\<Product>,
  // and path_provider throws `MissingPlatformDirectoryException` when
  // `SHGetKnownFolderPath` answers E_INVALIDARG/E_FAIL. On a locked-down
  // or corrupted profile — the exact case the degraded mode below exists
  // for — that throw used to propagate out of this function, out of
  // `main()`, and past `runApp`: the Win32 window the runner already
  // created never got a Flutter view, so the user saw a dead window and
  // no error at all.
  //
  // [resolveDataRoot] THEREFORE NEVER THROWS. Every failure, including a
  // lookup that could not even name a directory, comes back as
  // [DataRootUnusable] and the app starts in the degraded session it
  // already knows how to run. `data_root_test.dart` asserts it for a
  // throwing lookup as well as a failing probe.
  final String support;
  try {
    support = await applicationSupportDirectory();
  } on Object catch (e) {
    return DataRootUnusable(
      // There is no path to name: the lookup is what failed. Empty is the
      // honest answer, and the degraded-mode banner reads from `portable`
      // and `cause`, never from a path it would have to invent.
      attemptedPath: '',
      portable: false,
      cause: e,
    );
  }

  try {
    await fs.createDirectory(support);
    await _probeWritable(fs, ctx, support);
  } on Object catch (e) {
    return DataRootUnusable(
      attemptedPath: support,
      portable: false,
      cause: e,
    );
  }
  return DataRootReady(support, portable: false);
}

Future<void> _probeWritable(FileStore fs, p.Context ctx, String root) async {
  final probe = ctx.join(root, kWritableProbeFileName);
  await fs.writeBytes(probe, _probeBytes);
  try {
    await fs.delete(probe);
    // A probe file we could write but not remove is untidy, not fatal —
    // the root IS writable, which is the only thing being established.
    // ignore: avoid_catches_without_on_clauses
  } catch (_) {}
}

final Uint8List _probeBytes = Uint8List.fromList('rackmate'.codeUnits);

// --- The two production environment lookups ----------------------------
//
// These are the ONLY reason this file imports `dart:io` and
// `path_provider`, and they contain no logic at all — everything
// decidable lives in [resolveDataRoot], above, which is pure and fully
// unit-tested. `main()` wires these two in; nothing else in the app may.

/// The directory containing the running executable.
///
/// UNUSABLE UNDER TEST, which is exactly why it is injected rather than
/// read inside [resolveDataRoot]: under `flutter test`,
/// `Platform.resolvedExecutable` points at the Dart test runner in the
/// SDK, so a portable-mode check performed here would look for
/// `portable.txt` next to `dart.exe`.
String productionExecutableDirectory() =>
    p.dirname(Platform.resolvedExecutable);

/// `%APPDATA%\<company>\<product>`, the installed-app data root.
///
/// THIS IS THE ONE CALL SITE IN THE ENTIRE APP, and
/// `test/storage/storage_layering_test.dart` asserts it. That single
/// assertion is the whole retrofit-prevention mechanism: M2's portable
/// build changes [resolveDataRoot] and nothing else, because no store can
/// reach around it.
///
/// ==================================================================
/// `path_provider_windows` DIRECTLY, NOT THE `path_provider` UMBRELLA
/// ==================================================================
/// SAME CODE, SAME PATH: on Windows the umbrella package does nothing but
/// forward to `PathProviderWindows.getApplicationSupportPath()`, which is
/// the call below. What the umbrella ALSO did was drag
/// `path_provider_android` into a Windows-only build, and that package
/// pulls the `jni` FFI plugin — so `dartjni.dll`, an Android JNI bridge,
/// was being copied into `build/windows/x64/runner/Release/` beside
/// `rackmate.exe` and would have shipped in the portable ZIP. Dead weight,
/// and one more unsigned native binary for an enterprise allowlist to
/// block. `flutter_dependency_test.dart` asserts it is gone.
///
/// A NULL IS A REAL OUTCOME, not an impossibility: `SHGetKnownFolderPath`
/// answers E_INVALIDARG/E_FAIL on a locked-down or corrupted profile,
/// which is exactly the case [DataRootUnusable] exists for. Throwing here
/// is what routes it into [resolveDataRoot]'s guard — which never
/// propagates, so the app starts in the degraded session it already knows
/// how to run.
Future<String> productionApplicationSupportDirectory() async {
  final path = await PathProviderWindows().getApplicationSupportPath();
  if (path == null) {
    throw StateError('Windows could not name an application support folder.');
  }
  return path;
}
